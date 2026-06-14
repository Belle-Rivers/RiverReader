# River Reader Frontend Source of Truth

This document is the single source of truth for the `frontend` folder. It describes the Flutter app that renders the EPUB reader, manages the Vault, and runs light games. The frontend prioritizes "Silent Flow" — minimizing friction before introducing gamification elements.

---

## 1) Tech Stack

- **Flutter** (SDK >=3.3.0) with Dart
- **State management:** flutter_riverpod (^2.5.1)
- **Navigation:** go_router (^13.2.0)
- **EPUB reader:** flutter_inappwebview (InAppWebView)
- **HTTP:** dart http.Client (no Dio)
- **Local storage:** shared_preferences (session, preferences), sqflite (via backend lib)
- **Fonts:** google_fonts (DynaPuff for display), Inter/Merriweather for UI/body
- **Icons:** font_awesome_flutter
- **File picking:** file_picker (EPUB upload, backup import)
- **Platform storage:** path_provider

---

## 2) Architecture

### Folder structure

```
frontend/lib/
├── main.dart                              # Entry point, ProviderScope, MaterialApp.router
├── core/
│   ├── error/error_logger.dart            # Developer console logging wrapper
│   ├── router/app_router.dart             # GoRouter route definitions + auth redirect
│   ├── storage/
│   │   ├── file_storage_manager.dart      # Platform-conditional export (IO vs Web)
│   │   ├── file_storage_manager_io.dart   # IO: paths for epubs, covers, backups
│   │   └── file_storage_manager_web.dart  # Web: stub implementations
│   ├── theme/app_theme.dart               # ThemeData for Sunlight/Midnight modes
│   └── widgets/
│       ├── river_ui.dart                  # RiverScaffold, RiverCard, bottom nav
│       └── theme_mode_menu_button.dart    # Theme toggle icon button
└── features/
    ├── auth/
    │   ├── application/
    │   │   ├── auth_providers.dart        # Session user ID provider
    │   │   └── current_user_provider.dart # Current user profile provider
    │   ├── data/registration_api.dart     # Auth API (register, login, recovery, export/import)
    │   └── presentation/
    │       ├── register_page.dart         # Sign-in / create-account with segmented toggle
    │       └── forgot_password_page.dart  # Security question password recovery
    ├── games/
    │   ├── application/
    │   │   ├── game_backfill_provider.dart    # Background AI backfill (30s periodic)
    │   │   ├── game_decks_provider.dart       # Fetches all 5 game decks
    │   │   └── game_session_controller.dart   # Game session state machine
    │   ├── data/game_api.dart                 # Game API (decks, answer, backfill, cache-status)
    │   └── presentation/
    │       ├── games_page.dart                # Game hub (5 mode cards, today's pool)
    │       └── game_session_page.dart         # Active game UI per mode
    ├── home/
    │   ├── application/home_provider.dart     # Home summary provider
    │   ├── data/home_api.dart                 # GET /v1/me/home
    │   └── presentation/home_page.dart        # Dashboard (stats, XP, continue reading, recent words)
    ├── library/
    │   ├── controllers/library_shelf_controller.dart  # Book list + upload/delete
    │   ├── data/book_api.dart                         # Book API (CRUD, upload, progress, chapters)
    │   └── presentation/library_shelf_page.dart       # Grid view of books with upload zone
    ├── reader/
    │   ├── controllers/
    │   │   ├── reader_controller.dart             # Per-book reader state (chapter load, progress)
    │   │   └── reader_preferences_provider.dart   # Font preference toggle
    │   ├── data/dictionary_api.dart               # Dictionary lookup (GET/POST/PUT)
    │   └── presentation/
    │       ├── reader_page.dart                   # InAppWebView EPUB reader
    │       ├── web_helper.dart                    # Platform-conditional WebView helpers
    │       ├── web_helper_web.dart
    │       └── web_helper_stub.dart
    ├── settings/
    │   ├── application/backup_autosave_provider.dart  # Auto-backup every 30s
    │   ├── data/
    │   │   ├── backup_downloader.dart                 # Platform-conditional backup download
    │   │   ├── backup_downloader_io.dart
    │   │   └── backup_downloader_web.dart
    │   └── presentation/settings_page.dart            # Theme, font, account, backup, sign-out
    ├── splash/
    │   └── presentation/splash_page.dart              # Launch screen with auto-redirect
    └── vault/
        ├── application/vault_provider.dart            # Vault items + search/filter state
        ├── data/
        │   ├── highlight_api.dart                     # POST /v1/highlights (with offline queue)
        │   └── vault_api.dart                         # GET /v1/vault, DELETE highlights
        └── presentation/vault_page.dart               # Word list, search, book filter, sort
```

