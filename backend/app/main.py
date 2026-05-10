from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import health_router, root_router, version_router
from app.settings import get_settings


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(
        title=settings.app_title,
        version=settings.app_version,
        lifespan=lifespan,
    )
    application.include_router(root_router)
    application.include_router(health_router)
    application.include_router(version_router, prefix=settings.api_v1_prefix)
    return application


app = create_app()
