#.rst:
# csQt
# ----
#
# Qt: finding it with the checks of csCMake, and what a deployment of a Qt GUI application needs besides the libraries
# its binaries link (found by :command:`cs_deployment`): the plugins Qt loads at run time.
#
# Qt is found with :command:`cs_find_package` (``cs_find_package(<target> PUBLIC|PRIVATE Qt6 ...)``), or by the
# ``<namespace>Config.cmake`` of a csCMake package that depends on it: then the hook of csQt for ``Qt6``
# (:command:`cs_add_after_find_hook`) checks that the project builds for a macOS Qt supports
# (``CMAKE_OSX_DEPLOYMENT_TARGET`` at least ``QT_SUPPORTED_MIN_MACOS_VERSION`` of the Qt package,
# :command:`cs_require_macos_deployment_target`). Qt found otherwise (a plain :command:`find_package`, or a non-csCMake
# package that finds it) fails the configure at the end of the project, unless ``CSCMAKE_QT_ALLOW_FIND_PACKAGE`` is
# ``ON``: then a warning, and the check is done anyway.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csDeployment)
include(modules/csMacosDeploymentTarget)

# The check of csCMake on Qt just found (cs_after_find_dependency): the project builds for a macOS Qt supports.
#
# Reads:
#
# * variable QT_SUPPORTED_MIN_MACOS_VERSION, Qt6_VERSION (Qt6ConfigExtras.cmake, Qt6ConfigVersion.cmake)
#
# Writes:
#
# * global property _CSCMAKE_QT_CHECKED
function(_cs_qt_after_find package)
  set_property(GLOBAL PROPERTY _CSCMAKE_QT_CHECKED TRUE)
  cs_require_macos_deployment_target("${QT_SUPPORTED_MIN_MACOS_VERSION}" REASON "Qt ${Qt6_VERSION}")
endfunction()
cs_add_after_find_hook(Qt6 _cs_qt_after_find)

# At the end of the project (_cs_finalize_project): Qt loaded (Qt6_DIR, and its commands) without the check of csCMake
# fails, unless CSCMAKE_QT_ALLOW_FIND_PACKAGE: a warning, and the check from the Qt6ConfigExtras.cmake of Qt6_DIR.
#
# Reads:
#
# * cache variable Qt6_DIR, CSCMAKE_QT_ALLOW_FIND_PACKAGE
# * global property _CSCMAKE_QT_CHECKED
function(_cs_qt_check_found_with_cscmake)
  # cscmake-lint: disable=CS103 the variable of Qt6ConfigExtras.cmake (it sets it when empty), local to this function
  get_property(checked GLOBAL PROPERTY _CSCMAKE_QT_CHECKED)
  # Qt6_DIR alone may be left in the cache by an older configure: Qt is loaded in this one when its commands exist
  if(checked OR NOT Qt6_DIR OR NOT IS_DIRECTORY "${Qt6_DIR}" OR NOT COMMAND qt6_add_executable)
    return()
  endif()
  if(NOT CSCMAKE_QT_ALLOW_FIND_PACKAGE)
    message(
      FATAL_ERROR
      "[csCMake] Qt (${Qt6_DIR}) is found without the checks of csCMake (find_package, or a package that is not "
      "csCMake's): find it with cs_find_package(<target> PUBLIC|PRIVATE Qt6 ...), which checks that "
      "the project builds for a macOS Qt supports. To keep find_package: -DCSCMAKE_QT_ALLOW_FIND_PACKAGE=ON (a "
      "warning instead, the check done anyway)."
    )
  endif()
  message(
    WARNING
    "[csCMake] Qt (${Qt6_DIR}) is found without the checks of csCMake (CSCMAKE_QT_ALLOW_FIND_PACKAGE): checked now "
    "from its Qt6ConfigExtras.cmake"
  )
  set(QT_SUPPORTED_MIN_MACOS_VERSION "")
  if(EXISTS "${Qt6_DIR}/Qt6ConfigExtras.cmake")
    include("${Qt6_DIR}/Qt6ConfigExtras.cmake")
  endif()
  set_property(GLOBAL PROPERTY _CSCMAKE_QT_CHECKED TRUE)
  cs_require_macos_deployment_target("${QT_SUPPORTED_MIN_MACOS_VERSION}" REASON "Qt (${Qt6_DIR})")
