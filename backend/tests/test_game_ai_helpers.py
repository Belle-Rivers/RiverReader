import json
from collections.abc import Generator
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from sqlmodel import Session, SQLModel, create_engine

from app.db import engine as engine_module
from app.db import session as session_module
from app.models import Book, DictionaryEntry, GameCache, Highlight, SrsItem
from app.services.ai_service import (
    _cache_needs_regeneration,
    _cloze_payload_valid,
    _parse_cache,
    _true_or_bluff_payload_valid,
    queue_replay_regeneration,
    resolve_true_or_bluff,
    resolve_word_meaning,
)
from app.services.game_service import _meaning_match_deck


@pytest.fixture()
def session(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Generator[Session, None, None]:
    test_engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}",
        connect_args={"check_same_thread": False},
    )
    monkeypatch.setattr(engine_module, "_ENGINE", test_engine)
    monkeypatch.setattr(engine_module, "get_engine", lambda: test_engine)
    monkeypatch.setattr(session_module, "get_engine", lambda: test_engine)
    SQLModel.metadata.create_all(test_engine)
    with Session(test_engine) as db_session:
        yield db_session


def _completed_cache(**overrides) -> GameCache:
    payload = {
        "word_meaning": "calm and peaceful",
        "context_clash": {
            "correct_sentence": "She was serene by the lake.",
            "clash_sentence": "She was serene and shouted loudly.",
            "explanation": "Serene means calm.",
        },
        "odd_one_out": {
            "synonyms": ["calm", "peaceful", "tranquil"],
            "misfit_word": "loud",
            "misfit_definition": "making much noise",
            "justification": "Loud is not calm like serene.",
        },
        "true_or_bluff": {
            "true_statement": "A serene lake reflects the sky quietly.",
            "bluff_statement": "A serene lake roars like thunder.",
            "true_explanation": "The true statement uses serene for a calm, quiet lake.",
            "bluff_explanation": "The bluff statement misuses serene because roaring is noisy, not calm.",
        },
        "cloze": {"sentence": "The garden felt serene at dawn.", "word_meaning": "calm and peaceful"},
    }
    payload.update(overrides)
    return GameCache(
        word="serene",
        word_normalized="serene",
        context_clash_json=json.dumps(payload["context_clash"]),
        odd_one_out_json=json.dumps(payload["odd_one_out"]),
        true_or_bluff_json=json.dumps(payload["true_or_bluff"]),
        cloze_json=json.dumps(payload["cloze"]),
        generation_status="Completed",
        updated_at=datetime.now(timezone.utc),
    )


def test_cache_needs_regeneration_for_legacy_true_or_bluff() -> None:
    cache = _completed_cache()
    cache.true_or_bluff_json = json.dumps({"statement": "Serene means loud.", "is_true": False})
    assert _cache_needs_regeneration(cache) is True


def test_cache_needs_regeneration_for_true_or_bluff_without_target_word() -> None:
    cache = _completed_cache()
    tb = json.loads(cache.true_or_bluff_json)
    tb["true_statement"] = "A quiet lake reflects the sky."
    cache.true_or_bluff_json = json.dumps(tb)
    assert _cache_needs_regeneration(cache) is True


def test_cache_needs_regeneration_for_bad_cloze_form() -> None:
    cache = _completed_cache()
    cache.word = "buzzed"
    cache.word_normalized = "buzzed"
    cache.cloze_json = json.dumps(
        {"sentence": "The crowd began to buzzed with excitement.", "word_meaning": "made a low sound"}
    )
    assert _cache_needs_regeneration(cache) is True


def test_cloze_payload_valid_allows_exact_inflected_form() -> None:
    assert _cloze_payload_valid(
        {"sentence": "The crowd buzzed with excitement after the announcement."},
        "buzzed",
    )


def test_cache_needs_regeneration_for_missing_justification() -> None:
    cache = _completed_cache()
    oo = json.loads(cache.odd_one_out_json)
    oo.pop("justification")
    cache.odd_one_out_json = json.dumps(oo)
    assert _cache_needs_regeneration(cache) is True


