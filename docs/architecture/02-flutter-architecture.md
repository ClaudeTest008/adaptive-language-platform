# Flutter Architecture

## Targets

Android, iOS, web from one codebase in `app/flutter/`. Admin panel is web-only, role-gated routes in the same app (ADR-0003).

## Routing (go_router)

- Declarative route table in `core/router/`.
- Auth guard: unauthenticated users redirected to login; admin routes additionally require admin role (custom claim, re-verified by security rules server-side).
- Route structure:

```
/login, /register, /forgot-password
/                      # dashboard (progress)
/practice              # topic selection
/practice/session
/exam                  # mock exam start
/exam/session
/exam/result/:attemptId
/review                # incorrect answers
/bookmarks
/search
/settings
/admin                 # admin home (web + admin claim only)
/admin/exams, /admin/exams/:id
/admin/questions, /admin/questions/:id
/admin/users
/admin/analytics
```

## Theming

- Material 3, `ColorScheme.fromSeed` with one brand seed color.
- Light + dark `ThemeData` from the same seed; theme mode (light/dark/system) persisted in settings.
- All spacing/typography via theme; no hard-coded colors in widgets.

## Localization

- `flutter_localizations` + ARB files (`lib/l10n/`), `intl` codegen.
- V1 ships `en` only; all user-facing strings through localization from the first widget — retrofitting is the expensive path.

## State Management

- Riverpod. Screen state in `AsyncNotifier`s; ephemeral widget state (text controllers, animation) stays in `StatefulWidget`s.
- Session-scoped state (current practice session, running mock exam with timer) in dedicated notifiers, invalidated on session end.

## Shared Components (`core/widgets/`)

Only extracted after second usage (rule of three relaxed to two): `AppScaffold`, `LoadingView`, `ErrorView` (retry callback), `QuestionCard`, `AnswerOption`, `StatTile`, `ConfirmDialog`.

## Responsiveness & Accessibility

- Breakpoint at 600 /  1024 logical px: single column phone, constrained-width content on tablet/web, side navigation rail on wide layouts.
- Semantics labels on interactive elements; text scales with system settings; contrast per Material 3 defaults; touch targets ≥ 48 dp.

## Performance Practices

- Const constructors, `ListView.builder`, cached network images for question images, pagination for question lists.
- No animations beyond Material defaults (product requirement: minimal animations).
