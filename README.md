# River Reader

**River Reader** is a Flutter-based EPUB reader application designed with a unique "Silent Flow" capture system. It acts as a premium reading experience combined with a sophisticated language learning and vocabulary restoration game.

## Project Architecture

The project is structured into two main packages to enforce a clean separation of concerns:

- **frontend/**: The main Flutter application containing the UI, Riverpod state management, routing (`go_router`), and the EPUB WebView rendering engine (`flutter_inappwebview`).
- **backend/**: A local Dart package handling data persistence (`sqflite`), file management, and application logging. It acts as the local backend for the application.

## Key Features

1. **High-Fidelity EPUB Rendering:**
   - Loads local EPUB files into a custom WebView.
   - Dynamic theming support (Parchment, Midnight, Ink) with font resizing.
   
2. **"Silent Flow" Capture System (Ghost Highlights):**
   - Allows users to swipe and highlight words without interrupting their reading flow.
   - Automatically captures the context sentence and saves it to the local database.

3. **Scholar's Vault & Restoration Game:**
   - Saved words appear in the "Scholar's Vault".
   - Utilizes a SuperMemo-2 (SM2) Spaced Repetition algorithm for a daily vocabulary restoration mini-game.

4. **Offline Dictionary:**
   - Query synonyms offline using an embedded local SQLite database.

## Requirements

The project dependencies are documented in the respective `requirements.txt` and `pubspec.yaml` files inside the `frontend` and `backend` directories.

**Main Tech Stack:**
- **Framework:** Flutter
- **State Management:** Riverpod
- **Local Database:** sqflite (with `sqflite_common_ffi_web` for web support)
- **Routing:** go_router
- **EPUB Engine:** Epub.js (injected via `flutter_inappwebview`)

## Getting Started

1. **Install Dependencies:**
   Navigate into both the `backend` and `frontend` directories and run:
   ```bash
   flutter pub get
   ```

2. **Run the Application:**
   From the `frontend` directory, run:
   ```bash
   flutter run
   ```
