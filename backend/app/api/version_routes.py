from fastapi import APIRouter

from app.schemas.version import VersionResponse
from app.settings import get_settings

version_router = APIRouter(tags=["Version"])


@version_router.get("/version", response_model=VersionResponse)
def get_api_version() -> VersionResponse:
    settings = get_settings()
    return VersionResponse(version=settings.app_version, api="v1")
