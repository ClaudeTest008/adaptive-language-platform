# ADR-0018: AI Tutor Foundation — Context Assembly, Modes, Validation

**Status:** Accepted
**Date:** 2026-07-16

## Context

Phase 3 needs the tutor foundation: a personal teacher that knows the learner (vision: "not a generic chatbot"), six modes, provider independence, and validated output — without full dialogue logic yet. The inherited AI layer (`lib/ai/`, ADR-0010) provides the vendor seam (`AiChatModel`) and must stay untouched.

## Decision

1. **Tutor lives in the language layer** (`lib/language/tutor.dart`, pure Dart), consuming `AiChatModel` directly. `lib/ai/` unchanged — the tutor is a language-platform orchestration, not a core capability extension.
2. **Context is a first-class immutable snapshot.** `buildTutorContext` assembles `TutorContext` per session from real learner state: per-skill mastery, weakest concepts (named, with mastery), most-frequent misconceptions, per-concept signals, goals, Learning DNA traits, and — for concept-targeted modes — a knowledge-graph slice (focus concept, its typed relations with notes, its pattern family). The tutor never reaches into stores.
3. **Modes are prompt contracts.** `TutorMode` (Teacher, Conversation, Coach, Socratic, Grammar, Immersion) each define a persona; `tutorSystemPrompt` = persona + serialized `[LEARNER CONTEXT]` block + output rules. Dialogue depth (turn strategies, mode-specific state) is later Phase 3 work; the contract is fixed now.
4. **Every output passes validation** (`validateTutorReply`): non-empty, length cap, no context-block leakage, and grounding — Teacher/Grammar replies about a focus concept must actually mention the concept, its pattern, or its family. Rejected output never reaches the learner; `LanguageTutor.respond` substitutes a safe fallback and reports the reason.
5. **Provider independence proven by two implementations**: `FakeChatModel` (tests) and `DemoTutorModel` (infrastructure) — the demo model composes teacherly replies by reading the SAME system prompt a vendor would receive (misconception repair first, then pattern family), so the live demo is honest and vendor swap stays a one-line binding change (`tutorModelProvider`).
6. **Default session focus = the top misconception's concept** — "repair first" is the tutor's opening move, consistent with the lesson engine.
7. UI: `/language/tutor` (mode selector grid + chat session with context chips), tutor CTA on the Language Lab dashboard.

## Consequences

- Real vendors (Anthropic/OpenAI/Gemini/local) land as `AiChatModel` adapters bound in `tutorModelProvider`; prompts, validation and UI are already final.
- Immersion-mode language purity is NOT yet validated (needs language detection); current validation is structural + grounding. Deeper Phase 3 item.
- Tutor sessions are ephemeral (no persistence); `tutorHistory` schema (docs/database/05) lands with Firestore swap.
- Conversation/Socratic/Coach modes share the generic demo composer until dialogue logic lands — acceptable for foundation.
