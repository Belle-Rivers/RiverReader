from datetime import datetime, timezone
from uuid import UUID

from sqlmodel import Session, select

from app.models import Book, BookChapter
from app.schemas import BookChapterCreate, BookCreate, BookRead, BookUpdate


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _chapters_for_book(session: Session, book_id: UUID) -> list[BookChapter]:
    statement = (
        select(BookChapter)
        .where(BookChapter.book_id == book_id)
        .order_by(BookChapter.chapter_index.asc())
    )
    return list(session.exec(statement).all())


def _read_book(session: Session, book: Book) -> BookRead:
    return BookRead.model_validate(book).model_copy(
        update={"chapters": _chapters_for_book(session, book.id)}
    )


def _replace_chapters(
    session: Session,
    book_id: UUID,
    chapters: list[BookChapterCreate],
) -> None:
    for chapter in _chapters_for_book(session, book_id):
        session.delete(chapter)
    for chapter in chapters:
        session.add(
            BookChapter(
                book_id=book_id,
                chapter_index=chapter.chapter_index,
                title=chapter.title,
                href=chapter.href,
            )
        )


def create_book(session: Session, data: BookCreate) -> BookRead:
    file_hash = data.file_hash.strip() if data.file_hash else None
    if file_hash:
        statement = select(Book).where(
            Book.user_id == data.user_id,
            Book.file_hash == file_hash,
            Book.is_deleted == False,  # noqa: E712
        )
        existing = session.exec(statement).first()
        if existing is not None:
            existing.title = data.title.strip()
            existing.author = data.author
            existing.language = data.language
            existing.cover_ref = data.cover_ref
            existing.updated_at = _now()
            if data.chapters:
                _replace_chapters(session, existing.id, data.chapters)
            session.add(existing)
            session.commit()
            session.refresh(existing)
            return _read_book(session, existing)

    book = Book(
        user_id=data.user_id,
        title=data.title.strip(),
        author=data.author,
        language=data.language,
        file_hash=file_hash,
        cover_ref=data.cover_ref,
    )
    session.add(book)
    session.commit()
    session.refresh(book)
    if data.chapters:
        _replace_chapters(session, book.id, data.chapters)
        session.commit()
    return _read_book(session, book)


def list_books(session: Session, user_id: UUID, *, include_deleted: bool = False) -> list[BookRead]:
    statement = select(Book).where(Book.user_id == user_id)
    if not include_deleted:
        statement = statement.where(Book.is_deleted == False)  # noqa: E712
    statement = statement.order_by(Book.created_at.asc())
    return [_read_book(session, book) for book in session.exec(statement).all()]


def get_book(session: Session, book_id: UUID, user_id: UUID | None = None) -> BookRead | None:
    book = session.get(Book, book_id)
    if book is None or book.is_deleted:
        return None
    if user_id is not None and book.user_id != user_id:
        return None
    return _read_book(session, book)


def get_active_book_model(session: Session, book_id: UUID, user_id: UUID) -> Book | None:
    book = session.get(Book, book_id)
    if book is None or book.is_deleted or book.user_id != user_id:
        return None
    return book


def update_book(
    session: Session,
    book_id: UUID,
    data: BookUpdate,
    user_id: UUID,
) -> BookRead | None:
    book = session.get(Book, book_id)
    if book is None or book.is_deleted or book.user_id != user_id:
        return None
    changed = False
    for field_name in ("title", "author", "language", "file_hash", "cover_ref"):
        new_value = getattr(data, field_name)
        if new_value is not None and new_value != getattr(book, field_name):
            setattr(book, field_name, new_value.strip() if isinstance(new_value, str) else new_value)
            changed = True
    if data.chapters is not None:
        _replace_chapters(session, book.id, data.chapters)
        changed = True
    if changed:
        book.updated_at = _now()
        session.add(book)
        session.commit()
        session.refresh(book)
    return _read_book(session, book)


def soft_delete_book(session: Session, book_id: UUID, user_id: UUID | None = None) -> bool:
    book = session.get(Book, book_id)
    if book is None or book.is_deleted:
        return False
    if user_id is not None and book.user_id != user_id:
        return False
    book.is_deleted = True
    book.updated_at = _now()
    session.add(book)
    session.commit()
    return True
