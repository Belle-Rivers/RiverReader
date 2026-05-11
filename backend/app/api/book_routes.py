from uuid import UUID

from fastapi import APIRouter, HTTPException, Response, status

from app.db import SessionDep
from app.schemas import BookCreate, BookRead, BookUpdate, ReadingProgressRead, ReadingProgressUpsert
from app.services import book_service, progress_service

book_router = APIRouter(prefix="/books", tags=["Books"])


@book_router.post("", response_model=BookRead, status_code=status.HTTP_201_CREATED)
def create_book(payload: BookCreate, session: SessionDep) -> BookRead:
    return book_service.create_book(session, payload)


@book_router.get("", response_model=list[BookRead])
def list_books(
    session: SessionDep,
    user_id: UUID,
    include_deleted: bool = False,
) -> list[BookRead]:
    return book_service.list_books(session, user_id, include_deleted=include_deleted)


@book_router.get("/{book_id}", response_model=BookRead)
def get_book(book_id: UUID, user_id: UUID, session: SessionDep) -> BookRead:
    book = book_service.get_book(session, book_id, user_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book not found")
    return book


@book_router.patch("/{book_id}", response_model=BookRead)
def update_book(
    book_id: UUID,
    user_id: UUID,
    payload: BookUpdate,
    session: SessionDep,
) -> BookRead:
    book = book_service.update_book(session, book_id, payload, user_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book not found")
    return book


@book_router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(
    book_id: UUID,
    user_id: UUID,
    session: SessionDep,
) -> Response:
    if not book_service.soft_delete_book(session, book_id, user_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@book_router.get("/{book_id}/progress", response_model=ReadingProgressRead)
def get_progress(book_id: UUID, user_id: UUID, session: SessionDep) -> ReadingProgressRead:
    progress = progress_service.get_progress(session, book_id, user_id)
    if progress is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="progress not found")
    return progress


@book_router.put("/{book_id}/progress", response_model=ReadingProgressRead)
def upsert_progress(
    book_id: UUID,
    payload: ReadingProgressUpsert,
    session: SessionDep,
) -> ReadingProgressRead:
    progress = progress_service.upsert_progress(session, book_id, payload)
    if progress is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book not found")
    return progress
