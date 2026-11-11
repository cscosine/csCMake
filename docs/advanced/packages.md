# Installed packages internals

How `cs_install_target` and the finalization of the project turn the targets of a project into an installed package
with components. For the use of the package, see [Installed packages](../user/install.md).

## Recording the components: `cs_install_target`

`cs_install_target(<target> COMPONENT <component> [DEFAULT])`:

- installs the target in the export set `<namespace>_<component>-targets` (binaries to `bin`/`lib`, the PDB file with
  MSVC);
- installs its headers queued by `cs_target_sources` (`*_INSTALL`): to
  `${CMAKE_INSTALL_INCLUDEDIR}[/$<CONFIG>]/<path from the project folder>`; the `$<CONFIG>` folder is there when the
  project has more than one configuration (`cs_get_install_include_dir`), so that the headers of every
  configuration, generated ones included, can be installed in one prefix. The consumers get them through
  `<namespace>::cscmake_base_include`: one include folder per configuration, `$<$<CONFIG:<config>>:<prefix>/include/<config>>`,
  so they follow the configuration CMake selects for the imported targets (the same as the libraries);
- records the component: `CSCMAKE_COMPONENT` on the target,
  `CSCMAKE_<namespace>_COMPONENTS` (and `_DEFAULT_COMPONENTS` with `DEFAULT`),
  `CSCMAKE_<namespace>_COMPONENT_<component>_TARGETS`, and the `PUBLIC` `cs_find_package` arguments of
  the target in `CSCMAKE_<namespace>_COMPONENT_<component>_FIND_PACKAGES`.

## Finalizing: the end of the project

After the [runtime dependencies](runtime-dependencies.md) (which give the project dependencies of every target):

1. installs the export set of each component as `lib/cmake/<namespace>/targets/<component>Targets.cmake`, with the
   `<namespace>::` prefix;
2. for each component, for each project dependency of its targets:
   - a target of the same project in another component: that component is a dependency
     (`CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES`);
   - a target of another csCMake project of the build (nested projects): its package becomes a `find_dependency`
     of the component, `<other namespace> COMPONENTS <its component> REQUIRED CONFIG`;
3. fails on a cycle between components;
4. sorts the dependencies of each component, each after the ones it depends on
   (`CSCMAKE_<namespace>_COMPONENT_<component>_DEPENDENCIES_SORTED`);
5. generates `<namespace>Config.cmake` from `templates/csTemplateConfig.cmake.in` (`configure_file(@ONLY)`) and
   `<namespace>ConfigVersion.cmake` (`write_basic_package_version_file`, `CSCMAKE_VERSION_COMPATIBILITY`), and
   installs both in `lib/cmake/<namespace>/`.

## The generated `<namespace>Config.cmake`

csCMake fills the placeholders of the template with:

- the components and the default components;
- for each component, `set(<namespace>_<component>_DEPENDENCIES "<sorted dependencies>")`;
- for each component with find_package arguments, the `find_dependency(...)` calls to make when it is loaded;
- the path from the Config folder to the install prefix, for `<namespace>_BASE_DIR`.

When loaded by `find_package(<namespace> [COMPONENTS ...])`, it:

1. takes the requested components, or the default ones;
2. for each one: an unknown component sets `<namespace>_<component>_FOUND` to `FALSE` (and `<namespace>_FOUND` to
   `FALSE` with `<namespace>_NOT_FOUND_MESSAGE` if it was required); otherwise, for each of its dependencies then
   itself, calls the `find_dependency` of that component (once per component) and includes
   `targets/<component>Targets.cmake`, then sets `<namespace>_<component>_FOUND` to `TRUE`;
3. unsets its own work variables: everything it sets other than the public variables starts with
   `<namespace>_` / `_<namespace>_`.

The namespace with `-` replaced by `_` names its helper macro and its work variables.
