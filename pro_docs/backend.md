# River Reader Backend Source of Truth

This document is the single source of truth for building the `backend` folder. It keeps River Reader's backend separate from the Flutter frontend while preserving the product idea: users read for pleasure, silently collect difficult words, then optionally review them through a calm Vault or light games.

The backend must not turn River Reader into a school quiz app. Its job is to store reading data, protect the user's flow, generate useful review material, and expose clear API endpoints the frontend can call.

---

## 1) Backend Direction

Recommended MVP stack:

- **Python + FastAPI** for the HTTP API and automatic docs at `GET /docs`.
- **Uvicorn** as the local development server.
- **SQLite** as the no-cost local database (default). **PostgreSQL** supported via connection string for hosted deployments.
- **SQLModel** for models and DB access (SQLAlchemy + Pydantic).
- **Pydantic** for request/response validation.
- **httpx** for external API calls (dictionaryapi.dev, Groq).
- **python-multipart** for file uploads (EPUB).

Why this is suitable:

- FastAPI gives a clean API contract without heavy framework overhead.
- SQLite keeps the MVP cheap, local, inspectable, and easy to back up.
- The same API can later move from local development to a low-cost hosted backend.
- `/docs` is useful for debugging, but the real reason for this stack is clear data ownership and testable backend logic.

---

## 2) Architecture Boundary

The project remains separated:

- `frontend`: Flutter app, EPUB reader UI, haptics, visual feedback, offline UI cache.
- `backend`: API, database, user profile, books metadata, highlights, reading progress, Vault data, games, SRS, optional AI/dictionary enrichment.

The frontend should not directly own the main learning logic. It should send events to the backend and render the backend's response. The Dart client-side backend (`backend/lib/`) provides a local-first persistence layer that can operate independently of the Python API.

### Dart client-side backend (`backend/lib/`)

The `backend/` folder also contains a **Dart/Flutter package** (`river_reader_backend`) that provides a local-first persistence layer using `sqflite`. This is the Flutter-side companion to the Python FastAPI backend.

- `lib/river_reader_backend.dart` — barrel export
- `lib/src/database/database_service.dart` — local SQLite init with `books` and `ghost_highlights` tables
- `lib/src/library/book_repository.dart` — book CRUD (insertBook, getAllBooks, deleteBook)
- `lib/src/vault/highlight_repository.dart` — `GhostHighlight` CRUD (insert, getByBook)
- `lib/src/providers/backend_providers.dart` — Riverpod providers for all repositories
- `lib/src/storage/file_storage_manager.dart` — platform-conditional export (IO vs Web)
- `lib/src/storage/file_storage_manager_io.dart` — IO: paths for epubs, covers, dictionary, backups
- `lib/src/storage/file_storage_manager_web.dart` — Web: stub implementations
- `lib/src/error/error_logger.dart` — logging wrapper

This Dart package uses a simpler schema than the Python backend (integer IDs, `cover_path`/`epub_path` on books, `ghost_highlights` table). It is the original local persistence layer; the Python FastAPI backend was built later as a server-side supplement.

---

## 3) User Identity and Personalization

For MVP, use a lightweight local profile instead of full authentication.

### MVP profile approach

- **Registration** (`POST /v1/users/register`) creates a profile with `email` (unique, normalized), `display_name`, and optional fields.
- **Login** (`POST /v1/users/login`) verifies credentials by email + password.
- Passwords are hashed with **PBKDF2-SHA256** + random salt (not plain text).
- **Password recovery** uses security questions: `POST /v1/users/forgot-password` verifies the security answer and allows a password reset.
- `GET /v1/users/recovery-question/{email}` returns the security question for a given email.
- Duplicate email registration is rejected (409).
- The backend creates a `user_profiles` record.
- This profile controls personalization: greeting, reading stats, last opened book, Vault count, streak/progress.

### User data collected by the backend

Some user fields are entered manually, while others are collected by the app or purchase provider.

