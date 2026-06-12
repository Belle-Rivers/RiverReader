import hashlib
import json
import logging
from datetime import datetime, timezone

import httpx
from sqlmodel import Session, select

from app.models import GameCache, LlmCache
from app.schemas import AiRequest, AiResponse
from app.settings import get_settings

log = logging.getLogger("river_reader.ai")

_GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
_GROQ_MODEL = "llama-3.1-8b-instant"

_SYSTEM_PROMPT = """You are an expert game designer specializing in lexical acquisition for casual intermediate English readers.

Analyze the target word: "{word}".
Context from the book: "{context}"

Generate game content matching the exact JSON structure defined below.

Constraints:
- Sentences must match the readability profile of a B1/B2 level English reader.
- Avoid academic, archaic, or esoteric terminology in definitions.
- For "context_clash": the correct_sentence uses the word naturally; the clash_sentence is syntactically correct but contextually absurd (replace the target word with a different vault word to make it absurd).
- For "odd_one_out": provide 3 genuine synonyms of the target word and exactly 1 misfit word with no semantic overlap.
- For "true_or_bluff": generate a clear declarative condition statement that is TRUE about the word's meaning.

Your output must strictly be raw JSON matching this schema:
{{
  "context_clash": {{
    "correct_sentence": "string",
    "clash_sentence": "string",
    "explanation": "string"
  }},
  "odd_one_out": {{
    "synonyms": ["string", "string", "string"],
    "misfit_word": "string"
  }},
  "true_or_bluff": {{
    "statement": "string",
    "is_true": true
  }}
}}"""


def _cache_key(word: str, context: str | None) -> str:
    raw = f"groq_games:{word.strip().lower()}:{context or ''}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


# ─── Public API used by highlight creation ────────────────────────────────────

def generate_game_content(session: Session, word: str, context_sentence: str | None = None) -> dict | None:
    """Call Groq to generate all 3 game payloads for a word. Cache in game_cache.

    Returns the parsed JSON dict or None on failure.
    """
    settings = get_settings()
    if not settings.ai_enabled or not settings.groq_api_key:
        log.info("AI disabled or no Groq key – skipping game generation for %r", word)
        return None

    word_normalized = word.strip().lower()

    # Check if already cached
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()
    if existing and existing.generation_status == "Completed":
        log.info("Game cache hit for %r – skipping Groq call", word)
        return _parse_cache(existing)

    log.info("Generating game content via Groq for %r …", word)

    user_prompt = _SYSTEM_PROMPT.format(
        word=word.strip(),
        context=context_sentence or "(no context available)",
    )

    payload = {
        "model": _GROQ_MODEL,
        "messages": [
            {"role": "system", "content": user_prompt},
            {"role": "user", "content": f"Generate game content for the word: {word}"},
        ],
        "temperature": 0.7,
        "max_tokens": 1024,
        "response_format": {"type": "json_object"},
    }

    headers = {
        "Authorization": f"Bearer {settings.groq_api_key}",
        "Content-Type": "application/json",
    }

    try:
        with httpx.Client(timeout=30.0) as client:
            resp = client.post(_GROQ_API_URL, json=payload, headers=headers)
    except Exception as exc:
        log.error("Groq API call failed for %r: %s", word, exc)
        _mark_failed(session, word_normalized)
        return None

    if resp.status_code != 200:
        log.error("Groq returned %d for %r: %s", resp.status_code, word, resp.text[:300])
        _mark_failed(session, word_normalized)
        return None

    try:
        body = resp.json()
        raw_text = body["choices"][0]["message"]["content"]
        parsed = json.loads(raw_text)
    except (KeyError, json.JSONDecodeError, IndexError) as exc:
        log.error("Failed to parse Groq response for %r: %s", word, exc)
        _mark_failed(session, word_normalized)
        return None

    # Validate the structure
    required_keys = ["context_clash", "odd_one_out", "true_or_bluff"]
    for key in required_keys:
        if key not in parsed:
            log.error("Groq response missing key %r for %r", key, word)
            _mark_failed(session, word_normalized)
            return None

    # Cache to game_cache
    _save_game_cache(session, word, word_normalized, parsed)
    log.info("✓ Groq game content cached for %r", word)
    return parsed


def get_cached_game_content(session: Session, word: str) -> dict | None:
    """Read cached game content from game_cache for a word."""
    word_normalized = word.strip().lower()
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()
    if existing and existing.generation_status == "Completed":
        return _parse_cache(existing)
    return None


# ─── Internal helpers ─────────────────────────────────────────────────────────

def _parse_cache(cache: GameCache) -> dict | None:
    """Parse all 3 JSON fields from a GameCache row into a single dict."""
    try:
        result = {}
        if cache.context_clash_json:
            result["context_clash"] = json.loads(cache.context_clash_json)
        if cache.odd_one_out_json:
            result["odd_one_out"] = json.loads(cache.odd_one_out_json)
        if cache.true_or_bluff_json:
            result["true_or_bluff"] = json.loads(cache.true_or_bluff_json)
        return result if result else None
    except json.JSONDecodeError:
        return None


def _save_game_cache(session: Session, word: str, word_normalized: str, data: dict) -> None:
    """Upsert game_cache row with the 3 game payloads."""
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()

    clash_json = json.dumps(data.get("context_clash")) if data.get("context_clash") else None
    odd_json = json.dumps(data.get("odd_one_out")) if data.get("odd_one_out") else None
    bluff_json = json.dumps(data.get("true_or_bluff")) if data.get("true_or_bluff") else None

    if existing is not None:
        existing.context_clash_json = clash_json
        existing.odd_one_out_json = odd_json
        existing.true_or_bluff_json = bluff_json
        existing.generation_status = "Completed"
        existing.updated_at = datetime.now(timezone.utc)
    else:
        entry = GameCache(
            word=word.strip(),
            word_normalized=word_normalized,
            context_clash_json=clash_json,
            odd_one_out_json=odd_json,
            true_or_bluff_json=bluff_json,
            generation_status="Completed",
        )
        session.add(entry)
    session.commit()


def _mark_failed(session: Session, word_normalized: str) -> None:
    """Mark a game_cache entry as Failed so we don't keep retrying immediately."""
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()
    if existing is not None:
        existing.generation_status = "Failed"
        existing.updated_at = datetime.now(timezone.utc)
        session.commit()


# ─── Legacy endpoints (still used by /ai/define and /ai/generate-distractors) ─

def _llm_cache_key(kind: str, data: AiRequest) -> str:
    raw = f"{kind}:{data.word.strip().lower()}:{data.context_sentence or ''}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def get_cached_or_disabled(session: Session, kind: str, data: AiRequest) -> AiResponse:
    key = _llm_cache_key(kind, data)
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
