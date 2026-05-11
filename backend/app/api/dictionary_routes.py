from fastapi import APIRouter, HTTPException, status

from app.db import SessionDep
from app.schemas import DictionaryEntryRead
from app.services import dictionary_service

dictionary_router = APIRouter(prefix="/dictionary", tags=["Dictionary"])


@dictionary_router.get("/{word}", response_model=DictionaryEntryRead)
def get_dictionary_entry(word: str, session: SessionDep) -> DictionaryEntryRead:
    entry = dictionary_service.get_entry(session, word)
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="dictionary entry not found")
    return entry
