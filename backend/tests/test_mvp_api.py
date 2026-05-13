import json
from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine

from app.db import session as session_module
from app.db import engine as engine_module
from app.main import create_app
from app.models import DictionaryEntry, LlmCache


@pytest.fixture()
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Generator[TestClient, None, None]:
    test_engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}",
        connect_args={"check_same_thread": False},
    )

    monkeypatch.setattr(engine_module, "_ENGINE", test_engine)
    monkeypatch.setattr(engine_module, "get_engine", lambda: test_engine)
    monkeypatch.setattr(session_module, "get_engine", lambda: test_engine)
    SQLModel.metadata.create_all(test_engine)

    with TestClient(create_app()) as test_client:
        yield test_client


def _register(client: TestClient, email: str = "reader") -> str:
    response = client.post("/v1/users/register", json={"email": email})
    assert response.status_code == 201
    return response.json()["id"]


def _book(client: TestClient, user_id: str) -> dict:
    response = client.post(
        "/v1/books",
        json={
            "user_id": user_id,
            "title": "The River",
            "author": "River Reader",
            "language": "en",
            "file_hash": "hash-1",
            "chapters": [{"chapter_index": 0, "title": "Source", "href": "chapter.xhtml"}],
        },
    )
    assert response.status_code == 201
    return response.json()


def _highlight(client: TestClient, user_id: str, book_id: str) -> dict:
    response = client.post(
        "/v1/highlights",
        json={
            "user_id": user_id,
            "book_id": book_id,
            "target_word": "serene",
            "context_before": "The path bent toward water.",
            "context_sentence": "The river was serene under moonlight.",
            "context_after": "Nobody spoke for a while.",
            "chapter_index": 0,
            "chapter_title": "Source",
            "cfi": "epubcfi(/6/2[chapter])",
        },
    )
    assert response.status_code == 201
    return response.json()


def test_profile_crud_regression(client: TestClient) -> None:
    user_id = _register(client, "Reader")

    duplicate = client.post("/v1/users/register", json={"email": "reader"})
    assert duplicate.status_code == 409

    by_email = client.get("/v1/users/by-email/READER")
    assert by_email.status_code == 200
    assert by_email.json()["id"] == user_id

    patch = client.patch(
        f"/v1/users/{user_id}",
        json={"display_name": "River Friend", "learning_level": "B2"},
    )
    assert patch.status_code == 200
    assert patch.json()["display_name"] == "River Friend"
    assert patch.json()["learning_level"] == "B2"

    delete = client.delete(f"/v1/users/{user_id}")
    assert delete.status_code == 204


