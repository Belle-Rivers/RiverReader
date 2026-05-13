# Development Plan: Project "River Reader" v1.0

**Project Phase:** MVP Implementation  
**Tech Stack:** Flutter (frontend), FastAPI (backend API), SQLite, Epub.js (via WebView), Riverpod (State Management)  
**Methodology:** Agile / Granular Task Breakdown  

---

## Phase 0: Backend API Foundation (Separate Service)

**Goal:** Stand up a separate backend service that exposes OpenAPI docs at `/docs` and persists data in SQLite.
*Note: FastAPI is a **developer-only tool**. Users never interact with it, and it is not deployed to production. It serves as an inspection tool and development backend until the drift migration.*

*   **Task 0.1:** Choose backend framework: **FastAPI** + **Uvicorn** + **SQLite** (single-file DB).
*   **Task 0.2:** Define the MVP schema (books, highlights, SRS state, review events).
*   **Task 0.3:** Implement `GET /health` and confirm it appears in Swagger at `/docs`.
*   **Task 0.4:** Implement CRUD endpoints for `books` and `highlights` under `/v1/*`.
*   **Task 0.5:** Implement SRS endpoints (`GET /v1/reviews/due`, `POST /v1/reviews/{id}/grade`).
*   **Task 0.6:** Add optional AI endpoints (definitions / cloze generation) behind a feature flag and a cache table.
*   **Task 0.7:** Document local persistence location (`backend/data/river_reader.db`) and backup/export strategy.

---

## Phase 1: Foundational Architecture (Front-End + Client-Side Persistence)

### Epic 1: Scaffold App Architecture, State, and Local Database
**User Story:** As an engineering team, we need a robust, scalable project structure with a configured local database and state management engine so that feature development is decoupled, secure, and reliable.

*   ✅ **Task 1.1:** Initialize the Flutter environment, configure linting rules, and implement a Feature-First or Clean Architecture folder structure (UI, Domain, Data layers).
*   ✅ **Task 1.2:** Integrate and configure `Riverpod` for global state management, dependency injection, and reactivity across the app.
*   ✅ **Task 1.3:** Set up application routing (e.g., using `GoRouter`) defining the navigation graph for the Library Shelf, EPUB Reader, and Scholar's Vault.
*   ✅ **Task 1.4:** Build the global UI theming engine, defining the color palettes, typography scales (Serif/Sans-serif), and logic to switch between "Sunlight" and "Midnight" modes.
*   ✅ **Task 1.5:** Initialize a **client-side** SQLite cache using `sqflite` (or `drift` for type-safety), and execute the initial schema migrations (Tables: `books`, `ghost_highlights`). *Note: During development, drift is for EPUB asset caching and offline queues only. When FastAPI is deprecated for production, drift becomes the full data layer.*
*   ✅ **Task 1.6:** Develop DAOs + Repository layer for local reads/writes, and prepare the interface to later sync with the backend API.
*   ✅ **Task 1.7:** Implement a secure File Storage Manager using `path_provider` to handle app directory paths for storing unzipped EPUB assets, cover images, and the offline dictionary.
*   ✅ **Task 1.8:** Set up a global error-handling and structured logging service to monitor WebView crashes, database read/write failures, and state anomalies.

---

## Phase 2: Core Architecture & EPUB Foundation

### Epic 2: [F01] High-Fidelity EPUB Rendering Engine
**User Story:** As a reader, I want to open an EPUB file and read it with customizable fonts and themes, so I have a premium reading experience equivalent to Kindle.

*   ✅ **Task 2.1:** Initialize Flutter project, configure Riverpod for state management, and set up the `flutter_inappwebview` package.
*   ✅ **Task 2.2:** Implement chapter content loading for WebView rendering (`GET /v1/books/{book_id}/chapters/{chapter_index}/content`).
*   ✅ **Task 2.3:** Integrate the bidirectional JavaScript-to-Dart communication channel for real word-tap capture events.
*   **Task 2.4:** Write and inject custom CSS stylesheets for the two core themes ("Sunlight", "Midnight").
*   **Task 2.5:** Implement DOM manipulation scripts to override hardcoded publisher CSS (e.g., forcing transparent backgrounds and overriding font-families).
*   **Task 2.6:** Develop the pagination logic and dynamic font-resizing functions, ensuring layout recalculation occurs in <200ms.
*   **Task 2.7:** Build the Table of Contents (TOC) parser and map EPUB chapters to a native Flutter drawer UI.
*   **Task 2.8:** Implement Canonical Fragment Identifier (CFI) generation to save the user's exact scroll position on exit.

