# River Reader — Technology Stack

This document describes every technology used in River Reader, why each was chosen, and how AI appears in both the product and the development workflow.

---

## 1) Backend Technologies

### Python 3.11+

Chosen because:

- The fastest path from idea to a working REST API with auto-generated docs (`/docs`).
- Rich ecosystem for data manipulation, testing, and prototyping.
- Easy to hire for and easy to debug in a solo-developer context.

### FastAPI

Chosen because:

- Produces a typed, self-documenting API contract via OpenAPI/Swagger at `/docs` with zero extra work.
- Native async support for non-blocking I/O (database, external API calls).
- Pydantic integration means request/response validation is automatic, not hand-written.
- Lightweight compared to Django or Flask with extensions; the backend stays a thin data layer, not a monolith.

### Uvicorn

Chosen because:

- ASGI server that pairs directly with FastAPI.
- Fast enough for local development and low-traffic deployments.
- No configuration needed for basic use; just `uvicorn app.main:app`.

### SQLite (local development) + PostgreSQL (hosted)

Chosen because:

- SQLite is zero-cost, file-based, and inspectable — perfect for a local-first MVP where the developer and the user share the same machine.
- PostgreSQL via Neon (serverless) is the path to hosted deployments without rewriting queries; SQLModel abstracts the difference.
- The same codebase supports both by switching `RIVER_READER_DATABASE_URL`.

### SQLModel (SQLAlchemy + Pydantic)

Chosen because:

- Unifies ORM models and Pydantic schemas in a single class definition, cutting boilerplate in half.
- SQLAlchemy is battle-tested; Pydantic v2 is fast for validation.
- Avoids the need for separate model, schema, and migration layers in an MVP.

### httpx

Chosen because:

- Async-capable HTTP client that matches FastAPI's async nature.
- Used for external API calls (Groq LLM, dictionaryapi.dev) without blocking the event loop.
- More modern than `requests`; supports timeout and retry patterns cleanly.

### Pydantic / pydantic-settings

Chosen because:

- Automatic request validation, serialization, and error messages with zero manual code.
- `pydantic-settings` reads `.env` files and environment variables with type coercion, replacing hand-written config parsers.

### python-multipart

Chosen because:

- Required by FastAPI for multipart file uploads (EPUB upload via `POST /v1/books/upload`).
- No alternative needed; it is the standard for this use case.

---

## 2) Frontend Technologies

### Flutter (Dart SDK >=3.3.0)

Chosen because:

- Single codebase for Android, iOS, macOS, Linux, Windows, and Web — River Reader targets all six platforms.
- Hot reload speeds up UI iteration dramatically.
- Dart's null safety and strong typing catch bugs at compile time.
- The `InAppWebView` plugin provides a reliable EPUB reader without building a custom rendering engine.

### flutter_riverpod

Chosen because:

- Compile-safe, testable, and scalable state management with no boilerplate patterns (no `ChangeNotifier`, no `BlocProvider` nesting).
- `FutureProvider` and `AsyncNotifier` handle async API calls cleanly.
- `Provider.family` allows per-book and per-user state isolation without manual scoping.
- Worker providers handle background tasks (auto-backup, AI backfill) without extra packages.

### go_router

Chosen because:

- Declarative routing with type-safe path parameters (`/reader/:bookId`).
- Auth redirect logic is built into the router, not scattered across widgets.
- Supports deep linking and browser URL bar on web.

### flutter_inappwebview (InAppWebView)

Chosen because:

- Renders real EPUB HTML in a WebView, letting EPUB.js-style rendering work on mobile.
- Supports JavaScript injection for ghost capture (double-tap word detection) and dictionary hints.
- Handles chapter navigation, link interception, and progress tracking natively.

### google_fonts

Chosen because:

- Provides Inter (UI) and Merriweather (body) without bundling font files in the app.
- DynaPuff available for display text.
- Reduces app size compared to embedding fonts directly.

### http (dart:http)

Chosen because:

- Simple, dependency-light HTTP client for API calls.
- No need for Dio's interceptors or advanced features; the backend API is straightforward.
- Keeps the dependency tree small.

### shared_preferences