def test_home_summary_and_cors(client: TestClient) -> None:
    user_id = _register(client)
    book = _book(client, user_id)
    _highlight(client, user_id, book["id"])

    progress = client.put(
        f"/v1/books/{book['id']}/progress",
        json={
            "user_id": user_id,
            "chapter_index": 0,
            "chapter_title": "Source",
            "cfi": "epubcfi(/6/2[source])",
            "progress_percent": 12.25,
        },
    )
    assert progress.status_code == 200

    home = client.get(f"/v1/me/home?user_id={user_id}")
    assert home.status_code == 200
    payload = home.json()
    assert payload["user"]["id"] == user_id
    assert payload["stats"] == {
        "books_count": 1,
        "vault_count": 1,
        "due_reviews_count": 1,
    }
    assert payload["last_opened_book"]["id"] == book["id"]
    assert payload["last_progress"]["progress_percent"] == 12.25
    recent = payload["recent_vault_words"]
    assert isinstance(recent, list) and len(recent) >= 1
    assert recent[0]["target_word"] == "serene"
    assert recent[0]["book_title"] is not None

    preflight = client.options(
        "/v1/users/register",
        headers={
            "Origin": "http://localhost:8080",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert preflight.status_code == 200
    assert preflight.headers["access-control-allow-origin"] == "http://localhost:8080"


def test_book_progress_and_soft_delete_flow(client: TestClient) -> None:
    user_id = _register(client)
    book = _book(client, user_id)
    book_id = book["id"]
    assert book["chapters"][0]["title"] == "Source"

    duplicate = _book(client, user_id)
    assert duplicate["id"] == book_id

    progress = client.put(
        f"/v1/books/{book_id}/progress",
        json={
            "user_id": user_id,
            "chapter_index": 1,
            "chapter_title": "Next",
            "cfi": "epubcfi(/6/4[next])",
            "progress_percent": 42.5,
        },
    )
    assert progress.status_code == 200
    assert progress.json()["progress_percent"] == 42.5

    delete = client.delete(f"/v1/books/{book_id}?user_id={user_id}")
    assert delete.status_code == 204
    hidden = client.get(f"/v1/books?user_id={user_id}")
    assert hidden.status_code == 200
    assert hidden.json() == []


def test_highlight_vault_and_games_flow(client: TestClient) -> None:
    user_id = _register(client)
    book = _book(client, user_id)
    highlight = _highlight(client, user_id, book["id"])
    assert highlight["srs"]["mastery_level"] == 0

    vault = client.get(f"/v1/vault/search?user_id={user_id}&q=moonlight")
    assert vault.status_code == 200
    assert vault.json()[0]["target_word"] == "serene"

    deck = client.get(f"/v1/games/deck?user_id={user_id}&type=cloze")
    assert deck.status_code == 200
    item = deck.json()[0]
    assert "_____" in item["prompt"]
    assert item["correct_answer"] == "serene"

    answer = client.post(
        "/v1/games/answer",
        json={
            "user_id": user_id,
            "srs_item_id": item["srs_item_id"],
            "game_type": "cloze",
            "selected_answer": "serene",
            "is_correct": True,
        },
    )
    assert answer.status_code == 200
    assert answer.json()["grade"] == 4
    assert answer.json()["srs"]["repetitions"] == 1

    delete = client.delete(f"/v1/highlights/{highlight['id']}?user_id={user_id}")
    assert delete.status_code == 204
    assert client.get(f"/v1/vault?user_id={user_id}").json() == []


def test_srs_grade_endpoint_wrong_answer(client: TestClient) -> None:
    user_id = _register(client)
    book = _book(client, user_id)
    highlight = _highlight(client, user_id, book["id"])
    srs_item_id = highlight["srs"]["id"]

    response = client.post(
        f"/v1/reviews/{srs_item_id}/grade?user_id={user_id}",
        json={"is_correct": False, "selected_answer": "stormy", "game_type": "cloze"},
    )
    assert response.status_code == 200
    assert response.json()["grade"] == 0
    assert response.json()["srs"]["mastery_level"] == 0
    assert response.json()["srs"]["interval_days"] == 1


def test_empty_game_deck_dictionary_and_ai_cache(client: TestClient) -> None:
    user_id = _register(client)
    empty_deck = client.get(f"/v1/games/deck?user_id={user_id}")
    assert empty_deck.status_code == 200
    assert empty_deck.json() == []

    missing = client.get("/v1/dictionary/serene")
    assert missing.status_code == 404

    with Session(engine_module.get_engine()) as session:
        session.add(
            DictionaryEntry(
                word="Serene",
                word_normalized="serene",
                definition="Calm and peaceful.",
                synonyms_json=json.dumps(["calm", "peaceful"]),
                source="test",
            )
        )
        session.add(
            LlmCache(
                cache_key="not-used",
                payload_json=json.dumps({"definition": "Cached value"}),
            )
        )
        session.commit()

    hit = client.get("/v1/dictionary/SERENE")
    assert hit.status_code == 200
    assert hit.json()["synonyms"] == ["calm", "peaceful"]

    disabled = client.post("/v1/ai/define", json={"word": "serene"})
    assert disabled.status_code == 200
    assert disabled.json()["enabled"] is False
    assert disabled.json()["cached"] is False

    with Session(engine_module.get_engine()) as session:
        session.add(
            LlmCache(
                cache_key=disabled.json()["cache_key"],
                payload_json=json.dumps({"definition": "Cached value"}),
            )
        )
        session.commit()

    cached = client.post("/v1/ai/define", json={"word": "serene"})
    assert cached.status_code == 200
    assert cached.json()["cached"] is True
    assert cached.json()["payload"] == {"definition": "Cached value"}
