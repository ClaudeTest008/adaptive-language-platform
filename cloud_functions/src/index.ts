import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import * as functionsV1 from "firebase-functions/v1";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

initializeApp();
const db = getFirestore();
const auth = getAuth();

/**
 * Creates the Firestore user profile when an auth account is created.
 * Auth triggers are v1-only; everything else uses v2.
 */
export const onUserCreate = functionsV1.auth.user().onCreate(async (user) => {
  await db.doc(`users/${user.uid}`).set({
    displayName: user.displayName ?? "",
    countryId: null,
    categoryId: null,
    examId: null,
    settings: { themeMode: "system", locale: "en" },
    disabled: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  logger.info("User profile created", { uid: user.uid });
});

/**
 * Grants or revokes the admin custom claim. Callable by existing admins only.
 * The first admin is bootstrapped manually (see docs/deployment/).
 */
export const setUserRole = onCall<{ uid: string; admin: boolean }>(
  async (request) => {
    if (request.auth?.token.admin !== true) {
      throw new HttpsError("permission-denied", "Admin privileges required.");
    }
    const { uid, admin } = request.data;
    if (typeof uid !== "string" || uid.length === 0 || typeof admin !== "boolean") {
      throw new HttpsError("invalid-argument", "Expected { uid: string, admin: boolean }.");
    }
    if (uid === request.auth.uid && !admin) {
      throw new HttpsError("failed-precondition", "Admins cannot revoke their own role.");
    }
    await auth.setCustomUserClaims(uid, admin ? { admin: true } : null);
    logger.info("Role updated", { target: uid, admin, by: request.auth.uid });
    return { ok: true };
  }
);

/**
 * Account deletion (FR-7.3): purges all user-owned data, then deletes the
 * auth account. Callable only by the account owner.
 */
export const deleteUserData = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  for (const sub of ["bookmarks", "incorrect", "attempts", "topicStats"]) {
    await db.recursiveDelete(db.collection(`users/${uid}/${sub}`));
  }
  await db.doc(`users/${uid}`).delete();
  await auth.deleteUser(uid);
  logger.info("User data deleted", { uid });
  return { ok: true };
});

/**
 * Daily roll-up of per-question accuracy from the last 24h of attempts
 * into /questionStats for admin analytics.
 */
export const aggregateQuestionStats = onSchedule("every day 03:00", async () => {
  const since = Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
  const attempts = await db
    .collectionGroup("attempts")
    .where("completedAt", ">=", since)
    .get();

  const tally = new Map<string, { examId: string; answered: number; correct: number }>();
  for (const doc of attempts.docs) {
    const answers = (doc.get("answers") ?? []) as Array<{
      questionId: string;
      correct: boolean;
    }>;
    const examId = doc.get("examId") as string;
    for (const a of answers) {
      const entry = tally.get(a.questionId) ?? { examId, answered: 0, correct: 0 };
      entry.answered += 1;
      if (a.correct) entry.correct += 1;
      tally.set(a.questionId, entry);
    }
  }

  const writer = db.bulkWriter();
  for (const [questionId, stats] of tally) {
    writer.set(
      db.doc(`questionStats/${questionId}`),
      {
        examId: stats.examId,
        answered: FieldValue.increment(stats.answered),
        correct: FieldValue.increment(stats.correct),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await writer.close();
  logger.info("Question stats aggregated", {
    attempts: attempts.size,
    questions: tally.size,
  });
});
