# Progress Memory

## Current Approach
Keep River Reader split cleanly into a Flutter frontend and a FastAPI backend. Use the backend for user/profile CRUD via `/v1/*` routes, and keep Flutter screens thin: themed UI + small API clients that call the backend directly (configurable base URL for simulator/device testing). Database is PostgreSQL on Render (was SQLite locally). Backups are server-side (auto-save every 30 s) with manual export/import as a fallback.

---

## Completed Work

### Phase 1 — Backend Foundation
- Rewrote `pro_docs/backend.md` as the backend source of truth instead of only an API sketch.
- Added the FastAPI + SQLite direction and `/docs` workflow to the backend docs.
- Restored product detail for username-only profiles, reading progress, silent highlighting, Vault behavior, SRS, and games.
- Added system-collected user fields such as device install ID, timezone, locale, and subscription identifiers to the docs.
- Implemented the backend app title fix so Swagger shows `River Reader`.
- Added a root route that redirects `/` to `/docs` and a `favicon.ico` no-op route.
- Added a user registration CRUD surface at `/v1/users/*`.
- Extended the profile model, schema, and service with optional profile and entitlement metadata.
- Added SQLite startup initialization and table/column creation for the local database.
- Created the `progress-memory` skill in `~/.codex/skills`.
- Wired the Flutter frontend to backend registration: `POST /v1/users/register`.
- Added a themed registration page and route in Flutter at `/register`.
- Added a Home CTA to navigate to registration for iOS simulator testing.

### Phase 2 — Games (Groq/LLaMA Integration)
- Added 3 vocabulary games: **Complete the Sentence (Cloze)**, **Match Meanings**, **True or Bluff**.
- Integrated Groq's `llama-8b-instant` model via `ai_service.py` for AI game content generation.
- Built `GameCache` model: stores generated content per word, tracks `generation_status` (Pending / Ready / Failed).
- Built `GameApi` in Flutter, `game_session_controller.dart` state machine, `game_session_page.dart` UI.
- Added background sync (`game_backfill_provider`) to pre-generate game content for vault words.
- Added `game_decks_provider` to expose ready/pending deck counts.

### Phase 3 — Web Platform Support
- **Web reader gestures**: Adjusted the web reader to mirror iOS behaviour:
  - Double-tap → silent highlight capture.
  - Long-tap → emergency dictionary lookup.
- **EPUB parsing on web**: Fixed the chapter/index navigation so it works correctly in the browser WebView bridge.
- **Platform file storage**: Created `file_storage_manager.dart` with `_io.dart` / `_web.dart` / `stub.dart` splits so the same code compiles for mobile and web.
- **Web helper bridge**: Added `web_helper.dart` / `web_helper_stub.dart` / `web_helper_web.dart` for the `window.postMessage` bridge used to receive word captures and gesture events from the injected JS reader.
- **Error logging**: Added `error_logger.dart` for uncaught Flutter zone errors and framework errors.

### Phase 4 — Render Deployment

#### Render Deployment Fixes
1. **Backend: `ModuleNotFoundError: No module named 'httpx'`**
   - **Cause:** `httpx` was in `[project.optional-dependencies] dev` but used in production `ai_service.py`. Render's `uv` only installs main `dependencies`.
   - **Fix:** Moved `httpx>=0.27.0` from `dev` to `[project.dependencies]` in `pyproject.toml`.

2. **Backend: `Form data requires "python-multipart"`**
   - **Cause:** `python-multipart` was in `requirements.txt` but absent from `pyproject.toml`. Render reads only `pyproject.toml`.
   - **Fix:** Added `python-multipart>=0.0.9` to `[project.dependencies]`.

3. **Backend: No open ports detected on 0.0.0.0**
   - **Cause:** Uvicorn was binding to `127.0.0.1:8000` (localhost only); Render requires `0.0.0.0` and the `$PORT` env var.
   - **Fix:** Set Render start command to `uvicorn app.main:app --host 0.0.0.0 --port $PORT`.

4. **Frontend: Poetry/pip error on `requirements.txt`**
   - **Cause:** `frontend/requirements.txt` contained Dart syntax (`flutter_riverpod: ^2.5.1`), which pip can't parse. Render misdetected it as a Python project.
   - **Fix:** Deleted the invalid `requirements.txt` from `frontend/`.