User-entered MVP fields:

- `email` (unique, normalized)
- `display_name`
- `hashed_password` (PBKDF2-SHA256 with random salt)
- `security_question` and `security_answer_hash` (for password recovery)
- optional `learning_level` (`B1`, `B2`, etc.) if onboarding asks for it

System-collected MVP fields:

- `device_install_id` for identifying the local install without requiring login.
- `preferred_locale` for language/formatting defaults.
- `timezone` for streaks, reading history, and daily review scheduling.
- `subscription_status` such as `free`, `trial`, `active`, `expired`, or `cancelled`.
- `app_store_product_id` for the selected Apple/Google subscription product.
- `app_store_original_transaction_id` for Apple's stable subscription identity.
- `subscription_expires_at` for entitlement checks.

These fields should be optional at registration because the frontend may learn them at different moments. For example, the profile can be created with only an email and password, then patched later when StoreKit returns subscription data.

---

## 4) Local Storage Strategy

Since the backend and frontend are separate, "local" has two meanings:

### Frontend local storage

Used for fast reader UX:

- active theme,
- current reader UI state,
- temporary offline highlight queue if backend is unavailable,
- cached last known homepage data.

### Backend local storage

Main source of truth:

- SQLite file at `backend/data/river_reader.db`.
- Stores user profile, books, reading positions, highlights, Vault entries, game sessions, and review history.
- EPUB files stored at `backend/data/books/{uuid}.epub` (uploaded via `POST /v1/books/upload`).
- The backend serves EPUB resources (cover, chapters, images) directly from stored files.

Future-proofing:

- use UUID primary keys,
- add `created_at` and `updated_at`,
- prefer soft deletes (`is_deleted`) for books/highlights,
- keep `file_hash` for reconnecting books if re-imported.

---

## 5) EPUB Book Processing

The frontend owns rendering through WebView/Epub.js, but the backend owns the book record and learning metadata.

### Import flow

1. User imports an `.epub` in Flutter.
2. Frontend extracts or sends metadata:
   - title,
   - author,
   - language,
   - cover path or cover reference,
   - file hash,
   - table of contents if available.
3. Backend creates/updates the `books` record.
4. If the same `file_hash` already exists, backend reconnects old highlights and reading progress instead of treating it as a totally new book.

### Implemented EPUB endpoints

- `POST /v1/books/upload` — multipart upload of an EPUB file. Backend saves the file to `data/books/{uuid}.epub`, parses metadata and chapters, and creates the book record.
- `GET /v1/books/{book_id}/file` — download the raw EPUB file.
- `GET /v1/books/{book_id}/cover` — serve the book's cover image extracted from the EPUB.
- `GET /v1/books/{book_id}/resources/{resource_path}` — serve any asset from inside the EPUB (images, CSS, fonts) for WebView rendering.
- `GET /v1/books/{book_id}/chapters/{chapter_index}/content` — extract and return a chapter's HTML and plain text content.

### EPUB processing responsibilities

Frontend:

- unzip/load EPUB assets for Epub.js,
- render chapters,
- calculate CFI/location,
- detect selected word and local text context,
- send book metadata and events to backend.

Current implementation status:

- ✅ Backend now exposes chapter content extraction endpoint: `GET /v1/books/{book_id}/chapters/{chapter_index}/content`
- ✅ This is used by frontend `InAppWebView` to provide real DOM text for JS capture during Phase 2

Backend:

- store book metadata,
- store chapter list / table of contents if provided,
- store reading progress,
- store highlight context and CFI,
- provide Vault/game data based on that stored reading data.

---

## 6) Reading Progress and "Continue Where You Left Off"

The backend must store enough location data for the homepage to reopen the exact book position.

### Store per book

Use a `reading_progress` table with:

- `id`
- `user_id`
- `book_id`
- `chapter_index`
- `chapter_title`
- `cfi`
- `progress_percent`
- `last_read_at`
- `updated_at`

