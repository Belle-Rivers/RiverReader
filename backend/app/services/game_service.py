import logging
import random
import re
from uuid import UUID

from sqlmodel import Session, select

from app.models import Book, Highlight, SrsItem
from app.schemas import GameAnswerCreate, GameDeckItemRead, GameDecksRead
from app.services import srs_service

log = logging.getLogger("river_reader.games")

_AI_GAME_TYPES = frozenset({"cloze", "context_clash", "odd_one_out", "true_or_bluff"})


def get_deck(
    session: Session,
    user_id: UUID,
    *,
    game_type: str = "cloze",
    limit: int = 10,
) -> list[GameDeckItemRead]:
    log.info("Game deck request: type=%s  limit=%d  user=%s", game_type, limit, user_id)
    decks = get_all_decks(session, user_id, limit=limit)
    return getattr(decks, game_type if game_type != "definition_reveal" else "cloze", [])


def get_all_decks(
    session: Session,
    user_id: UUID,
    *,
    limit: int = 10,
) -> GameDecksRead:
    """Build every game deck in one pass (single DB round-trip, shared AI cache reads)."""
    log.info("Game decks request: limit=%d  user=%s", limit, user_id)
    row_limit = min(limit * 5, 50)
    rows = _deck_rows(session, user_id, limit=row_limit)
    if not rows:
        log.info("  → no vault words available")
        return GameDecksRead()

    log.info("  → found %d vault words for decks", len(rows))
    return GameDecksRead(
        cloze=_cloze_deck(session, user_id, rows, limit=limit),
        meaning_match=_meaning_match_deck(session, user_id, rows, limit=limit),
        context_clash=_context_clash_deck(session, user_id, rows, limit=limit),
        odd_one_out=_odd_one_out_deck(session, user_id, rows, limit=limit),
        true_or_bluff=_true_or_bluff_deck(session, user_id, rows, limit=limit),
    )


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
    from sqlmodel import func
    statement = (
        select(SrsItem, Highlight)
        .join(Highlight, SrsItem.highlight_id == Highlight.id)
        .join(Book, Highlight.book_id == Book.id)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            Book.is_deleted == False,  # noqa: E712
        )
        .order_by(func.random())
        .limit(limit)
    )
    return list(session.exec(statement).all())


def _word_definition(session: Session, word: str, cached: dict | None = None) -> str | None:
    from app.services.ai_service import resolve_word_meaning

    return resolve_word_meaning(session, word, cached)


def _meaning_match_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
    *,
    limit: int,
) -> list[GameDeckItemRead]:
    """Build one match round from the first vault rows with usable meanings."""
    from app.services.ai_service import get_cached_game_content

    pairs: list[tuple[SrsItem, Highlight, str]] = []
    for srs_item, highlight in rows:
        if len(pairs) >= limit:
            break

        cached = get_cached_game_content(session, highlight.target_word)
        definition = _word_definition(session, highlight.target_word, cached)
        if not definition:
            continue
        pairs.append((srs_item, highlight, definition.strip()))
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
        entry_def = meaning
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
    entry_def = _word_definition(session, highlight.target_word)
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


def _meaning_choices(
    session: Session,
    user_id: UUID,
    correct_word: str,
    correct_definition: str | None,
) -> list[str]:
    from app.models import DictionaryEntry
    from sqlmodel import func

    choices: list[str] = []
    if correct_definition:
        choices.append(correct_definition)

    other_words = session.exec(
        select(Highlight.target_word)
        .join(Book, Highlight.book_id == Book.id)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            Book.is_deleted == False,  # noqa: E712
            Highlight.target_word != correct_word,
        )
        .order_by(func.random())
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


def _blank_word(sentence: str, target_word: str) -> str:
    return re.sub(re.escape(target_word), "_____", sentence, count=1, flags=re.IGNORECASE)


def _word_choices(session: Session, user_id: UUID, correct: str) -> list[str]:
    from sqlmodel import func
    statement = (
        select(Highlight.target_word)
        .join(Book, Highlight.book_id == Book.id)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
            Book.is_deleted == False,  # noqa: E712
            Highlight.target_word != correct,
        )
        .order_by(func.random())
        .limit(3)
    )
    choices = [word for word in session.exec(statement).all()]
    choices.append(correct)
    return sorted(dict.fromkeys(choices), key=str.lower)


# ---------------------------------------------------------------------------
# Cloze: fill in the blank using an AI-generated sentence
# ---------------------------------------------------------------------------

def _cloze_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
    *,
    limit: int,
) -> list[GameDeckItemRead]:
    from app.services.ai_service import get_cached_game_content

    log.info("  Building cloze deck…")
    items: list[GameDeckItemRead] = []

    for srs_item, highlight in rows:
        if len(items) >= limit:
            break

        cached = get_cached_game_content(session, highlight.target_word)
        if not cached or "cloze" not in cached:
            log.debug("  → skipping %r (AI cache not ready)", highlight.target_word)
            continue

        sentence = cached["cloze"].get("sentence", "")
        if not sentence:
            continue

        book = session.get(Book, highlight.book_id)
        definition = _word_definition(session, highlight.target_word, cached)
        prompt = _blank_word(sentence, highlight.target_word)
        if "_____" not in prompt:
            continue

        items.append(GameDeckItemRead(
            game_type="cloze",
            highlight_id=highlight.id,
            srs_item_id=srs_item.id,
            target_word=highlight.target_word,
            prompt=prompt,
            choices=_word_choices(session, user_id, highlight.target_word),
            correct_answer=highlight.target_word,
            definition=definition,
            book_title=book.title if book else None,
        ))

    random.shuffle(items)
    log.info("  → cloze: %d items ready (AI cache)", len(items))
    return items


