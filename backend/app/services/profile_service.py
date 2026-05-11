from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.models import UserProfile
from app.schemas.profile import UserProfileCreate, UserProfileUpdate


def normalize_username(username: str) -> str:
    return username.strip().lower()


def create_user_profile(session: Session, data: UserProfileCreate) -> UserProfile:
    """Register a new user profile. Raises ValueError if the username is taken."""
    normalized = normalize_username(data.username)
    if not normalized:
        raise ValueError("username must not be empty")
    display = (data.display_name or "").strip() or None
    profile = UserProfile(
        username=data.username.strip(),
        username_normalized=normalized,
        display_name=display,
        device_install_id=data.device_install_id,
        preferred_locale=data.preferred_locale,
        timezone=data.timezone,
        learning_level=data.learning_level,
        app_store_original_transaction_id=data.app_store_original_transaction_id,
        app_store_product_id=data.app_store_product_id,
        subscription_status=data.subscription_status or "free",
        subscription_expires_at=data.subscription_expires_at,
    )
    session.add(profile)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise ValueError("username is already registered") from None
    session.refresh(profile)
    return profile


def get_user_profile_by_id(session: Session, user_id: UUID) -> UserProfile | None:
    return session.get(UserProfile, user_id)


def get_user_profile_by_username(session: Session, username: str) -> UserProfile | None:
    normalized = normalize_username(username)
    if not normalized:
        return None
    statement = select(UserProfile).where(UserProfile.username_normalized == normalized)
    return session.exec(statement).first()


def list_user_profiles(session: Session, *, limit: int = 100, offset: int = 0) -> list[UserProfile]:
    statement = (
        select(UserProfile).order_by(UserProfile.created_at.asc()).offset(offset).limit(limit)
    )
    return list(session.exec(statement).all())


def update_user_profile(session: Session, user_id: UUID, data: UserProfileUpdate) -> UserProfile | None:
    """Update profile fields. Raises ValueError if the new username is taken."""
    profile = session.get(UserProfile, user_id)
    if profile is None:
        return None
    changed = False
    if data.display_name is not None:
        new_display = (data.display_name or "").strip() or None
        if new_display != profile.display_name:
            profile.display_name = new_display
            changed = True
    if data.username is not None:
        new_username = data.username.strip()
        new_normalized = normalize_username(new_username)
        if not new_normalized:
            raise ValueError("username must not be empty")
        if new_normalized != profile.username_normalized:
            profile.username = new_username
            profile.username_normalized = new_normalized
            changed = True
    for field_name in (
        "device_install_id",
        "preferred_locale",
        "timezone",
        "learning_level",
        "app_store_original_transaction_id",
        "app_store_product_id",
        "subscription_status",
        "subscription_expires_at",
    ):
        new_value = getattr(data, field_name)
        if new_value is not None and new_value != getattr(profile, field_name):
            setattr(profile, field_name, new_value)
            changed = True
    if not changed:
        return profile
    profile.updated_at = datetime.now(timezone.utc)
    session.add(profile)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise ValueError("username is already registered") from None
    session.refresh(profile)
    return profile


def delete_user_profile(session: Session, user_id: UUID) -> bool:
    """Remove a profile row. Returns False if the id did not exist."""
    profile = session.get(UserProfile, user_id)
    if profile is None:
        return False
    session.delete(profile)
    session.commit()
    return True