### Save behavior

Frontend sends progress updates when:

- user changes page/chapter,
- user closes reader,
- app moves to background,
- every small interval while reading (for example every 10-20 seconds), but not on every scroll event.

### Continue behavior

Homepage calls:

- `GET /v1/me/home?user_id=…` — **implemented:** returns `user`, `stats` (`books_count`, `vault_count`, `due_reviews_count`, `total_xp`), `last_opened_book`, `last_progress`, and `recent_vault_words` (last five highlights, newest first, with `book_title` / `book_author` for UI).
- `GET /v1/books/{book_id}/progress`

Backend returns the last active book and CFI. Frontend opens the reader and asks Epub.js to navigate to that CFI.

---

## 7) Silent Highlighting (Core Product Behavior)

Silent highlighting is the main idea of River Reader. The user should feel almost no interruption while reading.

### UX rule

When the user marks a word:

- no permanent yellow highlight,
- no dictionary popup,
- no modal,
- no forced exercise,
- no visible study mode.

Allowed feedback:

- a very short shimmer/ink glint around the word (about 0.2-0.5 seconds),
- a light haptic tap,
- optionally a tiny fade that disappears immediately.

The text should return to normal after the feedback.

### Technical flow

1. Frontend detects a gesture on one word inside the EPUB WebView.
2. Frontend identifies:
   - `target_word`,
   - surrounding sentence,
   - previous sentence if available,
   - next sentence if available,
   - `book_id`,
   - chapter title/index,
   - exact `cfi`.
3. Frontend triggers haptic feedback and a short visual shimmer.
4. Frontend sends the capture payload to the backend asynchronously.
5. Backend stores it as a Vault item and creates/updates its SRS record.

Important: the database write must not block the reading interaction. If backend is temporarily unavailable, frontend can queue the capture locally and retry later.

### Context capture

For every silent highlight, save:

- target word,
- sentence containing the word,
- previous sentence,
- next sentence,
- book metadata,
- chapter title,
- CFI,
- timestamp.

This is what makes later games feel personal instead of generic.

---

## 8) Vault Behavior

The Vault is the user's collection of captured words.

### Highlights vs Vault (API shape)

- **`POST /v1/highlights`** is how the app **adds** a word to the Vault. The backend persists a highlight row (target word, context, CFI, chapter metadata, user, book). That row is what games and SRS build on.
- **`GET /v1/vault`** (and **`GET /v1/vault/search`**) are **read-only** views of the same captured data: a list or search tuned for the Vault UI. There is no `POST /v1/vault` by design—creating a highlight is the write path; the Vault endpoints only query.

Backend responsibilities:

- list captured words,
- search target words and context,
- group by book/source,
- expose mastery status,
- expose "jump to source" using stored CFI,
- support soft delete/archive.

Useful endpoints:

- `GET /v1/vault`
- `GET /v1/vault?book_id=...`
- `GET /v1/vault/search?q=...`
- `GET /v1/highlights/{highlight_id}`
- `DELETE /v1/highlights/{highlight_id}`
- `GET /v1/dictionary/{word}` (reader hint + Vault word details; `example_sentence` included in JSON when set — used by cloze generation)
- **Dev dictionary maintenance (populate SQLite `dictionary_entries`):**
  - `POST /v1/dictionary` — create (409 if `word_normalized` already exists)
  - `PUT /v1/dictionary/{word}` — upsert by normalized word from path
  - `PATCH /v1/dictionary/{word}` — partial update
  - `DELETE /v1/dictionary/{word}` — remove entry

Current implementation status:

- ✅ Vault filtering by `book_id` is now active in frontend
- ✅ Vault search query (`q`) is now active in frontend
- ✅ Vault word tap loads dictionary text via `DictionaryApi` (with loading state); reader double-tap uses the same lookup
- ✅ Dictionary service falls back to dictionaryapi.dev free API when local entry not found, auto-caches result to `dictionary_entries` table

