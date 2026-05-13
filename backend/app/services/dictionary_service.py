import json
import logging
from uuid import uuid4

import httpx
from sqlmodel import Session, select

from app.models import DictionaryEntry
from app.schemas import DictionaryEntryCreate, DictionaryEntryRead, DictionaryEntryUpdate

log = logging.getLogger(__name__)

_FREE_DICT_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/{word}"


def normalize_word(word: str) -> str:
    return word.strip().lower()


def _entry_to_read(entry: DictionaryEntry) -> DictionaryEntryRead:
    synonyms = json.loads(entry.synonyms_json or "[]")
    return DictionaryEntryRead(
        id=entry.id,
        word=entry.word,
        definition=entry.definition,
        synonyms=synonyms,
        example_sentence=entry.example_sentence,
        source=entry.source,
    )


def _parse_free_dict_response(word: str, data: list) -> DictionaryEntryCreate | None:
    """Extract the best definition, synonyms, and example from dictionaryapi.dev JSON."""
    if not data or not isinstance(data, list):
        return None

    entry_data = data[0]
    meanings = entry_data.get("meanings", [])
    if not meanings:
        return None

    definition = ""
    example_sentence: str | None = None
    synonyms: list[str] = []

    for meaning in meanings:
        defs = meaning.get("definitions", [])
        for d in defs:
            if not definition and d.get("definition"):
                definition = d["definition"]
            if not example_sentence and d.get("example"):
                example_sentence = d["example"]
        # Collect synonyms from meanings level
        for syn in meaning.get("synonyms", []):
            if syn not in synonyms:
                synonyms.append(syn)
        # Also from each definition
        for d in defs:
            for syn in d.get("synonyms", []):
                if syn not in synonyms:
                    synonyms.append(syn)
        if definition:
            break  # first meaningful entry is enough

    if not definition:
        return None

    return DictionaryEntryCreate(
        word=word.strip(),
        definition=definition,
        synonyms=synonyms[:10],  # cap to keep it clean
        example_sentence=example_sentence,
        source="dictionaryapi.dev",
    )


def _save_to_local_db(session: Session, payload: DictionaryEntryCreate) -> DictionaryEntry:
    """Persist a fetched entry so future lookups are instant (cache)."""
    normalized = normalize_word(payload.word)
    entry = DictionaryEntry(
        id=uuid4(),
        word=payload.word.strip(),
        word_normalized=normalized,
        definition=payload.definition.strip(),
        example_sentence=payload.example_sentence,
        synonyms_json=json.dumps(payload.synonyms),
        source=payload.source,
    )
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return entry


def get_entry_sync(session: Session, word: str) -> DictionaryEntryRead | None:
    """Synchronous local-DB-only lookup. Used by game_service (sync context)."""
    normalized = normalize_word(word)
    entry = session.exec(
        select(DictionaryEntry).where(DictionaryEntry.word_normalized == normalized)
    ).first()
    return _entry_to_read(entry) if entry is not None else None


async def get_entry(session: Session, word: str) -> DictionaryEntryRead | None:
    """Look up a word — local DB first, then free public dictionary API."""
    normalized = normalize_word(word)

    # 1. Try local DB (fastest)
    local = session.exec(
        select(DictionaryEntry).where(DictionaryEntry.word_normalized == normalized)
    ).first()
    if local is not None:
        return _entry_to_read(local)

    # 2. Fall back to dictionaryapi.dev (free, no key)
    url = _FREE_DICT_URL.format(word=normalized)
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
    except Exception as exc:
        log.warning("Free dictionary API unreachable for %r: %s", word, exc)
        return None

    if resp.status_code == 404:
        return None  # word genuinely not found
    if resp.status_code != 200:
        log.warning("Free dictionary API returned %s for %r", resp.status_code, word)
        return None

    payload = _parse_free_dict_response(word, resp.json())
    if payload is None:
        return None

    # 3. Cache the result locally so next lookup is instant
    try:
        cached = _save_to_local_db(session, payload)
        return _entry_to_read(cached)
    except Exception as exc:
        log.warning("Could not cache dictionary entry for %r: %s", word, exc)
        # Return transient result anyway
        from uuid import uuid4 as _uuid4
        return DictionaryEntryRead(
            id=str(_uuid4()),
            word=payload.word,
            definition=payload.definition,
            synonyms=list(payload.synonyms),
            example_sentence=payload.example_sentence,
            source=payload.source,
        )


def create_entry(session: Session, payload: DictionaryEntryCreate) -> DictionaryEntryRead:
    normalized = normalize_word(payload.word)
    existing = session.exec(
        select(DictionaryEntry).where(DictionaryEntry.word_normalized == normalized)
    ).first()
    if existing is not None:
        raise ValueError("dictionary entry already exists")
    synonyms_json = json.dumps(payload.synonyms)
    entry = DictionaryEntry(
        id=uuid4(),
        word=payload.word.strip(),
        word_normalized=normalized,
        definition=payload.definition.strip(),
        example_sentence=payload.example_sentence,
        synonyms_json=synonyms_json,
        source=payload.source,
    )
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return _entry_to_read(entry)


def upsert_entry(session: Session, word: str, payload: DictionaryEntryCreate) -> DictionaryEntryRead:
    normalized = normalize_word(word)
    entry = session.exec(
        select(DictionaryEntry).where(DictionaryEntry.word_normalized == normalized)
    ).first()
    synonyms_json = json.dumps(payload.synonyms)
    if entry is None:
        entry = DictionaryEntry(
            id=uuid4(),
            word=payload.word.strip(),
            word_normalized=normalized,
            definition=payload.definition.strip(),
            example_sentence=payload.example_sentence,
            synonyms_json=synonyms_json,
            source=payload.source,
        )
        session.add(entry)
    else:
        entry.word = payload.word.strip()
        entry.definition = payload.definition.strip()
        entry.example_sentence = payload.example_sentence
        entry.synonyms_json = synonyms_json
        entry.source = payload.source
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return _entry_to_read(entry)


def update_entry(
    session: Session, word: str, payload: DictionaryEntryUpdate
) -> DictionaryEntryRead | None:
    normalized = normalize_word(word)
    entry = session.exec(
        select(DictionaryEntry).where(DictionaryEntry.word_normalized == normalized)
    ).first()
    if entry is None:
        return None
    if payload.definition is not None:
        entry.definition = payload.definition.strip()
    if payload.synonyms is not None:
        entry.synonyms_json = json.dumps(payload.synonyms)
    if payload.example_sentence is not None:
        entry.example_sentence = payload.example_sentence
    if payload.source is not None:
        entry.source = payload.source
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return _entry_to_read(entry)


def delete_entry(session: Session, word: str) -> bool:
    normalized = normalize_word(word)
    entry = session.exec(
        select(DictionaryEntry).where(DictionaryEntry.word_normalized == normalized)
    ).first()
    if entry is None:
        return False
    session.delete(entry)
    session.commit()
    return True
