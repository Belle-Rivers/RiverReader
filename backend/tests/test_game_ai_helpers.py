import json
from collections.abc import Generator
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from sqlmodel import Session, SQLModel, create_engine

from app.db import engine as engine_module
from app.db import session as session_module
from app.models import DictionaryEntry, GameCache, Highlight
from app.services.ai_service import (
    _cache_needs_regeneration,
    _parse_cache,
    queue_replay_regeneration,
    resolve_true_or_bluff,
    resolve_word_meaning,
)


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
            "explanation": "Serene means calm, not loud.",
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
        "explanation": "Serene means calm.",
    }
    seen = {resolve_true_or_bluff(tb)[1] for _ in range(30)}
    assert seen == {True, False}


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
