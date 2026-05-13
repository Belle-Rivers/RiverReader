
# MVP Specification: Project "River Reader"
**Product Developer:** Rawan ElShenieky  
**Version:** 1.0 (MVP)  
**Target Audience:** B1-B2 "Intermediate Plateau" English Learners (Teens/Adults)  
**Aesthetic:** "The Scholar" (Minimalist, Dark Academia, High-End Reading Experience)

---

## 1. Product Vision
To bridge the gap between "Learning a Language" and "Reading for Pleasure" by removing the cognitive friction of dictionary lookups. We provide a psychological scaffold through **Silent Highlighting** and **Contextual Recall Games**.

---

## 2. Core User Loop
1. **Import:** User uploads an EPUB or Web Article.
2. **Immerse:** User reads. When they hit an unknown word, they swipe it. 
3. **Confirm:** A subtle haptic/visual "shimmer" confirms the word is saved without breaking flow.
4. **Master:** After the session, the user enters "The Archive" to play a restoration game using their own captured sentences.

---

## 3. The 10 "Must-Have" Features (MVP)

### [F01] High-Fidelity EPUB Parser
* **Requirement:** Must render `.epub` files with flowable text.
* **Capabilities:** Font resizing, line-height adjustment, and chapter navigation.
* **Goal:** Provide a reading experience that rivals Kindle or Apple Books.

### [F02] The "Ghost" Highlight (Silent Capture)
* **Requirement:** A gesture-based selection (swipe or long-press).
* **UX:** Upon selection, the word displays a 0.5s low-opacity shimmer or a "taptic" vibration.
* **Visuals:** No permanent yellow/bright highlight. The text remains clean to maintain the "movie in the head."

### [F03] Context-Aware Metadata Capture
* **Requirement:** When a word is highlighted, the system must automatically save the **entire sentence** (string) surrounding it.
* **Technical:** Capture `[Preceding_Sentence] + [Target_Word] + [Succeeding_Sentence]`.

### [F04] The Scholar’s Vault (Archive)
* **Requirement:** A centralized list of all captured words.
* **Organization:** Grouped by "Source Material" (e.g., *Words from 'Great Gatsby'*).
* **Details:** Displays the word, the captured sentence, and a placeholder for the definition.

### [F05] The "Restoration" Game (Core Gamification)
* **Requirement:** A Cloze-test (Fill-in-the-blank) exercise.
* **Mechanic:** The app shows the captured sentence with the target word redacted. User must type or select the word from a small list.
* **Purpose:** Active recall based on the *narrative context* they just read.

### [F06] The "Source Link" (Contextual Jump)
* **Requirement:** Every word in the Vault/Game has a "Jump to Source" button.
* **Function:** Instantly opens the book to the exact page where that word exists.

### [F07] Emergency "Synonym" Hint
* **Requirement:** An "escape hatch" for when flow is totally blocked.
* **Interaction:** Double-tap a word during reading.
* **Content:** Shows a 2-second pop-up with a **synonym in English** (not a translation).

### [F08] "Scholar" UI Themes
* **Requirement:** Two high-quality reading modes.
* **Themes:** * *Sunlight:* Warm cream with charcoal text.
    * *Midnight:* Deep slate with off-white text.

### [F09] Mastery Progress Visualization
* **Requirement:** A simple dashboard.
* **Metrics:** "Words Encountered" vs. "Words Restored" (Mastered).
* **Psychology:** Show the B1-B2 learner they are "owning" more of the language every day.

### [F10] "The Silent Method" Onboarding
* **Requirement:** A 3-slide "contract" with the user.
* **Content:** Explain that they shouldn't look up words. They should trust the "Ghost Highlight" and the "Vault." This manages the anxiety of the intermediate learner.

---

## 4. Technical Constraints (MVP)
* **Platform:** Mobile-first (iOS/Android) via Flutter or React Native for rapid deployment.
* **Data:** Local storage for the Vault (can move to Cloud in V1.1).
* **File Support:** **EPUB Only** for MVP (PDF is out of scope due to parsing complexity).

---

## 5. Success Metrics (KPIs)
1. **Retention (D7):** Percentage of users who return to finish the first book they uploaded.
2. **Highlight Density:** Average number of "Ghost Highlights" per chapter (checks if the feature is being used).
3. **The "Game Loop" Entry:** Percentage of users who enter the "Vault" after a 15-minute reading session.

---

## 6. Design Vibe
* **Typography:** Serif fonts for reading (Merriweather, Playfair Display); Sans-serif for the UI.
* **Interactions:** Fluid, weighted, and intentional. No "bouncing" or "cartoonish" animations.
* **Sound:** Subtle "paper-flip" sounds and "ink-scratch" feedback for games.

***

### 💡 Pro-Tip for your Developer:
*The most difficult part of this MVP will be **Feature [F01] & [F02] integration**. Handling text selection inside a custom-rendered EPUB view requires careful handling of CSS and DOM selections. Make sure your developer prioritizes the "Text Selection Engine" above all else.*
