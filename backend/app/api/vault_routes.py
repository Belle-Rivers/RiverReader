from uuid import UUID

from fastapi import APIRouter, Query

from app.db import SessionDep
from app.schemas import VaultItemRead
from app.services import vault_service

vault_router = APIRouter(prefix="/vault", tags=["Vault"])


@vault_router.get("", response_model=list[VaultItemRead])
def list_vault(
    user_id: UUID,
    session: SessionDep,
    book_id: UUID | None = None,
    q: str | None = None,
    min_mastery: int | None = Query(default=None, ge=0, le=5),
    max_mastery: int | None = Query(default=None, ge=0, le=5),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> list[VaultItemRead]:
    return vault_service.list_vault_items(
        session,
        user_id,
        book_id=book_id,
        q=q,
        min_mastery=min_mastery,
        max_mastery=max_mastery,
        limit=limit,
        offset=offset,
    )


@vault_router.get("/search", response_model=list[VaultItemRead])
def search_vault(
    user_id: UUID,
    q: str,
    session: SessionDep,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> list[VaultItemRead]:
    return vault_service.search_vault_items(session, user_id, q, limit=limit, offset=offset)