### Feature-based organization

Each feature follows a consistent pattern:
- `application/` — Riverpod providers and controllers
- `data/` — API client files with embedded request/response models
- `presentation/` — Pages and widgets

---

## 3) Navigation and Routing

Uses `go_router` with `app_router.dart` providing a `GoRouter` instance.

### Routes

| Path | Page | Notes |
|------|------|-------|
| `/splash` | SplashPage | Initial location |
| `/` | HomePage | Main dashboard |
| `/register` | RegisterPage | `?mode=signin` query param |
| `/forgot-password` | ForgotPasswordPage | |
| `/shelf` | LibraryShelfPage | |
| `/reader/:bookId` | ReaderPage | `extra: BookApiModel` |
| `/vault` | VaultPage | Optional `?bookId=` query |
| `/games` | GamesPage | |
| `/games/complete-sentence` | GameSessionPage | `kind: GameSessionKind.completeSentence` |
| `/games/match-meanings` | GameSessionPage | `kind: GameSessionKind.matchMeanings` |
| `/games/context-clash` | GameSessionPage | `kind: GameSessionKind.contextClash` |
| `/games/odd-one-out` | GameSessionPage | `kind: GameSessionKind.oddOneOut` |
| `/games/true-or-bluff` | GameSessionPage | `kind: GameSessionKind.trueOrBluff` |
| `/settings` | SettingsPage | |

### Auth redirect logic

- Unauthenticated users are redirected to `/register`.
- Authenticated users on `/splash` are redirected to `/`.

---

## 4) State Management

Uses **flutter_riverpod** exclusively. Provider types:

| Provider Type | Examples | Purpose |
|---------------|----------|---------|
| `Provider<T>` | `appRouterProvider`, `bookApiProvider`, `vaultApiProvider`, `dictionaryApiProvider`, `highlightApiProvider`, `gameApiProvider`, `registrationApiProvider` | Service singletons |
| `FutureProvider<T?>` | `homeSummaryProvider`, `vaultItemsProvider`, `currentUserProfileProvider` | Async data fetching |
| `FutureProvider.family<T, A>` | `bookVaultCountProvider` | Per-book vault count |
| `AsyncNotifierProvider<T, S>` | `libraryShelfControllerProvider`, `gameDecksProvider` | Async state with mutations |
| `AsyncNotifierProvider.family<T, S, A>` | `readerControllerProvider` | Per-book reading progress |
| `NotifierProvider<T, S>` | `appThemeNotifierProvider`, `sessionUserIdProvider`, `readerPreferencesProvider` | Synchronous mutable state |
| `StateProvider<T>` | `vaultSearchQueryProvider`, `vaultSelectedBookIdProvider` | Simple state holding |
| `StateNotifierProvider.family<T, S, A>` | `gameSessionProvider` | Game session state with complex logic |
| Worker providers | `gameBackfillWorkerProvider`, `backupAutoExportProvider` | Background tasks |

---

## 5) Screens and Pages

### SplashPage (`features/splash/presentation/splash_page.dart`)

App launch screen. Shows logo + "read in flow." tagline with gradient background. After 1.8s timer, redirects to `/` (logged in) or `/register` (not logged in).

### RegisterPage (`features/auth/presentation/register_page.dart`)

Combined sign-in / create-account page with segmented toggle. Supports email, password, display name fields. Uses `SharedPreferences` to flag first-time users for the onboarding tour.

### ForgotPasswordPage (`features/auth/presentation/forgot_password_page.dart`)

Password recovery via security question. Loads question by email, validates answer, sets new password.

### HomePage (`features/home/presentation/home_page.dart`)

Main dashboard with:
- User greeting (display name)
- Stats row (books count, vault count, due reviews count)
- XP progress card (total XP earned, progress bar toward next 100 XP milestone)
- "Continue reading" section with last opened book cover and progress
- Recent vault captures preview (last 5 words with book title/author)
- "Restoration time" CTA linking to games
- First-login `_TourDialog` (3-page PageView walkthrough with dot indicators)

