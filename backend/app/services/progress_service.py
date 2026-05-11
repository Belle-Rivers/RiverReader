from datetime import datetime, timezone
from uuid import UUID

from sqlmodel import Session, select

from app.models import ReadingProgress
from app.schemas import ReadingProgressUpsert
from app.services import book_service


def upsert_progress(
    session: Session,
    book_id: UUID,
    data: ReadingProgressUpsert,
) -> ReadingProgress | None:
    if book_service.get_active_book_model(session, book_id, data.user_id) is None:
        return None
    statement = select(ReadingProgress).where(
        ReadingProgress.user_id == data.user_id,
        ReadingProgress.book_id == book_id,
    )
    progress = session.exec(statement).first()
    now = datetime.now(timezone.utc)
    if progress is None:
        progress = ReadingProgress(user_id=data.user_id, book_id=book_id)
    progress.chapter_index = data.chapter_index
    progress.chapter_title = data.chapter_title
    progress.cfi = data.cfi
    progress.progress_percent = data.progress_percent
    progress.last_read_at = now
    progress.updated_at = now
    session.add(progress)
    session.commit()
    session.refresh(progress)
    return progress


def get_progress(session: Session, book_id: UUID, user_id: UUID) -> ReadingProgress | None:
    if book_service.get_active_book_model(session, book_id, user_id) is None:
        return None
    statement = select(ReadingProgress).where(
        ReadingProgress.user_id == user_id,
        ReadingProgress.book_id == book_id,
    )
    return session.exec(statement).first()
