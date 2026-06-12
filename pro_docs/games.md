# River Reader — Architectural & Game Design Specification
**Target Audience:** Casual Intermediate Readers
**Core Technology Stack:** Client-Side SQLite, FastAPI Integration Wrapper, Groq API (`llama-3.1-8b-instant`)
**Document Purpose:** Production blueprint for the engineering and game design teams.

---

## 1. System Architecture & Data Pipeline

To avoid external database hosting costs (e.g., Supabase), River Reader operates completely on a client-side local storage architecture using SQLite. The core optimization strategy relies on a single master batch API call per word, combining all game variants into one network request.

### 1.1 Local SQLite Schema
The local database must maintain two core tables to manage the vocabulary lifecycle and the game state:



CREATE TABLE IF NOT EXISTS word_vault (
    word TEXT PRIMARY KEY,
    added_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT CHECK(status IN ('New', 'Learning', 'Learned')) DEFAULT 'New',
    correct_streak INTEGER DEFAULT 0,
    last_practiced_timestamp DATETIME,
    next_review_timestamp DATETIME
);

CREATE TABLE IF NOT EXISTS game_cache (
    word TEXT PRIMARY KEY,
    context_clash_json TEXT,  -- Contains correct, clash, and explanation
    odd_one_out_json TEXT,    -- Contains synonyms and misfit
    true_or_bluff_json TEXT,  -- Contains statement and answer
    generation_status TEXT CHECK(generation_status IN ('Pending', 'Completed', 'Failed')) DEFAULT 'Pending',
    FOREIGN KEY(word) REFERENCES word_vault(word) ON DELETE CASCADE
);

```

### 1.2 User-Specific Local Caching & Background Async Fetching

To guarantee zero-cost scalability and shield the user from latency or Groq API rate limits (30 RPM), the application must implement a decoupled, asynchronous queue pattern.

```
[User Highlights Word] 
         │
         ▼
 ┌───────────────┐
 │  Local SQLite │ ──(Exists?)──> YES ──> [Do Nothing / Silently Complete]
 └───────────────┘
         │
         NO
         ▼
 ┌──────────────────────────┐
 │ Insert to 'game_cache'   │
 │ status = 'Pending'       │
 └──────────────────────────┘
         │
         ▼
 ┌──────────────────────────┐
 │ Async Background Queue   │ ──(Fires worker thread / Service Worker)
 └──────────────────────────┘
         │
         ▼
 ┌──────────────────────────┐
 │ FastAPI API Client       │ ──(Rate Limit Guard: Max 1 call per 2 seconds)
 └──────────────────────────┘
         │
         ▼
 ┌──────────────────────────┐
 │ Groq API: Llama 3.1 8B   │ ──(Fetches ALL 3 games in 1 Payload)
 └──────────────────────────┘
         │
         ▼
 ┌──────────────────────────┐
 │ Update 'game_cache'      │
 │ status = 'Completed'     │
 └──────────────────────────┘

```

#### Detailed Execution Sequence:

1. **The Interception:** When a user silently highlights a word while reading, the client app immediately writes the word to `word_vault` and sets its `game_cache` status to `'Pending'`. The reading UI never pauses or displays a loading indicator.
2. **The Micro-Queue Worker:** A background task loop (using standard FastAPI background tasks or a client-side Service Worker Web Worker) polls the database for `'Pending'` entries.
3. **The Rate-Limit Gatekeeper:** The background worker enforces a strict token bucket or sleep delay (minimum 2 seconds between outbound requests). This ensures that even if a rapid reader highlights 15 words on a page in under a minute, the application safely throttles requests to stay well below Groq’s 30 RPM limit.
4. **The Compound Payload:** The worker calls the FastAPI backend, which requests data from Groq. The system fetches payloads for *all three games at once*. Once returned, the JSON blocks are saved to `game_cache`, and the status shifts to `'Completed'`.

---

## 2. Core Gamification Framework

The gamification architecture is built around sustainable mechanics for casual intermediate readers. It avoids punishing design choices while creating loops that encourage habit formation.

### 2.1 Meta Mechanics

* **Hearts (Session Energy):** The user begins each gameplay session with **3 Hearts**.
* An incorrect answer deducts 1 Heart.
* If Hearts drop to 0, the session terminates immediately. The user receives partial XP/Points accumulated up to that point. This mechanic prevents endless, mindless guessing.


* **The Countdown Timer:** Every question features a **15-second visual countdown bar**.
* If the timer runs out, it counts as an incorrect answer (deducts 1 Heart).
* For casual intermediate readers, this urgency forces intuitive comprehension over calculated analytical processing.


* **Daily Streaks:** Tracks consecutive days the user has engaged with the app (either reading or playing a mini-game).
* **In-Game Combo Multipliers:** Consecutive correct answers multiply the base score ($1\times \rightarrow 1.5\times \rightarrow 2\times$). An incorrect answer resets the multiplier to $1\times$.

### 2.2 Core Loop Termination Criteria

A gaming session ends if and only if:

1. The user manually exits the session via the close utility.
2. The user loses all 3 Hearts.
3. The session game-stack is exhausted (all queued words for that session have been successfully reviewed).

---

## 3. Game Specifications & AI Generation Blueprints

To maximize efficiency and protect API resources, the system issues a single unified system prompt to `llama-3.1-8b-instant`. The response is requested strictly via the parameter `"response_format": {"type": "json_object"}`.

### 3.1 The Master AI Prompt Architecture

```text
You are an expert game designer specializing in lexical acquisition for casual intermediate English readers. 
Analyze the target word: "{word}".

