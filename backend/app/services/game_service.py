import logging
import random
import re
from uuid import UUID

from sqlmodel import Session, select

from app.models import Book, DictionaryEntry, Highlight, SrsItem
from app.schemas import GameAnswerCreate, GameDeckItemRead
from app.services import dictionary_service, srs_service

log = logging.getLogger("river_reader.games")


def get_deck(
    session: Session,
    user_id: UUID,
    *,
    game_type: str = "cloze",
    limit: int = 10,
) -> list[GameDeckItemRead]:
    log.info("Game deck request: type=%s  limit=%d  user=%s", game_type, limit, user_id)
    rows = _deck_rows(session, user_id, limit=limit)
    if not rows:
        log.info("  → no vault words available, returning empty deck")
        return []
    log.info("  → found %d vault words for deck", len(rows))
    if game_type == "meaning_match":
        return _meaning_match_deck(session, user_id, rows)
    if game_type == "context_clash":
        return _context_clash_deck(session, user_id, rows)
    if game_type == "odd_one_out":
        return _odd_one_out_deck(session, user_id, rows)
    if game_type == "true_or_bluff":
        return _true_or_bluff_deck(session, user_id, rows)
    return [
        _build_item(session, srs_item, highlight, game_type)
        for srs_item, highlight in rows
    ]


def answer_game(session: Session, data: GameAnswerCreate):
    return srs_service.grade_item(session, data.srs_item_id, data, user_id=data.user_id)


def _deck_rows(
    session: Session,
    user_id: UUID,
    *,
    limit: int,
) -> list[tuple[SrsItem, Highlight]]:
    due = srs_service.list_due_items(session, user_id, limit=limit)
    if due:
        return list(due)
    return _recent_items(session, user_id, limit=limit)


def _recent_items(
    session: Session,
    user_id: UUID,
    *,
    limit: int,
) -> list[tuple[SrsItem, Highlight]]:
    statement = (
        select(SrsItem, Highlight)
        .join(Highlight, SrsItem.highlight_id == Highlight.id)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
        )
        .order_by(Highlight.created_at.desc())
        .limit(limit)
    )
    return list(session.exec(statement).all())


def _meaning_match_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
) -> list[GameDeckItemRead]:
    """Build one match round: several words share the same shuffled definition list."""
    pairs: list[tuple[SrsItem, Highlight, str]] = []
    for srs_item, highlight in rows:
        dictionary_entry = dictionary_service.get_entry_sync(session, highlight.target_word)
        definition = dictionary_entry.definition if dictionary_entry else None
        meaning = (definition or (highlight.context_sentence or "").strip())
        if not meaning:
            continue
        pairs.append((srs_item, highlight, meaning))
    if not pairs:
        return []
    if len(pairs) == 1:
        srs_item, highlight, meaning = pairs[0]
        return [_meaning_match_single(session, user_id, srs_item, highlight, meaning)]
    shuffled_meanings = [p[2] for p in pairs]
    random.shuffle(shuffled_meanings)
    out: list[GameDeckItemRead] = []
    for srs_item, highlight, meaning in pairs:
        book = session.get(Book, highlight.book_id)
        dictionary_entry = dictionary_service.get_entry_sync(session, highlight.target_word)
        entry_def = dictionary_entry.definition if dictionary_entry else None
        out.append(
            GameDeckItemRead(
                game_type="meaning_match",
                highlight_id=highlight.id,
                srs_item_id=srs_item.id,
                target_word=highlight.target_word,
                prompt=highlight.target_word,
                choices=list(shuffled_meanings),
                correct_answer=meaning,
                definition=entry_def,
                book_title=book.title if book else None,
            )
        )
    return out


def _meaning_match_single(
    session: Session,
    user_id: UUID,
    srs_item: SrsItem,
    highlight: Highlight,
    meaning: str,
) -> GameDeckItemRead:
    book = session.get(Book, highlight.book_id)
    dictionary_entry = dictionary_service.get_entry_sync(session, highlight.target_word)
    entry_def = dictionary_entry.definition if dictionary_entry else None
    choices = _meaning_choices(session, user_id, highlight.target_word, meaning)
    return GameDeckItemRead(
        game_type="meaning_match",
        highlight_id=highlight.id,
        srs_item_id=srs_item.id,
        target_word=highlight.target_word,
        prompt=highlight.target_word,
        choices=choices,
        correct_answer=meaning,
        definition=entry_def,
        book_title=book.title if book else None,
    )


