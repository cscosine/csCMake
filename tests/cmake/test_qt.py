"""cs_deployment_qt_gui: the Qt plugins of a GUI application in a deployment, per system (csQt.cmake).

Configure only, with stand-ins of the Qt targets (imported module libraries of the names of Qt): no Qt needed."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tests.cmake.cmake_project import configure

pytestmark = pytest.mark.requires("cmake", "ninja")

PLUGINS = [
    "QXcbIntegrationPlugin",
    "QWaylandIntegrationPlugin",
    "QOffscreenIntegrationPlugin",
    "QXcbGlxIntegrationPlugin",
    "QXcbEglIntegrationPlugin",
    "QWaylandXdgShellIntegrationPlugin",
    "QWaylandEglClientBufferPlugin",
    "QWaylandBradientDecorationPlugin",
    "QWindowsIntegrationPlugin",
    "QModernWindowsStylePlugin",
    "QCocoaIntegrationPlugin",
    "QMacStylePlugin",
]


def _body(plugins: list[str], call: str) -> str:
    """The Qt stand-ins (Qt6::Gui, the plugins), an application and its deployment, then call; reports the plugins of
    the deployment with their destinations."""
    lines = [
        "enable_language(CXX)",
        "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug Release)",
        "add_library(Qt6::Gui INTERFACE IMPORTED)",
        'file(WRITE "${CMAKE_BINARY_DIR}/fake-plugin" "")',
    ]
    for plugin in plugins:
        lines.append(f"add_library(Qt6::{plugin} MODULE IMPORTED)")
        lines.append(
            f'set_target_properties(Qt6::{plugin} PROPERTIES IMPORTED_LOCATION "${{CMAKE_BINARY_DIR}}/fake-plugin")'
        )
    lines += [
        "cs_add_executable(app main.cpp)",
        "cs_deployment(demo TARGETS app CONFIGS Release Debug)",
        call,
        "get_property(plugins GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_demo_PLUGINS)",
        'set(placed "")',
        "foreach(plugin IN LISTS plugins)",
        "  get_property(destination GLOBAL PROPERTY CSCMAKE_DEPLOYMENT_demo_PLUGIN_${plugin}_DESTINATION)",
        '  list(APPEND placed "${plugin}@${destination}")',
        "endforeach()",
        'cstest_report(plugins "${placed}")',
    ]
    return "\n".join(lines) + "\n"


def _placed(tmp_path: Path, plugins: list[str], call: str) -> dict[str, str]:
    result = configure(tmp_path, _body(plugins, call), {"main.cpp": "int main() { return 0; }\n"})
    assert result.returncode == 0, result.output
    return dict(entry.removeprefix("Qt6::").split("@") for entry in result.report_list("plugins"))


@pytest.mark.skipif(not sys.platform.startswith("linux"), reason="the Linux plugins")
def test_linux(tmp_path: Path) -> None:
    assert _placed(tmp_path / "default", PLUGINS, "cs_deployment_qt_gui(demo)") == {
        "QXcbIntegrationPlugin": "plugins/platforms",
        "QWaylandIntegrationPlugin": "plugins/platforms",
        "QXcbGlxIntegrationPlugin": "plugins/xcbglintegrations",
        "QXcbEglIntegrationPlugin": "plugins/xcbglintegrations",
        "QWaylandXdgShellIntegrationPlugin": "plugins/wayland-shell-integration",
        "QWaylandEglClientBufferPlugin": "plugins/wayland-graphics-integration-client",
        "QWaylandBradientDecorationPlugin": "plugins/wayland-decoration-client",
    }
    # xcb only, the offscreen platform; a Qt without the GLX integration: skipped
    without_glx = [p for p in PLUGINS if p != "QXcbGlxIntegrationPlugin"]
    assert _placed(tmp_path / "xcb", without_glx, "cs_deployment_qt_gui(demo OFFSCREEN NO_WAYLAND)") == {
        "QXcbIntegrationPlugin": "plugins/platforms",
        "QOffscreenIntegrationPlugin": "plugins/platforms",
        "QXcbEglIntegrationPlugin": "plugins/xcbglintegrations",
    }


@pytest.mark.skipif(sys.platform != "win32", reason="the Windows plugins")
def test_windows(tmp_path: Path) -> None:
    assert _placed(tmp_path, PLUGINS, "cs_deployment_qt_gui(demo OFFSCREEN)") == {
        "QWindowsIntegrationPlugin": "bin/platforms",
        "QOffscreenIntegrationPlugin": "bin/platforms",
        "QModernWindowsStylePlugin": "bin/styles",
    }


@pytest.mark.skipif(sys.platform != "darwin", reason="the macOS plugins")
def test_macos(tmp_path: Path) -> None:
    assert _placed(tmp_path, PLUGINS, "cs_deployment_qt_gui(demo)") == {
        "QCocoaIntegrationPlugin": "bin/platforms",
        "QMacStylePlugin": "bin/styles",
    }


def test_the_platform_plugin_of_the_system_is_required(tmp_path: Path) -> None:
    required = {"linux": "QXcbIntegrationPlugin", "win32": "QWindowsIntegrationPlugin"}.get(
        sys.platform, "QCocoaIntegrationPlugin"
    )
    plugins = [p for p in PLUGINS if p != required]
    result = configure(tmp_path, _body(plugins, "cs_deployment_qt_gui(demo)"), {"main.cpp": "int main() {}\n"})

    assert result.returncode != 0
    assert f"[cs_deployment_qt_gui] demo: Qt6::{required} is not a target" in " ".join(result.output.split())


@pytest.mark.parametrize(
    ("body", "message"),
    [
        ("cs_deployment_qt_gui(demo)", "Qt6::Gui is not a target here"),
        (
            "add_library(Qt6::Gui INTERFACE IMPORTED)\ncs_deployment_qt_gui(demo WAYLAND)",
            "unexpected arguments WAYLAND",
        ),
    ],
)
def test_mistakes_fail(tmp_path: Path, body: str, message: str) -> None:
    init = "cs_initialize_project(NAMESPACE cstest CXX_STANDARD 17 DEFAULT_CONFIG Debug Release)\n"
    result = configure(tmp_path, init + body + "\n")

    assert result.returncode != 0
    assert message in " ".join(result.output.split())
