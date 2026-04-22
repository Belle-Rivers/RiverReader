# Development Plan: Project "River Reader" v1.0

**Project Phase:** MVP Implementation  
**Tech Stack:** Flutter, SQLite, Epub.js (via WebView), Riverpod (State Management)  
**Methodology:** Agile / Granular Task Breakdown  

---

## Phase 1: Foundational Architecture (Front-End & Local Back-End)

### Epic 1: Scaffold App Architecture, State, and Local Database
**User Story:** As an engineering team, we need a robust, scalable project structure with a configured local database and state management engine so that feature development is decoupled, secure, and reliable.

*   **Task 1.1:** Initialize the Flutter environment, configure linting rules, and implement a Feature-First or Clean Architecture folder structure (UI, Domain, Data layers).
*   **Task 1.2:** Integrate and configure `Riverpod` for global state management, dependency injection, and reactivity across the app.
*   **Task 1.3:** Set up application routing (e.g., using `GoRouter`) defining the navigation graph for the Library Shelf, EPUB Reader, and Scholar's Vault.
*   **Task 1.4:** Build the global UI Theming engine, defining the color palettes, typography scales (Serif/Sans-serif), and logic to switch between "Parchment," "Midnight," and "Ink" modes.
*   **Task 1.5:** Initialize the local "Back-End" using `sqflite` (or `drift` for type-safety), and execute the initial schema migrations (Tables: `books`, `ghost_highlights`).
*   **Task 1.6:** Develop the Data Access Objects (DAOs) and the Repository layer to handle CRUD operations between the Flutter front-end and the SQLite back-end.
*   **Task 1.7:** Implement a secure File Storage Manager using `path_provider` to handle app directory paths for storing unzipped EPUB assets, cover images, and the offline dictionary.
*   **Task 1.8:** Set up a global error-handling and structured logging service to monitor WebView crashes, database read/write failures, and state anomalies.



## Phase 1: Core Architecture & EPUB Foundation

### Epic 1: [F01] High-Fidelity EPUB Rendering Engine
**User Story:** As a reader, I want to open an EPUB file and read it with customizable fonts and themes, so I have a premium reading experience equivalent to Kindle.

*   **Task 1.1:** Initialize Flutter project, configure Riverpod for state management, and set up the `flutter_inappwebview` package.
*   **Task 1.2:** Implement local file system routing to load unzipped EPUB assets into the local WebView server.
*   **Task 1.3:** Integrate the `Epub.js` library and create the bidirectional JavaScript-to-Dart communication channel.
*   **Task 1.4:** Write and inject custom CSS stylesheets for the three core themes ("Parchment", "Midnight", "Ink").
*   **Task 1.5:** Implement DOM manipulation scripts to override hardcoded publisher CSS (e.g., forcing transparent backgrounds and overriding font-families).
*   **Task 1.6:** Develop the pagination logic and dynamic font-resizing functions, ensuring layout recalculation occurs in <200ms.
*   **Task 1.7:** Build the Table of Contents (TOC) parser and map EPUB chapters to a native Flutter drawer UI.
*   **Task 1.8:** Implement Canonical Fragment Identifier (CFI) generation to save the user's exact scroll position on exit.

---

## Phase 2: The "Silent Flow" Capture System

### Epic 2: [F02 & F03] The "Ghost" Highlight & Context Capture
**User Story:** As an intermediate learner, I want to quickly swipe a word to save it and its surrounding sentence without seeing a pop-up dictionary, so my reading flow isn't interrupted.

*   **Task 2.1:** Override default iOS/Android native text selection behaviors (Copy/Look Up) within the WebView container.
*   **Task 2.2:** Write JavaScript event listeners to detect a single-word tap/swipe, isolating the specific DOM text node.
*   **Task 2.3:** Implement the 500ms "Shimmer" CSS animation (Radial Gradient Mask) triggered on the selected text node.
*   **Task 2.4:** Integrate native Haptic Feedback (iOS `UIImpactFeedbackStyleLight` / Android equivalent) mapped to the JS tap event.
*   **Task 2.5:** Develop a JS DOM traversal algorithm to scan backwards/forwards from the highlighted word to find the nearest sentence terminators (`.`, `!`, `?`).
*   **Task 2.6:** Construct the string payload: `[Sentence_Before] + [Target_Word] + [Sentence_After]`.
*   **Task 2.7:** Capture current metadata (Book ID, Chapter, exact CFI location) and bundle it with the string payload.
*   **Task 2.8:** Serialize the payload, send it through the JS bridge, and write an asynchronous SQLite `INSERT` to the `ghost_highlights` table.

