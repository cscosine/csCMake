from cscmake.utils.supported_variants import (
    GeneratorType,
    get_supported_context_os_architecture_list,
    get_supported_context_os_architecture_list_string,
)


def test_get_supported_context_os_architecture_list():
    supported_list = get_supported_context_os_architecture_list()
    n_all = len(supported_list)
    assert n_all > 0

    supported_list = get_supported_context_os_architecture_list(GeneratorType.SINGLE_CONFIG)
    n_single = len(supported_list)

    assert n_single > 0
    assert n_single < n_all

    supported_list = get_supported_context_os_architecture_list(GeneratorType.MULTI_CONFIG)
    n_multi = len(supported_list)

    assert n_multi > 0
    assert n_multi < n_all

    supported_list = get_supported_context_os_architecture_list("INVALID")  # type: ignore
    n_invalid = len(supported_list)
    assert n_invalid == 0


def test_get_supported_context_os_architecture_list_string():
    supported_list = get_supported_context_os_architecture_list_string()
    n_all = len(supported_list)
    assert n_all > 0

    supported_list = get_supported_context_os_architecture_list_string(GeneratorType.SINGLE_CONFIG)
    n_single = len(supported_list)

    assert n_single > 0
    assert n_single < n_all

    supported_list = get_supported_context_os_architecture_list_string(GeneratorType.MULTI_CONFIG)
    n_multi = len(supported_list)

    assert n_multi > 0
    assert n_multi < n_all

    supported_list = get_supported_context_os_architecture_list_string("INVALID")  # type: ignore
    n_invalid = len(supported_list)
    assert n_invalid == 0