---

## Phase 3: The "Silent Flow" Capture System

### Epic 3: [F02 & F03] The "Ghost" Highlight & Context Capture
**User Story:** As an intermediate learner, I want to quickly swipe a word to save it and its surrounding sentence without seeing a pop-up dictionary, so my reading flow isn't interrupted.

*   **Task 3.1:** Override default iOS/Android native text selection behaviors (Copy/Look Up) within the WebView container.
*   **Task 3.2:** Write JavaScript event listeners to detect a single-word tap/swipe, isolating the specific DOM text node.
*   **Task 3.3:** Implement the 500ms "Shimmer" CSS animation (Radial Gradient Mask) triggered on the selected text node.
*   **Task 3.4:** Integrate native Haptic Feedback (iOS `UIImpactFeedbackStyleLight` / Android equivalent) mapped to the JS tap event.
*   **Task 3.5:** Develop a JS DOM traversal algorithm to scan backwards/forwards from the highlighted word to find the nearest sentence terminators (`.`, `!`, `?`).
*   **Task 3.6:** Construct the string payload: `[Sentence_Before] + [Target_Word] + [Sentence_After]`.
*   **Task 3.7:** Capture current metadata (Book ID, Chapter, exact CFI location) and bundle it with the string payload.
*   ✅ **Task 3.8:** Serialize the payload, send it through the JS bridge, and call `POST /v1/highlights` asynchronously. On failure, add to offline queue in SharedPreferences.

---

## Phase 4: Data Management & Vault UI

### Epic 4: [F04, F11, F13] Local Library & Scholar's Vault
**User Story:** As a user, I want to manage my imported books and browse a beautiful archive of the words I've captured, so I can see my progress.

*   ✅ **Task 4.0 (Home dashboard):** Wire the Home tab to `GET /v1/me/home` — library/vault/due stats, resume reading from `last_opened_book` + `last_progress`, and **Latest captures** from `recent_vault_words` (last five vault words with book titles). Provider refresh tied to highlights, shelf edits, reading progress, and game answers.

*   **Task 4.1:** Define and instantiate the SQLite schema (Tables: `books`, `ghost_highlights`, `user_stats`).
*   **Task 4.2:** Implement native file picker integration (iOS Files / Android Documents) to import `.epub` files into the app's secure sandbox.
*   **Task 4.3:** Extract metadata (Cover Art Blob, Title, Author) from the EPUB package and save it to the `books` table.
*   **Task 4.4:** Build the native Flutter UI for the "Library Shelf" utilizing a Staggered Grid layout with cover art caching.
*   ✅ **Task 4.5:** Develop the "Scholar's Vault" List View, grouping captured `ghost_highlights` by `book_id`.
*   🚧 **Task 4.6:** Implement Full-Text SQLite search indexing to allow instant querying of target words and context sentences. *(Current status: API-backed search/filter/sort is working; FTS indexing remains pending.)*
*   **Task 4.7:** Build the database cascade deletion logic: when a book is deleted, prompt the user to either retain or delete associated Vault words.
*   **Task 4.8:** Implement the "Jump to Source" deep-link routing, passing the saved `CFI` to the EPUB Reader to open the exact page.

### Brought forward usability fixes

*   ✅ Reader index and reader-to-vault actions are now clickable and wired.
*   ✅ Vault word tap now opens definition and mention context details.
*   ✅ Vault sort and filter controls now work.

---

## Phase 5: Gamification & Recall

### Epic 5: [F05 & F12] The Restoration Game & Reveal Logic
**User Story:** As a learner, I want to play a contextual fill-in-the-blank game using my saved words, so I can transfer them to my active vocabulary.