Use SQLite FTS5 later for fast full-text search across `target_word`, `context_sentence`, and book title.

---

## 9) Games and Exercises

Games are optional reinforcement, not the core reading experience. The backend should generate game material from the user's own Vault.

### Existing MVP games from frontend

1. **Match Word with Meaning** (`meaning_match`)
   - Backend selects several highlights (one round, e.g. five pairs) and returns one row per word.
   - Each row shares the same shuffled `choices[]` list: the definitions for every word in that round (no extra distractors when there are multiple pairs—pairing is the challenge).
   - Frontend shows a **word grid** and a **definition list**; the user taps a word then its meaning. Each correct match posts `POST /v1/games/answer` with `response_time_ms` and gamification fields.
   - Wrong pairing applies a **time penalty** on the client (e.g. −3 seconds); SRS is not updated until a correct match.

2. **Complete the Sentence** (`cloze`)
   - Backend selects one highlight.
   - Backend replaces the target word in a newly generated example sentence (from dictionary or LLM) with a blank.
   - Backend provides the correct word plus distractor words from the Vault.
   - Frontend renders choices.
   - User answer updates mastery.

3. **Context Clash** (`context_clash`)
   - Backend selects a highlight and presents two similar-sounding or confusable words.
   - The user must pick which word fits the original sentence context.
   - Tests contextual word recognition without explicit definitions.

4. **Odd One Out** (`odd_one_out`)
   - Backend presents a group of words where one does not belong.
   - The user identifies the word that is semantically or contextually different.
   - Builds word association and categorization skills.

5. **True or Bluff** (`true_or_bluff`)
   - Backend generates two statements about a word: one true, one false (bluff).
   - The user picks which statement is true.
   - Uses side explanations for feedback when available.

### Gamification Fields
To align with the frontend UI, the backend stores the following fields on game answers:
- `combo_multiplier`: int (calculated client-side based on streak)
- `xp_earned`: int (base_xp * combo_multiplier)
- `response_time_ms`: int (time taken to answer, for match game timer tracking)

### Additional MVP-friendly game ideas

These are useful and easy for the backend to support:

- **Word Recall**
  - Show the sentence blank without choices.
  - User types the missing word.
  - Harder than multiple choice; can be optional.

- **Source Memory**
  - Show a word and ask which book/chapter it came from.
  - This reinforces reading memory without feeling academic.

- **Definition Reveal**
  - User guesses or taps "reveal" after seeing the sentence.
  - Useful when we do not want strict right/wrong pressure.

For MVP, prioritize:

1. Complete the Sentence
2. Match Word with Meaning
3. Definition Reveal (low pressure, very aligned with "reading for pleasure")

### Game session flow

1. Frontend requests due game items.
2. Backend returns a mixed deck based on SRS and recency.
3. Frontend renders by game type: **cloze** shows one sentence card at a time; **meaning_match** shows one round (several words + a shuffled definition list) until all pairs are matched.
4. Frontend posts result:
   - correct/incorrect,
   - selected answer,
   - response time if useful,
   - game type.
5. Backend stores a `review_event` and updates SRS state.

### Game cache and AI backfill

The backend maintains a `game_cache` table that pre-generates AI content for vault words. Each word can have cached content for multiple game types (cloze, context_clash, odd_one_out, true_or_bluff).

- `GET /v1/games/cache-status` — returns cache readiness stats (how many words have complete content).
- `POST /v1/games/backfill` — triggers global AI backfill for all pending words.
- `POST /v1/games/backfill/{user_id}` — triggers per-user AI backfill.
- `GET /v1/games/decks` — returns all 5 game type decks at once in a single response.

The `GameCache` row has a `generation_status` field (`pending`, `done`) and individual game type content fields (`cloze_json`, `context_clash_json`, `odd_one_out_json`, `true_or_bluff_json`). When a word's vault entry changes, `queue_replay_regeneration()` marks stale caches for re-generation.

