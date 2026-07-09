# Firebase Setup (Epic 4 — human steps)

One-time interactive steps that require a human with a Google account. Everything referenced already exists in the repository.

## 1. Install tooling

```bash
npm install -g firebase-tools   # Firebase CLI
# Java 11+ required for the Firestore emulator (rules tests)
```

## 2. Create projects

Two Firebase projects: `adaptive-exam-dev`, `adaptive-exam-prod` (names may vary; ids recorded in `.firebaserc`, which is gitignored — see note below).

```bash
firebase login
firebase projects:create adaptive-exam-dev
firebase projects:create adaptive-exam-prod
firebase use --add   # alias "dev" and "prod"
```

Enable in the console for each project: Authentication (Email/Password provider), Firestore (production mode), Storage, Analytics. Set Auth password policy minimum length to 8.

## 3. Deploy database artifacts

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage --project dev
```

## 4. Deploy functions

```bash
cd cloud_functions && npm install && cd ..
firebase deploy --only functions --project dev
```

Functions: `onUserCreate`, `setUserRole`, `deleteUserData`, `aggregateQuestionStats` (see `cloud_functions/src/index.ts`).

## 5. Bootstrap first admin

Register a user via the app (or Auth console), then set the claim once with a local Admin SDK script:

```bash
node scripts/set-admin.js <uid>   # uses GOOGLE_APPLICATION_CREDENTIALS
```

Subsequent admins are managed in-app via `setUserRole`.

## 6. Flutter wiring (Epic 5)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=adaptive-exam-dev   # generates firebase_options.dart
```

## Notes

- `.firebaserc` is gitignored so forks/white-labels don't inherit project ids; each environment runs `firebase use --add` once.
- Service-account JSON files must never be committed (gitignore pattern in place).
- Rules emulator tests: `firebase emulators:exec --only firestore "npm --prefix backend test"` — test suite lands with Epic 11.
