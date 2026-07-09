# ADR-0010: Production Readiness — Rules Tested in CI, AI Orchestration Layer, V3 Slice

**Status:** Accepted — 2026-07-09

## Context

Firebase project creation remains blocked (interactive login; no Java locally for the emulator either). Spec gate: no unverifiable code. GitHub-hosted CI runners have Java — the Firestore emulator CAN run there.

## Decisions

1. **Security rules verified in CI.** Rules deltas from ADR-0009 applied to `backend/firestore.rules` (status-enum learner gate, immutable `questionVersions`, `importJobs`, owner-only `learnerModel` with admins excluded). Rules unit tests (`backend/test/`, @firebase/rules-unit-testing) run in a dedicated CI job via `firebase emulators:exec` with `actions/setup-java`. Verification path: push → CI. Local runs need Java (documented).
2. **AI orchestration = one provider seam.** `AiChatModel` (`lib/ai/chat_model.dart`) is the single vendor interface: `complete(List<AiMessage>) → String`. `AiOrchestrator` implements six domain capabilities (tutor, coach, explanation, question generation, metadata, review) as prompts + parsers over any chat model — vendor never touches business logic. `AiConversation` bounds context uniformly. `FakeChatModel` makes the whole layer deterministic and tested. **Anthropic/OpenAI/Gemini/local adapters are deliberately absent**: network code without keys/quota is unverifiable; each adapter is one class implementing `AiChatModel` when keys exist. AI question generation always emits drafts attributed `ai:<provider>` — human approval gate is structural.
3. **Content Studio V3 verifiable slice**: advanced filters (topic + difficulty alongside status/search), bulk restore (archived → draft through the versioned path), version comparison (per-version diff vs current: text, explanation, correct answer, status, topic, tags).
4. **Docs-as-deliverables** (spec-required, no runtime dependency): threat model (`docs/security/02`), release/deployment/migration/smoke/rollback/DR/monitoring checklists (`docs/deployment/03`), search platform design + performance & accessibility audits (`docs/architecture/05`).

## Deferred (blockers named)

- Firestore/Storage/Auth/Analytics repository implementations, offline sync verification, App Check, Remote Config → Firebase project (human runbook).
- Excel import, image pipeline (storage, thumbnails, dedup, linking) → Firebase Storage + upload deps; architecture in docs/product/07 + swap guide.
- AI provider adapters, OCR/document extraction orchestration → API keys + binary transport.
- External search engine → content scale trigger (docs/architecture/05).
- Institution libraries, marketplace packs, white-label → business requirements pass.

## Consequences

- Security rules are no longer "written but never executed" — every push proves them against the emulator.
- Binding a real AI provider = implementing one interface + one DI line; all capability logic already tested.