def _build_item(
    session: Session,
    srs_item: SrsItem,
    highlight: Highlight,
    game_type: str,
) -> GameDeckItemRead:
    book = session.get(Book, highlight.book_id)
    definition = None
    dictionary_entry = dictionary_service.get_entry_sync(session, highlight.target_word)
    if dictionary_entry is not None:
        definition = dictionary_entry.definition

    if game_type == "definition_reveal":
        choices = []
        prompt = highlight.context_sentence
        correct_answer = definition or highlight.target_word
    else:
        game_type = "cloze"
        game_sentence = _get_game_sentence(dictionary_entry, highlight)
        prompt = _blank_word(game_sentence, highlight.target_word)
        choices = _word_choices(session, highlight.user_id, highlight.target_word)
        correct_answer = highlight.target_word

    return GameDeckItemRead(
        game_type=game_type,
        highlight_id=highlight.id,
        srs_item_id=srs_item.id,
        target_word=highlight.target_word,
        prompt=prompt,
        choices=choices,
        correct_answer=correct_answer,
        definition=definition,
        book_title=book.title if book else None,
    )


def _get_game_sentence(dictionary_entry, highlight) -> str:
    """Return the sentence used in the cloze game.

    Priority:
    1. dictionary_entries.example_sentence  — a curated standalone sentence
    2. highlight.context_sentence           — fallback only (same sentence as in Vault)

    The example_sentence is intentionally different from context_sentence so the
    user is tested on knowing the word, not just remembering where they saw it.
    """
    if dictionary_entry is not None and dictionary_entry.example_sentence:
        return dictionary_entry.example_sentence
    return highlight.context_sentence


def _blank_word(sentence: str, target_word: str) -> str:
    return re.sub(re.escape(target_word), "_____", sentence, count=1, flags=re.IGNORECASE)


def _word_choices(session: Session, user_id: UUID, correct: str) -> list[str]:
    statement = (
        select(Highlight.target_word)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            Highlight.target_word != correct,
        )
        .order_by(Highlight.created_at.desc())
        .limit(3)
    )
    choices = [word for word in session.exec(statement).all()]
    choices.append(correct)
    return sorted(dict.fromkeys(choices), key=str.lower)


def _meaning_choices(
    session: Session,
    user_id: UUID,
    correct_word: str,
    correct_definition: str | None,
) -> list[str]:
    """Return the correct definition plus up to 3 distractor definitions.

    Distractors are pulled from other dictionary entries for words in the user's
    vault. Using definitions (not context sentences) keeps the game semantically
    clean and unambiguous.
    """
    from app.models import DictionaryEntry

    choices: list[str] = []
    if correct_definition:
        choices.append(correct_definition)

    other_words = session.exec(
        select(Highlight.target_word)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            Highlight.target_word != correct_word,
        )
        .limit(10)
    ).all()

    for word in other_words:
        if len(choices) >= 4:
            break
        word_normalized = word.lower().strip()
        entry = session.exec(
            select(DictionaryEntry).where(DictionaryEntry.word_normalized == word_normalized)
        ).first()
        if entry and entry.definition and entry.definition not in choices:
            choices.append(entry.definition)

    return sorted(dict.fromkeys(choices))


# ---------------------------------------------------------------------------
# Context Clash: pick the sentence that makes logical sense
# ---------------------------------------------------------------------------

def _context_clash_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
) -> list[GameDeckItemRead]:
    """Build context-clash items: one correct sentence vs one absurd sentence."""
    from app.services.ai_service import get_cached_game_content

    log.info("  Building context_clash deck…")
    items: list[GameDeckItemRead] = []
    all_vault_words = _all_vault_words(session, user_id)
    log.info("  → %d vault words available for clash generation", len(all_vault_words))

    for srs_item, highlight in rows:
        book = session.get(Book, highlight.book_id)
        dictionary_entry = dictionary_service.get_entry_sync(session, highlight.target_word)
        definition = dictionary_entry.definition if dictionary_entry else None

        # Try Groq cache first
        cached = get_cached_game_content(session, highlight.target_word)
        if cached and "context_clash" in cached:
            cc = cached["context_clash"]
            correct_sentence = cc.get("correct_sentence", "")
            clash_sentence = cc.get("clash_sentence", "")
            explanation = cc.get("explanation", "")
            if correct_sentence and clash_sentence:
                items.append(GameDeckItemRead(
                    game_type="context_clash",
                    highlight_id=highlight.id,
                    srs_item_id=srs_item.id,
                    target_word=highlight.target_word,
                    prompt="Tap the sentence that makes logical sense:",
                    choices=[],
                    correct_answer=correct_sentence,
                    definition=definition,
                    book_title=book.title if book else None,
                    correct_sentence=correct_sentence,
                    clash_sentence=clash_sentence,
                    explanation=explanation,
                ))
                continue

        # Fallback: generate without LLM
        correct_sentence = _get_game_sentence(dictionary_entry, highlight)
        if not correct_sentence:
            continue

        clash_sentence = _make_clash_sentence(correct_sentence, highlight.target_word, all_vault_words)
        if not clash_sentence or clash_sentence == correct_sentence:
            continue

        explanation = (
            f"'{highlight.target_word}' means {definition}."
            if definition
            else f"The first sentence uses '{highlight.target_word}' correctly in context."
        )

        items.append(GameDeckItemRead(
            game_type="context_clash",
            highlight_id=highlight.id,
            srs_item_id=srs_item.id,
            target_word=highlight.target_word,
            prompt="Tap the sentence that makes logical sense:",
            choices=[],
            correct_answer=correct_sentence,
            definition=definition,
            book_title=book.title if book else None,
            correct_sentence=correct_sentence,
            clash_sentence=clash_sentence,
            explanation=explanation,
        ))
    random.shuffle(items)
    log.info("  → context_clash: %d items generated", len(items))
    return items


