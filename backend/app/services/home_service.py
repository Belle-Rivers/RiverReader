from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func
from sqlmodel import Session, select

from app.models import Book, Highlight, ReadingProgress, SrsItem, UserProfile
from app.schemas import HomeRead, HomeStatsRead, ReadingProgressRead, VaultItemRead
from app.services import book_service


def get_home(session: Session, user_id: UUID) -> HomeRead | None:
    user = session.get(UserProfile, user_id)
    if user is None:
        return None

    last_progress = _last_progress(session, user_id)
    last_opened_book = None
    if last_progress is not None:
        last_opened_book = book_service.get_book(session, last_progress.book_id, user_id)

    return HomeRead(
        user=user,
        stats=HomeStatsRead(
            books_count=_count_books(session, user_id),
            vault_count=_count_vault_items(session, user_id),
            due_reviews_count=_count_due_reviews(session, user_id),
        ),
        last_opened_book=last_opened_book,
        last_progress=ReadingProgressRead.model_validate(last_progress) if last_progress else None,
        recent_vault_words=_recent_vault_words(session, user_id),
    )


def _count_books(session: Session, user_id: UUID) -> int:
    statement = select(func.count()).select_from(Book).where(
        Book.user_id == user_id,
        Book.is_deleted == False,  # noqa: E712
    )
    return int(session.exec(statement).one())


def _count_vault_items(session: Session, user_id: UUID) -> int:
    statement = select(func.count()).select_from(Highlight).where(
        Highlight.user_id == user_id,
        Highlight.is_deleted == False,  # noqa: E712
    )
    return int(session.exec(statement).one())


def _count_due_reviews(session: Session, user_id: UUID) -> int:
    now = datetime.now(timezone.utc)
    statement = (
        select(func.count())
        .select_from(SrsItem)
        .join(Highlight, SrsItem.highlight_id == Highlight.id)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            SrsItem.next_review_at <= now,
        )
    )
    return int(session.exec(statement).one())


def _last_progress(session: Session, user_id: UUID) -> ReadingProgress | None:
    rows = session.exec(
        select(ReadingProgress)
        .where(ReadingProgress.user_id == user_id)
        .order_by(ReadingProgress.last_read_at.desc())
    ).all()
    for progress in rows:
        if book_service.get_active_book_model(session, progress.book_id, user_id) is not None:
            return progress
    return None


def _recent_vault_words(session: Session, user_id: UUID, limit: int = 5) -> list[VaultItemRead]:
    """Return the last `limit` words added to the Vault, with book title attached.

    Shown on the home page as a quick-glance reminder of recent captures.
    """
    rows = session.exec(
        select(Highlight)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
        )
        .order_by(Highlight.created_at.desc())
        .limit(limit)
    ).all()

    result: list[VaultItemRead] = []
    for highlight in rows:
        book = session.get(Book, highlight.book_id)
        item = VaultItemRead.model_validate(highlight)
        item.book_title = book.title if book else None
        item.book_author = book.author if book else None
        result.append(item)
    return result
