# Architecture

> Stub — to be filled in during the architecture phase. Decisions are recorded in `docs/decisions/`.

## Intended High-Level Shape

- **Client:** Flutter app (`app/flutter/`) targeting mobile first.
- **Backend:** services under `backend/`, plus serverless functions under `cloud_functions/`.
- **Learning engine:** adaptive question selection; design docs in `docs/learning-engine/`.
- **AI:** AI-assisted features documented in `docs/ai/`.
- **Data:** schema and storage design in `docs/database/`.

## Principles

- Preserve architectural consistency across AI sessions.
- Extend existing modules before creating new ones.
- Keep interfaces stable; record breaking changes as decisions.
