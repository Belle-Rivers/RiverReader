import hashlib
import json

from sqlmodel import Session, select

from app.models import LlmCache
from app.schemas import AiRequest, AiResponse
from app.settings import get_settings


def _cache_key(kind: str, data: AiRequest) -> str:
    raw = f"{kind}:{data.word.strip().lower()}:{data.context_sentence or ''}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def get_cached_or_disabled(session: Session, kind: str, data: AiRequest) -> AiResponse:
    key = _cache_key(kind, data)
    cache = session.exec(select(LlmCache).where(LlmCache.cache_key == key)).first()
    if cache is not None:
        return AiResponse(
            cache_key=key,
            enabled=get_settings().ai_enabled,
            cached=True,
            payload=json.loads(cache.payload_json),
        )
    if not get_settings().ai_enabled:
        return AiResponse(
            cache_key=key,
            enabled=False,
            cached=False,
            detail="AI enrichment is disabled and no cached response exists.",
        )
    return AiResponse(
        cache_key=key,
        enabled=True,
        cached=False,
        detail="AI enrichment provider is not configured for this MVP.",
    )