### Game content validation

The `ai_service.py` includes validation helpers:
- `_cache_needs_regeneration()` — checks if cached content is stale or malformed.
- `_cloze_payload_valid()` — verifies cloze has blank, correct answer, and distractors.
- `_true_or_bluff_payload_valid()` — verifies both statements have explanations.
- `_text_contains_exact_word()` — ensures the word appears in generated text.
- `_is_definition_style_statement()` — validates statement format.

Useful endpoints:

- `GET /v1/games/deck?type=cloze&limit=10`
- `GET /v1/games/deck?type=meaning_match&limit=10`
- `POST /v1/games/answer`
- `GET /v1/reviews/due?limit=...`

---

## 10) Spaced Repetition (SRS)

Use a simple SM-2 inspired system.

Each highlight gets an `srs_item` with:

- repetitions,
- ease factor,
- interval days,
- next review date,
- mastery level.

Grades:

- 0 = forgot / wrong
- 3 = correct but hard
- 4 = correct
- 5 = easy

For multiple-choice games:

- correct answer usually maps to 4,
- wrong answer maps to 0-2,
- fast/easy correct answers can map to 5.

The backend should keep the algorithm isolated in a service so it can be tested without the API.

---

## 11) Dictionary and LLM Strategy

### No/low-cost default

The app should work without paid AI.

Use:

- local dictionary data from `dictionary_entries` table,
- **dictionaryapi.dev** free API as fallback (auto-cached to local DB on first lookup),
- WordNet-style definitions/synonyms,
- cached meanings,
- rule-based cloze generation from the captured sentence.

### Optional LLM usage

LLM is optional enrichment, not a dependency. Currently implemented with **Groq** (llama-3.1-8b-instant model) behind the `AI_ENABLED` feature flag.

Good LLM uses:

- simple definition adapted to the original sentence,
- friendly synonym suggestions,
- better distractors for meaning-match games,
- short example sentence after the user finishes a game.

Cost controls:

- feature flag: `AI_ENABLED=false` by default,
- cache all responses in `llm_cache`,
- never call AI repeatedly for the same word/context,
- prefer local models (`ollama`, `llama.cpp`) before hosted APIs.

---

## 12) Data Model (MVP Tables)

Core tables:

- `user_profiles`
  - `id`, `email`, `email_normalized` (unique), `hashed_password`, `security_question`, `security_answer_hash`, `display_name`, `device_install_id`, `preferred_locale`, `timezone`, `learning_level`, `subscription_status`, `app_store_product_id`, `app_store_original_transaction_id`, `subscription_expires_at`, `created_at`, `updated_at`

- `books`
  - `id`, `user_id`, `title`, `author`, `language`, `file_hash`, `cover_ref`, `created_at`, `updated_at`, `is_deleted`

- `book_chapters`
  - `id`, `book_id`, `chapter_index`, `title`, `href`, `created_at`

- `reading_progress`
  - `id`, `user_id`, `book_id`, `chapter_index`, `chapter_title`, `cfi`, `progress_percent`, `last_read_at`, `updated_at`

- `highlights`
  - `id`, `user_id`, `book_id`, `target_word`, `context_before`, `context_sentence`, `context_after`, `chapter_index`, `chapter_title`, `cfi`, `created_at`, `is_deleted`

- `srs_items`
  - `id`, `highlight_id` (unique), `ease_factor`, `interval_days`, `repetitions`, `mastery_level`, `next_review_at`, `last_review_at`

- `review_events`
  - `id`, `srs_item_id`, `game_type`, `grade`, `is_correct`, `selected_answer`, `answered_at`, `combo_multiplier`, `xp_earned`, `response_time_ms`

- `dictionary_entries`
  - `id`, `word`, `word_normalized` (unique), `definition`, `example_sentence`, `synonyms_json`, `source`

