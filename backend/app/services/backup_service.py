import json
from collections import defaultdict
from datetime import datetime, timezone
from uuid import UUID

from sqlmodel import Session, select

from app.models import (
    Book,
    BookChapter,
    DictionaryEntry,
    GameCache,
    Highlight,
    ReadingProgress,
    ReviewEvent,
    SrsItem,
    UserProfile,
)
from app.schemas.backup import GameCacheBackupRead, UserDataBackupRead, UserProfileBackupRead
from app.schemas.reading import (
    BookChapterRead,
    BookRead,
    DictionaryEntryRead,
    HighlightRead,
    ReadingProgressRead,
    ReviewEventRead,
    SrsItemRead,
    VaultItemRead,
)


def export_user_backup(session: Session, user_id: UUID) -> UserDataBackupRead | None:
    user = session.get(UserProfile, user_id)
    if user is None:
        return None

    books = list(
        session.exec(
            select(Book).where(Book.user_id == user_id, Book.is_deleted == False)  # noqa: E712
        ).all()
    )
    chapters = list(
        session.exec(
            select(BookChapter).join(Book, BookChapter.book_id == Book.id).where(
                Book.user_id == user_id,
                Book.is_deleted == False,  # noqa: E712
            )
        ).all()
    )
    highlights = list(
        session.exec(
            select(Highlight).where(
                Highlight.user_id == user_id,
                Highlight.is_deleted == False,  # noqa: E712
            )
        ).all()
    )
    srs_items = list(
        session.exec(
            select(SrsItem).join(Highlight, SrsItem.highlight_id == Highlight.id).where(
                Highlight.user_id == user_id,
                Highlight.is_deleted == False,  # noqa: E712
            )
        ).all()
    )
    reading_progress = list(
        session.exec(
            select(ReadingProgress).where(ReadingProgress.user_id == user_id)
        ).all()
    )
    review_events = list(
        session.exec(
            select(ReviewEvent).join(SrsItem, ReviewEvent.srs_item_id == SrsItem.id).join(
                Highlight, SrsItem.highlight_id == Highlight.id
            ).where(
                Highlight.user_id == user_id,
                Highlight.is_deleted == False,  # noqa: E712
            )
        ).all()
    )

    target_words = {highlight.target_word.strip().lower() for highlight in highlights}
    dictionary_entries = list(
        session.exec(select(DictionaryEntry)).all()
    )
    game_cache_rows = (
        list(session.exec(select(GameCache).where(GameCache.word_normalized.in_(target_words))).all())
        if target_words
        else []
    )

    book_read_map: dict[UUID, BookRead] = {}
    chapters_by_book: dict[UUID, list[BookChapterRead]] = defaultdict(list)
    for chapter in chapters:
        chapters_by_book[chapter.book_id].append(
            BookChapterRead.model_validate(chapter, from_attributes=True)
        )
    for book in books:
        book_read = BookRead.model_validate(book, from_attributes=True)
        book_read.chapters = chapters_by_book.get(book.id, [])
        book_read_map[book.id] = book_read

    highlights_read = []
    for highlight in highlights:
        item = VaultItemRead.model_validate(highlight, from_attributes=True)
        book = next((book for book in books if book.id == highlight.book_id), None)
        item.book_title = book.title if book else None
        item.book_author = book.author if book else None
        highlights_read.append(item)

    srs_by_id = {item.id: item for item in srs_items}
    review_read: list[ReviewEventRead] = []
    for event in review_events:
        srs_item = srs_by_id.get(event.srs_item_id)
        review_read.append(
            ReviewEventRead(
                id=event.id,
                srs_item_id=event.srs_item_id,
                game_type=event.game_type,
                grade=event.grade,
                is_correct=event.is_correct,
                selected_answer=event.selected_answer,
                answered_at=event.answered_at,
                combo_multiplier=event.combo_multiplier,
                xp_earned=event.xp_earned,
                response_time_ms=event.response_time_ms,
                srs=SrsItemRead.model_validate(srs_item, from_attributes=True) if srs_item is not None else SrsItemRead(
                    id=event.srs_item_id,
                    highlight_id=srs_item.highlight_id if srs_item is not None else UUID(int=0),
                    ease_factor=1.0,
                    interval_days=0,
                    repetitions=0,
                    mastery_level=0,
                    next_review_at=event.answered_at,
                    last_review_at=None,
                ),
            )
        )

    return UserDataBackupRead(
        user=UserProfileBackupRead.model_validate(user, from_attributes=True),
        books=list(book_read_map.values()),
        book_chapters=[BookChapterRead.model_validate(chapter, from_attributes=True) for chapter in chapters],
        reading_progress=[
            ReadingProgressRead.model_validate(progress, from_attributes=True)
            for progress in reading_progress
        ],
        highlights=highlights_read,
        srs_items=[SrsItemRead.model_validate(item, from_attributes=True) for item in srs_items],
        review_events=review_read,
        dictionary_entries=[
            DictionaryEntryRead.model_validate(entry, from_attributes=True)
            for entry in dictionary_entries
        ],
        game_cache=[
            GameCacheBackupRead.model_validate(row, from_attributes=True) for row in game_cache_rows
        ],
    )


