from __future__ import annotations

from importlib import metadata

import pytest

from cscmake.devtools import third_party_licences
from cscmake.devtools.third_party_licences import licence_text, third_party_licences_markdown


def test_every_package_of_the_documentation_has_its_licence_text() -> None:
    markdown = third_party_licences_markdown()

    for name, _ in third_party_licences.DOCUMENTATION_PACKAGES:
        assert f"### {name} " in markdown
    assert "### Snowball" in markdown
    assert "Copyright (c) 2020 Pradyun Gedam" in markdown  # Furo
    assert "by the Sphinx team" in markdown
    assert markdown.count("```text\n") == markdown.count("\n```\n") == 5


def test_a_distribution_without_licence_file_fails(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(metadata, "files", lambda distribution: [])

    with pytest.raises(LookupError, match="no licence file in the installed distribution furo"):
        licence_text("furo")
