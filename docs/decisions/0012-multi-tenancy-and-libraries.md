# ADR-0012: Multi-Tenancy, Content Libraries, Curriculum Hierarchy

**Status:** Accepted — 2026-07-09

## Multi-tenancy

- Tenants (schools, training centers, universities, agencies, corporate) share ONE model: `/orgs/{orgId}` with `members`, `questions` (org-private library), `analytics` subcollections. Differences are content and branding, not schema.
- **Isolation is enforced where it cannot be bypassed: Firestore rules.** Every org-scoped operation requires a membership document under the SAME org (`exists(...members/$(request.auth.uid))`). Cross-tenant access is impossible by construction — proven by emulator tests in CI (member of org A denied on all of org B's collections; non-members denied; escalation attempts denied).
- Role ladder per org: `owner | admin | editor | member` — owners/admins manage members, editors write content, members consume. Validated in rules (role whitelist) and mirrored in domain (`OrgMember` capabilities).
- Platform admins retain operator access (billing, support) — documented in the threat model; institutional contracts may require removing this later (single rules change).
- Learner privacy unchanged: learner models remain owner-only even inside orgs.

## Content libraries (inheritance without duplication)

- Scopes: `global | official | marketplace | organization | private`. A library holds ONLY its own questions plus an optional `parentId` edge.
- `resolveLibrary` walks the chain root-first and layers children over ancestors: child override replaces the parent's version by question id; a child archiving an id hides the inherited question; cycles throw. Parent libraries are never mutated by children — tested.
- Firestore mapping: library docs hold metadata + parent edge; questions stay in their owning library's subcollection. Resolution is client/worker-side (chains are short: global → country → org → private).

## Curriculum hierarchy

`subject → course → module → chapter → topic → subtopic → concept → learning objective`, with optional level skipping (a driving exam has no "course" tier). Nodes derive **hierarchical concept ids** (`driving:signs:octagon`) — exactly the string ids the adaptive engine already tracks. An answer submits the node's full lineage as its concept list, so mastery accrues at every level. **The adaptive engine is unchanged** — verified by test feeding lineage ids through `LearnerEngine.applyAnswer`.

## Deferred

Org-scoped UI (org switcher, member management screens) — needs Firebase auth+org data live; branding application (theme seed from `brandColorHex` — trivial once orgs exist); marketplace licensing terms; institution analytics aggregation workers.
