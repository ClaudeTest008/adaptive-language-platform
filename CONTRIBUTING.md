# Contributing

## Workflow

1. Read `AI_CONTEXT.md`, `PROJECT_STATUS.md`, and `TASKS.md` before starting.
2. Work on exactly one task from `TASKS.md` (or the next roadmap epic) at a time.
3. Never repeat completed work; never redesign completed systems without an ADR justifying it.
4. Leave the repository consistent at the end of every session: code compiles, tests pass, tracking documents updated.

## Commits

- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`).
- Small, focused commits; only task-related files.
- Push to `origin/main`; report the commit hash.

## Code Standards

- Clean Architecture layer separation (see `ARCHITECTURE.md`); domain layer has no Firebase or Flutter imports.
- SOLID; dependency injection for cross-layer wiring.
- `dart format` and `flutter analyze` clean before commit.
- New domain logic ships with unit tests.

## Documentation

- Important technical decisions get an ADR in `docs/decisions/` (`NNNN-title.md`).
- Milestone completion updates: `AI_CONTEXT.md`, `ROADMAP.md`, `PROJECT_STATUS.md`, `TASKS.md`, `CHANGELOG.md`.
