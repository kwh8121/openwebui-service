"""Regression tests for background_tasks_handler context handling (#47).

`main.py` builds a title-only context (no `model`, no `assistant_message`) and
hands it to `background_tasks_handler` at chat creation, before any assistant
turn exists. The handler's memory review step runs "after a turn", so it must
not read `ctx['model']` for a context that has no completed turn.
"""

import asyncio

import pytest

from open_webui.constants import TASKS
from open_webui.utils import middleware
from open_webui.utils.chat_id import NON_SAVED_CHAT_ID_PREFIXES


def _form_data():
    return {
        'model': 'test-model',
        'messages': [{'role': 'user', 'content': 'hello'}],
    }


def _title_only_ctx():
    """Same keys as `title_ctx` in main.py (no `model`, no `assistant_message`)."""

    async def event_emitter(_event):
        return None

    return {
        'request': object(),
        'form_data': _form_data(),
        'user': object(),
        'metadata': {'chat_id': NON_SAVED_CHAT_ID_PREFIXES[0] + 'regression-47', 'message_id': 'm1'},
        'tasks': {TASKS.TITLE_GENERATION: False},
        'event_emitter': event_emitter,
    }


@pytest.fixture
def review_calls(monkeypatch):
    calls = []

    async def fake_review(**kwargs):
        calls.append(kwargs)

    monkeypatch.setattr(middleware, 'review_memory_after_turn', fake_review)
    return calls


def test_title_only_context_does_not_raise_or_review_memory(review_calls):
    asyncio.run(middleware.background_tasks_handler(_title_only_ctx()))

    assert review_calls == []


def test_completed_turn_context_reviews_memory_with_model(review_calls):
    ctx = _title_only_ctx()
    model = {'id': 'test-model'}
    assistant_message = {'content': 'hi there'}
    ctx['model'] = model
    ctx['assistant_message'] = assistant_message

    asyncio.run(middleware.background_tasks_handler(ctx))

    assert len(review_calls) == 1
    assert review_calls[0]['model'] is model
    assert review_calls[0]['assistant_message'] is assistant_message


def test_completed_turn_context_without_model_still_fails_loudly(review_calls):
    ctx = _title_only_ctx()
    ctx['assistant_message'] = {'content': 'hi there'}

    with pytest.raises(KeyError):
        asyncio.run(middleware.background_tasks_handler(ctx))

    assert review_calls == []
