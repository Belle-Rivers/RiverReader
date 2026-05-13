# Product Requirements Document (PRD): Project "River Reader" v1.0

**Project Name:** River Reader 


**Document Status:** Final / For Engineering Architecture  
**Document Version:** 1.0.4 (MVP Scale)  
**Author:** Senior Product Specialist (CPO Level)  
**Primary Tech Stack:** Flutter (Frontend) / FastAPI (Backend API) / SQLite / Epub.js Integration  

---

## 1. Executive Summary & Strategic Intent

### 1.1 The Problem Space
Intermediate English learners (B1-B2) suffer from "Dictionary Attrition." The transition from graded readers to authentic literature is often abandoned because the cognitive load of switching between a narrative and a translation tool breaks the Prefrontal Cortex's "Flow State." Current e-readers (Kindle, Apple Books) emphasize active study (heavy highlights, pop-up definitions), which reinforces the feeling of "studying" rather than "experiencing."

### 1.2 The "Silent Flow" Thesis
To achieve fluency, a user must consume high volumes of "Comprehensible Input" (Krashen’s Theory). **Silent Flow** is a psychological scaffold. It allows a user to flag an unknown word in **0.4 seconds** without seeing a definition, trusting that the "Vault" will handle the learning phase later. This separates the **Acquisition Phase** (Reading) from the **Reinforcement Phase** (Gaming).

### 1.3 Business Objective (The Unicorn Path)
* **Retention over Acquisition:** Create a "High-Utility Habit" where users feel they are building a personal linguistic asset (The Vault).
* **Market Positioning:** High-end, premium "Dark Academia" aesthetic targeting the $3B+ language learning app market, specifically the underserved "Upper Intermediate" segment.

---

## 2. Comprehensive User Personas

### 2.1 The "Plateau" Professional (Persona A)
* **Profile:** 28-45 years old, works in a global tech/finance hub.
* **Pain Point:** Can read news but struggles with the nuance of fiction (metaphors, phrasal verbs). Hates feeling like a "student" with flashcards.
* **The "Silent" Value:** Allows them to read *The Great Gatsby* on the train without looking like they are in a language class.

### 2.2 The Aesthetic Academic (Persona B)
* **Profile:** 18-24 years old, university student, heavy user of "Studygram" or "BookTok."
* **Pain Point:** Digital fatigue. Finds Duolingo "childish" and Kindle "utilitarian."
* **The "Silent" Value:** The "Scholar" UI themes and haptic feedback provide a tactile, premium sensory experience.

---

## 3. Detailed Functional Requirements (The "Big 10" Breakdown)

### [F01] High-Fidelity EPUB Rendering Engine (P0)
* **Core Logic:** Implement a WebView-based wrapper for `Epub.js` or a native Flutter rendering engine.
* **Requirements:**
    * **Reflowable Text:** Must recalculate pagination based on font size changes in <200ms.
    * **CFI Support:** Canonical Fragment Identifiers are mandatory for bookmarking and "Jump to Source" logic.
    * **CSS Injection:** System must inject custom stylesheets for "Sunlight" and "Midnight" modes to override book-specific hardcoded styles.
* **Edge Case:** Handle EPUBs with internal CSS that forces "white-background" text, ensuring our themes remain dominant.

### [F02] The "Ghost" Highlight (P0)
* **Interaction Design:** * **Trigger:** Single-word swipe or long-press.
    * **Haptic Profile:** "Light Impact" (iOS: UIImpactFeedbackStyleLight).
    * **Visual Feedback:** A 500ms "Shimmer" (Radial Gradient Mask) that travels across the word and fades. 
* **Constraint:** The highlight must NOT persist. The word must look identical to the surrounding text after the shimmer ends.
* **Technical Requirement:** Capture the `id` of the word and its position in the DOM without altering the DOM tree permanently.

### [F03] Context-Aware Metadata Harvesting (P0)
* **Logic:** Upon trigger of [F02], the system must execute a "Context Scrape."
* **Algorithm:** 1.  Identify the index of the `target_word`.
    2.  Seek the nearest sentence terminators (`.`, `!`, `?`) backwards and forwards.
    3.  Store: `[Sentence_Before] + [Sentence_with_Word] + [Sentence_After]`.
