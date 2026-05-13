from pathlib import Path

from sqlmodel import SQLModel, create_engine

from app.models import (  # noqa: F401 — register metadata
    Book,
    BookChapter,
    DictionaryEntry,
    Highlight,
    LlmCache,
    ReadingProgress,
    ReviewEvent,
    SrsItem,
    UserProfile,
)

_ENGINE = None


def _database_url() -> str:
    backend_root = Path(__file__).resolve().parents[2]
    db_path = backend_root / "data" / "river_reader.db"
    db_path.parent.mkdir(parents=True, exist_ok=True)
    return f"sqlite:///{db_path}"


def get_engine():
    global _ENGINE
    if _ENGINE is None:
        _ENGINE = create_engine(
            _database_url(),
            connect_args={"check_same_thread": False},
        )
    return _ENGINE


def init_db() -> None:
    engine = get_engine()
    SQLModel.metadata.create_all(engine)
    _ensure_user_profile_columns(engine)
    _ensure_dictionary_columns(engine)
    _ensure_review_event_columns(engine)


def _ensure_user_profile_columns(engine) -> None:
    columns = {
        "device_install_id": "VARCHAR(128)",
        "preferred_locale": "VARCHAR(16)",
        "timezone": "VARCHAR(64)",
        "learning_level": "VARCHAR(32)",
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