5. **Frontend: `IconData` final class compile error**
   - **Cause:** `font_awesome_flutter: ^10.8.0` resolved to 10.12.0, which tries to extend `IconData`. Flutter 3.44.0 (used in Docker build) made `IconData` a `final class`.
   - **Fix:** Upgraded `font_awesome_flutter` from `^10.8.0` to `^11.0.0` in `pubspec.yaml`.

6. **Frontend deployment infrastructure**
   - Created `frontend/Dockerfile` for Flutter web build on Render (Docker runtime).
   - Created `frontend/.dockerignore` to exclude unnecessary files.
   - Created `render.yaml` at repo root to configure both backend and frontend services.

7. **Frontend: `GameApi` using wrong env-var name**
   - **Cause:** `game_api.dart` was reading `RIVER_READER_API_BASE_URL` but the env var set on Render is `RIVER_READER_API_URL`.
   - **Fix:** Changed `String.fromEnvironment('RIVER_READER_API_BASE_URL', …)` → `'RIVER_READER_API_URL'` in `game_api.dart`.

### Phase 5 — SQLite → PostgreSQL Migration

#### Migration Issues Fixed
1. **Boolean columns NULL after migration**
   - **Cause:** SQLite stores booleans as integers; after dumping and restoring in Postgres some `is_deleted` columns ended up `NULL` instead of `false`.
   - **Fix:** Added `_fix_postgresql_null_booleans()` that runs `UPDATE highlights SET is_deleted = false WHERE is_deleted IS NULL` (and same for `books`) on first startup against a Postgres engine.

2. **`asyncpg` vs `psycopg2` driver mismatch**
   - **Fix:** Used `psycopg2-binary` (synchronous) to stay compatible with SQLModel's synchronous session; added `psycopg2-binary` to `[project.dependencies]`.

3. **`get_entry_sync` / `dictionary_service` circular calls crashing under Postgres**
   - **Cause:** `ai_service.py` called `get_entry_sync()` from `dictionary_service`, which opened a new session inside an existing session context, causing issues under Postgres connection pooling.
   - **Fix:** Inlined the dictionary lookup directly with `session.exec(select(DictionaryEntry).where(...))` in both `resolve_word_meaning` and `_word_definition_from_dict` to use the caller's existing session.

