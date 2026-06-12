import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    ai_router,
    book_router,
    dictionary_router,
    game_router,
    health_router,
    highlight_router,
    me_router,
    review_router,
    root_router,
    user_router,
    vault_router,
    version_router,
)
from app.db import init_db
from app.settings import get_settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-7s │ %(name)s │ %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("river_reader")


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    log.info("── River Reader backend starting ──")
    init_db()
    log.info("── Database initialised, ready to serve ──")
    yield
    log.info("── River Reader backend shutting down ──")


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(
        title=settings.app_title,
        version=settings.app_version,
        lifespan=lifespan,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allowed_origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    application.include_router(root_router)
    application.include_router(health_router)
    application.include_router(ai_router, prefix=settings.api_v1_prefix)
    application.include_router(book_router, prefix=settings.api_v1_prefix)
    application.include_router(dictionary_router, prefix=settings.api_v1_prefix)
    application.include_router(game_router, prefix=settings.api_v1_prefix)
    application.include_router(highlight_router, prefix=settings.api_v1_prefix)
    application.include_router(me_router, prefix=settings.api_v1_prefix)
    application.include_router(review_router, prefix=settings.api_v1_prefix)
    application.include_router(user_router, prefix=settings.api_v1_prefix)
    application.include_router(vault_router, prefix=settings.api_v1_prefix)
    application.include_router(version_router, prefix=settings.api_v1_prefix)

    @application.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        exc_str = f"{exc}".replace("\n", " ").replace("   ", " ")
        log.warning("Validation error %s %s – %s", request.method, request.url.path, exc_str)
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"detail": exc.errors(), "body": exc.body},
        )

    return application


app = create_app()