Chosen because:

- Lightweight key-value storage for session state, theme preference, and offline highlight queue.
- Sufficient for MVP; no need for Hive or Isar until complex local queries are required.

### file_picker

Chosen because:

- Native file picker for EPUB uploads and backup import.
- Handles platform differences (Android SAF, iOS document picker, desktop file dialog) in one API.

### path_provider

Chosen because:

- Provides platform-correct paths for storing EPUB files, covers, and backups.
- Works with the conditional export pattern for web vs. IO.

### font_awesome_flutter

Chosen because:

- Icon library for UI elements (nav icons, game icons, settings icons).
- Larger icon set than Flutter's built-in Icons; consistent style.

---

## 3) Infrastructure and DevOps

### Docker (frontend)

Chosen because:

- Multi-stage build: Flutter build stage + nginx serving stage.
- API URL injected at build time via `--dart-define`, no runtime config needed.
- Produces a static artifact deployable to any container host.

### Render.com (backend)

Chosen because:

- Free tier supports a Python FastAPI backend with PostgreSQL (Neon integration).
- `render.yaml` defines the deployment: Python runtime, environment variables, health checks.
- No Kubernetes or complex CI/CD needed for an MVP.

### Neon (PostgreSQL)

Chosen because:

- Serverless PostgreSQL with a free tier.
- Branching and auto-scaling without managing a database server.
- Direct connection string works with SQLAlchemy/SQLModel without driver changes.

---

## 4) AI Integration in the Product

AI is used **exclusively for game content generation** — not for definitions, translations, or reading assistance. The app works fully without AI enabled.

### Model: Groq (llama-3.1-8b-instant)

Chosen because:

- Free tier with 30 requests per minute — sufficient for a single-user MVP.
- `llama-3.1-8b-instant` is fast (low latency) and good enough for structured game content.
- JSON response mode (`response_format: {"type": "json_object"}`) eliminates parse errors.
- No vendor lock-in; the integration is raw HTTP via httpx, not a SDK wrapper.

### How it works

1. When a user highlights a word, the backend inserts a `GameCache` row with status `Pending`.
2. A background backfill worker polls pending entries and calls Groq to generate content for 4 game types.
3. The frontend polls `GET /v1/games/cache-status` every 30 seconds and triggers backfill when needed.
4. When the user opens a game, the backend serves pre-generated content from `game_cache` — no LLM call happens at game time.

### What AI generates

| Game Type | AI Output |
|-----------|-----------|
| **Cloze** | A standalone sentence using the exact word form, with the word removed to create a blank |
| **Context Clash** | A correct sentence vs. a contextually absurd sentence, plus explanation |
| **Odd One Out** | 3 synonyms + 1 misfit word, all same part of speech |
| **True or Bluff** | A true statement and a bluff statement using the word in context |

### Prompt design

The system prompt instructs the LLM to act as "an expert game designer specializing in lexical acquisition for casual intermediate English readers." Key constraints:

- B1/B2 readability level — no academic or archaic language.
- Exact word form must appear in all outputs (no lemma substitution).
- No copying context sentences from the original book.
- No "X means..." definition-style statements in true_or_bluff.

### Validation and caching

- Extensive validation catches LLM failure patterns: wrong word forms, definition-style statements, duplicate words, malformed JSON.
- Results are cached per word in `game_cache` with JSON columns for each game type.
- Failed entries have a 5-minute cooldown before retry.
- `queue_replay_regeneration()` marks stale caches for re-generation when the vault changes.

### Cost controls

- `AI_ENABLED=false` by default — the app works without AI.
- All responses are cached — no repeated calls for the same word.
- Rate limiting: 2-second sleep between Groq calls in the backfill worker.
- No AI call happens at game time — content is pre-generated.

### Dictionary: dictionaryapi.dev (free, no AI)

- Local `dictionary_entries` table is checked first.
- If not found, the free dictionaryapi.dev API is called and the result is cached.
- This is a REST API, not an AI service — no LLM involved.

---

## 5) AI in the Development Process

### Claude Code (AI coding assistant)

