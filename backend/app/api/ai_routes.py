from fastapi import APIRouter

from app.db import SessionDep
from app.schemas import AiRequest, AiResponse
from app.services import ai_service

ai_router = APIRouter(prefix="/ai", tags=["AI"])


@ai_router.post("/define", response_model=AiResponse)
def define_word(payload: AiRequest, session: SessionDep) -> AiResponse:
    return ai_service.get_cached_or_disabled(session, "define", payload)


@ai_router.post("/generate-distractors", response_model=AiResponse)
def generate_distractors(payload: AiRequest, session: SessionDep) -> AiResponse:
    return ai_service.get_cached_or_disabled(session, "generate-distractors", payload)
