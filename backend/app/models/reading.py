from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Book(SQLModel, table=True):
    __tablename__ = "books"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(index=True)
    title: str = Field(max_length=256)
    author: str | None = Field(default=None, max_length=256)
    language: str | None = Field(default=None, max_length=32)
    file_hash: str | None = Field(default=None, max_length=128, index=True)
    cover_ref: str | None = Field(default=None, max_length=512)
    created_at: datetime = Field(default_factory=utc_now)
    updated_at: datetime = Field(default_factory=utc_now)
    is_deleted: bool = Field(default=False, index=True)


class BookChapter(SQLModel, table=True):
    __tablename__ = "book_chapters"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    book_id: UUID = Field(index=True)
    chapter_index: int = Field(index=True)
    title: str | None = Field(default=None, max_length=256)
    href: str | None = Field(default=None, max_length=512)
    created_at: datetime = Field(default_factory=utc_now)


class ReadingProgress(SQLModel, table=True):
    __tablename__ = "reading_progress"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(index=True)
    book_id: UUID = Field(index=True)
    chapter_index: int | None = None
    chapter_title: str | None = Field(default=None, max_length=256)
    cfi: str | None = Field(default=None, max_length=1024)
    progress_percent: float | None = None
    last_read_at: datetime = Field(default_factory=utc_now)
    updated_at: datetime = Field(default_factory=utc_now)


class Highlight(SQLModel, table=True):
    __tablename__ = "highlights"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(index=True)
    book_id: UUID = Field(index=True)
    target_word: str = Field(max_length=128, index=True)
    context_before: str | None = None
    context_sentence: str
    context_after: str | None = None
    chapter_index: int | None = None
    chapter_title: str | None = Field(default=None, max_length=256)
    cfi: str | None = Field(default=None, max_length=1024)
    created_at: datetime = Field(default_factory=utc_now)
    is_deleted: bool = Field(default=False, index=True)


class SrsItem(SQLModel, table=True):
    __tablename__ = "srs_items"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    highlight_id: UUID = Field(index=True, unique=True)
    ease_factor: float = Field(default=2.5)
    interval_days: int = Field(default=0)
    repetitions: int = Field(default=0)
    mastery_level: int = Field(default=0, index=True)
    next_review_at: datetime = Field(default_factory=utc_now, index=True)
    last_review_at: datetime | None = None


class ReviewEvent(SQLModel, table=True):
    __tablename__ = "review_events"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    srs_item_id: UUID = Field(index=True)
    game_type: str = Field(max_length=32)
    grade: int
    is_correct: bool
    selected_answer: str | None = Field(default=None, max_length=512)
    answered_at: datetime = Field(default_factory=utc_now)


class DictionaryEntry(SQLModel, table=True):
    __tablename__ = "dictionary_entries"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    word: str = Field(max_length=128)
    word_normalized: str = Field(max_length=128, unique=True, index=True)
    definition: str
    # example_sentence: a standalone sentence using the word, used in the cloze game.
    # It is intentionally different from the context_sentence captured during reading.
    example_sentence: str | None = None
    synonyms_json: str | None = None
    source: str | None = Field(default=None, max_length=128)


class LlmCache(SQLModel, table=True):
    __tablename__ = "llm_cache"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    cache_key: str = Field(max_length=256, unique=True, index=True)
    payload_json: str
    created_at: datetime = Field(default_factory=utc_now)