4. **`_deck_rows` — games showing 0 words after migration**
   - **Cause:** The old logic was: "return SRS due items; if none, fall back to recent items." After migration, existing vault words had no SRS rows yet (SRS records weren't migrated), so both queries returned empty.
   - **Fix:** Rewrote `_deck_rows` to: (1) collect SRS due items, (2) top-up with recent items if < limit, (3) if still < limit, call `_ensure_srs_for_bare_highlights` which creates missing SRS rows on the fly for bare highlights.

5. **Cloze distractors using wrong word form**
   - **Cause:** `_word_choices` picked random vault words as distractors regardless of grammatical form — you'd see `"buzzed"` as the answer but `"happiness"` as a distractor, making the choice trivially obvious.
   - **Fix:** Added `_word_form_tag(word)` (detects `-ed`, `-ing`, `-ly`, `-tion`, etc.) and filtered distractors to match the target word's form. Falls back to global `DictionaryEntry` table, then to any vault word, so there are always 3 distractors.

6. **`True or Bluff` — wrong prompt / wrong justification phrasing**
   - **Cause:** The AI prompt for True or Bluff was not specifying clearly enough that the justification must match the actual verdict (true vs. bluff), leading to answers that said "the true statement uses…" even when the correct answer was bluff.
   - **Fix:** Rewrote the prompt in `ai_service.py` to explicitly state the expected output format and assert the justification must align with the verdict.

7. **`Odd One Out` — duplicate synonyms in AI response**
   - **Cause:** Groq occasionally returned a word in both `synonyms` and `misfit_word`, making the set of displayed words have a duplicate.
   - **Fix:** Added deduplication check in both `_cache_needs_regeneration` and `generate_game_content`; marks the cache as Failed/triggers re-generation if duplicates are detected.

8. **`Match Meanings` — only 2 words visible even after completing a round**
   - **Cause:** `_deck_rows` returned the same small set each time; also, after a full round the deck wasn't refreshed with new items.
   - **Fix:** The `_deck_rows` fix (#4 above) + the deduplication logic in `_deck_rows` (`seen_ids` set) prevent the same SRS item from appearing twice.

9. **Game answer submission blocking UI (timeout crashes)**
   - **Cause:** `submitAnswer()` (an HTTP call) was `await`-ed inside the game state machine. If the server was slow or the cloze/match timer fired, the `await` blocked the state update, causing the game to appear frozen or crash with an error state.
   - **Fix:** Changed all `submitAnswer` calls to fire-and-forget (`unawaited(...)`) — the state is updated immediately, and the API call resolves in the background. Errors are silently swallowed (`catchError`) since they don't affect local game progress.

10. **Failed game cache retried immediately, hammering Groq**
    - **Cause:** When `generate_game_content` failed (e.g., Groq rate-limit), it marked the cache `"Failed"`. The backfill provider would immediately retry on the next tick.
    - **Fix:** Added a 5-minute cooldown: if `generation_status == "Failed"` and `updated_at` was less than 5 minutes ago, skip regeneration.

### Phase 6 — Backup System

1. **Autosave duplicating vault words on each import**
   - **Cause:** `import_user_backup` was unconditionally `session.add(SrsItem(...))` for every SRS row in the payload, creating duplicate SRS entries for already-existing highlights.
   - **Fix:** Added `existing = session.exec(select(SrsItem).where(SrsItem.highlight_id == ...)).first()`. If the SRS row already exists, update its fields rather than inserting a new one.

2. **Backups moved from local file to server-side PostgreSQL**
   - Old approach: export/import JSON files saved to the device filesystem.
   - New approach: `POST /v1/users/{id}/backup` stores the backup JSON in the `UserBackup` table. `GET /v1/users/{id}/backup` returns the latest backup.
   - `backup_autosave_provider` now calls `registrationApi.triggerBackup(userId)` every 30 seconds instead of writing to disk.
   - Settings page updated: **Save now** (cloud upload) + **Download backup** (cloud download) + **Import backup from file** (manual fallback).

3. **Web: user lost session on browser refresh**
   - **Cause:** `sessionUserIdProvider` was in-memory only — on page reload the Riverpod state was wiped.
   - **Fix:** On `setUserId`, persist to `SharedPreferences` (→ `localStorage` on web). On app startup (`main.dart`), read `session_user_id` from `SharedPreferences` and pass it as a `ProviderScope` override so the session is restored before the first frame.
   - After session restore, the last backup is automatically downloaded and imported so the user's data is available immediately.

4. **Library shelf reading percentage not updating**
   - **Fix:** Invalidated the library state correctly after backup import so the reading percentage chips re-render.

### Phase 7 — Reader Word Capture Fixes

1. **Vault: search results persisting when leaving the Vault page**
   - **Cause:** The search query state was not cleared when navigating away from `vault_page.dart`.
   - **Fix:** Added a `dispose`/`onPageLeave` hook that resets the search provider back to an empty query.

2. **Dictionary lookup stripping `'s` possessives incorrectly**
   - **Cause:** When a user tapped "reader's", the full word including `'s` was sent to the dictionary API, returning no results.
   - **Fix:** Strip trailing `'s` (and `s'`) from the highlighted word before the dictionary lookup in `dictionary_api.dart`.

3. **Reader word capture firing twice for the same tap**
   - **Cause:** The web JS bridge could emit the same `postMessage` twice in rapid succession for a single double-tap on some browsers.
   - **Fix:** Added `_lastCapturedWord` + `_lastCapturedAt` debounce guard in `reader_page.dart`: if the same word arrives within 2 seconds of the last capture, the second event is ignored.

4. **Registration page missing show/hide password toggle**
   - **Fix:** Added an eye icon `IconButton` (`suffixIcon`) to the password field in `register_page.dart` to toggle `obscureText`.

---

## Current Status
- Backend: deployed and running on Render with PostgreSQL.
- Frontend: built via Docker and deployed on Render as a static web service.
- Games: all 3 games (Cloze, Match Meanings, True or Bluff) working with AI content.
- Backups: auto-saved to server every 30 s; browser refresh restores session automatically.
- Reader: web gestures match iOS; word capture debounced; dictionary strips possessives.

## Next Steps
- Verify end-to-end on production URL: register → read → highlight → play games.
- Add environment variables on Render: `RIVER_READER_API_URL` (frontend), `DATABASE_URL` (backend).
- Monitor Groq rate limits and cache hit rate in production logs.
- Consider adding a loading indicator while the backup auto-downloads on login restore.
