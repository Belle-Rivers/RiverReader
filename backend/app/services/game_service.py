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
        game_type = "cloze"
        prompt = _blank_word(highlight.context_sentence, highlight.target_word)
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
    choices = []
    if correct_definition:
        choices.append(correct_definition)
    entries = session.exec(
        select(Highlight.context_sentence)
        .where(
            Highlight.user_id == user_id,
            Highlight.is_deleted == False,  # noqa: E712
        )
        .limit(3)
    ).all()
    choices.extend(sentence for sentence in entries if correct_word.lower() not in sentence.lower())
    return sorted(dict.fromkeys(choices))
