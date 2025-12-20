/**
 * One-off admin script: verify a Firebase Auth user's email by address.
 *
 * Usage (from /workspace/functions):
 *   node scripts/verify-user-email.js "user@example.com"
 *
 * Auth:
 * - Uses Application Default Credentials (ADC) if available, or the default service account
 *   when run in a properly authenticated environment
 *   (e.g., Cloud Shell / CI with creds).
 */

const admin = require("firebase-admin");

/**
 * Entrypoint.
 * @return {Promise<void>}
 */
async function main() {
  const email = process.argv[2] ? String(process.argv[2]).trim() : "";
  if (!email) {
    // eslint-disable-next-line no-console
    console.error(
      "Missing email. Example: node scripts/verify-user-email.js " +
        "\"user@example.com\""
    );
    process.exit(2);
  }

  if (!admin.apps.length) {
    admin.initializeApp();
  }

  const user = await admin.auth().getUserByEmail(email);
  if (user.emailVerified) {
    // eslint-disable-next-line no-console
    console.log(`Already verified: ${email} (uid: ${user.uid})`);
    return;
  }

  await admin.auth().updateUser(user.uid, {emailVerified: true});
  // eslint-disable-next-line no-console
  console.log(`Verified: ${email} (uid: ${user.uid})`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});

