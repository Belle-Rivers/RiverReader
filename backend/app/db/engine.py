from sqlmodel import SQLModel, create_engine

from app.models import (  # noqa: F401 — register metadata
    Book,
    BookChapter,
    DictionaryEntry,
    GameCache,
    Highlight,
    LlmCache,
    ReadingProgress,
    ReviewEvent,
    SrsItem,
    UserBackup,
    UserProfile,
)
from app.settings import get_settings

import logging
log = logging.getLogger("river_reader")

_ENGINE = None


def get_engine():
    global _ENGINE
    if _ENGINE is None:
        url = get_settings().database_url
        # Mask password for safe logging
        try:
            from sqlalchemy.engine import make_url
            parsed = make_url(url)
            safe_url = parsed.render_as_string(hide_password=True)
        except Exception:
            safe_url = url.split("@")[-1] if "@" in url else url
        log.info("Connecting to database: %s", safe_url)
        engine_kwargs: dict = {}
        if url.startswith("sqlite"):
            engine_kwargs["connect_args"] = {"check_same_thread": False}
        elif url.startswith("postgres"):
            engine_kwargs["pool_pre_ping"] = True
            engine_kwargs["pool_recycle"] = 300
            engine_kwargs["pool_size"] = 10
            engine_kwargs["max_overflow"] = 20
        try:
            _ENGINE = create_engine(url, **engine_kwargs)
        except Exception as exc:
            log.error("Failed to parse database URL: %s", exc)
            log.error("URL starts with: %s...", url[:20])
            raise
    return _ENGINE


def init_db() -> None:
    engine = get_engine()
    SQLModel.metadata.create_all(engine)
    if engine.dialect.name == "sqlite":
        _ensure_user_profile_columns(engine)
        _ensure_dictionary_columns(engine)
        _ensure_review_event_columns(engine)
        _ensure_game_cache_columns(engine)
    elif engine.dialect.name == "postgresql":
        _fix_postgresql_null_booleans(engine)

def _fix_postgresql_null_booleans(engine) -> None:
    # After migration from SQLite, boolean fields might be NULL instead of false
    with engine.begin() as connection:
        try:
            connection.exec_driver_sql("UPDATE highlights SET is_deleted = false WHERE is_deleted IS NULL;")
            connection.exec_driver_sql("UPDATE books SET is_deleted = false WHERE is_deleted IS NULL;")
        except Exception as e:
            log.warning("Failed to fix postgresql boolean nulls: %s", e)

def _ensure_user_profile_columns(engine) -> None:
    columns = {
        "device_install_id": "VARCHAR(128)",
        "preferred_locale": "VARCHAR(16)",
        "timezone": "VARCHAR(64)",
        "learning_level": "VARCHAR(32)",
        "security_question": "VARCHAR(256)",
        "security_answer_hash": "VARCHAR(256)",
        "app_store_original_transaction_id": "VARCHAR(128)",
        "app_store_product_id": "VARCHAR(128)",
        "subscription_status": "VARCHAR(32)",
        "subscription_expires_at": "DATETIME",
    }
    with engine.begin() as connection:
        existing = {
            row[1]
            for row in connection.exec_driver_sql("PRAGMA table_info(user_profiles)").all()
        }
        for column_name, column_type in columns.items():
            if column_name not in existing:
                connection.exec_driver_sql(
                    f"ALTER TABLE user_profiles ADD COLUMN {column_name} {column_type}"
                )


def _ensure_dictionary_columns(engine) -> None:
    """Add columns to dictionary_entries that were introduced after the initial schema.

    example_sentence: a standalone sentence using the word, different from the
    context_sentence captured during reading. Used in the cloze game so the user
    is tested on their knowledge of the word in a new context.
    """
    columns = {
        "example_sentence": "TEXT",
    }
    with engine.begin() as connection:
        existing = {
            row[1]
            for row in connection.exec_driver_sql("PRAGMA table_info(dictionary_entries)").all()
        }
        for column_name, column_type in columns.items():
            if column_name not in existing:
                connection.exec_driver_sql(
                    f"ALTER TABLE dictionary_entries ADD COLUMN {column_name} {column_type}"
                )


def _ensure_game_cache_columns(engine) -> None:
    columns = {
        "cloze_json": "TEXT",
    }
    with engine.begin() as connection:
        existing = {
            row[1]
            for row in connection.exec_driver_sql("PRAGMA table_info(game_cache)").all()
        }
        for column_name, column_type in columns.items():
            if column_name not in existing:
                connection.exec_driver_sql(
                    f"ALTER TABLE game_cache ADD COLUMN {column_name} {column_type}"
                )


def _ensure_review_event_columns(engine) -> None:
    columns = {
        "combo_multiplier": "INTEGER DEFAULT 1",
        "xp_earned": "INTEGER DEFAULT 0",
        "response_time_ms": "INTEGER",
    }
    with engine.begin() as connection:
        existing = {
            row[1]
            for row in connection.exec_driver_sql("PRAGMA table_info(review_events)").all()
        }
        for column_name, column_type in columns.items():
            if column_name not in existing:
                connection.exec_driver_sql(
                    f"ALTER TABLE review_events ADD COLUMN {column_name} {column_type}"
                )
