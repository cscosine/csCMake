"""Runtime dependency analysis (csTargetDependencies.cmake): CSCMAKE_RUNTIME_LIBRARIES_<CONFIG>."""

from __future__ import annotations

from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

# two imported shared libraries, each brought by a project library; app links both
IMPORTED = """
foreach(x A B)
  add_library(ext${x} SHARED IMPORTED)
  set_target_properties(ext${x} PROPERTIES IMPORTED_LOCATION_DEBUG ${CMAKE_CURRENT_SOURCE_DIR}/lib${x}.so)
  cs_add_library(lib${x} INTERFACE)
  cs_target_link_libraries(lib${x} INTERFACE ext${x})
  cs_finalize_target(lib${x})
endforeach()
"""
APP = """
cs_add_library(app INTERFACE)
cs_target_link_libraries(app INTERFACE libA libB)
cs_finalize_target(app)
"""
REPORT = """
cs_finalize_project()
cs_get_target_runtime_libraries(app Debug libs)
cstest_report(app "${libs}")
"""


@pytest.mark.parametrize("app_first", [False, True], ids=["deps-first", "app-first"])
def test_runtime_libraries_of_every_dependency(tmp_path: Path, app_first: bool) -> None:
    """app gets the shared libraries of both its dependencies, also when it is finalized before they exist
    (resolved by cs_finalize_project; a quoted foreach dropped all but the first pending dependency)."""
    body = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug)\n"
    body += APP + IMPORTED if app_first else IMPORTED + APP
    result = configure(tmp_path, body + REPORT, {"libA.so": "", "libB.so": ""})

    assert result.returncode == 0, result.output
    assert sorted(Path(p).name for p in result.report_list("app")) == ["libA.so", "libB.so"]
