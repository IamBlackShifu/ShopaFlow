import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rules = await readFile(resolve(here, '../../firestore.rules'), 'utf8');
const testEnv = await initializeTestEnvironment({
  projectId: 'demo-shopaflow-rbac',
  firestore: { rules },
});

const companyId = 'company-a';
const storeId = 'store-a';
const registerId = 'register-a';
const ownerId = 'owner-a';
const superAdminId = 'RAKsm1i4I3TLQA17nJulIZOx8ip2';

async function seedCompany(extraMembers = []) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'companies', companyId), {
      id: companyId,
      name: 'Company A',
      owner_user_id: ownerId,
      subscription_status: 'active',
      operating_status: 'active',
    });
    await setDoc(doc(db, 'companies', companyId, 'stores', storeId), {
      id: storeId,
      company_id: companyId,
      name: 'Main store',
    });
    for (const member of [{ uid: ownerId, role: 'owner' }, ...extraMembers]) {
      await setDoc(doc(db, 'companies', companyId, 'users', member.uid), {
        id: member.uid,
        company_id: companyId,
        store_id: storeId,
        register_id: registerId,
        email: `${member.uid}@example.test`,
        role: member.role,
      });
      await setDoc(doc(db, 'user_memberships', member.uid, 'companies', companyId), {
        company_id: companyId,
        company_name: 'Company A',
        user_id: member.uid,
        store_id: storeId,
        register_id: registerId,
        email: `${member.uid}@example.test`,
        role: member.role,
      });
    }
  });
}

function provisionEmployee(db, uid, role) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'companies', companyId, 'users', uid), {
    id: uid,
    company_id: companyId,
    store_id: storeId,
    register_id: registerId,
    email: `${uid}@example.test`,
    role,
  });
  batch.set(doc(db, 'user_memberships', uid, 'companies', companyId), {
    company_id: companyId,
    company_name: 'Company A',
    user_id: uid,
    store_id: storeId,
    register_id: registerId,
    email: `${uid}@example.test`,
    role,
  });
  return batch.commit();
}

async function run(name, test) {
  await testEnv.clearFirestore();
  try {
    await test();
    console.log(`PASS ${name}`);
  } catch (error) {
    console.error(`FAIL ${name}`);
    throw error;
  }
}