endfunction()

#.rst:
# .. command:: cs_deployment_qt_gui
#
#   Add to a deployment the Qt plugins of a GUI application (Qt Gui / Widgets, OpenGL), for the system of the build.
#
#   .. code-block:: cmake
#
#     cs_deployment_qt_gui(<name> [OFFSCREEN] [NO_WAYLAND])
#
#   ``<name>`` is a deployment of the project (:command:`cs_deployment`, before or after this call); Qt is found
#   (``cs_find_package(<target> PRIVATE Qt6 COMPONENTS Gui)`` or ``Widgets``) in the folder of the call, where its
#   plugin targets are visible. The plugins go where Qt looks for them in the layout of the deployment:
#
#   * Linux: ``plugins/<type>/`` (Qt finds them from its libraries in ``lib/``): the platforms ``xcb`` (required) and
#     ``wayland``, the OpenGL integrations of xcb (GLX, EGL), the shell, graphics and decoration plugins of Wayland;
#   * Windows: ``bin/<type>/``, next to the executables (the layout of ``windeployqt``): the platform ``windows``
#     (required), the native style, and the software OpenGL of Qt (``opengl32sw.dll``, in ``bin/``, used with
#     ``QT_OPENGL=software`` on a machine without GPU driver) when the Qt package has it;
#   * macOS: ``bin/<type>/``, next to the executables (the folder of an application is a plugin folder of Qt): the
#     platform ``cocoa`` (required) and the native style.
#
#   A plugin the Qt package does not have (e.g. Qt built without Wayland) is skipped, with a message (``VERBOSE``);
#   a required one fails.
#
#   ``OFFSCREEN``
#     Also the platform ``offscreen`` (``QT_QPA_PLATFORM=offscreen``: no display, no OpenGL context).
#
#   ``NO_WAYLAND``
#     Linux: not the Wayland plugins (xcb only; on a Wayland desktop through XWayland).
#
#   E.g. the deployment of an application, with its Qt plugins:
#
#   .. code-block:: cmake
#
#     cs_add_executable(app main.cpp)
#     cs_find_package(app PRIVATE Qt6 COMPONENTS Widgets REQUIRED)
#     cs_target_link_libraries(app PRIVATE Qt6::Widgets)
#     cs_deployment(app TARGETS app)
#     cs_deployment_qt_gui(app)
function(cs_deployment_qt_gui name)
  _cs_message_context(cs_deployment_qt_gui)
  cmake_parse_arguments(PARSE_ARGV 1 arg "OFFSCREEN;NO_WAYLAND" "" "")
  if(DEFINED arg_UNPARSED_ARGUMENTS)
    message(
      FATAL_ERROR
      "[cs_deployment_qt_gui] ${name}: unexpected arguments ${arg_UNPARSED_ARGUMENTS} "
      "(cs_deployment_qt_gui(<name> [OFFSCREEN] [NO_WAYLAND]))"
    )
  endif()
  if(NOT TARGET Qt6::Gui)
    message(
      FATAL_ERROR
      "[cs_deployment_qt_gui] ${name}: Qt6::Gui is not a target here: find Qt (Gui or Widgets) in this folder first, "
      "cs_find_package(<target> PRIVATE Qt6 COMPONENTS Gui)"
    )
  endif()

  set(offscreen "")
  if(arg_OFFSCREEN)
    set(offscreen Qt6::QOffscreenIntegrationPlugin)
  endif()

  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(wayland "")
    if(NOT arg_NO_WAYLAND)
      set(wayland Qt6::QWaylandIntegrationPlugin)
    endif()
    _cs_deployment_qt_plugins(
      ${name}
      plugins/platforms
      REQUIRED Qt6::QXcbIntegrationPlugin
      OPTIONAL ${wayland} ${offscreen}
    )
    _cs_deployment_qt_plugins(
      ${name}
      plugins/xcbglintegrations
      OPTIONAL Qt6::QXcbGlxIntegrationPlugin Qt6::QXcbEglIntegrationPlugin
    )
    if(NOT arg_NO_WAYLAND)
      _cs_deployment_qt_plugins(
        ${name}
        plugins/wayland-shell-integration
        OPTIONAL Qt6::QWaylandXdgShellIntegrationPlugin
      )
      _cs_deployment_qt_plugins(
        ${name}
        plugins/wayland-graphics-integration-client
        OPTIONAL Qt6::QWaylandEglClientBufferPlugin
      )
      _cs_deployment_qt_plugins(
        ${name}
        plugins/wayland-decoration-client
        OPTIONAL Qt6::QWaylandBradientDecorationPlugin
      )
    endif()
  elseif(WIN32)
    _cs_deployment_qt_plugins(${name} bin/platforms REQUIRED Qt6::QWindowsIntegrationPlugin OPTIONAL ${offscreen})
    _cs_deployment_qt_plugins(${name} bin/styles OPTIONAL Qt6::QModernWindowsStylePlugin)
    # the software OpenGL of Qt, next to the executables (loaded at run time, nothing links it)
    set(opengl_software "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS}/opengl32sw.dll")
    if(DEFINED QT6_INSTALL_PREFIX AND EXISTS "${opengl_software}")
      cs_deployment(${name} FILES "${opengl_software}" DESTINATION bin)
    else()
      message(VERBOSE "${CSCMAKE_NAMESPACE}: ${name}: no opengl32sw.dll in the Qt package, not deployed")
    endif()
  elseif(APPLE)
    _cs_deployment_qt_plugins(${name} bin/platforms REQUIRED Qt6::QCocoaIntegrationPlugin OPTIONAL ${offscreen})
    _cs_deployment_qt_plugins(${name} bin/styles OPTIONAL Qt6::QMacStylePlugin)
  else()
    message(WARNING "[cs_deployment_qt_gui] ${name}: no Qt plugins known for ${CMAKE_SYSTEM_NAME}, none deployed")
  endif()
