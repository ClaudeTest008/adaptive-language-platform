# Application Architecture

## Layer Responsibilities

### Domain (innermost, pure Dart)
- Entities: `User`, `ExamCategory`, `Country`, `Exam`, `Topic`, `Question`, `Answer`, `Attempt`, `AttemptAnswer`, `Bookmark`, `TopicStats`.
- Value objects where invariants matter (e.g., `Score`, `Percentage`).
- Repository interfaces: `AuthRepository`, `QuestionRepository`, `AttemptRepository`, `BookmarkRepository`, `StatsRepository`, `AdminRepository`.
- Failures: sealed `Failure` hierarchy (`NetworkFailure`, `AuthFailure`, `PermissionFailure`, `NotFoundFailure`, `UnexpectedFailure`).
- No Flutter, no Firebase, no I/O.

### Application
- Use cases as callable classes, one responsibility each: `SignIn`, `SignUp`, `ResetPassword`, `StartPracticeSession`, `SubmitAnswer`, `ToggleBookmark`, `StartMockExam`, `SubmitMockExam`, `GetDashboardStats`, `SearchQuestions`, admin use cases.
- Orchestrates repositories; owns business rules that span entities (e.g., mock exam composition, pass/fail evaluation, weak-topic threshold).
- Returns `Result<T, Failure>` (simple sealed result type in `core/`), never throws across the boundary.

### Infrastructure
- Firebase implementations of repository interfaces.
- DTOs with `fromFirestore` / `toFirestore`; mappers DTO ↔ entity. Entities never serialize themselves.
- Maps `FirebaseException` / `FirebaseAuthException` codes to domain `Failure`s in one place per repository.

### Presentation
- Screens + widgets; Riverpod `Notifier`/`AsyncNotifier` controllers per screen.
- Controllers call use cases only. Widgets watch controllers. No business logic in widgets.

## Dependency Injection

Riverpod providers wire everything (ADR-0002):

```dart
final questionRepositoryProvider = Provider<QuestionRepository>(
  (ref) => FirestoreQuestionRepository(ref.watch(firestoreProvider)),
);
final submitAnswerProvider = Provider(
  (ref) => SubmitAnswer(ref.watch(attemptRepositoryProvider)),
);
```

- Firebase instances (`FirebaseAuth`, `FirebaseFirestore`, etc.) exposed via core providers; tests override them with fakes.
- No service locator, no codegen DI framework.

## Module Boundaries

V1 is a single Flutter package with feature-first folders (see `ARCHITECTURE.md`). Splitting into separate Dart packages is deferred until a second app target actually needs shared code — premature package splitting adds friction without benefit at this size. Revisit at white-label stage.

## SOLID Application

- SRP: one use case per user action; one repository per aggregate.
- OCP/LSP: new exam categories and future adaptive schedulers arrive as new data / new implementations of existing interfaces.
- ISP: repository interfaces scoped per aggregate, not one god repository.
- DIP: presentation and application depend on domain interfaces; Firebase only in infrastructure.
