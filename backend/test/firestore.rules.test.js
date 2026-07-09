// Firestore security rules tests. Run via `npm test` in backend/
// (firebase emulators:exec wraps the emulator). Cases follow
// docs/database/02-security-rules-and-validation.md.
const { test, before, after } = require("node:test");
const assert = require("node:assert");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const fs = require("node:fs");
const path = require("node:path");

let env;

const publishedQuestion = {
  examId: "exam1",
  topicId: "signs",
  text: { en: "What does a red octagon mean?" },
  explanation: { en: "Stop sign." },
  answers: [{ en: "Stop" }, { en: "Yield" }],
  correctIndex: 0,
  status: "published",
  version: 1,
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-rules-test",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "firestore.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 8080,
    },
  });
  // Seed content as the backend (bypasses rules, like the Admin SDK).
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc("questions/pub1").set(publishedQuestion);
    await db.doc("questions/draft1").set({
      ...publishedQuestion,
      status: "draft",
    });
    await db.doc("users/alice").set({
      displayName: "Alice",
      disabled: false,
      createdAt: new Date(),
    });
  });
});

after(async () => {
  await env.cleanup();
});

const anon = () => env.unauthenticatedContext().firestore();
const alice = () => env.authenticatedContext("alice").firestore();
const bob = () => env.authenticatedContext("bob").firestore();
const admin = () =>
  env.authenticatedContext("root", { admin: true }).firestore();

// ---------- content visibility ----------

test("anonymous cannot read anything", async () => {
  await assertFails(anon().doc("questions/pub1").get());
  await assertFails(anon().doc("users/alice").get());
});

test("signed-in user reads published questions only", async () => {
  await assertSucceeds(alice().doc("questions/pub1").get());
  await assertFails(alice().doc("questions/draft1").get());
});

test("admin reads drafts", async () => {
  await assertSucceeds(admin().doc("questions/draft1").get());
});

// ---------- content writes ----------

test("non-admin cannot write content", async () => {
  await assertFails(alice().doc("questions/new1").set(publishedQuestion));
});

test("admin write with valid shape succeeds", async () => {
  await assertSucceeds(admin().doc("questions/new1").set(publishedQuestion));
});

test("admin write with invalid status rejected", async () => {
  await assertFails(
    admin()
      .doc("questions/bad1")
      .set({ ...publishedQuestion, status: "live" })
  );
});

test("admin write with out-of-range correctIndex rejected", async () => {
  await assertFails(
    admin()
      .doc("questions/bad2")
      .set({ ...publishedQuestion, correctIndex: 5 })
  );
});

// ---------- version history immutability ----------

test("versions: admin create-only, never update or delete", async () => {
  const ref = "questionVersions/pub1/versions/1";
  await assertSucceeds(admin().doc(ref).set(publishedQuestion));
  await assertFails(
    admin().doc(ref).set({ ...publishedQuestion, version: 99 })
  );
  await assertFails(admin().doc(ref).delete());
  await assertFails(alice().doc(ref).get());
});

// ---------- user data isolation ----------

test("user cannot read another user's profile", async () => {
  await assertFails(bob().doc("users/alice").get());
  await assertSucceeds(alice().doc("users/alice").get());
});

test("owner cannot flip own 'disabled' flag", async () => {
  await assertFails(
    alice().doc("users/alice").update({ disabled: true })
  );
  await assertSucceeds(
    alice().doc("users/alice").update({ displayName: "Alice B" })
  );
});

// ---------- attempts immutability ----------

test("attempts: owner create-only, immutable afterwards", async () => {
  const attempt = {
    type: "practice",
    examId: "exam1",
    score: 1,
    total: 2,
    answers: [],
  };
  const ref = "users/alice/attempts/a1";
  await assertSucceeds(alice().doc(ref).set(attempt));
  await assertFails(alice().doc(ref).update({ score: 2 }));
  await assertFails(alice().doc(ref).delete());
  await assertFails(bob().doc(ref).get());
});

// ---------- learner model ----------

test("learner model: owner only, admins excluded, shape validated", async () => {
  const model = { totalAnswered: 4, totalCorrect: 2 };
  const ref = "users/alice/learnerModel/exam1";
  await assertSucceeds(alice().doc(ref).set(model));
  await assertSucceeds(alice().doc(ref).get());
  await assertFails(bob().doc(ref).get());
  await assertFails(admin().doc(ref).get()); // learner privacy
  await assertFails(
    alice().doc(ref).set({ totalAnswered: 1, totalCorrect: 5 }) // correct > answered
  );
});

// ---------- import jobs ----------

test("import jobs: admin create/read, immutable, hidden from users", async () => {
  const job = { imported: 2, rejected: 1, duplicates: 0 };
  await assertSucceeds(admin().doc("importJobs/j1").set(job));
  await assertFails(admin().doc("importJobs/j1").update({ imported: 99 }));
  await assertFails(alice().doc("importJobs/j1").get());
  await assertFails(alice().doc("importJobs/j2").set(job));
});

// ---------- default deny ----------

test("unknown collections denied even for admins", async () => {
  await assertFails(admin().doc("random/x").set({ a: 1 }));
  await assertFails(alice().doc("random/x").get());
});