- `llm_cache`
  - `id`, `cache_key` (unique), `payload_json`, `created_at`

- `user_backups`
  - `user_id` (PK), `data` (JSON string), `updated_at`
  - Stores exported user data as a JSON blob for server-side backup and restore.

- `game_cache`
  - `id`, `word`, `word_normalized` (unique), `context_clash_json`, `odd_one_out_json`, `true_or_bluff_json`, `cloze_json`, `generation_status`, `created_at`, `updated_at`
  - Pre-generated AI content for each vault word. `generation_status` is `pending` or `done`. Individual game type fields store JSON payloads from the AI service.

---

## 13) API Surface

All product endpoints are versioned under `/v1`.

### Health and docs

- `GET /` — redirect to `/docs`
- `GET /health`
- `GET /docs`
- `GET /openapi.json`
- `GET /version`
- `GET /favicon.ico` — returns 204 No Content

### Profile

- `POST /v1/users/register`
- `POST /v1/users/login`
- `POST /v1/users/forgot-password`
- `GET /v1/users/recovery-question/{email}`
- `GET /v1/users`
- `GET /v1/users/by-email/{email}`
- `GET /v1/users/{user_id}`
- `PATCH /v1/users/{user_id}`
- `DELETE /v1/users/{user_id}`
- `GET /v1/me/home?user_id=…` (MVP: `user_id` query param; returns dashboard payload including `recent_vault_words`)

### Backup and export

- `GET /v1/users/{user_id}/export` — export full user data package (user profile, books, chapters, highlights, SRS items, review events, dictionary entries, game cache)
- `POST /v1/users/import` — import full user data package (clears existing data and recreates from import)
- `POST /v1/users/{user_id}/backup` — trigger server-side backup save to `user_backups` table
- `GET /v1/users/{user_id}/backup` — download stored backup JSON from `user_backups` table

### Books and progress

- `GET /v1/books`
- `POST /v1/books` — create book metadata
- `POST /v1/books/upload` — upload EPUB file (multipart)
- `GET /v1/books/{book_id}`
- `PATCH /v1/books/{book_id}` — update book metadata
- `DELETE /v1/books/{book_id}`
- `GET /v1/books/{book_id}/file` — download EPUB file
- `GET /v1/books/{book_id}/cover` — get book cover image
- `GET /v1/books/{book_id}/resources/{resource_path}` — get EPUB resource (images, CSS, etc.)
- `GET /v1/books/{book_id}/chapters/{chapter_index}/content` — get chapter HTML + plain text
- `GET /v1/books/{book_id}/progress`
- `PUT /v1/books/{book_id}/progress`

### Highlights and Vault

- `POST /v1/highlights`
- `GET /v1/highlights`
- `GET /v1/highlights/{highlight_id}`
- `DELETE /v1/highlights/{highlight_id}`
- `GET /v1/vault`
- `GET /v1/vault/search`

### Games and reviews

- `GET /v1/games/decks` — all 5 game type decks at once
- `GET /v1/games/deck` — single game type deck (`?type=cloze&limit=10`)
- `POST /v1/games/answer`
- `GET /v1/games/cache-status` — AI cache readiness stats
- `POST /v1/games/backfill` — global AI backfill
- `POST /v1/games/backfill/{user_id}` — per-user AI backfill
- `GET /v1/reviews/due`
- `POST /v1/reviews/{srs_item_id}/grade`

### Dictionary and optional AI

- `GET /v1/dictionary/{word}`
- `POST /v1/dictionary` — create dictionary row (409 if `word_normalized` exists)
- `PUT /v1/dictionary/{word}` — upsert
- `PATCH /v1/dictionary/{word}` — partial update
- `DELETE /v1/dictionary/{word}` — delete
- `POST /v1/ai/define`
- `POST /v1/ai/generate-distractors`

---

## 14) Target Backend Folder Structure

