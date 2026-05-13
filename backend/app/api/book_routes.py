from uuid import UUID

import os
from fastapi import APIRouter, HTTPException, Response, status, UploadFile, File, Form
from fastapi.responses import FileResponse

from app.db import SessionDep
from app.schemas import (
    BookChapterContentRead,
    BookCreate,
    BookRead,
    BookUpdate,
    ReadingProgressRead,
    ReadingProgressUpsert,
)
from app.services import book_service, progress_service

book_router = APIRouter(prefix="/books", tags=["Books"])


@book_router.post("", response_model=BookRead, status_code=status.HTTP_201_CREATED)
def create_book(payload: BookCreate, session: SessionDep) -> BookRead:
    return book_service.create_book(session, payload)


@book_router.post("/upload", response_model=BookRead, status_code=status.HTTP_201_CREATED)
async def upload_book(
    session: SessionDep,
    file: UploadFile = File(...),
    user_id: UUID = Form(...),
) -> BookRead:
    from app.services.epub_parser import parse_epub_file, save_upload_file
    
    if not file.filename.endswith('.epub'):
        raise HTTPException(status_code=400, detail="Only EPUB files are supported")
    
    # Generate a temporary path to save the file
    upload_dir = "data/books"
    os.makedirs(upload_dir, exist_ok=True)
    
    # We use a temporary UUID for the file, we will rename it after we get the DB book ID
    import uuid
    temp_id = uuid.uuid4()
    temp_path = os.path.join(upload_dir, f"{temp_id}.epub")
    
    try:
        await save_upload_file(file, temp_path)
        book_create = parse_epub_file(temp_path, user_id)
        book = book_service.create_book(session, book_create)
        
        # Rename to the actual book ID
        final_path = os.path.join(upload_dir, f"{book.id}.epub")
        os.rename(temp_path, final_path)
        return book
    except Exception as e:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise HTTPException(status_code=400, detail=f"Failed to process EPUB: {e}")


@book_router.get("/{book_id}/file", response_class=FileResponse)
def get_book_file(book_id: UUID, user_id: UUID, session: SessionDep):
    book = book_service.get_book(session, book_id, user_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book not found")
    
    file_path = f"data/books/{book_id}.epub"
    if not os.path.exists(file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book file not found on server")
    
    return FileResponse(file_path, media_type="application/epub+zip", filename=f"{book.title}.epub")


@book_router.get("/{book_id}/chapters/{chapter_index}/content", response_model=BookChapterContentRead)
def get_book_chapter_content(
    book_id: UUID,
    chapter_index: int,
    user_id: UUID,
    session: SessionDep,
) -> BookChapterContentRead:
    if chapter_index < 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid chapter index")
    chapter = book_service.get_book_chapter(
        session,
        book_id=book_id,
        user_id=user_id,
        chapter_index=chapter_index,
    )
    if chapter is None or not chapter.href:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="chapter not found")
    file_path = f"data/books/{book_id}.epub"
    if not os.path.exists(file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="book file not found on server")
    from app.services.epub_parser import extract_chapter_content, extract_chapter_text
    try:
        chapter_html = extract_chapter_content(file_path, chapter.href)
        chapter_text = extract_chapter_text(file_path, chapter.href)
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="chapter file missing in epub") from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"failed to parse chapter: {exc}") from exc
    return BookChapterContentRead(
        book_id=book_id,
        chapter_index=chapter_index,
        chapter_title=chapter.title,
        chapter_href=chapter.href,
        content_html=chapter_html,
        content_text=chapter_text,
    )



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