def _make_clash_sentence(sentence: str, target_word: str, all_words: list[str]) -> str | None:
    """Create a clash sentence by replacing the target word with an unrelated vault word.

    The replacement word is chosen to be semantically different so the sentence
    becomes syntactically correct but contextually absurd.
    """
    candidates = [w for w in all_words if w.lower() != target_word.lower()]
    if not candidates:
        return None
    random.shuffle(candidates)
    for replacement in candidates:
        clash = re.sub(re.escape(target_word), replacement, sentence, count=1, flags=re.IGNORECASE)
        if clash != sentence:
            return clash
    return None


def _all_vault_words(session: Session, user_id: UUID) -> list[str]:
    """Return all non-deleted target words for a user (for clash / misfit generation)."""
    statement = (
        select(Highlight.target_word)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
        )
        .distinct()
    )
    return [w for w in session.exec(statement).all()]


# ---------------------------------------------------------------------------
# Odd One Out: 3 synonyms + 1 misfit word
# ---------------------------------------------------------------------------

def _odd_one_out_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
) -> list[GameDeckItemRead]:
    """Build odd-one-out items: find the word that doesn't belong."""
    from app.services.ai_service import get_cached_game_content

    log.info("  Building odd_one_out deck…")
    all_vault_words = _all_vault_words(session, user_id)
    items: list[GameDeckItemRead] = []

    for srs_item, highlight in rows:
        book = session.get(Book, highlight.book_id)
        dictionary_entry = dictionary_service.get_entry_sync(session, highlight.target_word)
        definition = dictionary_entry.definition if dictionary_entry else None

        # Try Groq cache first
        cached = get_cached_game_content(session, highlight.target_word)
        if cached and "odd_one_out" in cached:
            oo = cached["odd_one_out"]
            synonyms = oo.get("synonyms", [])
            misfit_word = oo.get("misfit_word", "")
            if synonyms and misfit_word and len(synonyms) >= 2:
                items.append(GameDeckItemRead(
                    game_type="odd_one_out",
                    highlight_id=highlight.id,
                    srs_item_id=srs_item.id,
                    target_word=highlight.target_word,
                    prompt="Which word does NOT belong with the others?",
                    choices=[],
                    correct_answer=misfit_word,
                    definition=definition,
                    book_title=book.title if book else None,
                    synonyms=synonyms[:3],
                    misfit_word=misfit_word,
                ))
                continue

        # Fallback: generate without LLM
        synonyms_raw: list[str] = []
        db_entry = _get_db_dictionary_entry(session, highlight.target_word)
        if db_entry and db_entry.synonyms_json:
            import json
            try:
                synonyms_raw = json.loads(db_entry.synonyms_json)
            except (json.JSONDecodeError, TypeError):
                synonyms_raw = []

        if len(synonyms_raw) < 2:
            if definition and len(definition.split()) >= 2:
                words = [w.strip('.,;:!?') for w in definition.split() if len(w) > 3]
                synonyms_raw = words[:3]
            if len(synonyms_raw) < 2:
                continue

        game_synonyms = synonyms_raw[:3]
        misfit = _pick_misfit_word(session, user_id, highlight.target_word, game_synonyms, all_vault_words)
        if not misfit:
            continue

        items.append(GameDeckItemRead(
            game_type="odd_one_out",
            highlight_id=highlight.id,
            srs_item_id=srs_item.id,
            target_word=highlight.target_word,
            prompt="Which word does NOT belong with the others?",
            choices=[],
            correct_answer=misfit,
            definition=definition,
            book_title=book.title if book else None,
            synonyms=game_synonyms,
            misfit_word=misfit,
        ))
    random.shuffle(items)
    log.info("  → odd_one_out: %d items generated", len(items))
    return items


