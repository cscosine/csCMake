import pytest

from cscmake.presets.render import validate_substitutions


def test_validate_substitutions() -> None:
    with pytest.raises(ValueError):
        validate_substitutions({})
