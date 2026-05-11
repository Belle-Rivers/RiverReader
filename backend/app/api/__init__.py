from app.api.ai_routes import ai_router
from app.api.book_routes import book_router
from app.api.dictionary_routes import dictionary_router
from app.api.game_routes import game_router
from app.api.health_routes import health_router
from app.api.highlight_routes import highlight_router
from app.api.review_routes import review_router
from app.api.root_routes import root_router
from app.api.user_routes import user_router
from app.api.vault_routes import vault_router
from app.api.version_routes import version_router

__all__ = [
    "ai_router",
    "book_router",
    "dictionary_router",
    "game_router",
    "health_router",
    "highlight_router",
    "review_router",
    "root_router",
    "user_router",
    "vault_router",
    "version_router",
]
