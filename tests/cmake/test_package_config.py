"""The generated <namespace>Config.cmake, used through find_package by consumer projects."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure, install

pytestmark = pytest.mark.requires("cmake", "ninja")

# package A: component core
PACKAGE_A = """
project(A VERSION 1.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE A CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(a_core INTERFACE)
cs_install_target(a_core core DEFAULT)
cs_finalize_target(a_core)
cs_finalize_project()
"""
# package B: component x needs package A (find_dependency), component core depends on component b_base of B.
# A also has a component named core.
PACKAGE_B = """
project(B VERSION 1.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE B CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(b_x INTERFACE)
cs_find_package(b_x PUBLIC A COMPONENTS core REQUIRED CONFIG)
cs_install_target(b_x x)
cs_finalize_target(b_x)
cs_add_library(b_base INTERFACE)
cs_install_target(b_base b_base)
cs_finalize_target(b_base)
cs_add_library(b_core INTERFACE)
cs_target_link_libraries(b_core INTERFACE b_base)
cs_install_target(b_core core)
cs_finalize_target(b_core)
cs_finalize_project()
"""


@pytest.fixture
def prefix(tmp_path: Path) -> Path:
    """Install folder with the packages A and B."""
    prefix = tmp_path / "install"
    for name, body in (("A", PACKAGE_A), ("B", PACKAGE_B)):
        result = install(
            tmp_path / name,
            body,
            prefix,
        )
        assert result.returncode == 0, result.output
    return prefix


def consume(tmp_path: Path, prefix: Path, body: str):  # type: ignore[no-untyped-def]
    return configure(tmp_path / "consumer", body, args=[f"-DCMAKE_PREFIX_PATH={prefix.as_posix()}"])


def test_components_with_the_same_name_in_two_packages(tmp_path: Path, prefix: Path) -> None:
    """B::core still gets its dependency b_base when loading component x of B finds A (which has a core too)."""
    body = """
find_package(B COMPONENTS x core REQUIRED CONFIG)
add_library(consumer INTERFACE)
target_link_libraries(consumer INTERFACE B::b_core)
if(TARGET B::b_base)
  cstest_report(b_base found)
endif()
"""
    result = consume(tmp_path, prefix, body)

    assert result.returncode == 0, result.output
    assert result.reports.get("b_base") == "found"


def test_no_variable_leaks_into_the_consumer(tmp_path: Path, prefix: Path) -> None:
    body = """
get_cmake_property(before VARIABLES)
find_package(B COMPONENTS x core REQUIRED CONFIG)
get_cmake_property(after VARIABLES)
list(REMOVE_ITEM after ${before} before)
list(FILTER after EXCLUDE REGEX "^(A|B)(_|Config_|$)")
list(FILTER after EXCLUDE REGEX "^(CMAKE_|_CMAKE_|FIND_PACKAGE_MESSAGE_DETAILS_)")
cstest_report(leaked "${after}")
"""
    result = consume(tmp_path, prefix, body)

    assert result.returncode == 0, result.output
    assert result.report_list("leaked") == []


def test_unknown_optional_component(tmp_path: Path, prefix: Path) -> None:
    body = """
find_package(A COMPONENTS core OPTIONAL_COMPONENTS nope REQUIRED CONFIG)
cstest_report(found "${A_FOUND}")
cstest_report(core "${A_core_FOUND}")
cstest_report(nope "${A_nope_FOUND}")
"""
    result = consume(tmp_path, prefix, body)

    assert result.returncode == 0, result.output
    assert result.reports["found"] in ("1", "TRUE", "ON")
    assert result.reports["core"] in ("1", "TRUE", "ON")
    assert result.reports["nope"] in ("0", "FALSE", "OFF")


def test_unknown_component_not_required(tmp_path: Path, prefix: Path) -> None:
    result = consume(tmp_path, prefix, 'find_package(A COMPONENTS nope CONFIG)\ncstest_report(found "${A_FOUND}")\n')

    assert result.returncode == 0, result.output
    assert result.reports["found"] in ("0", "FALSE", "OFF")


def test_unknown_component_required(tmp_path: Path, prefix: Path) -> None:
    result = consume(tmp_path, prefix, "find_package(A COMPONENTS nope REQUIRED CONFIG)\n")

    assert result.returncode != 0
    assert "unknown component nope, available: cscmake_common, core" in " ".join(result.output.split())


def test_base_dir_is_the_install_prefix(tmp_path: Path, prefix: Path) -> None:
    result = consume(tmp_path, prefix, 'find_package(A REQUIRED CONFIG)\ncstest_report(base "${A_BASE_DIR}")\n')

    assert result.returncode == 0, result.output
    assert Path(result.reports["base"]).resolve() == prefix.resolve()


def test_cyclic_dependency_between_components(tmp_path: Path) -> None:
    """The targets do not form a cycle (ta -> tb -> tc), their components do (a -> b -> a)."""
    body = """
project(C VERSION 1.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE C CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(tc INTERFACE)
cs_install_target(tc a)
cs_finalize_target(tc)
cs_add_library(tb INTERFACE)
cs_target_link_libraries(tb INTERFACE tc)
cs_install_target(tb b)
cs_finalize_target(tb)
cs_add_library(ta INTERFACE)
cs_target_link_libraries(ta INTERFACE tb)
cs_install_target(ta a)
cs_finalize_target(ta)
cs_finalize_project()
"""
    result = configure(tmp_path, body)

    assert result.returncode != 0
    message = " ".join(result.output.split())  # CMake wraps the message over several lines
    assert "[cs_finalize_project] cyclic dependency between the components: a -> b -> a" in message


@pytest.mark.parametrize("debug", [False, True], ids=["default", "debug-on"])
def test_the_debug_option_of_a_package_adds_no_cache_entry(tmp_path: Path, prefix: Path, debug: bool) -> None:
    body = """
find_package(B COMPONENTS core REQUIRED CONFIG)
get_property(cached CACHE B_DEBUG PROPERTY TYPE SET)
cstest_report(cached "${cached}")
"""
    args = [f"-DCMAKE_PREFIX_PATH={prefix.as_posix()}"]
    if debug:
        body = "set(B_DEBUG ON)\n" + body

    result = configure(tmp_path / "consumer", body, args=args)

    assert result.returncode == 0, result.output
    assert result.reports["cached"] == "0"
    assert ("[BConfig] entry point" in result.output) == debug


def test_many_paths_between_components_are_checked_once(tmp_path: Path) -> None:
    """24 components, each depending on the next two: about 75 000 paths, each component checked once."""
    count = 24
    lines = [
        "project(C VERSION 1.0.0 LANGUAGES NONE)",
        "cs_initialize_project(NAMESPACE C CXX_STANDARD 17 DEFAULT_CONFIG Debug)",
    ]
    for index in range(count, -1, -1):
        lines.append(f"cs_add_library(t{index} INTERFACE)")
        for dependency in (index + 1, index + 2):
            if dependency <= count:
                lines.append(f"cs_target_link_libraries(t{index} INTERFACE t{dependency})")
        lines += [f"cs_install_target(t{index} c{index})", f"cs_finalize_target(t{index})"]
    lines.append("cs_finalize_project()")

    result = configure(tmp_path, "\n".join(lines) + "\n", timeout=60)

    assert result.returncode == 0, result.output


def test_a_wrong_find_package_mode_fails_before_the_search(tmp_path: Path) -> None:
    """The mode is checked first: the error names it, not the package that does not exist."""
    body = """
project(C VERSION 1.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE C CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_library(lib INTERFACE)
cs_find_package(lib PUBLIK NotAPackage REQUIRED)
"""
    result = configure(tmp_path, body)

    assert result.returncode != 0
    assert "[cs_find_package] lib: the mode is PUBLIC or PRIVATE, got PUBLIK" in " ".join(result.output.split())
    assert "NotAPackage" not in result.output


VERSIONED = """
project(V VERSION 2.0.0 LANGUAGES NONE)
cs_initialize_project(NAMESPACE V CXX_STANDARD 17 DEFAULT_CONFIG Debug{compatibility})
cs_add_library(v_core INTERFACE)
cs_install_target(v_core core DEFAULT)
cs_finalize_target(v_core)
cs_finalize_project()
"""


@pytest.mark.parametrize(
    ("compatibility", "accepted"),
    [
        ("", {"1.0": False, "2.0": True, "2.0.0": True, "2.5": False}),
        (" VERSION_COMPATIBILITY AnyNewerVersion", {"1.0": True, "2.0": True, "2.0.0": True, "2.5": False}),
        (" VERSION_COMPATIBILITY ExactVersion", {"1.0": False, "2.0": False, "2.0.0": True, "2.5": False}),
    ],
    ids=["default-same-major", "any-newer", "exact"],
)
def test_version_compatibility(tmp_path: Path, compatibility: str, accepted: dict[str, bool]) -> None:
    """Package version 2.0.0: which find_package(V <version>) requests accept it."""
    prefix = tmp_path / "install"
    result = install(tmp_path / "package", VERSIONED.format(compatibility=compatibility), prefix)
    assert result.returncode == 0, result.output

    consumer = "".join(
        f'find_package(V {version} QUIET CONFIG)\ncstest_report("{version}" "${{V_FOUND}}")\nunset(V_FOUND)\n'
        "unset(V_DIR CACHE)\n"
        for version in accepted
    )
    found = configure(tmp_path / "consumer", consumer, args=[f"-DCMAKE_PREFIX_PATH={prefix.as_posix()}"])

    assert found.returncode == 0, found.output
    assert {version: found.reports[version] == "1" for version in accepted} == accepted


def test_an_unknown_version_compatibility_is_rejected(tmp_path: Path) -> None:
    result = configure(tmp_path, VERSIONED.format(compatibility=" VERSION_COMPATIBILITY Any"))

    assert result.returncode != 0
    assert "VERSION_COMPATIBILITY is AnyNewerVersion, SameMajorVersion, SameMinorVersion or ExactVersion, got Any" in (
        " ".join(result.output.split())
    )