- `backend/`
  - `app/`
    - `__init__.py`
    - `main.py`
    - `settings.py`
    - `api/`
      - `__init__.py`
      - `ai_routes.py`
      - `book_routes.py`
      - `dictionary_routes.py`
      - `game_routes.py`
      - `health_routes.py`
      - `highlight_routes.py`
      - `me_routes.py`
      - `review_routes.py`
      - `root_routes.py`
      - `user_routes.py`
      - `vault_routes.py`
      - `version_routes.py`
    - `db/`
      - `__init__.py`
      - `engine.py`
      - `session.py`
    - `models/`
      - `__init__.py`
      - `reading.py`
      - `user_profile.py`
    - `schemas/`
      - `__init__.py`
      - `backup.py`
      - `health.py`
      - `home.py`
      - `profile.py`
      - `reading.py`
      - `version.py`
    - `services/`
      - `__init__.py`
      - `ai_service.py`
      - `backup_service.py`
      - `book_service.py`
      - `dictionary_service.py`
      - `epub_parser.py`
      - `game_service.py`
      - `highlight_service.py`
      - `home_service.py`
      - `profile_service.py`
      - `progress_service.py`
      - `srs_service.py`
      - `vault_service.py`
  - `lib/` — Dart/Flutter client-side backend package
    - `river_reader_backend.dart`
    - `src/`
      - `database/database_service.dart`
      - `error/error_logger.dart`
      - `library/book_repository.dart`
      - `providers/backend_providers.dart`
      - `storage/file_storage_manager.dart`
      - `storage/file_storage_manager_io.dart`
      - `storage/file_storage_manager_web.dart`
      - `vault/highlight_repository.dart`
  - `data/`
    - `river_reader.db`
    - `books/` — EPUB files stored as `{UUID}.epub`
    - `.gitkeep`
  - `tests/`
    - `test_mvp_api.py`
    - `test_game_ai_helpers.py`
  - `pyproject.toml`
  - `requirements.txt`
  - `pubspec.yaml` — Dart package manifest
  - `pubspec.lock`
  - `analysis_options.yaml` — Dart linter config
  - `.env` — environment variables (database URL, AI keys)
  - `.flutter-plugins-dependencies`

### Configuration (`app/settings.py`)

Uses Pydantic `BaseSettings` with env prefix `RIVER_READER_`. Key settings:

- `app_title`, `app_version` ("0.1.0")
- `api_v1_prefix` ("/v1")
- `ai_enabled` (default `False`)
- `groq_api_key` (from env)
- `database_url` (default SQLite at `sqlite:///data/river_reader.db`)
- `cors_allowed_origins` (list of localhost origins for dev)

### Service modules to expect:

- `profile_service.py` — user CRUD, login verification, password hashing (PBKDF2-SHA256), security question recovery
- `book_service.py` — book CRUD, dedup by file_hash
- `progress_service.py` — reading progress upsert and retrieval
- `highlight_service.py` — highlight CRUD, game cache pending insertion
- `vault_service.py` — vault listing, filtering, text search
- `srs_service.py` — SM-2 algorithm, due item listing, grading
- `game_service.py` — deck building for 5 game types, answer processing
- `dictionary_service.py` — local DB lookup + dictionaryapi.dev fallback with auto-caching
- `ai_service.py` — Groq LLM integration for game content generation, cache management
- `backup_service.py` — full user data export/import, server-side backup persistence
- `epub_parser.py` — EPUB zip parsing, chapter content extraction, resource extraction
- `home_service.py` — aggregated dashboard (user, stats, last book, recent words)

---

## 15) Implementation Phases

### Phase 0.5: Development-to-Production Migration

- Note: The FastAPI backend is a development tool. Production relies entirely on Flutter SQLite (`drift`).
- Ensure `drift` schema matches SQLite schema.
- Port SRS, Vault, Game, and Progress logic from Python to Dart.
- Replace HTTP calls in Flutter with direct DB calls.
- **Status:** Dart client-side backend (`backend/lib/`) provides local-first persistence via sqflite with `books` and `ghost_highlights` tables.

