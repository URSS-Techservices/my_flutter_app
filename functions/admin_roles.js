/**
 * Staff roles for the admin dashboard, stored as Firebase Auth custom
 * claims (`role`). Firestore rules read them from `request.auth.token.role`.
 * A claim can only be set by server code, so nobody can make themselves an
 * admin by editing their own user document.
 *
 * Roles:
 *   admin     — full access (you)
 *   moderator — interns: review and remove posts, comments, stories,
 *               reviews; handle feedback and reports. No chats, no
 *               earnings, no app config, cannot give out roles.
 *
 * The first admin is set with scripts/set_role.js; after that, admins can
 * give or remove roles from the dashboard through this callable.
 */
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

const ROLES = ['admin', 'moderator'];

exports.setUserRole = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only admins can change roles.');
  }
  const uid = String((request.data && request.data.uid) || '').trim();
  const role = request.data ? request.data.role : null;
  if (!uid) throw new HttpsError('invalid-argument', 'uid is required.');
  if (role !== null && !ROLES.includes(role)) {
    throw new HttpsError('invalid-argument', `role must be one of ${ROLES.join(', ')} or null.`);
  }
  if (uid === request.auth.uid && role !== 'admin') {
    throw new HttpsError('failed-precondition', 'You cannot remove your own admin role.');
  }

  const user = await admin.auth().getUser(uid);
  const claims = { ...(user.customClaims || {}) };
  if (role) claims.role = role;
  else delete claims.role;
  await admin.auth().setCustomUserClaims(uid, claims);

  // Visible record for the dashboard; rules make it read-only for clients.
  await admin.firestore().collection('staff_roles').doc(uid).set({
    role: role || null,
    updatedBy: request.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { uid, role: role || null };
});

exports.ROLES = ROLES;
