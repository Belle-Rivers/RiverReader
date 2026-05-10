# River Reader Backend Source of Truth

This document is the single source of truth for building the `backend` folder. It keeps River Reader's backend separate from the Flutter frontend while preserving the product idea: users read for pleasure, silently collect difficult words, then optionally review them through a calm Vault or light games.

The backend must not turn River Reader into a school quiz app. Its job is to store reading data, protect the user's flow, generate useful review material, and expose clear API endpoints the frontend can call.

---

## 1) Backend Direction

Recommended MVP stack:

- **Python + FastAPI** for the HTTP API and automatic docs at `GET /docs`.
- **Uvicorn** as the local development server.
- **SQLite** as the no-cost local database.
- **SQLModel** or **SQLAlchemy** for models and DB access.
- **Pydantic** for request/response validation.

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

The frontend should not directly own the main learning logic. It should send events to the backend and render the backend's response.

---

## 3) User Identity and Personalization

For MVP, use a lightweight local profile instead of full authentication.

### MVP profile approach

- User enters a **display name** or username only.
- No password required in the first MVP if the app is local/single-user.
- The backend creates a local `user_profile` record.
- This profile controls personalization: greeting, reading stats, last opened book, Vault count, streak/progress.

### Optional password later

Add username + password only if:

- multiple people use the same app/device,
- the backend becomes hosted online,
- cloud sync is introduced.

If passwords are added later:

- store only hashed passwords using `bcrypt` or `argon2`,
- use session/JWT auth,
- never store plain text passwords.

For now, the preferred MVP path is **username-only personalization** because it keeps friction low and matches the personal reading habit.

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
- Raw EPUB files can remain in frontend/device storage for MVP, while backend stores metadata and references.

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

### EPUB processing responsibilities

Frontend:

- unzip/load EPUB assets for Epub.js,
- render chapters,
- calculate CFI/location,
- detect selected word and local text context,
- send book metadata and events to backend.

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

- `GET /v1/me/home`
- or `GET /v1/books/{book_id}/progress`

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

Use SQLite FTS5 later for fast full-text search across `target_word`, `context_sentence`, and book title.

---

## 9) Games and Exercises

Games are optional reinforcement, not the core reading experience. The backend should generate game material from the user's own Vault.

### Existing MVP games from frontend

1. **Match Word with Meaning**
   - Backend selects one highlighted word.
   - Backend provides the correct meaning.
   - Backend provides 2-3 distractor meanings from other Vault words or dictionary entries.
   - Frontend renders choices.
   - User answer is posted back for scoring/SRS.

2. **Complete the Sentence**
   - Backend selects one highlight.
   - Backend replaces the target word in `context_sentence` with a blank.
   - Backend provides the correct word plus distractor words from the Vault.
   - Frontend renders choices.
   - User answer updates mastery.

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
3. Frontend displays one card at a time.
4. Frontend posts result:
   - correct/incorrect,
   - selected answer,
   - response time if useful,
   - game type.
5. Backend stores a `review_event` and updates SRS state.

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

- local dictionary data,
- WordNet-style definitions/synonyms,
- cached meanings,
- rule-based cloze generation from the captured sentence.

### Optional LLM usage

LLM is optional enrichment, not a dependency.

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
  - `id`, `username`, `display_name`, `created_at`, `updated_at`

- `books`
  - `id`, `user_id`, `title`, `author`, `language`, `file_hash`, `cover_ref`, `created_at`, `updated_at`, `is_deleted`

- `book_chapters`
  - `id`, `book_id`, `chapter_index`, `title`, `href`, `created_at`

- `reading_progress`
  - `id`, `user_id`, `book_id`, `chapter_index`, `chapter_title`, `cfi`, `progress_percent`, `last_read_at`, `updated_at`

- `highlights`
  - `id`, `user_id`, `book_id`, `target_word`, `context_before`, `context_sentence`, `context_after`, `chapter_index`, `chapter_title`, `cfi`, `created_at`, `is_deleted`

- `srs_items`
  - `id`, `highlight_id`, `ease_factor`, `interval_days`, `repetitions`, `mastery_level`, `next_review_at`, `last_review_at`

- `review_events`
  - `id`, `srs_item_id`, `game_type`, `grade`, `is_correct`, `selected_answer`, `answered_at`

- `dictionary_entries`
  - `id`, `word`, `definition`, `synonyms_json`, `source`

- `llm_cache`
  - `id`, `cache_key`, `payload_json`, `created_at`

---

## 13) API Surface

All product endpoints are versioned under `/v1`.

### Health and docs

- `GET /health`
- `GET /docs`
- `GET /openapi.json`
- `GET /v1/version`

### Profile

- `GET /v1/me`
- `POST /v1/me`
- `PATCH /v1/me`
- `GET /v1/me/home`

### Books and progress

- `GET /v1/books`
- `POST /v1/books`
- `GET /v1/books/{book_id}`
- `DELETE /v1/books/{book_id}`
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

- `GET /v1/games/deck`
- `POST /v1/games/answer`
- `GET /v1/reviews/due`
- `POST /v1/reviews/{srs_item_id}/grade`

### Dictionary and optional AI

- `GET /v1/dictionary/{word}`
- `POST /v1/ai/define`
- `POST /v1/ai/generate-distractors`

---

## 14) Target Backend Folder Structure

- `backend/`
  - `app/`
    - `main.py`
    - `api/`
    - `db/`
    - `models/`
    - `schemas/`
    - `services/`
    - `settings.py`
  - `data/`
  - `tests/`
  - `pyproject.toml` or `requirements.txt`

Service modules to expect:

- `profile_service.py`
- `book_service.py`
- `progress_service.py`
- `highlight_service.py`
- `vault_service.py`
- `srs_service.py`
- `game_service.py`
- `dictionary_service.py`
- `ai_service.py`

---

## 15) Implementation Phases

### Phase 1: API and database foundation

- Create FastAPI app.
- Add `/health`, `/docs`, `/openapi.json`.
- Add SQLite connection and migrations.
- Create profile, books, reading progress, highlights, and SRS tables.

### Phase 2: Book and progress flow

- Store imported EPUB metadata.
- Store chapter list if provided.
- Store and retrieve last reading CFI.
- Support "continue where you left off".

### Phase 3: Silent capture engine

- Accept highlight payloads from frontend.
- Store target word + context + source location.
- Create SRS item automatically.
- Support offline retry-friendly idempotency.

### Phase 4: Vault and search

- List Vault words.
- Filter by book/source/mastery.
- Add search with SQLite FTS5.
- Support jump-to-source via CFI.

### Phase 5: Games and SRS

- Generate cloze decks.
- Generate meaning-match decks.
- Store game answers.
- Update SM-2 schedule and mastery level.

### Phase 6: Dictionary and optional AI

- Add local dictionary lookup.
- Add cached AI enrichment behind feature flag.
- Generate better meanings and distractors only when low/no-cost strategy allows.

---

## 16) Non-Goals for MVP

- No mandatory paid AI.
- No heavy authentication unless hosting/cloud sync requires it.
- No PDF support.
- No permanent visible highlights in the reader.
- No exercises forced during reading.
- No frontend implementation changes in this documentation step.

