# Progress Memory

## Current Approach
Keep River Reader split cleanly into a Flutter frontend and a FastAPI backend. Use the backend for user/profile CRUD via `/v1/*` routes, and keep Flutter screens thin: themed UI + small API clients that call the backend directly (configurable base URL for simulator/device testing).

## Completed Work
- Rewrote `pro_docs/backend.md` as the backend source of truth instead of only an API sketch.
- Added the FastAPI + SQLite direction and `/docs` workflow to the backend docs.
- Restored product detail for username-only profiles, reading progress, silent highlighting, Vault behavior, SRS, and games.
- Added system-collected user fields such as device install ID, timezone, locale, and subscription identifiers to the docs.
- Implemented the backend app title fix so Swagger shows `River Reader`.
- Added a root route that redirects `/` to `/docs` and a `favicon.ico` no-op route.
- Added a user registration CRUD surface at `/v1/users/*`.
- Extended the profile model, schema, and service with optional profile and entitlement metadata.
- Added SQLite startup initialization and table/column creation for the local database.
- Created the `progress-memory` skill in `~/.codex/skills`.
- Wired the Flutter frontend to backend registration: `POST /v1/users/register`.
- Added a themed registration page and route in Flutter at `/register`.
- Added a Home CTA to navigate to registration for iOS simulator testing.

## Current Blocker
- Local environment here cannot run Flutter commands (`flutter: command not found`), so `flutter pub get` / builds weren’t validated in this session.

## Next Step
- On your machine: run `flutter pub get` in `frontend/`, then launch iOS simulator to test `/register` against your running FastAPI server.
- If simulator can’t reach `localhost`, pass `--dart-define=RIVER_READER_API_URL=http://127.0.0.1:8000` (or your LAN IP) when running the Flutter app.
