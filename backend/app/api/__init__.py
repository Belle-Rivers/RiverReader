from app.api.health_routes import health_router
from app.api.root_routes import root_router
from app.api.user_routes import user_router
from app.api.version_routes import version_router

__all__ = ["health_router", "root_router", "user_router", "version_router"]
