from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.db import SessionDep
from app.schemas import HomeRead
from app.services import home_service

me_router = APIRouter(prefix="/me", tags=["Me"])


@me_router.get("/home", response_model=HomeRead)
def get_home(user_id: UUID, session: SessionDep) -> HomeRead:
    home = home_service.get_home(session, user_id)
    if home is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    return home
