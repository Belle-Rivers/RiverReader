import logging
import time
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query, status

from app.db import SessionDep, get_session
from app.schemas import GameAnswerCreate, GameDeckItemRead, GameDecksRead, ReviewEventRead
from app.services import game_service

log = logging.getLogger("river_reader.games")
game_router = APIRouter(prefix="/games", tags=["Games"])

# In-memory guards so duplicate background triggers do not stack Groq calls.
_backfill_running: bool = False
_backfill_running_users: set[UUID] = set()
_replay_refresh_users: set[UUID] = set()


def request_replay_refresh(user_id: UUID) -> None:
    """Mark that the next backfill for this user may regenerate stale completed caches."""
    _replay_refresh_users.add(user_id)


# ─── Background backfill worker ───────────────────────────────────────────────

def _backfill_worker(user_id: UUID | None = None) -> None:
    """Poll game_cache for words with status != 'Completed' and generate via Groq.

    When user_id is provided only that user's vault words are processed.
    When user_id is None every distinct vault word across all users is considered
    (used by the generic POST /games/backfill trigger).

    Runs as a background task with a 2-second rate-limit guard between API calls.
    """
    global _backfill_running
    from app.models import GameCache, Highlight
    from app.services import ai_service
    from app.services.ai_service import _cache_needs_regeneration
    from app.services.highlight_service import ensure_game_cache_pending
    from sqlmodel import select

    if user_id is None:
        if _backfill_running:
            log.info("Backfill: global run already in progress – skipping duplicate trigger")
            return
        _backfill_running = True
    elif user_id in _backfill_running_users:
        log.info("Backfill: user %s already in progress – skipping duplicate trigger", user_id)
        return
    else:
        _backfill_running_users.add(user_id)

    session = next(get_session())
    try:
        stmt = select(Highlight.target_word, Highlight.context_sentence).where(
            Highlight.is_deleted == False  # noqa: E712
        )
        if user_id is not None:
            stmt = stmt.where(Highlight.user_id == user_id)

        rows = session.exec(stmt.distinct()).all()
        log.info("Backfill (user=%s): found %d distinct vault words", user_id or "all", len(rows))

        pending: list[tuple[str, str | None]] = []
        for word, context in rows:
            word_normalized = word.strip().lower()
            ensure_game_cache_pending(session, word)
            cached = session.exec(
                select(GameCache).where(GameCache.word_normalized == word_normalized)
            ).first()
            if cached is None or _cache_needs_regeneration(cached):
                if cached is not None and cached.generation_status in ("Failed", "Completed"):
                    cached.generation_status = "Pending"
                    session.add(cached)
                    session.commit()
                pending.append((word, context))

        if not pending:
            log.info("Backfill (user=%s): all vault words already cached", user_id or "all")
            replay = user_id is not None and user_id in _replay_refresh_users
            if replay:
                _replay_refresh_users.discard(user_id)
                replay_pending = ai_service.queue_replay_regeneration(
                    session, user_id, rows, limit=8
                )
                pending.extend(replay_pending)
            if not pending:
                return
            if replay:
                log.info(
                    "Backfill (user=%s): replay regen queued %d words",
                    user_id,
                    len(pending),
                )

        log.info("Backfill (user=%s): %d words need generation", user_id or "all", len(pending))

        for i, (word, context) in enumerate(pending):
            log.info("Backfill [%d/%d]: generating for %r …", i + 1, len(pending), word)
            ai_service.generate_game_content(session, word, context)
            # Rate limit: 2 seconds between calls (Groq free tier = 30 RPM)
            if i < len(pending) - 1:
                time.sleep(2)

        log.info("Backfill (user=%s): complete – processed %d words", user_id or "all", len(pending))
    except Exception as exc:
        log.error("Backfill worker failed (user=%s): %s", user_id or "all", exc)
    finally:
        session.close()
        if user_id is None:
            _backfill_running = False
        else:
            _backfill_running_users.discard(user_id)


