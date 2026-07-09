#!/usr/bin/env node
// Bootstrap the first admin: node scripts/set-admin.js <uid>
// Requires GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key.
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

const uid = process.argv[2];
if (!uid) {
  console.error("Usage: node scripts/set-admin.js <uid>");
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
getAuth()
  .setCustomUserClaims(uid, { admin: true })
  .then(() => console.log(`admin claim set for ${uid} (user must re-login)`))
  .catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
