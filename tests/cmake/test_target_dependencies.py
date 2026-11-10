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
