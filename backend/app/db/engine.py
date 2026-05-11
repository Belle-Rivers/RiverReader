from pathlib import Path

from sqlmodel import SQLModel, create_engine

from app.models import UserProfile  # noqa: F401 — register metadata

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
