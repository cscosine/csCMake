import pytest

from cscmake.utils.generate_cs_preset_variants import validate_substitutions


def test_validate_substitutions() -> None:
    with pytest.raises(ValueError):
        validate_substitutions({})
