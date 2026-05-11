from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from app.db import SessionDep
from app.schemas import GameAnswerCreate, GameDeckItemRead, ReviewEventRead
from app.services import game_service

game_router = APIRouter(prefix="/games", tags=["Games"])


@game_router.get("/deck", response_model=list[GameDeckItemRead])
def get_game_deck(
    user_id: UUID,
    session: SessionDep,
    type: str = Query(default="cloze", pattern="^(cloze|meaning_match|definition_reveal)$"),
    limit: int = Query(default=10, ge=1, le=50),
) -> list[GameDeckItemRead]:
    return game_service.get_deck(session, user_id, game_type=type, limit=limit)


@game_router.post("/answer", response_model=ReviewEventRead)
def answer_game(payload: GameAnswerCreate, session: SessionDep) -> ReviewEventRead:
    event = game_service.answer_game(session, payload)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="review item not found")
    return event
