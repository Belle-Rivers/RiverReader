from uuid import UUID

from sqlmodel import Session, select

from app.models import GameCache, Highlight
from app.schemas import HighlightCreate, HighlightRead
from app.services import book_service, srs_service


def _read_highlight(session: Session, highlight: Highlight) -> HighlightRead:
    return HighlightRead.model_validate(highlight).model_copy(
        update={"srs": srs_service.get_srs_for_highlight(session, highlight.id)}
    )


def create_highlight(session: Session, data: HighlightCreate) -> HighlightRead | None:
    if book_service.get_active_book_model(session, data.book_id, data.user_id) is None:
        return None
    word = data.target_word.strip()
    existing = session.exec(
        select(Highlight).where(
            Highlight.user_id == data.user_id,
            Highlight.book_id == data.book_id,
            Highlight.target_word == word,
            Highlight.is_deleted == False,  # noqa: E712
        )
    ).first()
    if existing is not None:
        return _read_highlight(session, existing)
    highlight = Highlight(
        user_id=data.user_id,
        book_id=data.book_id,
        target_word=word,
        context_before=data.context_before,
        context_sentence=data.context_sentence,
        context_after=data.context_after,
        chapter_index=data.chapter_index,
        chapter_title=data.chapter_title,
        cfi=data.cfi,
    )
    session.add(highlight)
    session.commit()
    session.refresh(highlight)
    srs_service.create_initial_srs_item(session, highlight.id)
    ensure_game_cache_pending(session, word)
    return _read_highlight(session, highlight)


def ensure_game_cache_pending(session: Session, word: str) -> None:
    """Insert a Pending GameCache row for 'word' if one does not already exist.

    This guarantees the background backfill worker will pick the word up even
    if the in-request AI generation is skipped (e.g. offline reading, AI disabled).
    """
    word_normalized = word.strip().lower()
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()
    if existing is None:
        session.add(GameCache(word=word, word_normalized=word_normalized))
        session.commit()


def list_highlights(
    session: Session,
    user_id: UUID,
    *,
    book_id: UUID | None = None,
    include_deleted: bool = False,
    limit: int = 100,
    offset: int = 0,
) -> list[HighlightRead]:
    statement = select(Highlight).where(Highlight.user_id == user_id)
    if book_id is not None:
        statement = statement.where(Highlight.book_id == book_id)
    if not include_deleted:
        statement = statement.where(Highlight.is_deleted == False)  # noqa: E712
    statement = statement.order_by(Highlight.created_at.desc()).offset(offset).limit(limit)
    return [_read_highlight(session, highlight) for highlight in session.exec(statement).all()]


def get_highlight(
    session: Session,
    highlight_id: UUID,
    user_id: UUID | None = None,
) -> HighlightRead | None:
    highlight = session.get(Highlight, highlight_id)
    if highlight is None or highlight.is_deleted:
        return None
    if user_id is not None and highlight.user_id != user_id:
        return None
    return _read_highlight(session, highlight)


def soft_delete_highlight(
    session: Session,
    highlight_id: UUID,
    user_id: UUID | None = None,
) -> bool:
    highlight = session.get(Highlight, highlight_id)
    if highlight is None or highlight.is_deleted:
        return False
    if user_id is not None and highlight.user_id != user_id:
        return False
    highlight.is_deleted = True
    session.add(highlight)
    session.commit()
    return True
