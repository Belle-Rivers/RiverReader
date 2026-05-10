from fastapi import APIRouter
from fastapi.responses import RedirectResponse, Response

root_router = APIRouter(tags=["Root"])


@root_router.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse(url="/docs")


@root_router.get("/favicon.ico", include_in_schema=False)
def favicon() -> Response:
    return Response(status_code=204)

