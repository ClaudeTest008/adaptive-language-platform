# ADR-0021: Bottom Navigation Shell

**Status:** Accepted
**Date:** 2026-07-16

## Context

The dashboard hung the AI Tutor off a floating action button, and the new Stories and Speaking surfaces needed a home. The FAB does not scale to four destinations, and a floating control over content is not the standard mobile pattern.

## Decision

Replace the FAB with a `NavigationBar` shell (`HomeShell`) over four tabs — Lab, Stories, Speaking, Tutor — held in an `IndexedStack` (tab state persists when switching). The selected tab is a `StateProvider` (`homeTabProvider`) so any widget switches tabs without prop drilling (the dashboard tutor hero sets it to the Tutor tab). Deep screens (practice, concept, story reader) remain pushed routes over the shell. The keyboard now appears only when a text field is focused — standard Flutter behavior, no forced side bar.

## Consequences

- `/language/tutor` is now a tab, not a pushed route; the route redirects to the shell for legacy deep links.
- Each tab keeps its own `Scaffold`/`AppBar` inside the stack — simple, no shared app-bar coupling.
- IndexedStack builds all four tabs once; cheap here (demo data), revisit if a tab becomes heavy.
