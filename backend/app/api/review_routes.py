from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from app.db import SessionDep
from app.schemas import HighlightRead, ReviewEventRead, ReviewGradeCreate
from app.services import srs_service

review_router = APIRouter(prefix="/reviews", tags=["Reviews"])


@review_router.get("/due", response_model=list[HighlightRead])
def list_due_reviews(
    user_id: UUID,
    session: SessionDep,
    limit: int = Query(default=20, ge=1, le=100),
) -> list[HighlightRead]:
    due = srs_service.list_due_items(session, user_id, limit=limit)
    highlights = []
    for srs_item, highlight in due:
        highlights.append(
            HighlightRead.model_validate(highlight).model_copy(update={"srs": srs_item})
        )
    return highlights


@review_router.post("/{srs_item_id}/grade", response_model=ReviewEventRead)
def grade_review(
    srs_item_id: UUID,
    user_id: UUID,
    payload: ReviewGradeCreate,
    session: SessionDep,
) -> ReviewEventRead:
    event = srs_service.grade_item(session, srs_item_id, payload, user_id=user_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="review item not found")
    return event
