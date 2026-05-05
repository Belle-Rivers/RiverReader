[cite_start]This checklist is designed to keep your backend logic decoupled from the UI, ensuring that the **River Reader** "Local-First" architecture is ready to scale to a cloud-synced version in the future[cite: 50, 52].

### Phase 1: Foundational Database & Repository Setup
* **Initialize the SQLite Schema:**
    * [cite_start]Create the `books` table with columns for `id (UUID)`, metadata, and `file_hash`[cite: 56, 57].
    * [cite_start]Create the `ghost_highlights` table including `cfi_location` and `timestamp`[cite: 58].
    * [cite_start]Create the `mastery_stats` table to track SRS progress[cite: 58].
* **Implement "Sync-Ready" Columns:**
    * [cite_start]Add `created_at` and `updated_at` timestamps to every table row for future Delta Syncs[cite: 75, 76].
    * [cite_start]Implement a `is_deleted` boolean (Soft Delete) for every record to prevent data conflicts during future cloud reconciliations[cite: 77].
* **Establish the Repository Pattern:**
    * [cite_start]Define the `VaultRepository` interface so the UI never interacts with SQLite directly[cite: 54, 55].

### Phase 2: File Persistence & Integrity
* **Secure Sandboxing:**
    * [cite_start]Implement logic to move imported `.epub` files into the `ApplicationDocumentsDirectory`[cite: 70].
    * [cite_start]Develop an "Exploding" service to unzip EPUB assets into a hidden cache for the `Epub.js` engine[cite: 71, 72].
* **Data Resurrection Logic:**
    * [cite_start]Generate an **MD5 hash** for every uploaded file[cite: 73].
    * [cite_start]Build a lookup service that uses this hash to reconnect old highlights if a user re-adds a previously deleted book[cite: 74].

### Phase 3: The "Silent" Capture Engine
* **The JS-to-Dart Bridge:**
    * [cite_start]Configure the bridge to receive the `target_word` and a 1000-character context chunk from the WebView[cite: 63].
* **Native Context Scrape:**
    * [cite_start]Build a Dart-based `SentenceSplitter` using regex for `[.!?]` to isolate sentences outside of the high-latency WebView environment[cite: 64, 65].
* **Latency Optimization:**
    * [cite_start]Implement "Fire and Forget" asynchronous database writes to ensure the capture feels instant (<50ms) to the user[cite: 82, 83].

### Phase 4: High-Performance Search & Management
* **Full-Text Search (FTS5):**
    * [cite_start]Enable the **FTS5 extension** in SQLite for the `ghost_highlights` table to keep query speeds under 10ms[cite: 59, 60].
* **Cascade & Cleanup:**
    * [cite_start]Develop the logic for book deletion, ensuring it triggers a soft-delete update for all associated highlights[cite: 77, 86].

### Phase 5: Spaced Repetition (SRS) & Game Logic
* **The SM2 Service:**
    * [cite_start]Implement a pure Dart version of the **SuperMemo-2 algorithm** that accepts a `quality` score (0-5)[cite: 66, 67].
* **Game Deck Generation:**
    * [cite_start]Write the SQL query to pull the daily "Restoration Game" deck based on `next_review` dates and `interval` stats[cite: 58, 86].
* **Batch Updates:**
    * [cite_start]Create a service to trigger a single batch update to `mastery_stats` once a game session concludes[cite: 68].

### Phase 6: Offline Dictionary Optimization
* **Dictionary Compression:**
    * [cite_start]Package the 15MB WordNet database and index it using a **Prefix Tree** or **Mecab** for instantaneous "Emergency Synonym" lookups[cite: 84].
* **Memory Management:**
    * [cite_start]Implement the `dispose()` logic to clear `Epub.js` and WebView instances when the user exits the reader to prevent memory leaks[cite: 80, 81].