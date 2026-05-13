# RiverReader — Implementation Plan (Settled)

## ✅ Architecture (Final Decision)

**Local-First with `drift` (Flutter SQLite) for production. FastAPI for development only.**

| Layer | Tool | Purpose |
|---|---|---|
| **Flutter (production)** | `drift` (SQLite on device) | Primary data store for all users |
| **FastAPI (development)** | Python + SQLite | Swagger UI, DB inspection, prototyping logic |
| **Cloud sync (future IAP)** | Supabase | Premium feature: sync across devices |

> [!IMPORTANT]
> The FastAPI backend is a **developer tool only** — it never ships to users. When a user installs RiverReader from the App Store or Google Play, all data lives in `drift` SQLite on their device. No server needed. Zero cost.

---

## 📍 When to Switch from FastAPI → drift

This is the clearest possible answer to "when do I stop using FastAPI and switch to local storage":

```
PHASE                    TOOL               REASON
─────────────────────────────────────────────────────────────
Development (now)        FastAPI + SQLite   Swagger UI, fast iteration, inspect DB
Before first TestFlight  Migrate to drift   All logic ported to Dart; FastAPI stays as dev tool
App Store submission     drift only         No Python needed. Just build and submit Flutter app
When adding cloud sync   drift + Supabase   Supabase added behind IAP paywall for premium users
```

### Transition Checklist (FastAPI → drift)

Tick these off before submitting to the App Store:

