from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class UserProfileCreate(BaseModel):
    """Payload to register a local user profile (username-only MVP)."""

    username: str = Field(min_length=1, max_length=64)
    display_name: str | None = Field(default=None, max_length=128)
    device_install_id: str | None = Field(default=None, max_length=128)
    preferred_locale: str | None = Field(default=None, max_length=16, examples=["en-US"])
    timezone: str | None = Field(default=None, max_length=64, examples=["Africa/Cairo"])
    learning_level: str | None = Field(default=None, max_length=32, examples=["B1"])
    app_store_original_transaction_id: str | None = Field(default=None, max_length=128)
    app_store_product_id: str | None = Field(default=None, max_length=128)
    subscription_status: str | None = Field(default=None, max_length=32, examples=["free"])
    subscription_expires_at: datetime | None = None


class UserProfileUpdate(BaseModel):
    """Partial update for display name and/or username."""

    username: str | None = Field(default=None, min_length=1, max_length=64)
    display_name: str | None = Field(default=None, max_length=128)
    device_install_id: str | None = Field(default=None, max_length=128)
    preferred_locale: str | None = Field(default=None, max_length=16)
    timezone: str | None = Field(default=None, max_length=64)
    learning_level: str | None = Field(default=None, max_length=32)
    app_store_original_transaction_id: str | None = Field(default=None, max_length=128)
    app_store_product_id: str | None = Field(default=None, max_length=128)
    subscription_status: str | None = Field(default=None, max_length=32)
    subscription_expires_at: datetime | None = None


class UserProfileRead(BaseModel):
    """Public profile shape (no internal normalized username field)."""

    id: UUID
    username: str
    display_name: str | None
    device_install_id: str | None
    preferred_locale: str | None
    timezone: str | None
    learning_level: str | None
    app_store_original_transaction_id: str | None
    app_store_product_id: str | None
    subscription_status: str | None
    subscription_expires_at: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
