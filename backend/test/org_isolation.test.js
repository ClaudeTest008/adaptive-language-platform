// Multi-tenant isolation tests (ADR-0012). The core enterprise guarantee:
// no tenant can access another tenant's data — proven against the emulator.
const { test, before, after } = require("node:test");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const fs = require("node:fs");
const path = require("node:path");

let env;

const orgQuestion = {
  examId: "exam1",
  topicId: "signs",
  text: { en: "Org question?" },
  explanation: { en: "Because." },
  answers: [{ en: "A" }, { en: "B" }],
  correctIndex: 0,
  status: "draft",
  version: 1,
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-rules-test-orgs",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "firestore.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 8080,
    },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc("orgs/acme").set({ name: "Acme Driving School" });
    await db.doc("orgs/globex").set({ name: "Globex University" });
    // acme members: owner-alice, editor-eve, member-mia
    await db.doc("orgs/acme/members/alice").set({ role: "owner" });
    await db.doc("orgs/acme/members/eve").set({ role: "editor" });
    await db.doc("orgs/acme/members/mia").set({ role: "member" });
    // globex member: bob
    await db.doc("orgs/globex/members/bob").set({ role: "owner" });
    await db.doc("orgs/acme/questions/q1").set(orgQuestion);
    await db.doc("orgs/globex/questions/q1").set(orgQuestion);
    await db.doc("orgs/acme/analytics/summary").set({ users: 3 });
  });
});

after(async () => {
  await env.cleanup();
});

const as = (uid, claims) =>
  env.authenticatedContext(uid, claims).firestore();

// ---------- tenant isolation ----------

test("member of one org cannot read another org's data", async () => {
  // bob (globex) cannot touch acme in any collection
  await assertFails(as("bob").doc("orgs/acme").get());
  await assertFails(as("bob").doc("orgs/acme/questions/q1").get());
  await assertFails(as("bob").doc("orgs/acme/members/alice").get());
  await assertFails(as("bob").doc("orgs/acme/analytics/summary").get());
  // and cannot write himself into acme
  await assertFails(
    as("bob").doc("orgs/acme/members/bob").set({ role: "owner" })
  );
});

test("members read their own org", async () => {
  await assertSucceeds(as("mia").doc("orgs/acme").get());
  await assertSucceeds(as("mia").doc("orgs/acme/questions/q1").get());
});

test("non-member signed-in user has no org access at all", async () => {
  await assertFails(as("stranger").doc("orgs/acme").get());
  await assertFails(as("stranger").doc("orgs/acme/questions/q1").get());
});

// ---------- roles ----------

test("editor writes org content; plain member cannot", async () => {
  await assertSucceeds(
    as("eve").doc("orgs/acme/questions/q2").set(orgQuestion)
  );
  await assertFails(
    as("mia").doc("orgs/acme/questions/q3").set(orgQuestion)
  );
});

test("owner manages members; editor cannot", async () => {
  await assertSucceeds(
    as("alice").doc("orgs/acme/members/newbie").set({ role: "member" })
  );
  await assertFails(
    as("eve").doc("orgs/acme/members/friend").set({ role: "member" })
  );
  // invalid role rejected even for owner
  await assertFails(
    as("alice").doc("orgs/acme/members/x").set({ role: "superuser" })
  );
});

test("member cannot escalate own role", async () => {
  await assertFails(
    as("mia").doc("orgs/acme/members/mia").set({ role: "owner" })
  );
});

// ---------- content validation + analytics ----------

test("org content writes are shape-validated", async () => {
  await assertFails(
    as("eve")
      .doc("orgs/acme/questions/bad")
      .set({ ...orgQuestion, correctIndex: 9 })
  );
  await assertFails(
    as("eve")
      .doc("orgs/acme/questions/bad2")
      .set({ ...orgQuestion, status: "live" })
  );
});

test("analytics are read-only for everyone including owners", async () => {
  await assertSucceeds(as("alice").doc("orgs/acme/analytics/summary").get());
  await assertFails(
    as("alice").doc("orgs/acme/analytics/summary").set({ users: 99 })
  );
});

// ---------- platform operator ----------

test("platform admin retains operator access", async () => {
  const admin = as("root", { admin: true });
  await assertSucceeds(admin.doc("orgs/acme/questions/q1").get());
  await assertSucceeds(admin.doc("orgs/globex/questions/q1").get());
  await assertSucceeds(admin.doc("orgs/new-org").set({ name: "New Org" }));
});
