from pydantic import BaseModel

from app.schemas.profile import UserProfileRead
from app.schemas.reading import BookRead, ReadingProgressRead, VaultItemRead


class HomeStatsRead(BaseModel):
    books_count: int
    vault_count: int
    due_reviews_count: int
    xp_earned_total: int = 0
    xp_progress_percent: float = 0.0


class HomeRead(BaseModel):
    user: UserProfileRead
    stats: HomeStatsRead
    last_opened_book: BookRead | None = None
    last_progress: ReadingProgressRead | None = None
    # Last 5 words added to the Vault, shown on the home page for quick reference
    recent_vault_words: list[VaultItemRead] = []
