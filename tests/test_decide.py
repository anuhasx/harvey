"""decide_next_action: the deterministic priority ladder, and lead-list mode."""

import pytest

from harvey.config import HarveyConfig
from harvey.main import decide_next_action

BASE = {
    "persona": {"name": "H", "company": "A", "role": "B", "email": "e", "linkedin": "", "tone": "t"},
    "product": {"name": "P", "description": "D", "pricing": "$1", "key_benefits": [],
                "objection_responses": {}},
    "icp": {"industries": [], "company_size": "", "titles": [], "geography": []},
}


def _config(email_enabled: bool) -> HarveyConfig:
    return HarveyConfig(**BASE, channels={"email": {"enabled": email_enabled, "provider": "smtp"}})


def _summary(new=0, drafts=0, convos=0):
    return {"prospects": {"new": new}, "draft_campaigns": drafts, "open_conversations": convos}


@pytest.mark.asyncio
@pytest.mark.parametrize("summary, expected", [
    (_summary(convos=1, drafts=1, new=5), "handle_replies"),
    (_summary(drafts=1, new=5), "send_campaign"),
    (_summary(new=5), "write_campaign"),
    (_summary(), "prospect"),
])
async def test_priority_ladder_with_email_on(summary, expected):
    assert await decide_next_action(None, None, _config(True), summary=summary) == expected


@pytest.mark.asyncio
@pytest.mark.parametrize("summary", [
    _summary(new=5),               # would be write_campaign with email on
    _summary(drafts=2, new=50),    # would pin on send_campaign forever
    _summary(),                    # empty pipeline
])
async def test_email_off_always_prospects(summary):
    assert await decide_next_action(None, None, _config(False), summary=summary) == "prospect"


def test_scout_rotation_walks_every_item():
    from harvey.agents.scout import ROTATE_SECONDS, _rotate

    items = ["a", "b", "c", "d", "e"]
    seen = set()
    for tick in range(5):
        picked = _rotate(items, 2, now=tick * ROTATE_SECONDS)
        assert len(picked) == 2
        seen.update(picked)
    assert seen == set(items)
    assert _rotate([], 2) == []
    assert _rotate(["only"], 2) == ["only"]
