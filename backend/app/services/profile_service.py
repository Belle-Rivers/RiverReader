import hashlib
import os
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.models import UserProfile
from app.schemas.profile import UserProfileCreate, UserProfileUpdate, UserLogin


def normalize_email(email: str) -> str:
    return email.strip().lower()

def hash_password(password: str) -> str:
    salt = os.urandom(16)
    pw_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 100000)
    return salt.hex() + ":" + pw_hash.hex()

def verify_password(password: str, hashed: str) -> bool:
    if not hashed or ":" not in hashed:
        return False
    salt_hex, hash_hex = hashed.split(":", 1)
    salt = bytes.fromhex(salt_hex)
    pw_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 100000)
    return pw_hash.hex() == hash_hex


def create_user_profile(session: Session, data: UserProfileCreate) -> UserProfile:
    """Register a new user profile. Raises ValueError if the email is taken."""
    normalized = normalize_email(data.email)
    if not normalized:
        raise ValueError("email must not be empty")
    display = (data.display_name or "").strip() or None
    hashed = hash_password(data.password) if data.password else None
    profile = UserProfile(
        email=data.email.strip(),
        email_normalized=normalized,
        hashed_password=hashed,
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
        raise ValueError("email is already registered") from None
    session.refresh(profile)
    return profile


def get_user_profile_by_id(session: Session, user_id: UUID) -> UserProfile | None:
    return session.get(UserProfile, user_id)


def get_user_profile_by_email(session: Session, email: str) -> UserProfile | None:
    normalized = normalize_email(email)
    if not normalized:
        return None
    statement = select(UserProfile).where(UserProfile.email_normalized == normalized)
    return session.exec(statement).first()

def verify_login(session: Session, data: UserLogin) -> UserProfile | None:
    profile = get_user_profile_by_email(session, data.email)
    if not profile or not profile.hashed_password:
        return None
    if verify_password(data.password, profile.hashed_password):
        return profile
    return None


def list_user_profiles(session: Session, *, limit: int = 100, offset: int = 0) -> list[UserProfile]:
    statement = (
        select(UserProfile).order_by(UserProfile.created_at.asc()).offset(offset).limit(limit)
    )
    return list(session.exec(statement).all())


def update_user_profile(session: Session, user_id: UUID, data: UserProfileUpdate) -> UserProfile | None:
    """Update profile fields. Raises ValueError if the new email is taken."""
    profile = session.get(UserProfile, user_id)
    if profile is None:
        return None
    changed = False
    if data.display_name is not None:
        new_display = (data.display_name or "").strip() or None
        if new_display != profile.display_name:
            profile.display_name = new_display
            changed = True
    if data.email is not None:
        new_email = data.email.strip()
        new_normalized = normalize_email(new_email)
        if not new_normalized:
            raise ValueError("email must not be empty")
        if new_normalized != profile.email_normalized:
            profile.email = new_email
            profile.email_normalized = new_normalized
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
        raise ValueError("email is already registered") from None
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
