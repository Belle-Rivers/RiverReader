from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class BookChapterCreate(BaseModel):
    chapter_index: int = Field(ge=0)
    title: str | None = Field(default=None, max_length=256)
    href: str | None = Field(default=None, max_length=512)


class BookChapterRead(BookChapterCreate):
    id: UUID
    book_id: UUID
    created_at: datetime

    model_config = {"from_attributes": True}


class BookCreate(BaseModel):
    user_id: UUID
    title: str = Field(min_length=1, max_length=256)
    author: str | None = Field(default=None, max_length=256)
    language: str | None = Field(default=None, max_length=32)
    file_hash: str | None = Field(default=None, max_length=128)
    cover_ref: str | None = Field(default=None, max_length=512)
    chapters: list[BookChapterCreate] = Field(default_factory=list)


class BookUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=256)
    author: str | None = Field(default=None, max_length=256)
    language: str | None = Field(default=None, max_length=32)
    file_hash: str | None = Field(default=None, max_length=128)
    cover_ref: str | None = Field(default=None, max_length=512)
    chapters: list[BookChapterCreate] | None = None


class BookRead(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    author: str | None
    language: str | None
    file_hash: str | None
    cover_ref: str | None
    created_at: datetime
    updated_at: datetime
    is_deleted: bool
    chapters: list[BookChapterRead] = Field(default_factory=list)
    progress_percent: float | None = None
    last_read_at: datetime | None = None

    model_config = {"from_attributes": True}


class ReadingProgressUpsert(BaseModel):
    user_id: UUID
    chapter_index: int | None = Field(default=None, ge=0)
    chapter_title: str | None = Field(default=None, max_length=256)
    cfi: str | None = Field(default=None, max_length=1024)
    progress_percent: float | None = Field(default=None, ge=0, le=100)


class ReadingProgressRead(BaseModel):
    id: UUID
    user_id: UUID
    book_id: UUID
    chapter_index: int | None
    chapter_title: str | None
    cfi: str | None
    progress_percent: float | None
    last_read_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BookChapterContentRead(BaseModel):
    book_id: UUID
    chapter_index: int
    chapter_title: str | None = None
    chapter_href: str
    content_html: str
    content_text: str = ""


class HighlightCreate(BaseModel):
    user_id: UUID
    book_id: UUID
    target_word: str = Field(min_length=1, max_length=128)
    context_before: str | None = None
    context_sentence: str = Field(min_length=1)
    context_after: str | None = None
    chapter_index: int | None = Field(default=None, ge=0)
    chapter_title: str | None = Field(default=None, max_length=256)
    cfi: str | None = Field(default=None, max_length=1024)


class SrsItemRead(BaseModel):
    id: UUID
    highlight_id: UUID
    ease_factor: float
    interval_days: int
    repetitions: int
    mastery_level: int
    next_review_at: datetime
    last_review_at: datetime | None

    model_config = {"from_attributes": True}


class HighlightRead(BaseModel):
    id: UUID
    user_id: UUID
    book_id: UUID
    target_word: str
    context_before: str | None
    context_sentence: str
    context_after: str | None
    chapter_index: int | None
    chapter_title: str | None
    cfi: str | None
    created_at: datetime
    is_deleted: bool
    srs: SrsItemRead | None = None

    model_config = {"from_attributes": True}


class VaultItemRead(HighlightRead):
    book_title: str | None = None
    book_author: str | None = None


class ReviewGradeCreate(BaseModel):
    grade: int | None = Field(default=None, ge=0, le=5)
    is_correct: bool | None = None
    selected_answer: str | None = Field(default=None, max_length=512)
    game_type: str = Field(default="review", max_length=32)


class ReviewEventRead(BaseModel):
    id: UUID
    srs_item_id: UUID
    game_type: str
    grade: int
    is_correct: bool
    selected_answer: str | None
    answered_at: datetime
    combo_multiplier: int = 1
    xp_earned: int = 0
    response_time_ms: int | None = None
    srs: SrsItemRead

    model_config = {"from_attributes": True}


class GameAnswerCreate(BaseModel):
    user_id: UUID
    srs_item_id: UUID
    game_type: str = Field(max_length=32)
    selected_answer: str | None = Field(default=None, max_length=512)
    is_correct: bool
    grade: int | None = Field(default=None, ge=0, le=5)
    combo_multiplier: int = Field(default=1, ge=1)
    xp_earned: int = Field(default=0, ge=0)
    response_time_ms: int | None = Field(default=None, ge=0)


class GameDeckItemRead(BaseModel):
    game_type: str
    highlight_id: UUID
    srs_item_id: UUID
    target_word: str
    prompt: str
    choices: list[str] = Field(default_factory=list)
    correct_answer: str
    definition: str | None = None
    book_title: str | None = None


class DictionaryEntryRead(BaseModel):
    id: UUID
    word: str
    definition: str
    synonyms: list[str] = Field(default_factory=list)
    source: str | None


class AiRequest(BaseModel):
    word: str = Field(min_length=1, max_length=128)
    context_sentence: str | None = None


class AiResponse(BaseModel):
    cache_key: str
    enabled: bool
    cached: bool
    payload: dict | None = None
    detail: str | None = None