- [ ] `drift` schema matches current SQLite schema (`users`, `books`, `highlights`, `srs_items`, `review_events`, `reading_progress`, `dictionary_entries`)
- [ ] SM-2 SRS algorithm ported to Dart (`srs_service.py` → `srs_repository.dart`)
- [ ] Game deck generation ported to Dart (`game_service.py` → `game_repository.dart`)
- [ ] Vault query with search ported to Dart (`vault_service.py` → `vault_repository.dart`)
- [ ] Reading progress save/load ported to Dart (`progress_service.py` → `progress_repository.dart`)
- [ ] All HTTP API calls in Flutter replaced with direct `drift` DB calls
- [ ] FastAPI backend kept on your Mac for admin/debugging (it's still useful for you, just not for users)

---

## 🎮 Games: Backend Contract + Gamification Alignment

### The Two MVP Games

Both games are powered by **words from the user's Vault** (captured highlights). The backend already has this logic in `game_service.py`. The frontend UI already has the visual shell in `game_session_page.dart` but uses hardcoded mock data.

#### Game 1: Complete the Sentence (`cloze`)
- Backend selects a vault word and returns a **newly generated sentence** containing the word (NOT the captured `context_sentence` from the book)
- The `context_sentence` is for Vault reference only — it shows the user where they first saw the word
- The game sentence must be different from the capture context so the user is tested on their knowledge of the word in a new context, not just recognising the original sentence
- Returns 3 distractor words (other vault words) + the correct word as `choices[]`
- Frontend renders the new sentence with the word blanked + word option tiles
- User taps a word → frontend submits answer → backend updates SRS

> [!IMPORTANT]
> **Backend change needed in `game_service.py`:** The `_blank_word()` function currently uses `highlight.context_sentence`. This must be replaced with a source for **new example sentences**. For MVP without AI, this comes from `dictionary_entries.example_sentence` (a new field to add to the dictionary table). When AI is enabled, the LLM generates a fresh sentence.

#### Game 2: Match the Word (`meaning_match`)
- Backend selects multiple highlights and returns words + their definitions
- Frontend displays words in one column, definitions in another
- User taps pairs to match them
- Each correct pair → submit answer → backend updates SRS

### Gamification Factors (Backend + Frontend Alignment)

The frontend already shows combo, XP (stars), lives, and a timer. These must be driven by backend data.

| UI Element | Frontend (current) | Backend contract |
|---|---|---|
| **Combo multiplier** (`combo x3`) | Hardcoded `x0` / `x3` | Calculated client-side: streak of correct answers. Reset on wrong answer. Sent in `answer` payload as `combo_multiplier`. |
| **XP / Stars** (`auto_awesome` icon) | Shows `110` hardcoded | Calculated as: `base_xp * combo_multiplier`. Backend receives final `xp_earned` in the answer payload and stores it in `review_events`. |
| **Lives** (❤️ icons) | 3 hearts hardcoded | Cloze game only. Start with 3. Each wrong answer costs 1 life. Session ends at 0 lives. Not stored on backend — session-only state in Flutter. |
| **Timer** (`33s`) | Hardcoded | Match game only. Client-side countdown. Time remaining sent in answer payload as `response_time_ms`. |
| **Round / Progress** (`ROUND 1/6`) | Hardcoded | Deck size from backend determines total rounds. Frontend tracks current round locally. |
| **Mastery level** | Not shown yet | Returned in `ReviewEventRead.srs` after each answer. Frontend can show mastery badge on word card. |

### Required Backend Schema Addition

The `review_events` table and `GameAnswerCreate` schema need two new fields:

```python
# Add to GameAnswerCreate schema
combo_multiplier: int = 1       # client-calculated streak multiplier
xp_earned: int = 0              # base_xp * combo_multiplier
response_time_ms: int | None = None  # for match game timer tracking
```

```sql
-- Add to review_events table migration
ALTER TABLE review_events ADD COLUMN combo_multiplier INTEGER DEFAULT 1;
ALTER TABLE review_events ADD COLUMN xp_earned INTEGER DEFAULT 0;
ALTER TABLE review_events ADD COLUMN response_time_ms INTEGER;
```

> [!NOTE]
> When migrating to `drift`, these fields are part of the schema from the start — no ALTER TABLE needed.

---

## 🗺️ Feature Connection Roadmap (Development Order)

These connect the FastAPI backend to the Flutter frontend, preparing the codebase for the eventual drift migration.

### Phase 1 — Reading Progress Sync
**Endpoint:** `GET/PUT /v1/books/{book_id}/progress`  
**Goal:** "Continue where you left off"

**Status:** ✅ Completed

**Files to create/modify:**
- `frontend/lib/features/library/data/book_api.dart` — add `getProgress()` and `saveProgress()` methods
- `frontend/lib/features/reader/presentation/reader_page.dart` — call `saveProgress()` on close/chapter change
- `frontend/lib/features/reader/controllers/reader_controller.dart` — manage CFI state

**Behavior:**
- On book open → `GET /v1/books/{book_id}/progress` → navigate Epub.js to returned CFI
- On chapter change / reader close → `PUT /v1/books/{book_id}/progress` with current CFI + percent
- Save interval: on chapter change + when app goes to background (not every scroll)

---

### Phase 2 — Silent Ghost Highlighting
**Endpoint:** `POST /v1/highlights`  
**Goal:** Word captured in Vault without interrupting reading

**Status:** ✅ Completed

**Files to create/modify:**
- `frontend/lib/features/vault/data/highlight_api.dart` — new file, `createHighlight()` method
- `frontend/lib/features/reader/presentation/reader_page.dart` — JS bridge callback
- `frontend/lib/features/vault/application/vault_provider.dart` — invalidate on new highlight

**Behavior:**
1. User **long-presses** (~0.5s) a word in the EPUB WebView (silent capture; no dictionary popup)
2. JS bridge fires immediately → Flutter triggers haptic + shimmer animation (< 50ms)
3. **Asynchronously** (fire and forget): `POST /v1/highlights` with `target_word`, `context_before`, `context_sentence`, `context_after`, `cfi`, `chapter_title`, `book_id`
4. If the POST fails (offline): save to a local JSON queue (`shared_preferences`) and retry on next app launch

**Implemented now:**
- ✅ Real `InAppWebView` JavaScript handler (`callHandler`) wired to Flutter highlight capture (**long-press** on word; double-tap is reserved for dictionary hint — see Phase 5)
- ✅ Real chapter HTML loading via `GET /v1/books/{book_id}/chapters/{chapter_index}/content`
- ✅ Chapter index now performs real chapter switching in WebView
- ✅ Per-chapter progress save runs on chapter navigation
- ✅ Reader controls now work (`-`/`+` font sizing and previous/next chapter navigation)
- ✅ Simulated highlight payload removed from reader flow
- ✅ Async `POST /v1/highlights` with offline queue retry kept active

**Offline queue contract:**
```dart
// Stored in SharedPreferences as JSON list
class PendingHighlight {
  final String targetWord;
  final String contextSentence;
  final String? contextBefore;
  final String? contextAfter;
  final String bookId;
  final String? cfi;
  final String? chapterTitle;
  final DateTime capturedAt;
}
```

---

### Phase 3 — Games: Connect Real Vault Data
**Endpoints:** `GET /v1/games/deck`, `POST /v1/games/answer`  
**Goal:** Replace all hardcoded mock data in game_session_page.dart with real vault words

**Files to create/modify:**
- `frontend/lib/features/games/data/game_api.dart` — `getDeck()` and `submitAnswer()` methods
- `frontend/lib/features/games/application/game_session_controller.dart` — Riverpod session state (deck, combo, XP, lives, timers)
- `frontend/lib/features/games/presentation/game_session_page.dart` — consume real deck data and gamification state

**Status:** ✅ Implemented (dev backend + Flutter)

**`GameDeckItemRead` already returns from backend:**
```
game_type, highlight_id, srs_item_id, target_word,
prompt, choices[], correct_answer, definition, book_title
```

**Session state managed in Flutter (not backend):**
```dart
class GameSessionState {
  final List<GameDeckItemRead> deck;
  final int currentIndex;
  final int combo;         // streak of correct answers
  final int xp;            // accumulated XP this session
  final int lives;         // cloze only, start at 3
  final int? timerMs;      // match game only
  final bool sessionOver;
}
```

**Submitting an answer:**
```dart
await gameApi.submitAnswer(GameAnswerCreate(
  srsItemId: item.srsItemId,
  userId: currentUserId,
  gameType: item.gameType,
  selectedAnswer: selectedWord,
  isCorrect: selectedWord == item.correctAnswer,
  grade: isCorrect ? 4 : 0,           // SM-2 grade
  comboMultiplier: state.combo,
  xpEarned: baseXp * state.combo,
  responseTimeMs: elapsedMs,          // match game only
));
```

---

### Phase 4 — Home Dashboard
**Endpoint:** `GET /v1/me/home`  
**Goal:** Show real user stats on the Home page

**Status:** ✅ Completed

**Data shown (from `HomeRead`):**
- ✅ `stats.vault_count` — total words captured
- ✅ `stats.books_count` — total books in library
- ✅ `stats.due_reviews_count` — games ready to play today
- ✅ `last_opened_book` + `last_progress` — resume reading button
- ✅ `recent_vault_words` — last 5 words added to the Vault (word + book title)

**Backend (`home_service.py`, `schemas/home.py`):**
- ✅ `HomeRead.recent_vault_words` + `_recent_vault_words()` query (newest highlights, book title attached)

**Frontend:**
- ✅ `frontend/lib/features/home/data/home_api.dart` — `fetchHome(userId)`
- ✅ `frontend/lib/features/home/application/home_provider.dart` — `homeSummaryProvider`
- ✅ `frontend/lib/features/home/presentation/home_page.dart` — stats row, continue reading, recent captures, due count on games card
- ✅ `homeSummaryProvider` invalidated after highlights, shelf changes, progress saves, and game answers so counts stay fresh

---

### Vault and Reader UX Fixes (Brought Forward)

These were originally part of later polish in Phase 4+, but are implemented now for usability:

- ✅ Vault word tap opens details (definition + where mentioned context); definition row comes from `GET /v1/dictionary/{word}` when present
- ✅ Vault sort button works (`Recent`, `A-Z`, `Book`)
- ✅ Vault filter button works (all books / specific book)
- ✅ Reader index button is now actionable
- ✅ Reader vault button opens vault filtered by the current `book_id`
- ✅ **Gesture split:** long-press (~0.5s) = silent capture to Vault; double-tap = dictionary hint overlay (Phase 5)

### Phase 5 — Emergency Synonym Hint
**Endpoint:** `GET /v1/dictionary/{word}` (read); **dev dictionary seeding:** `POST /v1/dictionary`, `PUT /v1/dictionary/{word}`, `PATCH /v1/dictionary/{word}`, `DELETE /v1/dictionary/{word}`  
**Goal:** Double-tap a word in the reader → show a transient hint with definition/synonyms; Vault detail sheet loads the same dictionary.

**Status:** ✅ Completed

**Files to create/modify:**
- `frontend/lib/features/reader/data/dictionary_api.dart` — `lookupWord` + optional `createEntry` / `upsertEntry` for dev tooling
- `frontend/lib/features/reader/presentation/reader_page.dart` — double-tap / double-click → `dictionaryHint` JS handler; overlay card; scroll → dismiss via `dictionaryDismiss`
- `frontend/lib/features/vault/application/vault_provider.dart` — `dictionaryApiProvider`
- `frontend/lib/features/vault/presentation/vault_page.dart` — word detail uses `DictionaryApi` with loading state
- `backend/app/api/dictionary_routes.py` — CRUD-style routes for managing entries during development
- `backend/app/services/dictionary_service.py` — create, upsert, patch, delete

**Gesture note (aligned with PRD F02 vs F07):**
- **Long-press (~480ms)** on a word → silent ghost capture to Vault (same payload as before).
- **Double-tap** (touch) or **double-click** (desktop WebView) → dictionary hint only (no capture).

**Behavior:**
- If backend returns a definition → show it in the reader overlay and in Vault details
- If offline or word not found → show "No hint available" gracefully (never crash)
- Dictionary rows are populated via dev `POST`/`PUT` until a bundled WordNet pipeline exists

---

## Documentation status (living docs)

The bullets below were a migration checklist; they are now **folded into** `Plan.md`, `backend.md`, `PRD.md`, and this plan where still relevant.

### `pro_docs/Plan.md`
- ✅ **Phase 0:** FastAPI called out as developer-only (see Plan Phase 0 intro).
- ✅ **Phase 1 (Task 1.5):** Drift note for dev vs production (see Plan Task 1.5).
- ✅ **Phase 3 (Task 3.8):** Highlights via `POST /v1/highlights` + offline queue (see Plan Task 3.8).
- ✅ **Phase 5 / Epic 5:** SM-2 note pointing at `game_service.py` / `srs_service.py` (see Plan Epic 5 Task 5.1).

### `pro_docs/backend.md`
- ✅ **Section 3:** `/login` username profile (see backend §3).
- ✅ **Section 9:** Two game types + gamification fields on answers (see backend §9).
- ✅ **Section 12 / model:** `review_events` combo / XP / response time (see backend data model sections).
- ✅ **Dictionary:** `GET` + dev `POST`/`PUT`/`PATCH`/`DELETE` `/v1/dictionary` (see backend §8 and §13).
- **Section 15 / 16:** Add explicit “Phase 0.5 drift migration” + non-goals paragraph if you want a single canonical migration narrative (optional polish).

---

## ✅ Verification Plan

| Feature | Test |
|---|---|
| **Reading Progress** | Open book → go to chapter 3 → close app → reopen → should resume at chapter 3 |
| **Ghost Highlight** | Tap a word → shimmer + haptic should fire instantly → check Vault page for the saved word |
| **Offline Highlight** | Stop the backend → tap a word → start backend again → confirm the word syncs to Vault |
| **Complete the Sentence** | Start game → sentences should come from real vault words, not Great Gatsby mock data |
| **Match the Word** | Start game → words + definitions from vault, not hardcoded options |
| **Combo/XP** | Answer 3 in a row correctly → combo should show x3 and XP should increase |
| **Home Dashboard** | Sign in → home shows Books/Vault/Due counts, resume card matches last saved progress, “Latest captures” lists last 5 words with book titles; after a game round, Due count updates when you return home |
| **Dictionary Hint** | Double-tap (or double-click) a word while reading → overlay shows definition/synonyms from `GET /v1/dictionary/{word}`; scroll dismisses the hint |
| **Dictionary seed (dev)** | `POST /v1/dictionary` with JSON `word`, `definition`, optional `synonyms`, `example_sentence`, `source` → Vault details and reader hint return that entry |
| **Ghost capture gesture** | Long-press a word (~0.5s) until shimmer → word appears in Vault |
