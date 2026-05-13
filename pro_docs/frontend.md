This checklist is structured to follow the logical flow of development: starting with the **Reader Foundation** (where the data is born), moving to **Data Management** (The Vault), and culminating in the **Engagement Layer** (The Restoration Game).

Since we are prioritizing "Silent Flow," the UI will focus on minimizing friction before we introduce the dopamine-heavy gamification elements.

---

### Phase 1: The Foundation & Design System
*Goal: Establish the "Scholar’s Palette" and the Library shell to support backend file ingestion.*

- [ ] **Design Token Implementation:**
    - [ ] Define `ThemeData` for **Sunlight** and **Midnight**.
    - [ ] Set up Typography scales using `Merriweather` (Body) and `Inter` (UI).
- [ ] **Library Shelf (Page):**
    - [ ] `SliverGrid` layout for book covers with a "Staggered Entrance" animation.
    - [ ] Empty state UI: "Your library is a silent room. Add a book to begin."
- [ ] **File Ingestion UI (Component):**
    - [ ] Bottom-sheet/Overlay for EPUB uploads.
    - [ ] **Import Progress Bar:** A thin, elegant line animation at the top of the screen.
- [ ] **Navigation Architecture:**
    - [ ] Implement a custom `PersistentTabController` or specialized router for seamless transitions between the Reader and the Vault.

---

### Phase 2: The Core Reader ("Silent Flow")
*Goal: Implement the Ghost Highlight (F01/F02) and sync with the SQLite backend.*

- [ ] **EPUB Viewer Integration:**
    - [ ] `WebView` or custom parser setup with CFI (Content Fragment Identifier) support for precise position saving.
- [ ] **The Ghost Highlight (Animation):**
    - [ ] **The Shimmer:** Create a `CustomPainter` or `ShaderMask` for the 500ms silver/gold glimmer effect upon text selection.
    - [ ] **Haptic Trigger:** Integrate `HapticFeedback.lightImpact()` exactly at the shimmer’s peak.
- [ ] **The Reading Overlay (UI):**
    - [ ] **HUD (Heads-Up Display):** Auto-hiding header/footer with reading progress percentage.
    - [ ] **Emergency Synonym (P2):** An `OverlayPortal` tooltip that appears on double-tap (zero-latency).
- [ ] **Transition:** Implementation of the "Page Flip" skeuomorphic animation (Flutter `CustomPainter` or `Transform.rotate`).

---

### Phase 3: The Scholar’s Vault (Vocabulary Management)
*Goal: Visualize the "Linguistic Artifacts" captured during reading (F04/F06).*

- [ ] **The Vault List (Page):**
    - [ ] Interactive list of words using `AnimatedList` for deletions/additions.
    - [ ] **Word Card Component:** Displays word, context sentence (Context Scrape), and "Artifact Grade" (Mastery Level).
- [ ] **The Dictionary Modal (Component):**
    - [ ] A sliding panel (bottom-up) showing AI-generated definitions and synonyms.
    - [ ] **"Return to Narrative" Button:** A deep-link transition that jumps the user back to the exact CFI in the Reader.
- [ ] **Search & Filter:** Minimalist UI for filtering by "New," "In Restoration," or "Mastered."

---

### Phase 4: The Restoration Game (Gamification)
*Goal: Turn spaced repetition into a tactile experience (F05/F12).*

- [ ] **Game Entrance Transition:**
    - [ ] A "Focus Zoom" animation that blurs the background and centers the "Linguistic Artifact" card.
- [ ] **Restoration Mechanics (Components):**
    - [ ] **Cloze Test UI:** Context sentence with a hole (`_____`) where the word should be.
    - [ ] **Tactile Tiles:** Draggable `Container` objects for the scrambled letters of the target word.
- [ ] **Feedback Loop (Animations):**
    - [ ] **Success:** The card flips 180 degrees (`AnimatedBuilder`) to reveal the definition with a "Golden Ink" glow.
    - [ ] **Failure:** A subtle "Red Ink Bleed" or shake animation on the card.
- [ ] **XP/Progress HUD:** A minimalist "Ink Well" that fills up as the user completes restoration rounds.

---

### Phase 5: Mastery & Progress Visualization
*Goal: Provide long-term motivation through data (F09).*

- [ ] **The Linguistic Map (Page):**
    - [ ] **Heatmap Widget:** A custom-drawn grid showing reading consistency (GitHub style but in the Scholar’s Palette).
    - [ ] **Mastery Nodes:** A `CustomPaint` radial graph showing the percentage of "Artifacts" fully restored.
- [ ] **Daily Streak Component:**
    - [ ] A small, elegant counter that only appears when a goal is met (to avoid cluttering the "Silent Flow").

---

### Phase 6: Polish, Juice, & Optimization
*Goal: Ensure the high-end senior engineer feel.*

- [ ] **Global Transitions:**
    - [ ] Shared Element Transitions (using Flutter’s `Hero` widget) for book covers and word cards.
- [ ] **Performance Audit:**
    - [ ] Ensure **60/120fps** during Ghost Highlight shimmer.
    - [ ] Lazy loading for the Vault to handle thousands of words without lag.
- [ ] **The "Final Touch":**
    - [ ] Subtle grain/texture overlay across the entire app to simulate physical paper.

---

> **Engineer's Note:** We should tackle **Phase 1 and 2 concurrently**. Without a working Reader foundation, we have no data to feed the Vault or the Restoration Game. Which specific component would you like to start building first?