*   **Task 5.1:** Implement the SuperMemo-2 (SM2) Spaced Repetition logic to calculate the `next_review_date` for each captured word. *(Note: SM-2 SRS algorithm lives in `game_service.py` / `srs_service.py` during development, and will be ported 1:1 to `srs_repository.dart` before App Store submission.)*
*   **Task 5.2:** Build the SQLite query to generate the daily "Game Deck," prioritizing words by recency and SM2 schedule.
*   ✅ **Task 5.3:** Build the "Complete the sentence" card: show a **blanked sentence** from the game deck (`GET /v1/games/deck`). Prefer a dictionary **example sentence** (new context); fall back to the captured context sentence when no example exists. Render multiple-choice word tiles (MVP; scrambled-letter tiles deferred).
*   **Task 5.4:** Write the logic to scramble the letters of the `target_word` into interactive, draggable bottom-sheet tiles.
*   **Task 5.5:** Implement input validation logic and trigger the "pencil-on-paper" audio asset upon correct completion.
*   **Task 5.6:** Build the "Reveal UI": a 3D flip or accordion expansion that displays the dictionary definition post-answer.
*   **Task 5.7:** Update the word's `mastery_level` (0-5) in SQLite and recalculate its next SM2 interval based on user success/failure.
*   **Task 5.8:** Update the UI State for the "Mastery Visualization" dashboard to reflect the newly restored words.

---

## Phase 6: Offline Dictionary & Final Polish

### Epic 6: [F07 & F14] Offline Dictionary & Emergency Hints
**User Story:** As a user, I want instant access to synonyms when I am completely stuck, even if I have no internet connection.

*   **Task 6.1:** Compress a subset of the English WordNet database (Synonyms and short definitions) into a pre-packaged SQLite `.db` file (~15MB).
*   **Task 6.2:** Implement an initialization script to copy the dictionary `.db` from the app bundle to the active local directory on first launch.
*   ✅ **Task 6.3 (dev path):** Lightweight dictionary lookup from Flutter via `GET /v1/dictionary/{word}` (`DictionaryApi`) — shared by Vault details and the reader hint overlay.
*   ✅ **Task 6.4:** Double-tap / double-click detection on words inside the EPUB reader WebView triggers the dictionary hint (long-press remains the silent Vault capture gesture).
*   ✅ **Task 6.5:** Transient reader overlay (definition + synonyms, loading state, close control).
*   ✅ **Task 6.6:** Hint dismisses on WebView scroll (JS → Flutter), timeout (~8s), or explicit close.
*   **Task 6.7:** Connect the offline dictionary querying service to the "Reveal Logic" in the Restoration Game.
*   **Task 6.8:** Implement the "Silent Onboarding" UI flow (3-slide carousel) to set user expectations before granting access to the main app interface.

**Dev backend:** Use `POST` / `PUT` `/v1/dictionary` to seed words you care about until Tasks 6.1–6.2 ship.

---

## Phase 7: QA, Optimization & Store Deployment

### Epic 7: Pre-Launch Polish & Release Preparation
**User Story:** As a product owner, I want the app tested, optimized, and packaged so it can be successfully reviewed and published on the Apple App Store and Google Play Store.

*   **Task 7.1:** Generate and configure native App Icons, Launch Screens (Splash screens matching the Dark Academia aesthetic), and app display names for both iOS and Android.
*   **Task 7.2:** Conduct performance profiling using Flutter DevTools to ensure EPUB rendering meets the < 1.5s cold start benchmark and < 50ms highlight latency.
*   **Task 7.3:** Write unit tests for the core business logic, specifically targeting the SM2 Spaced Repetition algorithm and the Context Scrape string manipulation.
*   **Task 7.4:** Perform edge-case QA testing on EPUB ingestion (handling massive file sizes, corrupt EPUBs, and missing metadata/cover art).
*   **Task 7.5:** Audit and implement required platform permissions (File Access/Storage permissions for importing EPUBs, Haptic feedback permissions).
*   **Task 7.6:** Configure build signing, provisioning profiles (iOS), and Keystore files (Android) for production release builds.
*   **Task 7.7:** Write the App Store/Play Store metadata (Descriptions, "Silent Method" marketing copy, privacy policy links regarding local data).
*   **Task 7.8:** Compile the final `AAB` (Android) and `IPA` (iOS) release builds and upload them to Google Play Console and App Store Connect for TestFlight/Internal testing.
