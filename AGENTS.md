# AGENTS.md

Entry point for coding agents working in this repository.

- **Rules**: [CLAUDE.md](CLAUDE.md) holds the rules every agent follows here (it is not specific to one tool):
  commands, generated files never edited by hand, Python and CMake conventions, the documentation format, and the
  process (review after each step, commit only when asked, never stage changes, no history in the docs).
- **State of the work**: [PLAN.md](PLAN.md): roadmap, open findings, `PLAN_STATE` and the changelog. Read it first.
- **Repository map and recipes**: [.agents/skills/cscmake-development/SKILL.md](.agents/skills/cscmake-development/SKILL.md).
- **How csCMake works**: the documentation in `docs/`: user guide, advanced pages (lifecycle, runtime dependencies,
  installed packages, presets internals), and the reference in the `#.rst:` blocks of `csCMake.cmake` and `utils/`.
- **Contributing**: [code](docs/contributing/code.md) and [documentation](docs/contributing/documentation.md).