### Phase 1: API and database foundation ✅

- Create FastAPI app.
- Add `/health`, `/docs`, `/openapi.json`.
- Add SQLite connection and migrations.
- Create profile, books, reading progress, highlights, and SRS tables.

### Phase 2: Book and progress flow ✅

- Store imported EPUB metadata.
- Store chapter list if provided.
- Store and retrieve last reading CFI.
- Support "continue where you left off".
- EPUB upload, file download, cover, resource serving, and chapter content extraction.

### Phase 3: Silent capture engine ✅

- Accept highlight payloads from frontend.
- Store target word + context + source location.
- Create SRS item automatically.
- Support offline retry-friendly idempotency.
- Game cache pending insertion for new highlights.

### Phase 4: Vault and search ✅

- List Vault words.
- Filter by book/source/mastery.
- Add search with SQLite FTS5.
- Support jump-to-source via CFI.

### Phase 5: Games and SRS ✅

- Generate cloze decks.
- Generate meaning-match decks.
- Generate context_clash, odd_one_out, true_or_bluff decks.
- Store game answers.
- Update SM-2 schedule and mastery level.
- AI cache management and backfill.

### Phase 6: Dictionary and optional AI ✅

- Add local dictionary lookup.
- Dictionaryapi.dev fallback with auto-caching.
- Cached AI enrichment behind `AI_ENABLED` feature flag (Groq/llama-3.1-8b-instant).
- Generate better meanings and distractors only when low/no-cost strategy allows.

---

## 16) Non-Goals for MVP

- No mandatory paid AI.
- No PDF support.
- No permanent visible highlights in the reader.
- No exercises forced during reading.
- No frontend implementation changes in this documentation step.
- FastAPI is not the production delivery mechanism. It is a development and inspection tool. The production app uses drift (Flutter SQLite).

---

## 17) Configuration and Environment

### `app/settings.py`

Uses Pydantic `BaseSettings` with env prefix `RIVER_READER_`. All settings are overridable via environment variables.

### `.env` file

The `.env` file at `backend/` contains:

- `RIVER_READER_GROQ_API_KEY` — API key for Groq LLM service.
- `RIVER_READER_AI_ENABLED` — toggle for AI features (`true`/`false`).
- `RIVER_READER_DATABASE_URL` — database connection string (SQLite default, PostgreSQL supported).

### CORS

CORS is configured for local development. Allowed origins include multiple `localhost` variants (port 3000, 8080, etc.) to support Flutter web dev server and mobile emulator access.

### Database engine (`app/db/engine.py`)

- Creates the SQLModel engine from `settings.database_url`.
- `init_db()` creates all tables on startup.
- Supports both SQLite (local) and PostgreSQL (hosted) via connection string.

### Session dependency (`app/db/session.py`)

- `SessionDep` is a FastAPI `Depends` that yields a database session per request.
- Used by all route handlers for transactional access.

---

## 18) Tests

The backend includes a Python test suite under `tests/`.

### `test_mvp_api.py` (integration tests)

Full API flow tests covering:

- User profile CRUD (register, duplicate rejection, update, delete)
- Home dashboard stats and CORS preflight
- Book creation, dedup by file_hash, progress, soft delete
- Highlight → vault search → cloze deck → answer → delete flow
- Security question password recovery and backup round-trip (export/import)
- SRS grading for incorrect answers
- Empty game deck and dictionary CRUD edge cases

### `test_game_ai_helpers.py` (unit tests)

Focused tests for AI/game cache validation logic:

- Cache staleness detection for true_or_bluff, cloze, and missing justification
- Cloze payload validation (inflected word forms)
- True or bluff resolution (dual statements, side explanations)
- Word meaning resolution (dictionary-first, AI fallback)
- Cache regeneration queuing when vault changes
- Meaning match scanning past undefined vault words
