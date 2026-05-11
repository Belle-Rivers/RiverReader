from uuid import UUID

from sqlmodel import Session, select

from app.models import Book, Highlight, SrsItem
from app.schemas import VaultItemRead
from app.services import srs_service


def list_vault_items(
    session: Session,
    user_id: UUID,
    *,
    book_id: UUID | None = None,
    q: str | None = None,
    min_mastery: int | None = None,
    max_mastery: int | None = None,
    limit: int = 100,
    offset: int = 0,
) -> list[VaultItemRead]:
    statement = (
        select(Highlight, Book, SrsItem)
        .join(Book, Highlight.book_id == Book.id)
        .join(SrsItem, SrsItem.highlight_id == Highlight.id)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            Book.is_deleted == False,  # noqa: E712
        )
    )
    if book_id is not None:
        statement = statement.where(Highlight.book_id == book_id)
    if min_mastery is not None:
        statement = statement.where(SrsItem.mastery_level >= min_mastery)
    if max_mastery is not None:
        statement = statement.where(SrsItem.mastery_level <= max_mastery)
    statement = statement.order_by(Highlight.created_at.desc()).offset(offset).limit(limit)
    rows = session.exec(statement).all()
    items = [
        VaultItemRead.model_validate(highlight).model_copy(
            update={
                "srs": srs,
                "book_title": book.title,
                "book_author": book.author,
            }
        )
        for highlight, book, srs in rows
    ]
    if q:
        needle = q.strip().lower()
        items = [
            item
            for item in items
            if needle in item.target_word.lower()
            or needle in item.context_sentence.lower()
            or (item.book_title and needle in item.book_title.lower())
        ]
    return items


def search_vault_items(
    session: Session,
    user_id: UUID,
    q: str,
    *,
    limit: int = 100,
    offset: int = 0,
) -> list[VaultItemRead]:
    return list_vault_items(session, user_id, q=q, limit=limit, offset=offset)