# ---------------------------------------------------------------------------
# Context Clash: pick the sentence that makes logical sense
# ---------------------------------------------------------------------------

def _context_clash_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
    *,
    limit: int,
) -> list[GameDeckItemRead]:
    from app.services.ai_service import get_cached_game_content

    log.info("  Building context_clash deck…")
    items: list[GameDeckItemRead] = []

    for srs_item, highlight in rows:
        if len(items) >= limit:
            break

        cached = get_cached_game_content(session, highlight.target_word)
        if not cached or "context_clash" not in cached:
            log.debug("  → skipping %r (AI cache not ready)", highlight.target_word)
            continue

        cc = cached["context_clash"]
        correct_sentence = cc.get("correct_sentence", "")
        clash_sentence = cc.get("clash_sentence", "")
        explanation = cc.get("explanation", "")
        if not correct_sentence or not clash_sentence:
            continue

        book = session.get(Book, highlight.book_id)
        definition = _word_definition(session, highlight.target_word, cached)

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
    log.info("  → context_clash: %d items ready (AI cache)", len(items))
    return items


# ---------------------------------------------------------------------------
# Odd One Out: 3 synonyms + 1 misfit word
# ---------------------------------------------------------------------------

def _odd_one_out_choice_definitions(
    session: Session,
    synonyms: list[str],
    misfit_word: str,
    misfit_definition: str | None,
) -> dict[str, str]:
    defs: dict[str, str] = {}
    for word in synonyms:
        definition = _word_definition(session, word)
        if definition:
            defs[word] = definition
    if misfit_definition:
        defs[misfit_word] = misfit_definition
    elif misfit_word not in defs:
        definition = _word_definition(session, misfit_word)
        if definition:
            defs[misfit_word] = definition
    return defs


def _odd_one_out_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
    *,
    limit: int,
) -> list[GameDeckItemRead]:
    from app.services.ai_service import get_cached_game_content

    log.info("  Building odd_one_out deck…")
    items: list[GameDeckItemRead] = []

    for srs_item, highlight in rows:
        if len(items) >= limit:
            break

        cached = get_cached_game_content(session, highlight.target_word)
        if not cached or "odd_one_out" not in cached:
            log.debug("  → skipping %r (AI cache not ready)", highlight.target_word)
            continue

        oo = cached["odd_one_out"]
        synonyms = oo.get("synonyms", [])
        misfit_word = oo.get("misfit_word", "")
        misfit_definition = oo.get("misfit_definition")
        if not synonyms or not misfit_word or len(synonyms) < 2:
            continue

        book = session.get(Book, highlight.book_id)
        definition = _word_definition(session, highlight.target_word, cached)
        choice_defs = _odd_one_out_choice_definitions(
            session, synonyms[:3], misfit_word, misfit_definition
        )
        justification = oo.get("justification", "").strip()
        explanation = justification or _odd_one_out_fallback_explanation(
            session,
            target_word=highlight.target_word,
            misfit_word=misfit_word,
            target_definition=definition,
            choice_definitions=choice_defs,
        )

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
            choice_definitions=choice_defs,
            explanation=explanation,
        ))

    random.shuffle(items)
    log.info("  → odd_one_out: %d items ready (AI cache)", len(items))
    return items


def _odd_one_out_fallback_explanation(
    session: Session,
    *,
    target_word: str,
    misfit_word: str,
    target_definition: str | None,
    choice_definitions: dict[str, str],
) -> str:
    from app.services.ai_service import resolve_odd_one_out_explanation

    return resolve_odd_one_out_explanation(
        session,
        target_word=target_word,
        misfit_word=misfit_word,
        selected_word=None,
        is_correct=True,
        cached_oo={},
        choice_definitions=choice_definitions,
        target_definition=target_definition,
    )


# ---------------------------------------------------------------------------
# True or Bluff: binary statement verification
# ---------------------------------------------------------------------------

def _true_or_bluff_deck(
    session: Session,
    user_id: UUID,
    rows: list[tuple[SrsItem, Highlight]],
    *,
    limit: int,
) -> list[GameDeckItemRead]:
    from app.services.ai_service import get_cached_game_content, resolve_true_or_bluff

    log.info("  Building true_or_bluff deck…")
    items: list[GameDeckItemRead] = []

    for srs_item, highlight in rows:
        if len(items) >= limit:
            break

        cached = get_cached_game_content(session, highlight.target_word)
        if not cached or "true_or_bluff" not in cached:
            log.debug("  → skipping %r (AI cache not ready)", highlight.target_word)
            continue

        tb = cached["true_or_bluff"]
        statement, is_true, explanation = resolve_true_or_bluff(tb)
        if not statement:
            continue

        book = session.get(Book, highlight.book_id)
        definition = _word_definition(session, highlight.target_word, cached)
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
            explanation=explanation or None,
        ))

    random.shuffle(items)
    log.info("  → true_or_bluff: %d items ready (AI cache)", len(items))
    return items
