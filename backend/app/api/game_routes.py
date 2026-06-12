import logging
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from app.db import SessionDep
from app.schemas import GameAnswerCreate, GameDeckItemRead, ReviewEventRead
from app.services import game_service

log = logging.getLogger("river_reader.games")
game_router = APIRouter(prefix="/games", tags=["Games"])


@game_router.get("/deck", response_model=list[GameDeckItemRead])
def get_game_deck(
    user_id: UUID,
    session: SessionDep,
    type: str = Query(default="cloze", pattern="^(cloze|meaning_match|definition_reveal|context_clash|odd_one_out|true_or_bluff)$"),
    limit: int = Query(default=10, ge=1, le=50),
) -> list[GameDeckItemRead]:
    log.info("GET /games/deck  user=%s  type=%s  limit=%d", user_id, type, limit)
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
