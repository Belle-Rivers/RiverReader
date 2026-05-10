from fastapi import APIRouter

from app.schemas.health import HealthResponse

health_router = APIRouter(tags=["Health"])


@health_router.get("/health", response_model=HealthResponse, summary="Health")
def get_health() -> HealthResponse:
    return HealthResponse(status="ok")
