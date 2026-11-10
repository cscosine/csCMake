"""Dependencies of the targets, resolved by cs_finalize_project (csTargetDependencies.cmake)."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

INIT = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"
# app -> alias of mid -> base (private link of a static library: $<LINK_ONLY:base> in its interface); app also links an
# imported library and a plain name
APP = """
cs_add_library(app INTERFACE)
cs_target_link_libraries(app INTERFACE cstest::mid ext m)
cs_finalize_target(app)
"""
DEPENDENCIES = """
add_library(ext SHARED IMPORTED)
set_target_properties(ext PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/libext.so)
cs_add_library(base INTERFACE)
cs_finalize_target(base)
cs_add_library(mid STATIC mid.cpp)
cs_add_library(cstest::mid ALIAS mid)
cs_target_link_libraries(mid PRIVATE base)
cs_finalize_target(mid)
"""
REPORT = """
cs_finalize_project()
cs_get_target_project_dependencies(app deps)
cstest_report(app "${deps}")
cs_get_target_project_dependencies(base deps)
cstest_report(base "${deps}")
"""


@pytest.mark.parametrize("app_first", [False, True], ids=["deps-first", "app-first"])
def test_project_dependencies_are_the_targets_of_the_build_linked_directly_or_not(
    tmp_path: Path, app_first: bool
) -> None:
    """Aliases resolved, $<LINK_ONLY:...> followed, imported targets and plain names left out; also when app is
    finalized before the targets it links exist."""
    body = "enable_language(CXX)\n" + INIT + (APP + DEPENDENCIES if app_first else DEPENDENCIES + APP) + REPORT

    result = configure(tmp_path, body, {"libext.so": "", "mid.cpp": "int mid() { return 0; }\n"})

    assert result.returncode == 0, result.output
    assert result.report_list("app") == ["mid", "base"]
    assert result.report_list("base") == []


def test_visual_studio_debugger_path(tmp_path: Path) -> None:
    """Executables and shared / module libraries: PATH starts with the folders of their DLLs, per configuration (CMake
    evaluates $<TARGET_RUNTIME_DLL_DIRS> at generate time), and keeps the environment; nothing when there are none.
    Other targets get no debugger environment."""
    body = (
        "enable_language(CXX)\n"
        + INIT
        + """
cs_add_executable(app main.cpp)
cs_finalize_target(app)
cs_add_library(alone INTERFACE)
cs_finalize_target(alone)
cs_finalize_project()
get_target_property(value app VS_DEBUGGER_ENVIRONMENT)
cstest_report(app "${value}")
get_target_property(value alone VS_DEBUGGER_ENVIRONMENT)
cstest_report(alone "${value}")
"""
    )
    result = configure(tmp_path, body, {"main.cpp": "int main() { return 0; }\n"})

    assert result.returncode == 0, result.output
    dirs = "$<TARGET_RUNTIME_DLL_DIRS:app>"
    assert result.reports["app"] == f"$<$<BOOL:{dirs}>:PATH={dirs};%PATH%>"
    assert result.reports["alone"] == "value-NOTFOUND"


ENVIRONMENT = """enable_language(CXX)
cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)
cs_add_executable(app main.cpp)
{before_finalize}
cs_finalize_target(app)
cs_finalize_project()
get_target_property(value app VS_DEBUGGER_ENVIRONMENT)
# one line per report: the newlines as <NL>
string(REPLACE "\n" "<NL>" value "${{value}}")
cstest_report(app "${{value}}")
"""


def _environment(tmp_path: Path, before_finalize: str) -> str:
    body = ENVIRONMENT.format(before_finalize=before_finalize)
    result = configure(tmp_path, body, {"main.cpp": "int main() { return 0; }\n"})
    assert result.returncode == 0, result.output
    return result.reports["app"]


def test_the_path_folders_of_the_project_come_first(tmp_path: Path) -> None:
    value = _environment(tmp_path, 'cs_target_runtime_environment(app PATH /sdk/bin "$<$<CONFIG:Debug>:/d>")')

    dirs = "/sdk/bin;$<$<CONFIG:Debug>:/d>;$<TARGET_RUNTIME_DLL_DIRS:app>"
    assert value == f"$<$<BOOL:{dirs}>:PATH={dirs};%PATH%>"


def test_an_environment_of_the_project_without_path_gets_the_path_entry_after_it(tmp_path: Path) -> None:
    value = _environment(tmp_path, "set_property(TARGET app PROPERTY VS_DEBUGGER_ENVIRONMENT QT_PLUGIN_PATH=/plugins)")

    dirs = "$<TARGET_RUNTIME_DLL_DIRS:app>"
    assert value == f"QT_PLUGIN_PATH=/plugins$<$<BOOL:{dirs}>:<NL>>$<$<BOOL:{dirs}>:PATH={dirs};%PATH%>"


DLL = "$<TARGET_RUNTIME_DLL_DIRS:app>"
HAS = f"$<BOOL:{DLL}>"
OWN_PATH = 'set_property(TARGET app PROPERTY VS_DEBUGGER_ENVIRONMENT "A=1\\nPATH=/mine;%PATH%")\n'


@pytest.mark.parametrize(
    ("setting", "expected"),
    [
        ("", f"A=1<NL>PATH=$<{HAS}:{DLL};>/mine;%PATH%"),
        ("cs_target_runtime_environment(app DEBUGGER_PATH BEFORE)", f"A=1<NL>PATH=$<{HAS}:{DLL};>/mine;%PATH%"),
        ("cs_target_runtime_environment(app DEBUGGER_PATH AFTER)", f"A=1<NL>PATH=/mine;$<{HAS}:{DLL};>%PATH%"),
        ("cs_target_runtime_environment(app DEBUGGER_PATH OFF)", "A=1<NL>PATH=/mine;%PATH%"),
    ],
    ids=["default-before", "before", "after", "off"],
)
def test_the_path_line_of_the_project_is_merged(tmp_path: Path, setting: str, expected: str) -> None:
    assert _environment(tmp_path, OWN_PATH + setting) == expected


def test_after_a_path_line_without_the_environment_path(tmp_path: Path) -> None:
    own = 'set_property(TARGET app PROPERTY VS_DEBUGGER_ENVIRONMENT "PATH=/only")\n'

    value = _environment(tmp_path, own + "cs_target_runtime_environment(app DEBUGGER_PATH AFTER)")

    assert value == f"PATH=/only$<{HAS}:;{DLL}>"


def test_off_without_an_environment_of_the_project_sets_nothing(tmp_path: Path) -> None:
    assert _environment(tmp_path, "cs_target_runtime_environment(app DEBUGGER_PATH OFF)") == "value-NOTFOUND"


def test_a_wrong_property_value_is_rejected(tmp_path: Path) -> None:
    """The property set directly (not through cs_target_runtime_environment) is checked by cs_finalize_project."""
    body = ENVIRONMENT.format(before_finalize="set_property(TARGET app PROPERTY CSCMAKE_DEBUGGER_PATH FIRST)")
    result = configure(tmp_path, body, {"main.cpp": "int main() { return 0; }\n"})

    assert result.returncode != 0
    assert "CSCMAKE_DEBUGGER_PATH is BEFORE, AFTER or OFF, got FIRST" in " ".join(result.output.split())


def test_variables_and_folders_of_several_calls(tmp_path: Path) -> None:
    """Each call adds; variables one line each (a ";" of a value kept), after the lines of the project; then PATH."""
    calls = """
