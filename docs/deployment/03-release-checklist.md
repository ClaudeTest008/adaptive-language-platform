# Version 1.0 Release Candidate — Checklists

## Release checklist

- [ ] Firebase runbook complete (`01-firebase-setup.md`) — dev + prod projects
- [ ] Firestore swap complete and verified (`02-firestore-swap-guide.md` §6)
- [ ] CI green on main: format, analyze, tests, web build, functions build, rules emulator tests
- [ ] Content seeded via content pack; admin bootstrapped
- [ ] Store listings, privacy policy, account-deletion URL (store requirement)

## Deployment checklist (per release)

1. `firebase deploy --only firestore:rules,firestore:indexes,storage --project prod`
2. `firebase deploy --only functions --project prod`
3. `flutter build web --release` → Firebase Hosting; `flutter build appbundle` / `ipa` → stores
4. Tag release `vX.Y.Z`; CHANGELOG section moved from Unreleased

## Migration checklist

- [ ] Migration scripts idempotent, tested against dev before prod
- [ ] Tolerant readers deployed BEFORE data migration (docs/database/03 ordering)
- [ ] `/migrations/{id}` progress doc verified after run

## Smoke test (post-deploy, ~10 min)

- [ ] Register → verify profile document created (`onUserCreate`)
- [ ] Practice session: feedback, explanation, bookmark
- [ ] Adaptive session: selector returns questions; readiness card updates
- [ ] Mock exam: timer, submit, result, history entry
- [ ] Content Studio: edit question → version bump; import 1 CSV row; rollback
- [ ] Offline: airplane mode → cached practice works → reconnect → sync
- [ ] Crashlytics test crash arrives; Analytics debug event visible

## Rollback procedure

- App: Hosting `firebase hosting:rollback`; stores: halt rollout (staged rollout at ≤20% until smoke passes).
- Rules: previous rules file from git → `firebase deploy --only firestore:rules`.
- Functions: redeploy previous tag.
- Data: schema changes are additive-only (docs/database/03); no destructive rollback needed. If a migration misbehaves: stop script, restore from backup (below), fix idempotent script, rerun.

## Backup / disaster recovery

- Firestore scheduled backups (daily, 30-day retention) via `gcloud firestore backups schedules create` — enable during runbook.
- Content additionally exportable as content packs (portable JSON) — weekly export stored outside GCP.
- Recovery: restore backup to new database → point project → redeploy rules. RPO 24 h, RTO < 4 h target for V1.

## Production monitoring

- Crashlytics alerts: new fatal issue, crash-free < 99.5% (docs/product/05 target)
- Cloud Monitoring: Firestore read/write anomaly alerts (cost guard), function error rate > 1%
- Analytics dashboards: activation, D7 retention, mock exam adoption (metrics in docs/product/05)

## Known limitations at RC

Demo-mode persistence until Firestore swap; single admin role; English only; no Excel/image import; scheduled publishing pending functions cron; answer keys client-visible (ADR-0005); learner model not backfilled from pre-launch attempts.
