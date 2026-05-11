from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel


class UserProfile(SQLModel, table=True):
    """Local user profile (MVP: username + optional display name, no password)."""

    __tablename__ = "user_profiles"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    username: str = Field(max_length=64)
    username_normalized: str = Field(max_length=64, unique=True, index=True)
    display_name: str | None = Field(default=None, max_length=128)
    device_install_id: str | None = Field(default=None, max_length=128, index=True)
    preferred_locale: str | None = Field(default=None, max_length=16)
    timezone: str | None = Field(default=None, max_length=64)
    learning_level: str | None = Field(default=None, max_length=32)
    app_store_original_transaction_id: str | None = Field(
        default=None,
        max_length=128,
        index=True,
    )
    app_store_product_id: str | None = Field(default=None, max_length=128)
    subscription_status: str | None = Field(default=None, max_length=32)
    subscription_expires_at: datetime | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
