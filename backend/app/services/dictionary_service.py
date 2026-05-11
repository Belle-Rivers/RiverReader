import json

from sqlmodel import Session, select

from app.models import DictionaryEntry
from app.schemas import DictionaryEntryRead


def normalize_word(word: str) -> str:
    return word.strip().lower()


def get_entry(session: Session, word: str) -> DictionaryEntryRead | None:
    statement = select(DictionaryEntry).where(
        DictionaryEntry.word_normalized == normalize_word(word)
    )
    entry = session.exec(statement).first()
    if entry is None:
        return None
    synonyms = json.loads(entry.synonyms_json or "[]")
    return DictionaryEntryRead(
        id=entry.id,
        word=entry.word,
        definition=entry.definition,
        synonyms=synonyms,
        source=entry.source,
    )
