---
name: Whimsical Scholar
colors:
  surface: '#fffbdc'
  surface-dim: '#dfdbbd'
  surface-bright: '#fffbdc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f9f5d6'
  surface-container: '#f3efd0'
  surface-container-high: '#ede9cb'
  surface-container-highest: '#e7e4c5'
  on-surface: '#1d1c0a'
  on-surface-variant: '#3e4944'
  inverse-surface: '#32311d'
  inverse-on-surface: '#f6f2d3'
  outline: '#6e7a74'
  outline-variant: '#bdc9c2'
  surface-tint: '#7fe1be'
  primary: '#7fe1be'
  on-primary: '#00644c'
  primary-container: '#7fe1be'
  on-primary-container: '#00644c'
  inverse-primary: '#77d9b6'
  secondary: '#bbaaf6'
  on-secondary: '#2a1a5e'
  secondary-container: '#c2b1fd'
  on-secondary-container: '#4f4084'
  tertiary: '#f4d569'
  on-tertiary: '#4a3c00'
  tertiary-container: '#ebcd62'
  on-tertiary-container: '#6a5600'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#93f5d1'
  primary-fixed-dim: '#77d9b6'
  on-primary-fixed: '#002117'
  on-primary-fixed-variant: '#00513d'
  secondary-fixed: '#e7deff'
  secondary-fixed-dim: '#cdbdff'
  on-secondary-fixed: '#1f0b51'
  on-secondary-fixed-variant: '#4b3c7f'
  tertiary-fixed: '#ffe179'
  tertiary-fixed-dim: '#e2c45a'
  on-tertiary-fixed: '#231b00'
  on-tertiary-fixed-variant: '#554500'
  background: '#fffbdc'
  on-background: '#1d1c0a'
  surface-variant: '#e7e4c5'
typography:
  display-lg:
    fontFamily: Newsreader
    fontSize: 48px
    fontWeight: '600'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Newsreader
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
  headline-md:
    fontFamily: Newsreader
    fontSize: 24px
    fontWeight: '500'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.4'
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  xs: 0.25rem
  sm: 0.5rem
  md: 1rem
  lg: 1.5rem
  xl: 2.5rem
  gutter: 1rem
  margin-mobile: 1rem
  margin-desktop: 2.5rem
---

## Brand & Style

The personality of this design system is a "Whimsical Scholar"—an aesthetic that celebrates the joy of reading and the magic of linguistics without the heaviness of traditional academia. It moves away from dusty libraries and dark wood towards sun-drenched reading nooks and sparkling insights. The target audience includes lifelong learners, casual readers, and bibliophiles who seek a serene yet playful digital environment.

The visual style is a blend of **Minimalism** and **Tactile** design. It uses heavy whitespace and a restricted pastel palette to maintain clarity, while employing soft gradients and "puffy" UI elements to create an inviting, approachable atmosphere. The goal is to evoke a sense of wonder, making the act of reading feel like a magical discovery.

## Colors