set_property(TARGET app PROPERTY VS_DEBUGGER_ENVIRONMENT A=1)
cs_add_executable(cstest::app_alias ALIAS app)
cs_target_runtime_environment(cstest::app_alias SET "QT_PLUGIN_PATH=/qt/plugins" "LIST=x;y" PATH /one)
cs_target_runtime_environment(app PATH /two SET "Q=$<CONFIG>")
"""
    value = _environment(tmp_path, calls)

    dirs = f"/one;/two;{DLL}"
    lines = "A=1<NL>QT_PLUGIN_PATH=/qt/plugins<NL>LIST=x$<SEMICOLON>y<NL>Q=$<CONFIG>"
    assert value == f"{lines}$<$<BOOL:{dirs}>:<NL>>$<$<BOOL:{dirs}>:PATH={dirs};%PATH%>"


def test_off_adds_no_variables_either(tmp_path: Path) -> None:
    calls = "cs_target_runtime_environment(app SET A=1 PATH /one)\ncs_target_runtime_environment(app DEBUGGER_PATH OFF)"

    assert _environment(tmp_path, calls) == "value-NOTFOUND"


@pytest.mark.parametrize(
    ("call", "message"),
    [
        ("cs_target_runtime_environment(app SET novalue)", "SET takes <name>=<value>, got novalue"),
        ("cs_target_runtime_environment(app SET PATH=/x)", "PATH is given with the PATH keyword"),
        ("cs_target_runtime_environment(app FOLDERS /x)", "unparsed arguments FOLDERS;/x"),
        ("cs_target_runtime_environment(missing PATH /x)", "missing is not a target"),
        ("cs_target_runtime_environment(app DEBUGGER_PATH FIRST)", "DEBUGGER_PATH is BEFORE, AFTER or OFF, got FIRST"),
    ],
)
def test_wrong_arguments_are_rejected(tmp_path: Path, call: str, message: str) -> None:
    body = ENVIRONMENT.format(before_finalize=call)
    result = configure(tmp_path, body, {"main.cpp": "int main() { return 0; }\n"})

    assert result.returncode != 0
    assert message in " ".join(result.output.split())


def test_a_call_after_finalize_project_is_rejected(tmp_path: Path) -> None:
    body = ENVIRONMENT.format(before_finalize="") + "cs_target_runtime_environment(app PATH /late)\n"
    result = configure(tmp_path, body, {"main.cpp": "int main() { return 0; }\n"})

    assert result.returncode != 0
    assert "app: call it before cs_finalize_project" in " ".join(result.output.split())
