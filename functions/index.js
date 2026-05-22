const admin = require('firebase-admin');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

admin.initializeApp();

const db = admin.firestore();

function cleanString(value, fallback = '') {
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

async function assertOwnerOrAdmin(companyId, uid) {
  const memberSnap = await db.doc(`companies/${companyId}/users/${uid}`).get();
  const role = memberSnap.data()?.role;
  if (role !== 'owner' && role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only owners and admins can create employees.');
  }
  return role;
}

exports.createEmployee = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }

  const companyId = cleanString(request.data.companyId);
  const storeId = cleanString(request.data.storeId);
  const email = cleanString(request.data.email).toLowerCase();
  const password = cleanString(request.data.password);
  const name = cleanString(request.data.name, email);
  const role = cleanString(request.data.role, 'cashier').toLowerCase();

  if (!companyId || !storeId || !email || !password) {
    throw new HttpsError('invalid-argument', 'Company, store, email, and password are required.');
  }
  if (!['admin', 'manager', 'cashier'].includes(role)) {
    throw new HttpsError('invalid-argument', 'Employee role must be admin, manager, or cashier.');
  }

  const actorRole = await assertOwnerOrAdmin(companyId, request.auth.uid);
  if (actorRole === 'admin' && role === 'admin') {
    throw new HttpsError('permission-denied', 'Only owners can create admin users.');
  }

  const storeSnap = await db.doc(`companies/${companyId}/stores/${storeId}`).get();
  if (!storeSnap.exists || storeSnap.data()?.company_id !== companyId) {
    throw new HttpsError('invalid-argument', 'Store does not belong to this company.');
  }

  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
    });
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      userRecord = await admin.auth().getUserByEmail(email);
    } else {
      throw new HttpsError('internal', error.message);
    }
  }

  const uid = userRecord.uid;
  const registerId = cleanString(request.data.registerId, `${storeId}_register`);
  const now = new Date().toISOString();
  const companySnap = await db.doc(`companies/${companyId}`).get();
  const companyName = companySnap.data()?.name || companyId;
  const member = {
    id: uid,
    company_id: companyId,
    store_id: storeId,
    register_id: registerId,
    name,
    email,
    role,
    updated_at: now,
    sync_status: 'synced',
  };
  const membership = {
    company_id: companyId,
    company_name: companyName,
    user_id: uid,
    store_id: storeId,
    register_id: registerId,
    email,
    role,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.runTransaction(async (txn) => {
    txn.set(db.doc(`companies/${companyId}/users/${uid}`), member, { merge: true });
    txn.set(db.doc(`user_memberships/${uid}/companies/${companyId}`), membership, { merge: true });
  });

  return { uid, role };
});