@game_router.post("/backfill", summary="Trigger global backfill for all vault words")
def trigger_backfill(background_tasks: BackgroundTasks) -> dict:
    """Kick off background generation for all vault words missing game_cache.

    Safe to call multiple times – already-cached words are skipped.
    A global lock prevents duplicate concurrent runs.
    """
    log.info("POST /games/backfill – triggering global background backfill worker")
    background_tasks.add_task(_backfill_worker, None)
    return {"status": "backfill_started", "detail": "Background Groq generation queued for all uncached vault words."}


@game_router.post("/backfill/{user_id}", summary="Trigger backfill for a specific user's vault words")
def trigger_user_backfill(user_id: UUID, background_tasks: BackgroundTasks) -> dict:
    """Kick off background generation specifically for this user's vault words.

    Called by the client after login so that old vault words captured while offline
    (or before AI was configured) receive AI-generated game content.
    """
    log.info("POST /games/backfill/%s – triggering per-user background backfill", user_id)
    background_tasks.add_task(_backfill_worker, user_id)
    return {"status": "backfill_started", "detail": f"Background Groq generation queued for user {user_id}."}


# ─── Existing endpoints ───────────────────────────────────────────────────────

@game_router.get("/cache-status", summary="Game cache readiness for a user's vault words")
def get_cache_status(user_id: UUID, session: SessionDep) -> dict:
    """Return how many vault words have AI game content ready vs still pending."""
    from app.models import Highlight
    from app.services.ai_service import is_cache_complete
    from sqlmodel import select

    words = session.exec(
        select(Highlight.target_word)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
        )
        .distinct()
    ).all()
    total = len(words)
    completed = 0
    for word in words:
        if is_cache_complete(session, word):
            completed += 1
    pending = total - completed
    return {
        "total": total,
        "completed": completed,
        "pending": pending,
        "ready": pending == 0 and total > 0,
    }


@game_router.get("/decks", response_model=GameDecksRead)
def get_all_game_decks(
    user_id: UUID,
    session: SessionDep,
    background_tasks: BackgroundTasks,
    limit: int = Query(default=10, ge=1, le=50),
    replay_refresh: bool = Query(default=False),
) -> GameDecksRead:
    """Return all game decks in one request (shared vault scan + AI cache reads)."""
    log.info("GET /games/decks  user=%s  limit=%d  replay=%s", user_id, limit, replay_refresh)
    if replay_refresh:
        request_replay_refresh(user_id)
    background_tasks.add_task(_backfill_worker, user_id)
    decks = game_service.get_all_decks(session, user_id, limit=limit)
    log.info(
        "  → cloze=%d  meaning_match=%d  context_clash=%d  odd_one_out=%d  true_or_bluff=%d",
        len(decks.cloze),
        len(decks.meaning_match),
        len(decks.context_clash),
        len(decks.odd_one_out),
        len(decks.true_or_bluff),
    )
    return decks


@game_router.get("/deck", response_model=list[GameDeckItemRead])
def get_game_deck(
    user_id: UUID,
    session: SessionDep,
    background_tasks: BackgroundTasks,
    type: str = Query(default="cloze", pattern="^(cloze|meaning_match|definition_reveal|context_clash|odd_one_out|true_or_bluff)$"),
    limit: int = Query(default=10, ge=1, le=50),
    replay_refresh: bool = Query(default=False),
) -> list[GameDeckItemRead]:
    log.info("GET /games/deck  user=%s  type=%s  limit=%d  replay=%s", user_id, type, limit, replay_refresh)
    if replay_refresh:
        request_replay_refresh(user_id)
    # Silently enqueue backfill for this user in the background so any words
    # that are still Pending/Failed (e.g. added while offline) are picked up.
    background_tasks.add_task(_backfill_worker, user_id)
    items = game_service.get_deck(session, user_id, game_type=type, limit=limit)
    log.info("  → returning %d items", len(items))
    return items


@game_router.post("/answer", response_model=ReviewEventRead)
def answer_game(payload: GameAnswerCreate, session: SessionDep) -> ReviewEventRead:
    log.info(
        "POST /games/answer  word=%s  correct=%s  combo=x%d  xp=%d",
        payload.selected_answer,
        payload.is_correct,
        payload.combo_multiplier,
        payload.xp_earned,
    )
    event = game_service.answer_game(session, payload)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="review item not found")
    return event
