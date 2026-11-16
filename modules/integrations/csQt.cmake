#.rst:
# csQt
# ----
#
# Qt: what a deployment of a Qt GUI application needs besides the libraries its binaries link (found by
# :command:`cs_deployment`): the plugins Qt loads at run time.
#
# Commands
# ^^^^^^^^
include_guard(GLOBAL)
include(modules/csDebug)
include(modules/csDeployment)

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
#   (``find_package(Qt6 COMPONENTS Gui)`` or ``Widgets``) in the folder of the call, where its plugin targets are
#   visible. The plugins go where Qt looks for them in the layout of the deployment:
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
#     find_package(Qt6 COMPONENTS Widgets REQUIRED)
#     cs_add_executable(app main.cpp)
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
      "[cs_deployment_qt_gui] ${name}: Qt6::Gui is not a target here: find_package(Qt6 COMPONENTS Gui) (or Widgets) "
      "in this folder first"
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
