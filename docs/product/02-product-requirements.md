# Product Requirements

## Functional Requirements

### FR-1 Authentication
- FR-1.1 Register with email and password.
- FR-1.2 Login with email and password.
- FR-1.3 Password reset via email.
- FR-1.4 Logout.
- FR-1.5 Sessions persist across app restarts until logout.

### FR-2 User Profile
- FR-2.1 View and edit display name and country.
- FR-2.2 Selected exam category stored on profile (V1: driver's license only, but stored as a category reference).

### FR-3 Practice Mode
- FR-3.1 User selects a topic (or all topics) and practices questions one at a time.
- FR-3.2 Immediate feedback after each answer: correct/incorrect plus the correct answer.
- FR-3.3 Every question shows a written explanation after answering.
- FR-3.4 User can bookmark/unbookmark any question.
- FR-3.5 Incorrect answers are recorded; user can start a review session containing only previously-incorrect questions.
- FR-3.6 Practice sessions have no timer and no pass/fail.

### FR-4 Mock Exams
- FR-4.1 Mock exam draws N random questions across topics, matching the real exam's composition (N and pass threshold configured per exam in the database).
- FR-4.2 Countdown timer; exam auto-submits at zero.
- FR-4.3 Score, pass/fail verdict, and per-question review shown at completion.
- FR-4.4 All attempts stored with date, score, duration, and per-question answers.

### FR-5 Progress Dashboard
- FR-5.1 Overall statistics: questions answered, accuracy, mock exams taken, pass rate.
- FR-5.2 Per-topic accuracy; topics below a threshold flagged as weak topics.
- FR-5.3 Study history: attempts over time.

### FR-6 Search
- FR-6.1 Search question text within the user's exam category.

### FR-7 Settings
- FR-7.1 Theme: light / dark / system.
- FR-7.2 Language selection (V1 ships English; localization scaffolding in place).
- FR-7.3 Account deletion (required by app store policies).

### FR-8 Admin Panel (web)
- FR-8.1 Admin login (role-gated; same Firebase Auth).
- FR-8.2 CRUD for exams (name, category, country, question count, pass threshold, time limit).
- FR-8.3 CRUD for questions (text, image, answers, correct answer, explanation, topic).
- FR-8.4 Image upload to Firebase Storage with reference from questions.
- FR-8.5 User list with disable/enable and role assignment.
- FR-8.6 Basic analytics: user counts, attempts, per-question accuracy.

## Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | Platforms: Android, iOS, web from one Flutter codebase |
| NFR-2 | Material Design 3, light and dark themes, responsive layout |
| NFR-3 | Accessibility: screen-reader labels, sufficient contrast, scalable text |
| NFR-4 | Cold start under 3 s on mid-range devices; question navigation feels instant (< 100 ms perceived) |
| NFR-5 | Offline-friendly: Firestore offline persistence enabled; previously loaded questions usable without connectivity; mock exam submissions queue until online |
| NFR-6 | Security: Firestore security rules enforce least privilege; admin operations verified server-side; no secrets in client code |
| NFR-7 | Privacy: analytics anonymized; account deletion removes personal data |
| NFR-8 | Testability: domain logic unit-tested; critical flows covered by widget and integration tests |
| NFR-9 | Maintainability: Clean Architecture, SOLID, dependency injection, documented ADRs |
| NFR-10 | Scalability: Firestore schema supports multiple categories, countries, and languages without migration of V1 data |
