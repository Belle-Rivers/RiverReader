from fastapi import APIRouter, HTTPException, Response, status

from app.db import SessionDep
from app.schemas import DictionaryEntryCreate, DictionaryEntryRead, DictionaryEntryUpdate
from app.services import dictionary_service

dictionary_router = APIRouter(prefix="/dictionary", tags=["Dictionary"])


@dictionary_router.get("/{word}", response_model=DictionaryEntryRead)
async def get_dictionary_entry(word: str, session: SessionDep) -> DictionaryEntryRead:
    entry = await dictionary_service.get_entry(session, word)
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="dictionary entry not found",
        )
    return entry


@dictionary_router.post("", response_model=DictionaryEntryRead, status_code=status.HTTP_201_CREATED)
def create_dictionary_entry(
    payload: DictionaryEntryCreate, session: SessionDep
) -> DictionaryEntryRead:
    try:
        return dictionary_service.create_entry(session, payload)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="dictionary entry already exists for this word",
        )


@dictionary_router.put("/{word}", response_model=DictionaryEntryRead)
def put_dictionary_entry(
    word: str, payload: DictionaryEntryCreate, session: SessionDep
) -> DictionaryEntryRead:
    return dictionary_service.upsert_entry(session, word, payload)


@dictionary_router.patch("/{word}", response_model=DictionaryEntryRead)
def patch_dictionary_entry(
    word: str, payload: DictionaryEntryUpdate, session: SessionDep
) -> DictionaryEntryRead:
    entry = dictionary_service.update_entry(session, word, payload)
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="dictionary entry not found",
        )
    return entry


@dictionary_router.delete("/{word}", status_code=status.HTTP_204_NO_CONTENT)
def delete_dictionary_entry(word: str, session: SessionDep) -> Response:
    deleted = dictionary_service.delete_entry(session, word)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="dictionary entry not found",
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
