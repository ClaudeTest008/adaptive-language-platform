# Threat Model (V1)

Assets: user PII (email, name), learner models (private study data), content library (commercial asset), admin credentials, service availability.

## Threats and Mitigations

| Threat | Vector | Mitigation | Status |
|---|---|---|---|
| Unauthorized data access | Client bypasses UI, calls Firestore directly | Default-deny rules, owner-scoped reads, emulator-tested in CI | Rules written + tested (CI) |
| Privilege escalation | User self-assigns admin | Roles only via custom claims set by `setUserRole` (admin-only callable); rules re-check claim on every write | Implemented (functions code) |
| Content tampering | Non-admin writes to content collections | Admin-only writes with shape validation; version history append-only | Implemented + tested |
| Learner data exposure | Admin or other user reads learner model | `learnerModel` rules: owner only, admins explicitly excluded | Implemented + tested |
| Forged analytics/audit | Client writes `questionStats`/`auditLogs` | Admin-SDK-only collections (`allow write: if false`) | Implemented |
| Answer-key extraction | Client inspects question documents | Accepted for V1 (ADR-0005: self-study app); server-side scoring is the upgrade if results ever gate real outcomes | Accepted risk |
| Abuse / bot traffic | Scripted signups, scraping | App Check (enforce mode) + Auth email verification; Firebase quotas as rate backstop; Cloud Functions `maxInstances` caps | Deferred to Firebase deploy (checklist item) |
| Secrets leakage | Keys in repo/CI | No service-account files in repo (gitignore pattern), GitHub Actions secrets, Firebase client config is non-secret by design | In place |
| Injection | Imported CSV/JSON content | Content is data, never executed; rendered as text in Flutter (no HTML interpolation); rules validate shape | In place |
| AI prompt injection / content poisoning | Malicious content in AI-assisted imports | All AI output lands as drafts behind the same human-approval pipeline; provider adapters isolated behind `AiChatModel` | Gate implemented; adapters pending |
| Account takeover | Weak passwords, no MFA | Min 8 chars now; Firebase email enumeration protection + optional MFA post-launch | Partial (documented) |

## Residual Risks (accepted, revisit at institutional launch)

Client-visible answer keys (ADR-0005); single admin role (no role separation until institutions); no rate limiting beyond Firebase defaults until App Check enforced.