def test_resolve_true_or_bluff_picks_dual_statements() -> None:
    tb = {
        "true_statement": "A serene place is quiet.",
        "bluff_statement": "A serene place is always noisy.",
        "true_explanation": "The true statement uses serene for a calm place.",
        "bluff_explanation": "The bluff statement misuses serene because noisy places are not calm.",
    }
    seen = {resolve_true_or_bluff(tb)[1] for _ in range(30)}
    assert seen == {True, False}


def test_true_or_bluff_payload_requires_side_explanations() -> None:
    assert not _true_or_bluff_payload_valid(
        {
            "true_statement": "A serene lake feels calm.",
            "bluff_statement": "A serene room is always chaotic.",
            "explanation": "The true statement uses serene correctly.",
        },
        "serene",
    )


def test_resolve_true_or_bluff_legacy_payload() -> None:
    statement, is_true, explanation = resolve_true_or_bluff(
        {"statement": "Serene days are calm.", "is_true": True, "explanation": "ok"}
    )
    assert statement == "Serene days are calm."
    assert is_true is True
    assert explanation == "ok"


def test_resolve_word_meaning_prefers_dictionary(session: Session) -> None:
    session.add(
        DictionaryEntry(
            word="Serene",
            word_normalized="serene",
            definition="Calm and peaceful.",
            source="test",
        )
    )
    session.commit()
    meaning = resolve_word_meaning(session, "serene", {"word_meaning": "ai meaning"})
    assert meaning == "Calm and peaceful."


def test_resolve_word_meaning_falls_back_to_ai(session: Session) -> None:
    meaning = resolve_word_meaning(session, "serene", {"word_meaning": "calm and quiet"})
    assert meaning == "calm and quiet"


def test_parse_cache_extracts_word_meaning() -> None:
    parsed = _parse_cache(_completed_cache())
    assert parsed is not None
    assert parsed["word_meaning"] == "calm and peaceful"


def test_queue_replay_regeneration_when_vault_unchanged(session: Session) -> None:
    user_id = uuid4()
    highlight_at = datetime.now(timezone.utc) - timedelta(hours=2)
    cache = _completed_cache()
    cache.updated_at = datetime.now(timezone.utc) - timedelta(hours=1)
    session.add(cache)
    session.add(
        Highlight(
            user_id=user_id,
            book_id=uuid4(),
            target_word="serene",
            context_sentence="The river was serene.",
            chapter_index=0,
            created_at=highlight_at,
        )
    )
    session.commit()

    queued = queue_replay_regeneration(session, user_id, [("serene", "ctx")], limit=3)
    assert queued == [("serene", "ctx")]
    refreshed = session.get(GameCache, cache.id)
    assert refreshed is not None
    assert refreshed.generation_status == "Pending"


def test_meaning_match_scans_past_undefined_vault_words(session: Session) -> None:
    user_id = uuid4()
    book = Book(user_id=user_id, title="The River")
    session.add(book)
    session.commit()

    rows = []
    for word in ["first", "second", "third", "fourth", "fifth"]:
        highlight = Highlight(
            user_id=user_id,
            book_id=book.id,
            target_word=word,
            context_sentence=f"The word was {word}.",
        )
        session.add(highlight)
        session.commit()
        srs_item = SrsItem(highlight_id=highlight.id)
        session.add(srs_item)
        rows.append((srs_item, highlight))

    for word in ["third", "fourth", "fifth"]:
        session.add(
            DictionaryEntry(
                word=word,
                word_normalized=word,
                definition=f"{word} definition",
                source="test",
            )
        )
    session.commit()

    deck = _meaning_match_deck(session, user_id, rows, limit=3)

    assert [item.target_word for item in deck] == ["third", "fourth", "fifth"]
    assert {item.correct_answer for item in deck} == {
        "third definition",
        "fourth definition",
        "fifth definition",
    }
