from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="RIVER_READER_",
        env_file=".env",
        extra="ignore",
    )

    app_title: str = "River Reader"
    app_version: str = "0.1.0"
    api_v1_prefix: str = "/v1"
    ai_enabled: bool = False


@lru_cache
def get_settings() -> Settings:
    return Settings()
