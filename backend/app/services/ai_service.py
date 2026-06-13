import hashlib
import json
import logging
import random
import re
from datetime import datetime, timezone
from uuid import UUID

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

Generate ALL game content in a single JSON response matching the exact structure below.

Constraints:
- Sentences must match the readability profile of a B1/B2 level English reader.
- Avoid academic, archaic, or esoteric terminology in definitions.
- Do NOT copy the context sentence from the book for any field.

"word_meaning": a concise B1/B2 definition of "{word}" (max 15 words). Used when no dictionary entry exists.

For "context_clash":
- "correct_sentence": a natural sentence that uses "{word}" correctly and makes logical sense.
- "clash_sentence": syntactically correct but contextually absurd because "{word}" is used in a way that contradicts its meaning.
- "explanation": explain WHY the correct sentence is right AND why the clash sentence is wrong.

For "odd_one_out":
- Provide 3 genuine synonyms of "{word}" and exactly 1 misfit word with no semantic overlap.
- Include a brief B1/B2 definition (max 12 words) for the misfit in "misfit_definition".
- "justification": explain why the misfit is NOT related to "{word}" and why the 3 synonyms ARE related. Compare meanings directly.

For "true_or_bluff":
- Provide BOTH a true statement and a bluff statement that use the exact word form "{word}" naturally in context — NOT dictionary definitions.
- Good bluff: "If an event is sporadic, it happens every single day."
- Good true: "A sporadic problem appears now and then, not on a fixed schedule."
- NEVER write "'{word}' means ..." or similar definition-style statements.
- "true_explanation": explain why the true statement uses "{word}" accurately.
- "bluff_explanation": explain why the bluff statement misuses "{word}".

For "cloze":
- "sentence": a fresh standalone sentence that uses the exact word form "{word}" correctly and grammatically in a new context (different from context_clash sentences).
- The sentence must already contain "{word}" exactly once as a complete word. Do not change tense, plurality, or form.
- If "{word}" is an inflected form, write a sentence where that exact form is grammatically required.
- Bad for "{word}" = "buzzed": "The crowd began to buzzed with excitement."
- Good for "{word}" = "buzzed": "The crowd buzzed with excitement after the winner was announced."