### LibraryShelfPage (`features/library/presentation/library_shelf_page.dart`)

Grid view of uploaded EPUB books with cover images. Has an "Add an EPUB" upload zone with `file_picker`. Long-press on a book shows open/delete actions.

### ReaderPage (`features/reader/presentation/reader_page.dart`)

Full EPUB reader using `InAppWebView`. Features:
- Renders chapter HTML in a WebView with custom JavaScript
- **Ghost capture:** double-tap word → highlight capture with offline queue
- **Dictionary hint:** long-press word → floating definition overlay near the tapped word
- Font size controls (increase/decrease)
- Original/app font toggle
- Chapter navigation (prev/next)
- Chapter index bottom sheet
- Chapter link interception (in-chapter navigation)
- Reading progress auto-save on chapter change and app background

### VaultPage (`features/vault/presentation/vault_page.dart`)

Vocabulary list with:
- Search bar (text query)
- Book filter dropdown
- Sort options (recent, A-Z, by book)
- Word cards showing target word and context sentence
- Tap opens detail sheet with dictionary lookup (definition, synonyms, example sentence)
- Word deletion support

### GamesPage (`features/games/presentation/games_page.dart`)

Game hub showing:
- "Today's pool" word count
- 5 game mode cards:
  1. Complete the Sentence (cloze)
  2. Match Meanings (meaning_match)
  3. Context Clash (context_clash)
  4. Odd One Out (odd_one_out)
  5. True or Bluff (true_or_bluff)

### GameSessionPage (`features/games/presentation/game_session_page.dart`)

Active game session. Renders the appropriate game UI based on `GameSessionKind`. Shows:
- Timer
- Combo streak
- XP earned
- Lives (hearts)
- Progress bar
- Each game mode has its own section with feedback cards

### SettingsPage (`features/settings/presentation/settings_page.dart`)

Settings with:
- Theme selection (Sunlight / Midnight)
- Reading font preference toggle (original vs app font)
- Account info display
- Security question setup
- Backup management (auto-save every 30s, manual save, download, import)
- Sign-out button

---

## 6) Core Components

### RiverScaffold (`core/widgets/river_ui.dart`)

App-wide scaffold shell with:
- Header (title, subtitle, logo, trailing actions, back button)
- Bottom navigation bar with 4 tabs: Home, Shelf, Game, Vault
- Mint-colored active indicator on selected tab

### RiverCard (`core/widgets/river_ui.dart`)

Styled card container with rounded corners and outline border. Reused across vault, games, settings.

### ThemeModeMenuButton (`core/widgets/theme_mode_menu_button.dart`)

Icon button that toggles between sunlight/midnight theme modes.

---

## 7) API Integrations

All APIs use `http.Client` and connect to `RIVER_READER_API_URL` (default `http://localhost:8000`).

### RegistrationApi (`features/auth/data/registration_api.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/v1/users/register` | Create account |
| POST | `/v1/users/login` | Sign in |
| GET | `/v1/users` | List profiles |
| GET | `/v1/users/:id` | Get profile |
| PATCH | `/v1/users/:id` | Update profile |
| GET | `/v1/users/recovery-question/:email` | Get security question |
| POST | `/v1/users/forgot-password` | Reset password |
| GET | `/v1/users/:id/export` | Export user data |
| POST | `/v1/users/import` | Import user data |
| POST | `/v1/users/:id/backup` | Trigger server backup |
| GET | `/v1/users/:id/backup` | Download backup |

### HomeApi (`features/home/data/home_api.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/v1/me/home` | Dashboard (user, stats, last book, recent words) |

### BookApi (`features/library/data/book_api.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/v1/books` | List books |
| POST | `/v1/books/upload` | Upload EPUB (multipart) |
| DELETE | `/v1/books/:id` | Delete book |
| GET | `/v1/books/:id/progress` | Get reading progress |
| PUT | `/v1/books/:id/progress` | Save reading progress |
| GET | `/v1/books/:id/chapters/:index/content` | Get chapter HTML + text |

### HighlightApi (`features/vault/data/highlight_api.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/v1/highlights` | Create highlight (with offline queue fallback) |