try {
  await run('owner can atomically create an admin', async () => {
    await seedCompany();
    const db = testEnv.authenticatedContext(ownerId).firestore();
    await assertSucceeds(provisionEmployee(db, 'admin-new', 'admin'));
  });

  await run('admin can create managers but cannot create peer admins', async () => {
    await seedCompany([{ uid: 'admin-a', role: 'admin' }]);
    const db = testEnv.authenticatedContext('admin-a').firestore();
    await assertSucceeds(provisionEmployee(db, 'manager-new', 'manager'));
    await assertFails(provisionEmployee(db, 'admin-new', 'admin'));
  });

  await run('manager cannot create employees', async () => {
    await seedCompany([{ uid: 'manager-a', role: 'manager' }]);
    const db = testEnv.authenticatedContext('manager-a').firestore();
    await assertFails(provisionEmployee(db, 'cashier-new', 'cashier'));
  });

  await run('cashier can read self but cannot enumerate another team member', async () => {
    await seedCompany([
      { uid: 'admin-a', role: 'admin' },
      { uid: 'cashier-a', role: 'cashier' },
    ]);
    const db = testEnv.authenticatedContext('cashier-a').firestore();
    await assertSucceeds(getDoc(doc(db, 'companies', companyId, 'users', 'cashier-a')));
    await assertFails(getDoc(doc(db, 'companies', companyId, 'users', 'admin-a')));
  });

  await run('manager can read the company team for back-office reporting', async () => {
    await seedCompany([
      { uid: 'manager-a', role: 'manager' },
      { uid: 'cashier-a', role: 'cashier' },
    ]);
    const db = testEnv.authenticatedContext('manager-a').firestore();
    await assertSucceeds(getDoc(doc(db, 'companies', companyId, 'users', 'cashier-a')));
  });

  await run('role mirrors must change atomically', async () => {
    await seedCompany([{ uid: 'manager-a', role: 'manager' }]);
    const db = testEnv.authenticatedContext(ownerId).firestore();
    await assertFails(setDoc(
      doc(db, 'companies', companyId, 'users', 'manager-a'),
      { role: 'cashier' },
      { merge: true },
    ));
    const batch = writeBatch(db);
    batch.set(doc(db, 'companies', companyId, 'users', 'manager-a'), { role: 'cashier' }, { merge: true });
    batch.set(doc(db, 'user_memberships', 'manager-a', 'companies', companyId), { role: 'cashier' }, { merge: true });
    await assertSucceeds(batch.commit());
  });

  await run('tenant and identity fields cannot be reassigned', async () => {
    await seedCompany([{ uid: 'cashier-a', role: 'cashier' }]);
    const db = testEnv.authenticatedContext(ownerId).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'companies', companyId, 'users', 'cashier-a'), { company_id: 'company-b' }, { merge: true });
    batch.set(doc(db, 'user_memberships', 'cashier-a', 'companies', companyId), { company_id: 'company-b' }, { merge: true });
    await assertFails(batch.commit());
  });

  await run('super admin can list shops and pause a subscription', async () => {
    await seedCompany();
    const db = testEnv.authenticatedContext(superAdminId).firestore();
    await assertSucceeds(getDocs(collection(db, 'companies')));
    await assertSucceeds(updateDoc(doc(db, 'companies', companyId), {
      subscription_status: 'pending',
      operating_status: 'paused',
      suspension_reason: 'Subscription payment pending',
      subscription_updated_at: '2026-09-23T00:00:00.000Z',
      subscription_updated_by: superAdminId,
      subscription_started_at: '2026-09-23T00:00:00.000Z',
      billing_cycle_days: 30,
      last_payment_at: '2026-09-23T00:00:00.000Z',
      next_payment_due_at: '2026-10-23T00:00:00.000Z',
      last_payment_amount: 10,
      billing_currency: 'USD',
      payment_reference: 'TEST-001',
      payment_count: 1,
    }));
  });

  await run('bootstrap super admin can register a platform administrator', async () => {
    await seedCompany();
    const db = testEnv.authenticatedContext(superAdminId).firestore();
    await assertSucceeds(setDoc(doc(db, 'platform_admins', 'delegate-admin'), {
      uid: 'delegate-admin',
      role: 'super_admin',
      email: 'delegate@example.test',
    }));
    const delegatedDb = testEnv.authenticatedContext('delegate-admin').firestore();
    await assertSucceeds(getDocs(collection(delegatedDb, 'companies')));
  });

  await run('ordinary users cannot grant themselves platform access', async () => {
    await seedCompany();
    const db = testEnv.authenticatedContext(ownerId).firestore();
    await assertFails(setDoc(doc(db, 'platform_admins', ownerId), {
      uid: ownerId,
      role: 'super_admin',
    }));
  });

  await run('company owners cannot alter protected subscription fields', async () => {
    await seedCompany();
    const db = testEnv.authenticatedContext(ownerId).firestore();
    await assertFails(updateDoc(doc(db, 'companies', companyId), {
      subscription_status: 'pending',
      operating_status: 'paused',
      next_payment_due_at: '2026-10-23T00:00:00.000Z',
    }));
  });

  await run('paused shops cannot create operational records', async () => {
    await seedCompany();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'companies', companyId), {
        subscription_status: 'pending',
        operating_status: 'paused',
      });
    });
    const db = testEnv.authenticatedContext(ownerId).firestore();
    await assertFails(setDoc(doc(db, 'companies', companyId, 'products', 'product-a'), {
      id: 'product-a',
      company_id: companyId,
      store_id: storeId,
      name: 'Blocked product',
    }));
  });
} finally {
  await testEnv.cleanup();
}
