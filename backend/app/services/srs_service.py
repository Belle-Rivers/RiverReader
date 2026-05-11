from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlmodel import Session, select

from app.models import Highlight, ReviewEvent, SrsItem
from app.schemas import GameAnswerCreate, ReviewEventRead, ReviewGradeCreate


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_initial_srs_item(session: Session, highlight_id: UUID) -> SrsItem:
    item = SrsItem(highlight_id=highlight_id)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


def get_srs_for_highlight(session: Session, highlight_id: UUID) -> SrsItem | None:
    statement = select(SrsItem).where(SrsItem.highlight_id == highlight_id)
    return session.exec(statement).first()


def list_due_items(
    session: Session,
    user_id: UUID,
    *,
    limit: int = 20,
) -> list[tuple[SrsItem, Highlight]]:
    now = _now()
    statement = (
        select(SrsItem, Highlight)
        .join(Highlight, SrsItem.highlight_id == Highlight.id)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            SrsItem.next_review_at <= now,
        )
        .order_by(SrsItem.next_review_at.asc())
        .limit(limit)
    )
    return list(session.exec(statement).all())


def grade_item(
    session: Session,
    srs_item_id: UUID,
    data: ReviewGradeCreate | GameAnswerCreate,
    user_id: UUID | None = None,
) -> ReviewEventRead | None:
    item = session.get(SrsItem, srs_item_id)
    if item is None:
        return None
    if user_id is not None:
        highlight = session.get(Highlight, item.highlight_id)
        if highlight is None or highlight.user_id != user_id or highlight.is_deleted:
            return None
    grade = data.grade
    is_correct = data.is_correct
    if grade is None:
        grade = 4 if is_correct else 0
    if is_correct is None:
        is_correct = grade >= 3

    _apply_sm2(item, grade)
    event = ReviewEvent(
        srs_item_id=item.id,
        game_type=data.game_type,
        grade=grade,
        is_correct=is_correct,
        selected_answer=data.selected_answer,
    )
    session.add(item)
    session.add(event)
    session.commit()
    session.refresh(item)
    session.refresh(event)
    return ReviewEventRead(
        id=event.id,
        srs_item_id=event.srs_item_id,
        game_type=event.game_type,
        grade=event.grade,
        is_correct=event.is_correct,
        selected_answer=event.selected_answer,
        answered_at=event.answered_at,
        srs=item,
    )


def _apply_sm2(item: SrsItem, grade: int) -> None:
    now = _now()
    if grade < 3:
        item.repetitions = 0
        item.interval_days = 1
        item.mastery_level = 0
    else:
        item.repetitions += 1
        if item.repetitions == 1:
            item.interval_days = 1
        elif item.repetitions == 2:
            item.interval_days = 6
        else:
            item.interval_days = max(1, round(item.interval_days * item.ease_factor))
        item.mastery_level = min(5, max(item.mastery_level, grade))
    item.ease_factor = max(
        1.3,
        item.ease_factor + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02)),
    )
    item.last_review_at = now
    item.next_review_at = now + timedelta(days=item.interval_days)