def import_user_backup(session: Session, payload: UserDataBackupRead) -> UserDataBackupRead:
    user = payload.user
    user_id = user.id

    _clear_user_data(session, user_id)

    profile = session.get(UserProfile, user_id)
    if profile is None:
        profile = UserProfile(
            id=user.id,
            email=user.email,
            email_normalized=user.email_normalized,
            hashed_password=user.hashed_password,
            security_question=user.security_question,
            security_answer_hash=user.security_answer_hash,
            display_name=user.display_name,
            device_install_id=user.device_install_id,
            preferred_locale=user.preferred_locale,
            timezone=user.timezone,
            learning_level=user.learning_level,
            app_store_original_transaction_id=user.app_store_original_transaction_id,
            app_store_product_id=user.app_store_product_id,
            subscription_status=user.subscription_status,
            subscription_expires_at=user.subscription_expires_at,
            created_at=user.created_at,
            updated_at=datetime.now(timezone.utc),
        )
        session.add(profile)
    else:
        profile.email = user.email
        profile.email_normalized = user.email_normalized
        profile.hashed_password = user.hashed_password
        profile.security_question = user.security_question
        profile.security_answer_hash = user.security_answer_hash
        profile.display_name = user.display_name
        profile.device_install_id = user.device_install_id
        profile.preferred_locale = user.preferred_locale
        profile.timezone = user.timezone
        profile.learning_level = user.learning_level
        profile.app_store_original_transaction_id = user.app_store_original_transaction_id
        profile.app_store_product_id = user.app_store_product_id
        profile.subscription_status = user.subscription_status
        profile.subscription_expires_at = user.subscription_expires_at
        profile.created_at = user.created_at
        profile.updated_at = datetime.now(timezone.utc)

    for book in payload.books:
        session.add(
            Book(
                id=book.id,
                user_id=user_id,
                title=book.title,
                author=book.author,
                language=book.language,
                file_hash=book.file_hash,
                cover_ref=book.cover_ref,
                created_at=book.created_at,
                updated_at=book.updated_at,
                is_deleted=book.is_deleted,
            )
        )

    for chapter in payload.book_chapters:
        session.add(
            BookChapter(
                id=chapter.id,
                book_id=chapter.book_id,
                chapter_index=chapter.chapter_index,
                title=chapter.title,
                href=chapter.href,
                created_at=chapter.created_at,
            )
        )

    for progress in payload.reading_progress:
        session.add(
            ReadingProgress(
                id=progress.id,
                user_id=user_id,
                book_id=progress.book_id,
                chapter_index=progress.chapter_index,
                chapter_title=progress.chapter_title,
                cfi=progress.cfi,
                progress_percent=progress.progress_percent,
                last_read_at=progress.last_read_at,
                updated_at=progress.updated_at,
            )
        )

    for highlight in payload.highlights:
        session.add(
            Highlight(
                id=highlight.id,
                user_id=user_id,
                book_id=highlight.book_id,
                target_word=highlight.target_word,
                context_before=highlight.context_before,
                context_sentence=highlight.context_sentence,
                context_after=highlight.context_after,
                chapter_index=highlight.chapter_index,
                chapter_title=highlight.chapter_title,
                cfi=highlight.cfi,
                created_at=highlight.created_at,
                is_deleted=highlight.is_deleted,
            )
        )

    for srs_item in payload.srs_items:
        session.add(
            SrsItem(
                id=srs_item.id,
                highlight_id=srs_item.highlight_id,
                ease_factor=srs_item.ease_factor,
                interval_days=srs_item.interval_days,
                repetitions=srs_item.repetitions,
                mastery_level=srs_item.mastery_level,
                next_review_at=srs_item.next_review_at,
                last_review_at=srs_item.last_review_at,
            )
        )

    for review in payload.review_events:
        session.add(
            ReviewEvent(
                id=review.id,
                srs_item_id=review.srs_item_id,
                game_type=review.game_type,
                grade=review.grade,
                is_correct=review.is_correct,
                selected_answer=review.selected_answer,
                answered_at=review.answered_at,
                combo_multiplier=review.combo_multiplier,
                xp_earned=review.xp_earned,
                response_time_ms=review.response_time_ms,
            )
        )

    for entry in payload.dictionary_entries:
        existing = session.exec(
            select(DictionaryEntry).where(DictionaryEntry.word_normalized == entry.word.lower())
        ).first()
        if existing is None:
            session.add(
                DictionaryEntry(
                    id=entry.id,
                    word=entry.word,
                    word_normalized=entry.word.lower(),
                    definition=entry.definition,
                    example_sentence=entry.example_sentence,
                    synonyms_json=json.dumps(entry.synonyms) if entry.synonyms else None,
                    source=entry.source,
                )
            )
        else:
            existing.definition = entry.definition
            existing.example_sentence = entry.example_sentence
            existing.synonyms_json = json.dumps(entry.synonyms) if entry.synonyms else None
            existing.source = entry.source

    for cache in payload.game_cache:
        existing = session.exec(
            select(GameCache).where(GameCache.word_normalized == cache.word_normalized)
        ).first()
        if existing is None:
            session.add(
                GameCache(
                    word=cache.word,
                    word_normalized=cache.word_normalized,
                    context_clash_json=cache.context_clash_json,
                    odd_one_out_json=cache.odd_one_out_json,
                    true_or_bluff_json=cache.true_or_bluff_json,
                    cloze_json=cache.cloze_json,
                    generation_status=cache.generation_status,
                    created_at=cache.created_at,
                    updated_at=cache.updated_at,
                )
            )
        else:
            existing.context_clash_json = cache.context_clash_json
            existing.odd_one_out_json = cache.odd_one_out_json
            existing.true_or_bluff_json = cache.true_or_bluff_json
            existing.cloze_json = cache.cloze_json
            existing.generation_status = cache.generation_status
            existing.updated_at = cache.updated_at

    session.commit()
    return export_user_backup(session, user_id) or payload


def _clear_user_data(session: Session, user_id: UUID) -> None:
    books = list(
        session.exec(
            select(Book.id).where(
                Book.user_id == user_id,
                Book.is_deleted == False,  # noqa: E712
            )
        ).all()
    )
    srs_ids = [item.id for item in session.exec(
        select(SrsItem).join(Highlight, SrsItem.highlight_id == Highlight.id).where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
        )
    ).all()]

    if srs_ids:
        session.exec(
            ReviewEvent.__table__.delete().where(ReviewEvent.srs_item_id.in_(srs_ids))
        )
        session.exec(SrsItem.__table__.delete().where(SrsItem.id.in_(srs_ids)))

    session.exec(
        ReadingProgress.__table__.delete().where(ReadingProgress.user_id == user_id)
    )
    session.exec(Highlight.__table__.delete().where(Highlight.user_id == user_id))
    if books:
        session.exec(BookChapter.__table__.delete().where(BookChapter.book_id.in_(books)))
    session.exec(Book.__table__.delete().where(Book.user_id == user_id))
    session.commit()