* **Metadata:** Store the book title, author, and Chapter Name automatically.

### [F04] The Scholar’s Vault (P1)
* **UI:** A "Library" view where words are displayed as "Artifacts."
* **Sorting:** By "Recency," "Difficulty" (based on word length/frequency), and "Source."
* **Search:** Full-text search across both target words and context sentences.

### [F05] The Restoration Game (Core Loop) (P0)
* **Mode:** Cloze-style fill-in-the-blank (multiple choice tiles) and optional **Match meanings** pairing game.
* **Logic:** The game tests words from the **Scholar's Vault** (reading captures). The sentence shown in **Complete the sentence** is **not** always the same as the captured `context_sentence`: when a dictionary `example_sentence` exists, that standalone line is used so the learner applies the word in a *new* context; otherwise the app falls back to the captured sentence until an example is available. The Vault still shows the original mention for source memory.
* **Input Method:** Multiple-choice word tiles (MVP). Optional future: scrambled letter tiles or typing for higher mastery.
* **SRS Integration:** Use a modified SuperMemo-2 (SM2) algorithm to schedule when words reappear in the game loop based on user performance.

### [F06] The "Source Link" Deep-Linking (P1)
* **Mechanism:** Each word card in the Vault contains a "Return to Narrative" icon.
* **Action:** Triggers the EPUB reader to navigate to the specific `CFI` stored in [F03].
* **UX:** The reader opens, scrolls to the word, and triggers a single "Ghost Shimmer" to orient the user's eye.

### [F07] Emergency "Synonym" Hint (P2)
* **Trigger:** Double-tap.
* **API:** Call a local WordNet dictionary or a lightweight English-English API.
* **UI:** A transient, non-modal tooltip that disappears as soon as the user scrolls or taps elsewhere.
* **Rule:** No translations. Only synonyms (e.g., "Meticulous" -> "Very careful; detailed").
* **Implementation (MVP / dev backend + Flutter):** ✅ `GET /v1/dictionary/{word}` powers the reader hint overlay and Vault word details. Dev-only write APIs (`POST` / `PUT` / `PATCH` / `DELETE` `/v1/dictionary`) seed `dictionary_entries` until the offline WordNet bundle ships. Reader **double-tap** requests a hint; **long-press** performs silent Vault capture so the two gestures do not collide.

### [F08] "Scholar" UI Themes (P1)
* **Sunlight:** `#F1F0CC` Background / `#1F1B14` Text.
* **Midnight:** `#030A23` Background / `#F9F4DA` Text.
* **Typography Scale:** * Body: 16pt - 24pt (Adjustable).
    * Line Height: 1.5x - 1.8x.

### [F09] Mastery Visualization (P2)
* **The "Linguistic Map":** A heat map or node-graph showing words mastered per book.
* **Psychology:** Use "Loss Aversion"—if they don't play the Restoration Game, their "Mastery Streak" for that book visually "fades."

### [F10] The Silent Onboarding (P1)
* **Copywriting:** Focus on "The Contract." 
    * "I will not look up words."
    * "I will trust my brain's pattern recognition."
    * "I will enjoy the story first."
 
#### [F11] Local Library Management (P0)
* **Requirement:** A "Shelf" view that displays all imported EPUBs using extracted metadata (Cover Art, Title, Author).
* **Persistence:** The system must save the `last_cfi` (last read position) every time the reader view is closed, allowing for "1-tap resume."
* **Implementation (dev backend + Flutter):** Home dashboard uses `GET /v1/me/home` — aggregate stats (books, vault size, due reviews), resume-reading from last opened book + saved progress, and the five most recent vault captures (word + book title).

#### [F12] The "Reveal" Logic in Restoration (P1)
* **Requirement:** In the [F05] Game, after a user submits an answer, the UI must "flip" or expand the card to show a dictionary definition and the "Emergency Synonym" from [F07].
* **Purpose:** To bridge the gap between "recognizing a word exists" and "knowing what it means" without leaving the game loop.