The palette is anchored by a warm Cream (#fffbdc) background, which provides a softer reading experience than pure white. Mint (#7fe1be) serves as the primary action color, symbolizing growth and the "flow" of the river. Lavender (#bbaaf6) and Sunny Yellow (#f4d569) act as secondary accents for highlights and progress indicators.

**Dark Mode Strategy:**
Transition from a "Sunlight" theme to a "Midnight Library" theme. The cream background shifts to a deep, desaturated charcoal with a slight yellow tint (#1c1b14). Pastel accents are muted and slightly deepened (e.g., Mint becomes a sage teal, Pink becomes a dusty mauve) to maintain readability and reduce eye strain while preserving the whimsical character.

## Typography

This design system utilizes a tiered typography approach to balance literary tradition with modern usability. 

- **Newsreader** is the primary serif typeface for headlines and long-form reading content. It provides the "Scholar" element, offering high legibility and an authoritative yet graceful rhythm.
- **Plus Jakarta Sans** is used for all UI-related elements, labels, and navigation. Its rounded terminals and open apertures complement the "Whimsical" aesthetic and ensure the interface feels friendly and accessible. 

Vertical rhythm should be strictly maintained to ensure a comfortable reading experience, with body text utilizing a generous line height of 1.6x.

## Layout & Spacing

The layout philosophy follows a **Fluid Grid** model with a focus on generous negative space to prevent cognitive overload. 

- **Grid:** Use a 12-column grid for desktop and a 4-column grid for mobile. 
- **Rhythm:** Spacing follows an 8px base unit. 
- **Margins:** Large horizontal margins (40px+) on desktop help center the reading experience, mimicking the margins of a well-designed book page. 
- **Padding:** Containers should use generous internal padding to create a "breathable" feel, ensuring text never feels cramped against its borders.

## Elevation & Depth

Hierarchy is established through **Tonal Layers** and **Ambient Shadows**. Instead of harsh black shadows, this design system uses soft, tinted shadows that pull colors from the element itself or the underlying surface.

- **Level 1 (Base):** Cream background.
- **Level 2 (Cards/Surface):** White or very light tinted surfaces with a 1px soft border in a slightly darker shade of the background.
- **Level 3 (Interactive):** Elevated elements use a diffused shadow (12px blur, 10% opacity) tinted with the primary Mint or Lavender color to create a "glow" effect rather than a traditional drop shadow.

Glassmorphism is used sparingly for navigation bars and overlays, utilizing a subtle backdrop blur (8px) and a semi-transparent white tint to maintain the "light and airy" energy.

## Shapes

The shape language is defined by the **ROUND_EIGHT** principle. All standard UI containers, buttons, and input fields utilize a base radius of 0.5rem (8px). 

Larger components, such as featured book cards or modal containers, use `rounded-xl` (1.5rem) to emphasize the playful, soft-touch nature of the design. Icons should follow this logic, utilizing rounded caps and joins rather than sharp corners to remain consistent with the friendly typography.

## Components

### Buttons
Buttons are "puffy" and inviting. Primary buttons use a soft linear gradient from Mint (#7fe1be) to a slightly lighter version. They feature a 0.5rem corner radius and a subtle, color-matched bottom shadow to create a tactile, pressable feel.

### Cards
Cards are the primary container for content. They should have a 1px border in Dusty Rose (#e3bdbd) at 30% opacity and a 1rem corner radius. Use the Cream background for the card body to keep the interface feeling light.

### Chips & Tags
Used for categories or linguistic artifacts. These are pill-shaped with background colors drawn from the accent palette (Lavender, Pink, Yellow) at 20% opacity, paired with high-contrast text for accessibility.

### Input Fields
Inputs should feel soft. Use a 0.5rem radius, a Cream background slightly darker than the page, and a Mint focus ring that "glows" (soft outer shadow) when active.

### Progress Indicators
Instead of standard bars, use "River Trails"—thicker, rounded lines in Mint that feature a small "sparkle" icon (drawn from the logo) at the leading edge of the progress.

### Navigation
The bottom navigation or sidebar should use a Lavender tint for active states, with icons that feel hand-drawn but clean, mirroring the logo's "River Reader" script style.

---

## Core Philosophy

*   **Silent Flow:** UI elements must never interrupt the reading experience. Navigation should feel like turning a page, not clicking a button.
*   **Cognitive Sanctuary:** Low-contrast transitions and tactile textures to reduce digital eye strain during long-form reading.
*   **Linguistic Artifacts:** Words are treated as valuable objects (artifacts) to be "restored" rather than "memorized." The UI should evoke the feeling of an archeological discovery.

## Midnight Library (Dark Mode)

The Midnight theme is designed for deep focus and nighttime reading. It preserves the "Scholar" aesthetic by using warm dark tones rather than pure blacks.

| Element | Color Code | Description |
| :--- | :--- | :--- |
| **Background** | `#1C1B14` | Deep charcoal with a slight yellow tint for warmth. |
| **Surface** | `#2A2920` | Elevated surfaces (Cards, Modals). |
| **Primary (Sage)** | `#77D9B6` | Muted version of the Sunlight Mint. |
| **On-Surface** | `#E7E4C5` | Desaturated cream text for high readability. |

## Gamification-Specific Widgets

### A. The "Ink Well" Progress Bar
A custom vertical progress bar that looks like an ink container. As the user restores words, the ink level rises with a slight wave animation (`CurvedAnimation`).

### B. The "Linguistic Artifact" Card
A card with a deckle-edge border (using `CustomPainter`). 
*   **Unrestored:** Faded, "dusty" appearance with lower contrast text.
*   **Restored:** Crisp text with a "Golden Ink" glow effect (`BoxShadow` with `SpreadRadius`).

### C. Tactile Restoration Tiles
Individual letter tiles for Cloze tests. These are `Draggable` widgets that provide `HapticFeedback.selectionClick()` when moved or placed.

## Motion & Transitions

### A. The Ghost Highlight
Signature selection animation. A `ShaderMask` creates a silver-to-transparent linear gradient shimmer that sweeps across the selected word in **500ms**, accompanied by a medium haptic impact halfway through.

### B. Skeuomorphic Page Flip
Uses `Transform` widgets with 3D rotation on the Y-axis and `Curves.easeInOutCubic` to simulate the physical weight of heavy paper.

### C. The "Vault" Entry
A `Hero` animation where the book cover expands into the "Vault" background, blurring the text and bringing the "Artifacts" into focus.

## Technical Implementation & Stack

| Type | Library | Purpose |
| :--- | :--- | :--- |
| **State Management** | `flutter_riverpod` | Global state and theme switching. |
| **Persistence** | `sqflite` | Local storage for book data and word progress. |
| **EPUB Engine** | `flutter_inappwebview` | Rendering book content and injecting JS highlights. |
| **Animations** | `flutter_animate` | Orchestrating UI transitions and glows. |
| **Navigation** | `go_router` | Declarative routing system. |

## Developer Implementation Notes

1.  **Global Texture:** Consider using a `Stack` at the root of the `MaterialApp` to apply a subtle paper grain overlay (`Opacity 0.03`) to keep the "Tactile" feel consistent across transitions.
2.  **Highlight Latency:** The "Ghost Highlight" must feel instantaneous. Trigger the visual animation *before* any SQLite persistence calls to ensure sub-50ms feedback.
3.  **Adaptive UI:** The Reader HUD should use `SystemChrome` to toggle immersive mode, allowing the "Whimsical Scholar" environment to fill the entire screen.