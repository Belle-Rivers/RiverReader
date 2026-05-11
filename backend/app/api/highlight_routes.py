from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response, status

from app.db import SessionDep
from app.schemas import HighlightCreate, HighlightRead
from app.services import highlight_service

highlight_router = APIRouter(prefix="/highlights", tags=["Highlights"])


@highlight_router.post("", response_model=HighlightRead, status_code=status.HTTP_201_CREATED)
def create_highlight(payload: HighlightCreate, session: SessionDep) -> HighlightRead:
    highlight = highlight_service.create_highlight(session, payload)
    if highlight is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book not found")
    return highlight


@highlight_router.get("", response_model=list[HighlightRead])
def list_highlights(
    user_id: UUID,
    session: SessionDep,
    book_id: UUID | None = None,
    include_deleted: bool = False,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> list[HighlightRead]:
    return highlight_service.list_highlights(
        session,
        user_id,
        book_id=book_id,
        include_deleted=include_deleted,
        limit=limit,
        offset=offset,
    )


@highlight_router.get("/{highlight_id}", response_model=HighlightRead)
def get_highlight(
    highlight_id: UUID,
    user_id: UUID,
    session: SessionDep,
) -> HighlightRead:
    highlight = highlight_service.get_highlight(session, highlight_id, user_id)
    if highlight is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="highlight not found")
    return highlight


@highlight_router.delete("/{highlight_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_highlight(
    highlight_id: UUID,
    user_id: UUID,
    session: SessionDep,
) -> Response:
    if not highlight_service.soft_delete_highlight(session, highlight_id, user_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="highlight not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