- Claude was used as an interactive coding assistant throughout development via the CLI tool.
- The project includes Claude configuration at `~/.claude/CLAUDE.md` with project-specific instructions (`@RTK.md`).
- Claude assisted with: writing FastAPI routes, building Riverpod providers, creating game session controllers, designing the SM-2 SRS algorithm, writing validation logic, and generating the documentation files.

### Groq API prototyping

- `test_groq.py` at the repo root is a standalone script that uses the `groq` Python SDK directly to test prompts before integrating them into the backend.
- This was used to iterate on the game content prompt, test JSON output formats, and validate response quality before writing production code.

### Iterative prompt engineering

- The system prompt in `ai_service.py` is the result of multiple iterations — evidenced by the detailed constraints and the validation functions that patch specific LLM failure modes.
- The validation layer (`_cloze_payload_valid`, `_is_definition_style_statement`, `_true_or_bluff_payload_valid`, etc.) was built reactively: each function addresses a real failure pattern encountered during testing.

### Documentation generation

- The `pro_docs/` documentation files (`backend.md`, `frontend.md`, `tech_stack.md`) were written with AI assistance, using the actual codebase as the source of truth.

---

## 6) Dependency Summary

### Python (backend)

```
fastapi>=0.115.0          — HTTP API framework
uvicorn[standard]>=0.30.0 — ASGI server
pydantic>=2.0             — Data validation
pydantic-settings>=2.0    — Environment config
sqlmodel>=0.0.22          — ORM + Pydantic hybrid
psycopg2-binary>=2.9.0    — PostgreSQL driver
httpx>=0.27.0             — Async HTTP client (Groq, dictionaryapi)
python-multipart>=0.0.9   — File upload support
```

No dedicated AI/ML packages. Groq integration is raw httpx.

### Dart (frontend)

```
flutter_riverpod: ^2.5.1          — State management
go_router: ^13.2.0                — Navigation
flutter_inappwebview: ^6.0.0      — EPUB reader WebView
google_fonts: ^6.2.1              — Typography
http: ^1.2.2                      — API client
shared_preferences: ^2.3.2        — Local key-value storage
file_picker: ^8.1.4               — File selection
path_provider: ^2.1.2             — Platform file paths
font_awesome_flutter: ^11.0.0     — Icons
http_parser: ^4.1.0               — Multipart requests
```

No AI/ML packages. The frontend is AI-free by design.

### Dart (backend/lib — local persistence)

```
flutter_riverpod: ^2.5.1         — Providers
sqflite: ^2.3.0                  — Local SQLite
path: ^1.9.0                     — Path manipulation
path_provider: ^2.1.2            — Platform paths
logger: ^2.0.2                   — Logging
sqflite_common_ffi_web: ^1.1.1   — Web SQLite support
```

---

## 7) Technology Decision Matrix

| Decision | Choice | Alternative considered | Why this choice |
|----------|--------|----------------------|-----------------|
| Backend framework | FastAPI | Flask, Django REST | Auto docs, async, Pydantic native |
| Database (local) | SQLite | Hive, Isar | SQL standard, inspectable, portable |
| Database (hosted) | PostgreSQL (Neon) | Supabase, Firebase | SQL standard, free tier, no vendor lock |
| ORM | SQLModel | SQLAlchemy alone, Prisma | Unified ORM + Pydantic, fewer files |
| Frontend framework | Flutter | React Native, Kotlin Multiplatform | 6-platform coverage, single codebase |
| State management | Riverpod | BLoC, Provider, GetX | Compile-safe, testable, less boilerplate |
| Navigation | GoRouter | AutoRoute, Navigator 2.0 | Declarative, auth redirects built-in |
| EPUB rendering | InAppWebView | epub_kitty, flutter_html | Real WebView, JS injection, mature |
| AI provider | Groq (Llama 3.1) | OpenAI, Ollama, local | Free tier, fast, JSON mode, no SDK lock |
| HTTP client (backend) | httpx | requests, aiohttp | Async, matches FastAPI's event loop |
| HTTP client (frontend) | dart:http | Dio | Simple, no extra dependencies needed |
| Deployment | Render.com | Vercel, Railway, self-hosted | Free tier, Python native, simple config |