### VaultApi (`features/vault/data/vault_api.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/v1/vault` | List vault items (with filters) |
| DELETE | `/v1/highlights/:id` | Delete highlight |

### DictionaryApi (`features/reader/data/dictionary_api.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/v1/dictionary/:word` | Lookup word definition |
| POST | `/v1/dictionary` | Create dictionary entry |
| PUT | `/v1/dictionary/:word` | Upsert dictionary entry |

### GameApi (`features/games/data/game_api.dart`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/v1/games/backfill/:userId` | Trigger AI backfill |
| GET | `/v1/games/cache-status` | AI cache readiness stats |
| GET | `/v1/games/decks` | Get all 5 game decks |
| GET | `/v1/games/deck` | Get single game type deck |
| POST | `/v1/games/answer` | Submit game answer |

---

## 8) Models

Models are embedded in API files (not separate model files):

| Model | File | Key Fields |
|-------|------|------------|
| RegistrationRequest | registration_api.dart | email, password, securityQuestion/Answer, displayName |
| LoginRequest | registration_api.dart | email, password |
| HomeStatsModel | home_api.dart | booksCount, vaultCount, dueReviewsCount, xpEarnedTotal, xpProgressPercent |
| HomeSummaryModel | home_api.dart | stats, lastOpenedBook, lastProgress, recentVaultWords, displayName |
| BookApiModel | book_api.dart | id, title, author, coverRef, progressPercent, lastReadAt, chapters |
| ReadingProgressModel | book_api.dart | bookId, cfi, chapterIndex, chapterTitle, progressPercent |
| BookChapterContentModel | book_api.dart | bookId, chapterIndex, chapterHref, contentHtml, contentText |
| VaultItemRead | vault_api.dart | id, targetWord, contextSentence, bookTitle, bookAuthor, cfi |
| HighlightCreateModel | highlight_api.dart | userId, bookId, targetWord, contextBefore/Sentence/After, cfi |
| PendingHighlight | highlight_api.dart | targetWord, contextSentence, bookId, userId, cfi, capturedAt |
| DictionaryEntryModel | dictionary_api.dart | id, word, definition, synonyms, exampleSentence, source |
| GameDeckItemRead | game_api.dart | gameType, highlightId, targetWord, prompt, choices, correctAnswer |
| GameDecksBundle | game_api.dart | cloze, meaningMatch, contextClash, oddOneOut, trueOrBluff |
| GameSessionVm | game_session_controller.dart | status, deck, currentIndex, comboStreak, xp, lives, timer state |

---

## 9) Theme System

### Sunlight mode

Light background, dark text. Mint accent color for active nav and CTAs.

### Midnight mode

Dark background, light text. Same mint accent.

### Theme toggle

`ThemeModeMenuButton` in the header allows instant switching. Preference persists via `appThemeNotifierProvider` (shared_preferences).

---

## 10) Animations

### Implemented

| Animation | Location | Description |
|-----------|----------|-------------|
| Ghost Glow (CSS) | reader_page.dart | `@keyframes ghostGlow` — 420ms ease-out highlight animation on double-tap capture. Background fades from gold to transparent. |
| Haptic Feedback | reader_page.dart, auth pages, settings | `HapticFeedback.lightImpact()` on word capture; `mediumImpact()` on successful auth/settings actions. |
| Tour PageView | home_page.dart | PageView with animated dot indicators (`AnimatedContainer` 200ms) for onboarding. |
| Button transitions | game_session_page.dart | Color/border transitions on game answer selection (mint for correct, red for wrong). |

### Planned (not yet implemented)

- Shimmer `CustomPainter` / `ShaderMask` 500ms silver/gold glimmer effect
- "Page Flip" skeuomorphic animation
- "Focus Zoom" game entrance (blur background, center artifact card)
- Card flip animation on game success (180-degree flip revealing definition)
- "Red Ink Bleed" / shake animation on game failure
- "Ink Well" XP progress HUD
- Shared Element Transitions (Hero widgets for book covers and word cards)
- Grain/texture overlay for paper simulation
- "Staggered Entrance" animation for library grid
- "Emergency Synonym" OverlayPortal tooltip (zero-latency)

---

## 11) Offline Support

