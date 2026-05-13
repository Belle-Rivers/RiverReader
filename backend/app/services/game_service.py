import re
from uuid import UUID

from sqlmodel import Session, select

from app.models import Book, Highlight, SrsItem
from app.schemas import GameAnswerCreate, GameDeckItemRead
from app.services import dictionary_service, srs_service


def get_deck(
    session: Session,
    user_id: UUID,
    *,
    game_type: str = "cloze",
    limit: int = 10,
) -> list[GameDeckItemRead]:
    due = srs_service.list_due_items(session, user_id, limit=limit)
    rows = due if due else _recent_items(session, user_id, limit=limit)
    return [
        _build_item(session, srs_item, highlight, game_type)
        for srs_item, highlight in rows
    ]


def answer_game(session: Session, data: GameAnswerCreate):
    return srs_service.grade_item(session, data.srs_item_id, data, user_id=data.user_id)


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


def _build_item(
    session: Session,
    srs_item: SrsItem,
    highlight: Highlight,
    game_type: str,
) -> GameDeckItemRead:
    book = session.get(Book, highlight.book_id)
    definition = None
    dictionary_entry = dictionary_service.get_entry(session, highlight.target_word)
    if dictionary_entry is not None:
        definition = dictionary_entry.definition

    if game_type == "meaning_match":
        choices = _meaning_choices(session, highlight.user_id, highlight.target_word, definition)
        prompt = highlight.target_word
        correct_answer = definition or highlight.context_sentence
    elif game_type == "definition_reveal":
        choices = []
        prompt = highlight.context_sentence
        correct_answer = definition or highlight.target_word
    else:
        # cloze: use the dictionary example_sentence as the game sentence.
        # This is intentionally a DIFFERENT sentence from the captured context_sentence.
        # The context_sentence is only shown in the Vault for reference.
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
    # Fallback: use captured sentence. Frontend can show a note that this is
    # the original sentence until an example_sentence is available.
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

    # Pull other vault words and look up their definitions as distractors
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
