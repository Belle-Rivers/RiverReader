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

## Render Deployment Fixes

### 1. Backend: `ModuleNotFoundError: No module named 'httpx'`
- **Cause:** `httpx` was listed under `[project.optional-dependencies] dev` in `pyproject.toml`, but used in production code (`app/services/ai_service.py`). Render uses `uv` which only installs main `dependencies`.
- **Fix:** Moved `httpx>=0.27.0` from `[project.optional-dependencies] dev` to `[project.dependencies]` in `pyproject.toml`.

### 2. Backend: `Form data requires "python-multipart"`
- **Cause:** `python-multipart` was in `requirements.txt` but missing from `pyproject.toml`. Render reads `pyproject.toml`, not `requirements.txt`.
- **Fix:** Added `python-multipart>=0.0.9` to `[project.dependencies]` in `pyproject.toml`.

### 3. Backend: No open ports detected on 0.0.0.0
- **Cause:** Uvicorn was binding to `127.0.0.1:8000` (localhost only). Render requires `0.0.0.0` and the `PORT` env var.
- **Fix:** Set Render start command to `uvicorn app.main:app --host 0.0.0.0 --port $PORT`.

### 4. Frontend: Poetry/pip error on `requirements.txt`
- **Cause:** `frontend/requirements.txt` contained Dart syntax (`flutter_riverpod: ^2.5.1`), which pip can't parse. Render detected it as a Python project.
- **Fix:** Deleted the invalid `requirements.txt` from `frontend/`.

### 5. Frontend: `IconData` final class compile error
- **Cause:** `font_awesome_flutter: ^10.8.0` resolved to 10.12.0, which tries to extend `IconData`. Flutter 3.44.0 (used in Docker build) made `IconData` a `final class`.
- **Fix:** Upgraded `font_awesome_flutter` from `^10.8.0` to `^11.0.0` in `pubspec.yaml`.

### 6. Frontend deployment infrastructure
- Created `frontend/Dockerfile` for Flutter web build on Render (Docker runtime).
- Created `frontend/.dockerignore` to exclude unnecessary files from Docker context.
- Created `render.yaml` at repo root to configure both backend and frontend services.

## Current Status
- Backend deploys and runs on Render successfully.
- Frontend builds and deploys on Render as a Docker service.

## Next Step
- Verify end-to-end: open the frontend URL, register a user, and confirm it reaches the backend.
- Add environment variables on Render: `RIVER_READER_API_URL` (frontend), `RIVER_READER_DATABASE_URL` (backend).
