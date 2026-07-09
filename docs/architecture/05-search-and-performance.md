# Search Platform Design + Performance & Accessibility Audit

## Search platform (design — implementation staged)

**V1 (current):** client-side search over the cached question set (bounded: hundreds of questions per exam). Admin search adds status/topic/difficulty/tag filters. Adequate below ~2k questions per exam.

**Scale path:** a `SearchService` interface at the application layer:

```dart
abstract class SearchService {
  Future<List<SearchHit>> search(SearchQuery query); // entity-typed hits
}
```

Entities: questions, topics, subtopics, learning objectives, tags, references, authors, versions, import jobs, content packs, institutions. Implementations, in adoption order: (1) `ClientSearchService` (current behavior, formalized), (2) Firestore field-prefix queries for admin lookups, (3) external engine (Algolia/Typesense/Meilisearch) fed by a Cloud Function on question write — the interface keeps the app unchanged. Trigger for (3): first exam library exceeding client-cache comfort (~5k questions) or multi-exam global search.

## Performance audit (current state)

| Area | State | Action |
|---|---|---|
| Question fetch | One pool query per session, Firestore cache after swap | Keep; monitor read counts post-launch |
| Lists | `ListView.builder` everywhere; admin list unpaginated | Paginate admin list at >500 questions (Firestore `limit`/`startAfter` ready in swap guide) |
| Adaptive engine | O(pool) scoring per selection, O(concepts) readiness — trivial at V1 scale (24–2000 questions) | None; profile if pools exceed 10k |
| Imports | Client-side parse, tested to thousands of rows | Cloud Function pipeline at scale (ADR-0007 seam) |
| Startup | No blocking I/O before first frame; demo repos instant | After swap: defer non-critical Firebase init post-first-frame |
| Bundle | Web release build via CI; no heavy deps (2 runtime packages) | Track size in CI when web deploy lands |
| Rebuild hygiene | Riverpod-scoped providers; const widgets; no global rebuilds observed | None |

## Accessibility audit (current state)

Done: semantic labels on icon buttons (tooltips), Material 3 contrast defaults in both themes, text scales with system settings, touch targets ≥48dp (Material defaults), screen-reader semantics verified functional (the browser test harness drives the app through the semantics tree — every flow exercised via it).

Gaps (tracked): explicit `Semantics` annotations for timer countdown (announce remaining time), focus order audit for keyboard navigation on web, high-contrast theme variant, color-blind check on green/red answer feedback (add icons — already present: check/cancel icons accompany color), WCAG AA contrast verification for `errorContainer` weak-topics card. Scheduled with Epic 12 deployment polish.