endfunction()

# Add to the deployment name the plugins in destination: the REQUIRED ones must be targets (Qt found with them), the
# OPTIONAL ones are skipped when they are not.
function(_cs_deployment_qt_plugins name destination)
  cmake_parse_arguments(PARSE_ARGV 2 arg "" "" "REQUIRED;OPTIONAL")
  set(plugins "")
  foreach(plugin IN LISTS arg_REQUIRED)
    if(NOT TARGET ${plugin})
      message(
        FATAL_ERROR
        "[cs_deployment_qt_gui] ${name}: ${plugin} is not a target: the Qt package has no such plugin, or Qt is found "
        "in another folder"
      )
    endif()
    list(APPEND plugins ${plugin})
  endforeach()
  foreach(plugin IN LISTS arg_OPTIONAL)
    if(TARGET ${plugin})
      list(APPEND plugins ${plugin})
    else()
      message(VERBOSE "${CSCMAKE_NAMESPACE}: ${name}: ${plugin} not in the Qt package, not deployed")
    endif()
  endforeach()
  if(plugins)
    cs_deployment(${name} PLUGINS ${plugins} DESTINATION ${destination})
  endif()
endfunction()

#.rst:
# Variables
# ^^^^^^^^^
#
# .. variable:: CSCMAKE_QT_ALLOW_FIND_PACKAGE
#
#   ``ON``: Qt loaded without the check of csCMake (a plain :command:`find_package`, or a package not made by csCMake
#   that finds it) is a warning at the end of the project, and the check is done then (from the
#   ``Qt6ConfigExtras.cmake`` of ``Qt6_DIR``); ``OFF`` or unset (default): it fails the configure.
#
# Global properties
# ^^^^^^^^^^^^^^^^^
#
# .. prop_gbl:: _CSCMAKE_QT_CHECKED
#
#   Internal: ``TRUE`` once Qt is checked (the hook of csQt for ``Qt6``, or the end of the project with
#   :variable:`CSCMAKE_QT_ALLOW_FIND_PACKAGE`).