- **Highlights:** When backend is unavailable, highlights are queued in `SharedPreferences` as `PendingHighlight` objects. On next app launch, queued highlights sync to the backend.
- **Dictionary:** Local cache in `dictionary_entries` table reduces API calls.

---

## 12) Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Supported | Full implementation |
| iOS | Supported | Full implementation |
| macOS | Supported | Desktop build |
| Linux | Supported | Desktop build |
| Windows | Supported | Desktop build |
| Web | Supported | Conditional exports for file storage and backup download (`dart:html` vs `dart:io`) |

---

## 13) Configuration and Environment

### Environment variables

- `RIVER_READER_API_URL` / `RIVER_READER_API_BASE_URL` — backend API base URL (default: `http://localhost:8000`)

### Assets

- `assets/images/logo.png` — app logo
- `assets/images/RiverReader_logo.png` — alternative logo

### pubspec.yaml

- Package name: `river_reader`
- SDK: `>=3.3.0 <4.0.0`
- Key dependencies: flutter_inappwebview, google_fonts, font_awesome_flutter, file_picker, path_provider, shared_preferences, flutter_riverpod, go_router

---

## 14) Tests

Current test coverage is minimal:

- `test/widget_test.dart` — single smoke test verifying `MaterialApp` renders

No feature-level unit, widget, or integration tests exist yet.

---

## 15) Implementation Phases

### Phase 1: The Foundation & Design System ✅

- [x] Design Token Implementation: `ThemeData` for Sunlight and Midnight
- [x] Typography: google_fonts for Inter (UI) and body text
- [x] Library Shelf (Page): Grid layout for book covers with upload zone
- [x] File Ingestion UI: file_picker for EPUB uploads
- [x] Navigation Architecture: GoRouter with persistent bottom nav

### Phase 2: The Core Reader ("Silent Flow") ✅

- [x] EPUB Viewer Integration: InAppWebView with CFI support
- [x] Ghost Highlight: CSS `ghostGlow` animation (420ms) on double-tap capture
- [x] Haptic Trigger: `HapticFeedback.lightImpact()` on capture
- [x] Reading Overlay: Auto-hiding header/footer with reading progress
- [x] Dictionary Hint: Long-press shows floating definition overlay
- [x] Chapter navigation and index
- [x] Font size controls and original/app font toggle
- [x] Reading progress save/load (CFI, chapter index, percentage)
- [ ] Shimmer CustomPainter/ShaderMask 500ms silver/gold glimmer
- [ ] "Page Flip" skeuomorphic animation

### Phase 3: The Scholar's Vault ✅

- [x] Vault List: Word cards with context sentence
- [x] Search & Filter: Text search, book filter, sort (recent/A-Z/book)
- [x] Dictionary Modal: Bottom sheet with AI-generated definitions and synonyms
- [x] Word deletion support
- [x] "Return to Narrative": Deep-link back to exact CFI in Reader

### Phase 4: The Restoration Game ✅

- [x] Game Hub: 5 game mode cards with today's pool count
- [x] Complete the Sentence (cloze) game mode
- [x] Match Meanings (meaning_match) game mode
- [x] Context Clash (context_clash) game mode
- [x] Odd One Out (odd_one_out) game mode
- [x] True or Bluff (true_or_bluff) game mode
- [x] Game timer, combo multiplier, XP system, lives/hearts
- [x] Background AI game backfill (30s periodic poll)
- [ ] "Focus Zoom" game entrance animation
- [ ] Card flip animation on success
- [ ] "Red Ink Bleed" shake animation on failure
- [ ] "Ink Well" XP progress HUD

### Phase 5: Mastery & Progress Visualization

- [x] Home dashboard with stats, XP progress, recent vault, continue reading
- [ ] Linguistic Map / Heatmap widget
- [ ] Mastery Nodes (radial graph)
- [ ] Daily Streak component

### Phase 6: Polish, Juice, & Optimization

- [x] First-login onboarding tour (3-page PageView)
- [x] Backup auto-save (30s), manual save, download, import
- [x] Settings (theme, font, account, recovery, backup, sign-out)
- [ ] Shared Element Transitions (Hero widgets)
- [ ] Grain/texture overlay for paper simulation
- [ ] Lazy loading for Vault
- [ ] 60/120fps performance optimization
- [ ] "Staggered Entrance" animation for library grid