def _get_db_dictionary_entry(session: Session, word: str) -> DictionaryEntry | None:
    """Get raw DB dictionary entry for synonyms_json access."""
    normalized = word.lower().strip()
    return session.exec(
        select(DictionaryEntry).where(DictionaryEntry.word_normalized == normalized)
    ).first()


def _pick_misfit_word(
    session: Session,
    user_id: UUID,
    target_word: str,
    synonyms: list[str],
    all_words: list[str],
) -> str | None:
    """Pick a word from the vault that is semantically different from the target."""
    synonyms_lower = {s.lower() for s in synonyms}
    synonyms_lower.add(target_word.lower())

    # Prefer vault words that are NOT synonyms
    candidates = [w for w in all_words if w.lower() not in synonyms_lower]
    if not candidates:
        return None

    # Try to pick a word that has its own dictionary entry (more meaningful)
    random.shuffle(candidates)
    for word in candidates[:5]:
        entry = _get_db_dictionary_entry(session, word)
        if entry and entry.definition:
            return word

    return candidates[0] if candidates else None


# ---------------------------------------------------------------------------
# True or Bluff: binary statement verification
# ---------------------------------------------------------------------------

def _true_or_bluff_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
) -> list[GameDeckItemRead]:
    """Build true-or-bluff items: is the statement correct?"""
    from app.services.ai_service import get_cached_game_content

    log.info("  Building true_or_bluff deck…")
    all_vault_words = _all_vault_words(session, user_id)
    items: list[GameDeckItemRead] = []

    for srs_item, highlight in rows:
        book = session.get(Book, highlight.book_id)
        dictionary_entry = dictionary_service.get_entry_sync(session, highlight.target_word)
        definition = dictionary_entry.definition if dictionary_entry else None
        if not definition:
            continue

        # Try Groq cache first
        cached = get_cached_game_content(session, highlight.target_word)
        if cached and "true_or_bluff" in cached:
            tb = cached["true_or_bluff"]
            statement = tb.get("statement", "")
            is_true = tb.get("is_true")
            if statement and is_true is not None:
                correct_answer = "TRUE" if is_true else "BLUFF"
                items.append(GameDeckItemRead(
                    game_type="true_or_bluff",
                    highlight_id=highlight.id,
                    srs_item_id=srs_item.id,
                    target_word=highlight.target_word,
                    prompt="Is this statement true or bluff?",
                    choices=["TRUE", "BLUFF"],
                    correct_answer=correct_answer,
                    definition=definition,
                    book_title=book.title if book else None,
                    statement=statement,
                    is_true=is_true,
                ))
                continue

        # Fallback: generate without LLM
        is_true = random.choice([True, False])

        if is_true:
            statement = f"'{highlight.target_word}' means {definition}."
        else:
            bluff_word = _pick_bluff_source(session, user_id, highlight.target_word, all_vault_words)
            if bluff_word:
                bluff_entry = dictionary_service.get_entry_sync(session, bluff_word)
                bluff_def = bluff_entry.definition if bluff_entry else None
                if bluff_def:
                    statement = f"'{highlight.target_word}' means {bluff_def}."
                else:
                    statement = f"'{highlight.target_word}' means {definition}."
                    is_true = True
            else:
                statement = f"'{highlight.target_word}' means {definition}."
                is_true = True

        correct_answer = "TRUE" if is_true else "BLUFF"

        items.append(GameDeckItemRead(
            game_type="true_or_bluff",
            highlight_id=highlight.id,
            srs_item_id=srs_item.id,
            target_word=highlight.target_word,
            prompt="Is this statement true or bluff?",
            choices=["TRUE", "BLUFF"],
            correct_answer=correct_answer,
            definition=definition,
            book_title=book.title if book else None,
            statement=statement,
            is_true=is_true,
        ))
    random.shuffle(items)
    log.info("  → true_or_bluff: %d items generated", len(items))
    return items


def _pick_bluff_source(
    session: Session,
    user_id: UUID,
    target_word: str,
    all_words: list[str],
) -> str | None:
    """Pick a word whose definition can be used as a bluff for the target word."""
    candidates = [w for w in all_words if w.lower() != target_word.lower()]
    if not candidates:
        return None
    random.shuffle(candidates)
    for word in candidates[:5]:
        entry = dictionary_service.get_entry_sync(session, word)
        if entry and entry.definition:
            return word
    return candidates[0] if candidates else None
