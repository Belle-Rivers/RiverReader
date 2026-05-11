# River Reader Backend MVP Core Plan

## Summary
Build the full MVP backend surface described in `pro_docs/backend.md`, using the existing FastAPI + SQLModel + SQLite structure. Keep the current username-only profile CRUD, then add the missing backend services for books, chapters, reading progress, silent highlights/Vault, SRS reviews, game decks, dictionary lookup, and cached AI enrichment stubs.

Chosen defaults:
- Product endpoints use explicit `user_id` query/body fields.
- Books and highlights use soft delete via `is_deleted=true`.
- AI endpoints exist behind settings/cache, but do not call a real provider yet.

## Key Changes
- Add SQLModel tables for:
  - `Book`, `BookChapter`, `ReadingProgress`
  - `Highlight`, `SrsItem`, `ReviewEvent`
  - `DictionaryEntry`, `LlmCache`
- Add Pydantic schemas for create/update/read payloads for each domain.
- Add service modules:
  - `book_service.py`: create/list/get/update/delete books, upsert chapters, enforce user ownership.
  - `progress_service.py`: get/upsert reading progress per `user_id + book_id`.
  - `highlight_service.py`: create/list/get/soft-delete highlights and automatically create an SRS item.
  - `vault_service.py`: list/search visible highlights with book/source/SRS metadata.
  - `srs_service.py`: isolate SM-2 inspired grading, due review queries, and review event writes.
  - `game_service.py`: generate cloze, meaning-match, and definition-reveal deck items from due/recent Vault items.
  - `dictionary_service.py`: local dictionary lookup by normalized word.
  - `ai_service.py`: cached placeholder endpoints controlled by settings, returning cached data or disabled responses.
- Add route modules under `/v1`:
  - `books`: `GET/POST /books`, `GET/PATCH/DELETE /books/{book_id}`, `GET/PUT /books/{book_id}/progress`
  - `highlights`: `POST/GET /highlights`, `GET/DELETE /highlights/{highlight_id}`
  - `vault`: `GET /vault`, `GET /vault/search`
  - `reviews`: `GET /reviews/due`, `POST /reviews/{srs_item_id}/grade`
  - `games`: `GET /games/deck`, `POST /games/answer`
  - `dictionary`: `GET /dictionary/{word}`
  - `ai`: `POST /ai/define`, `POST /ai/generate-distractors`
- Extend startup DB initialization to register all models and add minimal additive column/table creation compatible with the current lightweight SQLite approach.

## API Behavior
- `user_id` is required for user-owned reads/writes unless the route is global health/version/dictionary.
- Book creation accepts title, author, language, file hash, cover reference, and optional chapter list.
- Duplicate active books for the same `user_id + file_hash` return the existing book or update metadata instead of creating a second active copy.
- Reading progress is one row per `user_id + book_id`, updated through `PUT /books/{book_id}/progress`.
- Highlight creation stores target word, surrounding context, chapter/CFI metadata, creates an initial SRS item, and returns the highlight with review state.
- Vault listing excludes soft-deleted highlights and supports filters for `user_id`, `book_id`, mastery range, and search query.
- Game deck generation uses due SRS items first, then recent highlights as fallback, with deterministic local distractors where possible.
- Review grading writes `ReviewEvent`, updates `SrsItem`, and maps wrong answers to low grades and correct answers to grade `4` unless an explicit grade is supplied.
- Dictionary lookup normalizes words case-insensitively and returns `404` when no local entry exists.
- AI endpoints check an `ai_enabled` setting, use `llm_cache` by cache key, and return a clear disabled response when no cached value exists.

## Test Plan
- Add backend tests with FastAPI `TestClient` and an isolated SQLite test database.
- Cover profile regression: register, duplicate username conflict, update metadata, delete.
- Cover book/progress flow: create book with chapters, list by user, upsert progress, soft delete hides from list.
- Cover highlight/Vault flow: create highlight, auto-create SRS item, list/search Vault, soft delete highlight.
- Cover SRS logic directly: first correct answer, repeated correct answer, wrong answer reset/short interval.
- Cover games: cloze deck blanks target word, meaning-match includes correct answer, empty deck returns an empty list.
- Cover dictionary/AI: dictionary miss/hit, AI disabled response, cached AI response.

## Assumptions
- No password authentication, JWT, or hosted multi-user auth is added in this pass.
- No real LLM provider integration or external network calls are added.
- SQLite remains at `backend/data/river_reader.db` for local development.
- Soft-deleted records remain queryable only through internal services/tests, not normal user-facing list endpoints.
- Existing Flutter/Dart local backend package under `backend/lib` is left untouched unless Python backend tests expose an unavoidable conflict.