Your output must strictly be raw JSON matching this schema:
{{
  "word_meaning": "string",
  "context_clash": {{
    "correct_sentence": "string",
    "clash_sentence": "string",
    "explanation": "string"
  }},
  "odd_one_out": {{
    "synonyms": ["string", "string", "string"],
    "misfit_word": "string",
    "misfit_definition": "string",
    "justification": "string"
  }},
  "true_or_bluff": {{
    "true_statement": "string",
    "bluff_statement": "string",
    "true_explanation": "string",
    "bluff_explanation": "string"
  }},
  "cloze": {{
    "sentence": "string"
  }}
}}"""


def _cache_key(word: str, context: str | None) -> str:
    raw = f"groq_games:{word.strip().lower()}:{context or ''}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _is_definition_style_statement(statement: str, word: str) -> bool:
    """Detect legacy true_or_bluff payloads that only restate dictionary definitions."""
    lower = statement.lower().strip()
    normalized = word.strip().lower()
    if lower.startswith(f"'{normalized}' means") or lower.startswith(f'"{normalized}" means'):
        return True
    if lower.startswith(f"{normalized} means "):
        return True
    return False


def _text_contains_exact_word(text: str, word: str) -> bool:
    """Return True when text contains the target as a complete, exact word form."""
    target = word.strip()
    if not target:
        return False
    pattern = rf"(?<![A-Za-z]){re.escape(target)}(?![A-Za-z])"
    return re.search(pattern, text, flags=re.IGNORECASE) is not None


def _cloze_payload_valid(cloze: dict, word: str) -> bool:
    sentence = cloze.get("sentence", "").strip()
    if not sentence or not _text_contains_exact_word(sentence, word):
        return False

    target = word.strip()
    if not target:
        return False

    # Catch the most common LLM failure for inflected vault words:
    # "to buzzed", "to hesitated", etc.
    if target.lower().endswith("ed"):
        bad_infinitive = rf"\bto\s+{re.escape(target)}\b"
        if re.search(bad_infinitive, sentence, flags=re.IGNORECASE):
            return False

    return True


def _coerce_to_dict(value: object) -> dict | None:
    """Coerce an LLM response section into a dict.

    The LLM sometimes wraps the expected dict inside a single-element list,
    e.g. ``[{"statement": ..., "is_true": ...}]`` instead of the bare dict.
    This helper extracts the first dict from a list when that occurs.
    """
    if isinstance(value, dict):
        return value
    if isinstance(value, list) and len(value) > 0 and isinstance(value[0], dict):
        return value[0]
    return None


def _cache_needs_regeneration(cache: GameCache) -> bool:
    """Return True when cached content is missing fields or uses an outdated format."""
    if cache.generation_status != "Completed":
        return True
    parsed = _parse_cache(cache)
    if not parsed:
        return True
    required = ("context_clash", "odd_one_out", "true_or_bluff", "cloze")
    if any(key not in parsed for key in required):
        return True
    for key in required:
        if _coerce_to_dict(parsed[key]) is None:
            return True
    if not parsed.get("word_meaning", "").strip():
        return True
    oo = _coerce_to_dict(parsed.get("odd_one_out")) or {}
    if not oo.get("justification", "").strip():
        return True
    tb = _coerce_to_dict(parsed.get("true_or_bluff")) or {}
    if not _true_or_bluff_payload_valid(tb, cache.word):
        return True
    cloze = _coerce_to_dict(parsed.get("cloze")) or {}
    if not _cloze_payload_valid(cloze, cache.word):
        return True
    return False


def _true_or_bluff_payload_valid(tb: dict, word: str) -> bool:
    """Accept new dual-statement format or legacy single-statement format."""
    true_stmt = tb.get("true_statement", "").strip()
    bluff_stmt = tb.get("bluff_statement", "").strip()
    if true_stmt and bluff_stmt:
        has_side_explanations = bool(
            tb.get("true_explanation", "").strip()
            and tb.get("bluff_explanation", "").strip()
        )
        return has_side_explanations and not (
            _is_definition_style_statement(true_stmt, word)
            or _is_definition_style_statement(bluff_stmt, word)
            or not _text_contains_exact_word(true_stmt, word)
            or not _text_contains_exact_word(bluff_stmt, word)
        )
    statement = tb.get("statement", "").strip()
    is_true = tb.get("is_true")
    return (
        bool(statement)
        and is_true is not None
        and not _is_definition_style_statement(statement, word)
        and _text_contains_exact_word(statement, word)
    )


def resolve_word_meaning(session: Session, word: str, cached: dict | None) -> str | None:
    """Prefer dictionary definition; fall back to AI-generated concise meaning."""
    from app.services.dictionary_service import get_entry_sync

    entry = get_entry_sync(session, word)
    if entry and entry.definition:
        return entry.definition.strip()
    if cached:
        meaning = cached.get("word_meaning", "").strip()
        if meaning:
            return meaning
        cloze = _coerce_to_dict(cached.get("cloze")) or {}
        meaning = cloze.get("word_meaning", "").strip()
        if meaning:
            return meaning
    return None


def resolve_true_or_bluff(tb: dict) -> tuple[str, bool, str]:
    """Pick a random true/bluff variant from cached content."""
    true_stmt = tb.get("true_statement", "").strip()
    bluff_stmt = tb.get("bluff_statement", "").strip()
    if true_stmt and bluff_stmt:
        is_true = random.choice([True, False])
        if is_true:
            statement = true_stmt
            explanation = tb.get("true_explanation", "").strip() or tb.get("explanation", "").strip()
        else:
            statement = bluff_stmt
            explanation = tb.get("bluff_explanation", "").strip() or tb.get("explanation", "").strip()
            if explanation.lower().startswith(("the true statement", "true statement")):
                explanation = "This is a bluff because it uses the word in a way that does not match its meaning."
        return statement, is_true, explanation
    explanation = tb.get("explanation", "").strip()
    statement = tb.get("statement", "").strip()
    is_true = bool(tb.get("is_true", True))
    return statement, is_true, explanation


def resolve_odd_one_out_explanation(
    session: Session,
    *,
    target_word: str,
    misfit_word: str,
    selected_word: str | None,
    is_correct: bool,
    cached_oo: dict,
    choice_definitions: dict[str, str],
    target_definition: str | None,
) -> str:
    """Build odd-one-out feedback from AI justification or dictionary definitions."""
    justification = cached_oo.get("justification", "").strip()
    if justification:
        return justification

    misfit_def = choice_definitions.get(misfit_word) or _word_definition_from_dict(session, misfit_word)
    target_def = target_definition or _word_definition_from_dict(session, target_word)

    if is_correct:
        if target_def and misfit_def:
            return (
                f'"{misfit_word}" ({misfit_def}) is not related to '
                f'"{target_word}" ({target_def}).'
            )
        return f'"{misfit_word}" is not related to "{target_word}".'

    if selected_word:
        selected_def = choice_definitions.get(selected_word) or _word_definition_from_dict(
            session, selected_word
        )
        if selected_def and misfit_def:
            return (
                f'"{selected_word}" ({selected_def}) is related to "{target_word}". '
                f'The odd word was "{misfit_word}" ({misfit_def}).'
            )
        return (
            f'"{selected_word}" is related to "{target_word}". '
            f'The odd word was "{misfit_word}".'
        )

    if target_def and misfit_def:
        return f'The odd word was "{misfit_word}" ({misfit_def}) — {target_word}: {target_def}'
    return f'The odd word was "{misfit_word}".'


def _word_definition_from_dict(session: Session, word: str) -> str | None:
    from app.services.dictionary_service import get_entry_sync

    entry = get_entry_sync(session, word)
    return entry.definition.strip() if entry and entry.definition else None


def queue_replay_regeneration(
    session: Session,
    user_id: UUID,
    rows: list[tuple[str, str | None]],
    *,
    limit: int = 8,
) -> list[tuple[str, str | None]]:
    """Mark completed caches for regen when the vault has no new words since last generation."""
    from app.models import Highlight
    from sqlmodel import func, select

    if not rows:
        return []

    latest_highlight_at = session.exec(
        select(func.max(Highlight.created_at)).where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
        )
    ).one()
    if latest_highlight_at is None:
        return []

    candidates: list[tuple[datetime, str, str | None]] = []
    for word, context in rows:
        word_normalized = word.strip().lower()
        cached = session.exec(
            select(GameCache).where(GameCache.word_normalized == word_normalized)
        ).first()
        if (
            cached is None
            or cached.generation_status != "Completed"
            or latest_highlight_at > cached.updated_at
        ):
            continue
        candidates.append((cached.updated_at, word, context))

    if not candidates:
        return []

    candidates.sort(key=lambda item: item[0])
    queued: list[tuple[str, str | None]] = []
    for _, word, context in candidates[:limit]:
        word_normalized = word.strip().lower()
        cached = session.exec(
            select(GameCache).where(GameCache.word_normalized == word_normalized)
        ).first()
        if cached is None:
            continue
        cached.generation_status = "Pending"
        cached.updated_at = datetime.now(timezone.utc)
        session.add(cached)
        queued.append((word, context))

    if queued:
        session.commit()
        log.info(
            "Replay regen queued for user %s: %d words (no new highlights since cache)",
            user_id,
            len(queued),
        )
    return queued


# ─── Public API used by highlight creation ────────────────────────────────────

def generate_game_content(session: Session, word: str, context_sentence: str | None = None) -> dict | None:
    """Call Groq to generate all game payloads for a word. Cache in game_cache.

    Returns the parsed JSON dict or None on failure.
    """
    settings = get_settings()
    if not settings.ai_enabled or not settings.groq_api_key:
        log.info("AI disabled or no Groq key – skipping game generation for %r", word)
        return None

    word_normalized = word.strip().lower()

    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()
    if existing and existing.generation_status == "Completed" and not _cache_needs_regeneration(existing):
        log.info("Game cache hit for %r – skipping Groq call", word)
        return _parse_cache(existing)

    if existing is None:
        session.add(GameCache(word=word.strip(), word_normalized=word_normalized))
        session.commit()
    elif existing.generation_status == "Failed":
        existing.generation_status = "Pending"
        existing.updated_at = datetime.now(timezone.utc)
        session.add(existing)
        session.commit()

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
        "max_tokens": 1200,
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

    required_keys = ["word_meaning", "context_clash", "odd_one_out", "true_or_bluff", "cloze"]
    for key in required_keys:
        if key not in parsed:
            log.error("Groq response missing key %r for %r", key, word)
            _mark_failed(session, word_normalized)
            return None

    if not str(parsed.get("word_meaning", "")).strip():
        log.error("Groq response missing word_meaning for %r", word)
        _mark_failed(session, word_normalized)
        return None

    game_keys = ["context_clash", "odd_one_out", "true_or_bluff", "cloze"]
    for key in game_keys:
        coerced = _coerce_to_dict(parsed[key])
        if coerced is None:
            log.error("Groq response key %r for %r is %s and could not be coerced to dict", key, word, type(parsed[key]).__name__)
            _mark_failed(session, word_normalized)
            return None
        if coerced is not parsed[key]:
            log.warning("Groq response key %r for %r was %s, coerced to dict", key, word, type(parsed[key]).__name__)
        parsed[key] = coerced

    oo = parsed.get("odd_one_out", {})
    if not oo.get("justification", "").strip():
        log.error("Groq response missing odd_one_out.justification for %r", word)
        _mark_failed(session, word_normalized)
        return None

    tb = parsed.get("true_or_bluff", {})
    if not _true_or_bluff_payload_valid(tb, word):
        log.error("Groq returned invalid true_or_bluff for %r", word)
        _mark_failed(session, word_normalized)
        return None

    cloze = parsed.get("cloze", {})
    if not _cloze_payload_valid(cloze, word):
        log.error("Groq returned invalid cloze sentence for %r", word)
        _mark_failed(session, word_normalized)
        return None
    if cloze.get("word_meaning") is None:
        cloze["word_meaning"] = parsed.get("word_meaning", "")

    _save_game_cache(session, word, word_normalized, parsed)
    log.info("✓ Groq game content cached for %r", word)
    return parsed


def get_cached_game_content(session: Session, word: str) -> dict | None:
    """Read cached game content from game_cache for a word."""
    word_normalized = word.strip().lower()
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()
    if existing and existing.generation_status == "Completed" and not _cache_needs_regeneration(existing):
        return _parse_cache(existing)
    return None


def is_cache_complete(session: Session, word: str) -> bool:
    word_normalized = word.strip().lower()
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()
    return existing is not None and not _cache_needs_regeneration(existing)


# ─── Internal helpers ─────────────────────────────────────────────────────────

def _parse_cache(cache: GameCache) -> dict | None:
    """Parse all JSON fields from a GameCache row into a single dict."""
    try:
        result = {}
        if cache.context_clash_json:
            result["context_clash"] = json.loads(cache.context_clash_json)
        if cache.odd_one_out_json:
            result["odd_one_out"] = json.loads(cache.odd_one_out_json)
        if cache.true_or_bluff_json:
            result["true_or_bluff"] = json.loads(cache.true_or_bluff_json)
        if cache.cloze_json:
            cloze = json.loads(cache.cloze_json)
            result["cloze"] = cloze
            if cloze.get("word_meaning"):
                result["word_meaning"] = cloze["word_meaning"]
        if not result:
            return None
        for key in list(result):
            if key == "word_meaning":
                continue
            coerced = _coerce_to_dict(result[key])
            if coerced is not None:
                result[key] = coerced
        if "word_meaning" not in result:
            cloze = _coerce_to_dict(result.get("cloze")) or {}
            if cloze.get("word_meaning"):
                result["word_meaning"] = cloze["word_meaning"]
        return result
    except json.JSONDecodeError:
        return None


def _save_game_cache(session: Session, word: str, word_normalized: str, data: dict) -> None:
    """Upsert game_cache row with all game payloads."""
    existing = session.exec(
        select(GameCache).where(GameCache.word_normalized == word_normalized)
    ).first()

    clash_json = json.dumps(data.get("context_clash")) if data.get("context_clash") else None
    odd_json = json.dumps(data.get("odd_one_out")) if data.get("odd_one_out") else None
    bluff_json = json.dumps(data.get("true_or_bluff")) if data.get("true_or_bluff") else None
    cloze_payload = dict(data.get("cloze") or {})
    if data.get("word_meaning") and not cloze_payload.get("word_meaning"):
        cloze_payload["word_meaning"] = data["word_meaning"]
    cloze_json = json.dumps(cloze_payload) if cloze_payload else None

    if existing is not None:
        existing.context_clash_json = clash_json
        existing.odd_one_out_json = odd_json
        existing.true_or_bluff_json = bluff_json
        existing.cloze_json = cloze_json
        existing.generation_status = "Completed"
        existing.updated_at = datetime.now(timezone.utc)
    else:
        entry = GameCache(
            word=word.strip(),
            word_normalized=word_normalized,
            context_clash_json=clash_json,
            odd_one_out_json=odd_json,
            true_or_bluff_json=bluff_json,
            cloze_json=cloze_json,
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
