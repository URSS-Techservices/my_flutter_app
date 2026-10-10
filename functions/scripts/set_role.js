/**
 * Give (or remove) a staff role from the command line. Use it once to make
 * yourself the first admin; after that use the dashboard (setUserRole).
 *
 * Prerequisites:
 *   npx firebase-tools login
 *   gcloud auth application-default login   (or GOOGLE_APPLICATION_CREDENTIALS)
 *
 * Usage:
 *   cd functions
 *   node scripts/set_role.js you@example.com admin
 *   node scripts/set_role.js intern@example.com moderator
 *   node scripts/set_role.js intern@example.com none      # remove role
 *
 * The person must sign out and back in (or wait up to 1 hour) for a new
 * role to take effect.
 */
const admin = require('firebase-admin');
const { ROLES } = require('../admin_roles');

const projectId = process.env.GCLOUD_PROJECT || 'halo-fb212';

async function main() {
  const [email, roleArg] = process.argv.slice(2);
  if (!email || !roleArg) {
    console.error('Usage: node scripts/set_role.js <email> <admin|moderator|none>');
    process.exit(1);
  }
  const role = roleArg === 'none' ? null : roleArg;
  if (role !== null && !ROLES.includes(role)) {
    console.error(`Role must be one of: ${ROLES.join(', ')}, none`);
    process.exit(1);
  }

  admin.initializeApp({ projectId });
  const user = await admin.auth().getUserByEmail(email);
  const claims = { ...(user.customClaims || {}) };
  if (role) claims.role = role;
  else delete claims.role;
  await admin.auth().setCustomUserClaims(user.uid, claims);
  await admin.firestore().collection('staff_roles').doc(user.uid).set({
    role,
    updatedBy: 'cli',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`${email} (${user.uid}) → ${role || 'no role'}`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
