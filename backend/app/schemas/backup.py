from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.reading import (
    BookChapterRead,
    BookRead,
    DictionaryEntryRead,
    ReadingProgressRead,
    ReviewEventRead,
    SrsItemRead,
    VaultItemRead,
)


class UserProfileBackupRead(BaseModel):
    id: UUID
    email: str
    email_normalized: str
    hashed_password: str | None = None
    security_question: str | None = None
    security_answer_hash: str | None = None
    display_name: str | None = None
    device_install_id: str | None = None
    preferred_locale: str | None = None
    timezone: str | None = None
    learning_level: str | None = None
    app_store_original_transaction_id: str | None = None
    app_store_product_id: str | None = None
    subscription_status: str | None = None
    subscription_expires_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class GameCacheBackupRead(BaseModel):
    word: str
    word_normalized: str
    context_clash_json: str | None = None
    odd_one_out_json: str | None = None
    true_or_bluff_json: str | None = None
    cloze_json: str | None = None
    generation_status: str
    created_at: datetime
    updated_at: datetime


class UserDataBackupRead(BaseModel):
    version: int = 1
    user: UserProfileBackupRead
    books: list[BookRead] = Field(default_factory=list)
    book_chapters: list[BookChapterRead] = Field(default_factory=list)
    reading_progress: list[ReadingProgressRead] = Field(default_factory=list)
    highlights: list[VaultItemRead] = Field(default_factory=list)
    srs_items: list[SrsItemRead] = Field(default_factory=list)
    review_events: list[ReviewEventRead] = Field(default_factory=list)
    dictionary_entries: list[DictionaryEntryRead] = Field(default_factory=list)
    game_cache: list[GameCacheBackupRead] = Field(default_factory=list)