---

## Phase 3: Data Management & Vault UI

### Epic 3: [F04, F11, F13] Local Library & Scholar's Vault
**User Story:** As a user, I want to manage my imported books and browse a beautiful archive of the words I've captured, so I can see my progress.

*   **Task 3.1:** Define and instantiate the SQLite schema (Tables: `books`, `ghost_highlights`, `user_stats`).
*   **Task 3.2:** Implement native file picker integration (iOS Files / Android Documents) to import `.epub` files into the app's secure sandbox.
*   **Task 3.3:** Extract metadata (Cover Art Blob, Title, Author) from the EPUB package and save it to the `books` table.
*   **Task 3.4:** Build the native Flutter UI for the "Library Shelf" utilizing a Staggered Grid layout with cover art caching.
*   **Task 3.5:** Develop the "Scholar's Vault" List View, grouping captured `ghost_highlights` by `book_id`.
*   **Task 3.6:** Implement Full-Text SQLite search indexing to allow instant querying of target words and context sentences.
*   **Task 3.7:** Build the database cascade deletion logic: when a book is deleted, prompt the user to either retain or delete associated Vault words.
*   **Task 3.8:** Implement the "Jump to Source" deep-link routing, passing the saved `CFI` to the EPUB Reader to open the exact page.

---

## Phase 4: Gamification & Recall

### Epic 4: [F05 & F12] The Restoration Game & Reveal Logic
**User Story:** As a learner, I want to play a contextual fill-in-the-blank game using my saved words, so I can transfer them to my active vocabulary.

*   **Task 4.1:** Implement the SuperMemo-2 (SM2) Spaced Repetition logic to calculate the `next_review_date` for each captured word.
*   **Task 4.2:** Build the SQLite query to generate the daily "Game Deck," prioritizing words by recency and SM2 schedule.
*   **Task 4.3:** Develop the "Cloze-Test" UI card, rendering the context string with the `target_word` replaced by a `[___]` blank.
*   **Task 4.4:** Write the logic to scramble the letters of the `target_word` into interactive, draggable bottom-sheet tiles.
*   **Task 4.5:** Implement input validation logic and trigger the "pencil-on-paper" audio asset upon correct completion.
*   **Task 4.6:** Build the "Reveal UI": a 3D flip or accordion expansion that displays the dictionary definition post-answer.
*   **Task 4.7:** Update the word's `mastery_level` (0-5) in SQLite and recalculate its next SM2 interval based on user success/failure.
*   **Task 4.8:** Update the UI State for the "Mastery Visualization" dashboard to reflect the newly restored words.

---

## Phase 5: Offline Dictionary & Final Polish

### Epic 5: [F07 & F14] Offline Dictionary & Emergency Hints
**User Story:** As a user, I want instant access to synonyms when I am completely stuck, even if I have no internet connection.

*   **Task 5.1:** Compress a subset of the English WordNet database (Synonyms and short definitions) into a pre-packaged SQLite `.db` file (~15MB).
*   **Task 5.2:** Implement an initialization script to copy the dictionary `.db` from the app bundle to the active local directory on first launch.
*   **Task 5.3:** Build a lightweight querying service to fetch synonyms based on the exact string match of the highlighted word.
*   **Task 5.4:** Write JS logic to detect a "Double-Tap" gesture on a word inside the EPUB reader.
*   **Task 5.5:** Develop a transient Flutter Tooltip/Overlay UI for the "Emergency Synonym" that sits immediately above the selected word.
*   **Task 5.6:** Implement logic to auto-dismiss the tooltip upon any scroll event or tap outside the overlay.
*   **Task 5.7:** Connect the offline dictionary querying service to the "Reveal Logic" in the Restoration Game.
*   **Task 5.8:** Implement the "Silent Onboarding" UI flow (3-slide carousel) to set user expectations before granting access to the main app interface.


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