#### [F13] Import/Delete Workflow (P0)
* **Requirement:** A simple "+" button to trigger the native file picker (iOS Files / Android Documents).
* **Cleanup:** Users must be able to delete a book from the library, which should also trigger a "cleanup" of the database (or a prompt to keep/delete the associated words in the Vault).

---

## 4. Technical Architecture & Constraints

### 4.1 Data Schema (SQLite)
```sql
CREATE TABLE books (
    book_id UUID PRIMARY KEY,
    title TEXT,
    author TEXT,
    cover_blob BLOB,
    last_cfi TEXT
);

CREATE TABLE ghost_highlights (
    highlight_id UUID PRIMARY KEY,
    book_id UUID,
    target_word TEXT,
    sentence_context TEXT,
    cfi_location TEXT,
    mastery_level INT DEFAULT 0, -- 0 to 5
    next_review_date TIMESTAMP,
    FOREIGN KEY(book_id) REFERENCES books(book_id)
);
```

### 4.2 State Management
* **Provider/Riverpod (Flutter):** To manage the "Reading Theme" globally and the "Highlight Stream" which triggers haptics and DB writes asynchronously to ensure zero lag in the UI thread.

### 4.3 User Profile & Entitlement Metadata
* **MVP Identity:** Username-only local profile for personalization; password authentication is deferred until multi-user or cloud sync is required.
* **User-Entered Fields:** Username, optional display name, and optional English level for personalization.
* **System-Collected Fields:** Device install ID, preferred locale, timezone, subscription status, App Store product ID, App Store original transaction ID, and subscription expiration date.
* **Entitlement Rule:** Subscription fields are optional at registration and can be updated later after StoreKit/App Store receipt validation.

### 4.4 Performance Benchmarks
* **Cold Start to Book:** < 1.5 seconds.
* **Highlight Latency:** < 50ms (Capture must feel "instant").
* **Search Speed:** < 100ms for 1,000+ words.

---

## 5. UI/UX & Design Language

### 5.1 Motion Design
* **Transitions:** Use "Staggered Fades" for the Vault list.
* **The Page Turn:** A skeuomorphic "Curl" effect (optional) or a "Horizontal Slide" with 0% bounce.

### 5.2 Sound Design (The Audio "Anchor")
* **The Capture:** A "thwip" sound (low frequency, 10ms).
* **The Restoration:** A "pencil-on-paper" scratching sound for correct answers.

---

## 6. Strategic Roadmap

### Phase 1: The Core (MVP - Current)
* EPUB rendering + Ghost Highlighting + Simple Restoration Game.
* Local storage only.

### Phase 2: The Social Scholar (v1.2)
* "Commonly Ghosted Words": See which words other readers of *1984* found difficult.
* Cloud Sync across devices.

### Phase 3: The AI Tutor (v1.5)
* LLM-generated "Restoration Games" that create brand new stories using the user's captured words.

---

## 7. KPIs & Success Metrics

1.  **Ghosting Frequency:** Average highlights per 1,000 words (Target: 5-15).
2.  **Session Length:** Average reading time per session (Target: >18 minutes).
3.  **The "Morning-After" Loop:** Percentage of users who open the Vault within 24 hours of a reading session.
4.  **Churn Correlation:** Do users who capture >50 words in week 1 stay for month 2? (Predictive metric).

---

## 8. Appendix: Developer "Watch-Outs"

* **iOS Text Selection:** Standard iOS behavior wants to show "Copy/Look Up." This MUST be disabled or overridden to allow the "Ghost Swipe" to work without the system menu popping up.
* **EPUB Images:** Ensure the parser handles images and SVGs within the flowable text without breaking the CFI calculation.
* **UTF-8 Handling:** Ensure phrasal verbs or words with accents (common in English loanwords) are captured accurately.

---

> **Specialist's Insight:** By making the "meaning" of the word a reward *inside* the game, we turn the dictionary lookup from a "interruption" into a "victory." It’s a subtle shift that makes the learner feel like they are solving a mystery rather than doing homework.
