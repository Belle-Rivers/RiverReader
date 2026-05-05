This `design_system.md` is crafted to serve as the visual and structural backbone for **River Reader**. It adheres to the **Dark Academia** aesthetic while ensuring the technical implementation is optimized for Flutter’s rendering engine.

---

# Design System: The Scholar’s Palette (v1.0)

## 1. Core Philosophy
* **Silent Flow:** UI elements must never interrupt the reading experience.
* **Cognitive Sanctuary:** Low-contrast transitions and tactile textures to reduce digital eye strain.
* **Linguistic Artifacts:** Words are treated as valuable objects (artifacts) to be "restored" rather than "memorized."

---

## 2. Color Palettes (The Themes)
We implement three distinct environments using Flutter's `ThemeData`.

| Element | **Parchment (Default)** | **Midnight (Deep Focus)** | **Ink (OLED Night)** |
| :--- | :--- | :--- | :--- |
| **Background** | `#F4ECD8` (Paper texture) | `#1A1B26` (Storm blue) | `#000000` (True black) |
| **Primary Text** | `#2C2C2C` (Charcoal) | `#A9B1D6` (Soft slate) | `#E0E0E0` (Light grey) |
| **Accent (Gold)** | `#B8860B` (Aged gold) | `#E0AF68` (Warm amber) | `#BB9AF7` (Muted violet) |
| **Secondary Text**| `#6D6D6D` | `#565F89` | `#414868` |
| **Divider** | `#D9CDB0` | `#24283B` | `#1A1B26` |

---

## 3. Typography
* **Reading Serif (Body):** `Merriweather` or `Playfair Display`.
    * *Logic:* High legibility for long-form text.
* **UI Sans-Serif (System):** `Inter` or `Montserrat`.
    * *Logic:* Precision and modern feel for navigation.
* **Technical Mono (Captions):** `Roboto Mono`.
    * *Logic:* Used for word metadata and "Vault" stats.

---

## 4. Iconography & Texture
* **Library:** `LucideIcons` (Thin/Light weight). Use icons that look like line drawings.
* **Grain Overlay:** A global `Opacity(0.03, Image.asset('assets/textures/paper_grain.png'))` applied over the entire app to give a physical, non-digital feel.
* **Shadows:** Avoid large blurs. Use "Inner Shadows" for buttons to make them look pressed into the paper.

---

## 5. Gamification-Specific Widgets

### A. The "Ink Well" Progress Bar
* **Component:** A custom vertical progress bar that looks like an ink container.
* **Animation:** As the user restores words, the ink level rises with a slight wave animation (`CurvedAnimation`).

### B. The "Linguistic Artifact" Card
* **Component:** A card with a deckle-edge border (using `CustomPainter`).
* **State:** * *Unrestored:* Faded, "dusty" appearance.
    * *Restored:* Crisp text with a "Golden Ink" glow (`BoxShadow` with `SpreadRadius`).

### C. Tactile Restoration Tiles
* **Component:** Individual letter tiles for the Cloze tests.
* **Interaction:** `Draggable` widgets that provide a `HapticFeedback.selectionClick()` when moved.

---

## 6. Motion & Transitions

### A. The Ghost Highlight (Signature Animation)
* **Trigger:** Text selection in the Reader.
* **Visual:** A `ShaderMask` creating a silver-to-transparent linear gradient shimmer that sweeps across the word in **500ms**.
* **Haptic:** `HapticFeedback.mediumImpact()` exactly halfway through the shimmer.

### B. Skeuomorphic Page Flip
* **Implementation:** Use a `Transform` widget with a 3D rotation on the Y-axis. 
* **Curve:** `Curves.easeInOutCubic` to simulate the weight of heavy paper.

### C. The "Vault" Entry
* **Transition:** A `Hero` animation where the book cover expands into the "Vault" background, blurring the text and bringing the "Artifacts" into focus.

---

## 7. Flutter Library & Tech Stack

| Type | Library Recommendation |
| :--- | :--- |
| **State Management** | `flutter_riverpod` |
| **Persistence** | `sqflite` (with `drift` for type-safety) |
| **EPUB Engine** | `flutter_inappwebview` (to inject JS Ghost Highlight logic) |
| **Animations** | `simple_animations` or `flutter_animate` |
| **Fonts** | `google_fonts` |
| **Haptics** | `vibration` (for fine-tuned control) |

---

## 8. Implementation Notes for the Senior FE
1.  **Global Texture:** Use a `Stack` at the root of your `MaterialApp` to keep the paper texture consistent during page transitions.
2.  **Highlight Latency:** The "Ghost Highlight" must be local-first. Trigger the animation *before* the SQLite `await` call to ensure the 50ms latency target is met.
3.  **Adaptive UI:** Ensure the Reader HUD (Heads Up Display) uses `SystemChrome.setEnabledSystemUIMode` to toggle immersive mode, allowing the user to focus entirely on the "Scholar's" environment.