Generate game content matching the exact JSON structure defined below. 
Constraints:
- Sentences must match the readability profile of a B1/B2 level English reader.
- Avoid academic, archaic, or esoteric terminology in definitions.
- For "context_clash", the clash sentence must be syntactically correct and sound natural, but contextually absurd.
- For "odd_one_out", provide 3 genuine synonyms and exactly 1 misfit word with no semantic overlap.
- For "true_or_bluff", generate a clear declarative condition statement.

Your output must strictly be raw JSON matching this schema:
{
  "context_clash": {
    "correct_sentence": "string",
    "clash_sentence": "string",
    "explanation": "string"
  },
  "odd_one_out": {
    "synonyms": ["string", "string", "string"],
    "misfit_word": "string"
  },
  "true_or_bluff": {
    "statement": "string",
    "is_true": boolean
  }
}

```

---

### 3.2 Game 1: "Context Clash"

#### User Flow & Mechanics:

1. The engine randomly positions the `correct_sentence` and the `clash_sentence` in top and bottom UI slot containers.
2. The countdown timer initializes at 15 seconds.
3. The user taps the sentence that they believe makes logical and contextual sense.

```
┌────────────────────────────────────────────────────────┐
│ [♥ ♥ ♥]                   ⏱ 12s               Streak: 4│
├────────────────────────────────────────────────────────┤
│                     CONTEXT CLASH                      │
│                                                        │
│ Tap the sentence that makes logical sense:             │
│                                                        │
│ ┌────────────────────────────────────────────────────┐ │
│ │ A) She was so meticulous that she threw all her    │ │
│ │ files into random, messy piles on the floor.       │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ B) She was so meticulous that she checked the long │ │
│ │ report four times for typing mistakes.             │ │
│ └────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘

```

#### State Outcomes:

* **Success State:** If the correct choice is selected, play a subtle success haptic/audio tone, award base points $\times$ current combo multiplier, increment the word's `correct_streak`, and transition to the next card.
* **Fail State:** If the incorrect choice is selected, highlight the selected option in muted red, slide down the `explanation` block from the JSON payload to provide micro-learning context, deduct 1 Heart, and reset the combo multiplier to $1\times$. The user must tap "Continue" to progress.

---

### 3.3 Game 2: "Odd One Out"

#### User Flow & Mechanics:

1. The UI extracts the 3 arrays elements from `synonyms` and the single element from `misfit_word`.
2. The four tokens are shuffled and rendered as selectable cards.
3. The user has 15 seconds to isolate the single "misfit" intruder word that doesn't share meaning with the target word.

#### State Outcomes:

* **Success State:** The misfit card turns green. The UI displays a clean micro-badge showing the definition of the target word for reinforcement. Award points and transition.
* **Fail State:** The chosen card shakes and turns red. The true misfit card flashes green to reveal the correct answer. The user loses 1 Heart.

---

### 3.4 Game 3: "True or Bluff"

#### User Flow & Mechanics:

1. Designed as a high-speed, binary choice elimination round.
2. The screen displays the generated `statement`.
3. Two large, prominent CTA buttons are anchored to the bottom layout: **"TRUE"** and **"BLUFF"**.
4. The timer bar drains rapidly. The user must instinctively confirm or refute the semantic integrity of the statement.

#### State Outcomes:

* **Success State:** Instant visual feedback. User advances while compounding points.
* **Fail State:** Screen flashes a soft red overlay. Deduct 1 Heart, show the correct answer clearly, and pause for 1.5 seconds before auto-advancing.

---

## 4. Word State Lifecycle & Mastery Retention (Expert Opinion)

A common pitfall in educational software design is isolating "learned" words entirely from gameplay loops.

### 4.1 Expert Verdict on Learned Word Retention

**Learned words must never be permanently discarded.** If an item is permanently purged from the gameplay loop, the user will fall victim to Ebbinghaus's Forgetting Curve. However, to keep the game engaging, learned words should transition into new roles rather than repeating old patterns.

### 4.2 The "Leveled-Up Retention" Engine

We specify a 3-tier phase structure using a lightweight Spaced Repetition System (SRS) that adapts to the local storage design:

```
[Highlight] ──> Status: New
                  │
             (1st Practice)
                  │
                  ▼
            Status: Learning
                  │
         (Streak reaches 3)
                  │
                  ▼
            Status: Learned
                  │
                  ├──> 90% Pool Weight: Distractors & Misfits in other words' games.
                  └──> 10% Pool Weight: Re-introduced as "Speed Flashback" cards.

```

1. **The "Learning" Phase:** When a word is newly added, it enters high-frequency rotation. It requires a `correct_streak` of **3 consecutive correct answers** across any game variant to graduate.
2. **The Graduation Event:** Once the streak hits 3, the status changes to `'Learned'` in the `word_vault`.
3. **The Recycled Distractor System (90% Weight):** Learned words are converted into dynamic distractors for *other* games. For instance, when a newer word needs a "misfit word" or a sentence distractor, the game engine pulls a word marked as `'Learned'` from the user's personal vault. This creates a deeply personalized gameplay loop: **the game uses the user's past vocabulary history to test their current vocabulary challenges.**
4. **The Speed Flashback System (10% Weight):** During a session, there is a low-frequency chance ($10\%$) that a random card will trigger a "Speed Flashback." This pulls a `'Learned'` word for a lightning-fast "True or Bluff" round. Successfully passing maintains its status; failing immediately drops the word back to `'Learning'` status and resets its streak to 0. This approach ensures total long-term retention without cluttering the daily practice queue.
"""

