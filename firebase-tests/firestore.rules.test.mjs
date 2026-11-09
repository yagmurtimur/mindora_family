import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import test, { after, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(resolve(here, '../firestore.rules'), 'utf8');
const projectId = 'mindora-family-rules-local';

let testEnv;

const paths = {
  child: (childId) => `children/${childId}`,
  guardian: (childId, parentUid) => `children/${childId}/guardians/${parentUid}`,
  revoked: (childId, parentUid) => `children/${childId}/guardianRevocations/${parentUid}`,
  listing: (parentUid, childId) => `parents/${parentUid}/children/${childId}`,
  usage: (childId) => `children/${childId}/usageDays/2026-11-09`,
  policy: (childId) => `children/${childId}/appPolicies/social-media`,
  mood: (childId) => `children/${childId}/moods/2026-11-09`,
  device: (childId) => `children/${childId}/devices/device-${childId}`,
};

async function seedFixture({
  membership = true,
  revoked = false,
  scopes = { profileRead: true, usageRead: true, policiesRead: true },
} = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const writes = [
      setDoc(doc(db, 'accounts', 'parent-a'), {
        role: 'parent', status: 'active', displayName: 'Parent A', locale: 'en', timeZone: 'UTC',
      }),
      setDoc(doc(db, 'accounts', 'parent-b'), {
        role: 'parent', status: 'active', displayName: 'Parent B', locale: 'en', timeZone: 'UTC',
      }),
      setDoc(doc(db, 'accounts', 'child-a'), {
        role: 'child', status: 'active', displayName: 'Child A', locale: 'en', timeZone: 'UTC',
      }),
      setDoc(doc(db, 'accounts', 'child-b'), {
        role: 'child', status: 'active', displayName: 'Child B', locale: 'en', timeZone: 'UTC',
      }),
      setDoc(doc(db, paths.child('child-a')), {
        childId: 'child-a', displayName: 'Child A', timeZone: 'UTC', status: 'active', schemaVersion: 2,
      }),
      setDoc(doc(db, paths.child('child-b')), {
        childId: 'child-b', displayName: 'Child B', timeZone: 'UTC', status: 'active', schemaVersion: 2,
      }),
      setDoc(doc(db, paths.usage('child-a')), { date: '2026-11-09', totalSeconds: 3600 }),
      setDoc(doc(db, paths.usage('child-b')), { date: '2026-11-09', totalSeconds: 1800 }),
      setDoc(doc(db, paths.policy('child-a')), { policyId: 'social-media', enabled: true }),
      setDoc(doc(db, paths.policy('child-b')), { policyId: 'social-media', enabled: true }),
      setDoc(doc(db, paths.mood('child-a')), { date: '2026-11-09', timeZone: 'UTC', moodCode: 'good' }),
      setDoc(doc(db, paths.device('child-a')), { ownerChildId: 'child-a', enrollmentState: 'active' }),
      setDoc(doc(db, paths.device('child-b')), { ownerChildId: 'child-b', enrollmentState: 'active' }),
    ];

    if (membership) {
      writes.push(
        setDoc(doc(db, paths.guardian('child-a', 'parent-a')), {
          parentUid: 'parent-a', childId: 'child-a', relationshipId: 'relationship-a',
          status: 'accepted', acceptedAt: new Date(), allowedDataScopes: scopes,
          consentPolicyVersion: 'v1', updatedAt: new Date(),
        }),
        setDoc(doc(db, paths.listing('parent-a', 'child-a')), {
          parentUid: 'parent-a', childId: 'child-a', relationshipId: 'relationship-a',
          status: 'accepted', acceptedAt: new Date(), updatedAt: new Date(),
        }),
      );
    }
    if (revoked) {
      writes.push(setDoc(doc(db, paths.revoked('child-a', 'parent-a')), {
        parentUid: 'parent-a', childId: 'child-a', relationshipId: 'relationship-a',
        revokedAt: new Date(), reasonCode: 'requested', updatedAt: new Date(),
      }));
    }
    await Promise.all(writes);
  });
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

test('unauthenticated access is denied', async () => {
  await seedFixture();
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, paths.usage('child-a'))));
  await assertFails(getDocs(collection(db, 'parents', 'parent-a', 'children')));
});

test('an unrelated parent cannot read another child', async () => {
  await seedFixture();
  await assertFails(getDoc(doc(dbFor('parent-b'), paths.usage('child-a'))));
});

test('a parent is denied before invitation acceptance/membership creation', async () => {
  await seedFixture({ membership: false });
  await assertFails(getDoc(doc(dbFor('parent-a'), paths.usage('child-a'))));
});

test('an accepted parent reads only explicitly permitted child data', async () => {
  await seedFixture({ scopes: { profileRead: true, usageRead: true } });
  const db = dbFor('parent-a');
  await assertSucceeds(getDoc(doc(db, paths.child('child-a'))));
  await assertSucceeds(getDoc(doc(db, paths.usage('child-a'))));
  await assertFails(getDoc(doc(db, paths.mood('child-a'))));
  await assertFails(getDoc(doc(db, paths.usage('child-b'))));
});

test('a revocation marker immediately denies a stale guardian membership', async () => {
  await seedFixture({ revoked: true });
  await assertFails(getDoc(doc(dbFor('parent-a'), paths.usage('child-a'))));
});

test('a child cannot change their own role or another account', async () => {
  await seedFixture();
  const child = dbFor('child-a');
  await assertFails(updateDoc(doc(child, 'accounts', 'child-a'), { role: 'parent' }));
  await assertFails(updateDoc(doc(child, 'accounts', 'parent-a'), { displayName: 'Compromised' }));
});

test('a child cannot assign themselves a parent or fabricate a guardian membership', async () => {
  await seedFixture();
  const child = dbFor('child-a');
  await assertFails(setDoc(doc(child, paths.guardian('child-a', 'parent-b')), {
    parentUid: 'parent-b', childId: 'child-a', relationshipId: 'forged', status: 'accepted',
    allowedDataScopes: { usageRead: true }, consentPolicyVersion: 'v1', updatedAt: new Date(),
  }));
  await assertFails(setDoc(doc(child, paths.listing('parent-a', 'child-a')), {
    parentUid: 'parent-a', childId: 'child-a', relationshipId: 'forged', status: 'accepted',
  }));
});

test('a parent cannot fabricate membership or modify another parent policy', async () => {
  await seedFixture();
  const parent = dbFor('parent-a');
  await assertFails(setDoc(doc(parent, paths.guardian('child-b', 'parent-a')), {
    parentUid: 'parent-a', childId: 'child-b', relationshipId: 'forged', status: 'accepted',
    allowedDataScopes: { usageRead: true }, consentPolicyVersion: 'v1', updatedAt: new Date(),
  }));
  await assertFails(updateDoc(doc(parent, paths.policy('child-b')), { enabled: false }));
});

test('a parent lists multiple accepted children only through their own mirror', async () => {
  await seedFixture();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, paths.guardian('child-b', 'parent-a')), {
        parentUid: 'parent-a', childId: 'child-b', relationshipId: 'relationship-b',
        status: 'accepted', acceptedAt: new Date(), allowedDataScopes: { usageRead: true },
        consentPolicyVersion: 'v1', updatedAt: new Date(),
      }),
      setDoc(doc(db, paths.listing('parent-a', 'child-b')), {
        parentUid: 'parent-a', childId: 'child-b', relationshipId: 'relationship-b',
        status: 'accepted', acceptedAt: new Date(), updatedAt: new Date(),
      }),
    ]);
  });
  const parent = dbFor('parent-a');
  await assertSucceeds(getDocs(collection(parent, 'parents', 'parent-a', 'children')));
  await assertSucceeds(getDoc(doc(parent, paths.usage('child-b'))));
  await assertFails(getDocs(collection(parent, 'parents', 'parent-b', 'children')));
});

test('one child/device identity cannot access another child device data', async () => {
  await seedFixture();
  await assertSucceeds(getDoc(doc(dbFor('child-a'), paths.device('child-a'))));
  await assertFails(getDoc(doc(dbFor('child-a'), paths.device('child-b'))));
  await assertFails(setDoc(doc(dbFor('child-a'), paths.device('child-b')), {
    ownerChildId: 'child-b', enrollmentState: 'active',
  }));
});

test('invalid fields and types are rejected', async () => {
  await seedFixture();
  const child = dbFor('child-a');
  await assertFails(updateDoc(doc(child, paths.child('child-a')), { displayName: 7 }));
  await assertFails(updateDoc(doc(child, paths.child('child-a')), { parentId: 'parent-a' }));
  await assertFails(setDoc(doc(child, paths.mood('child-a')), {
    date: '2026-11-09', timeZone: 'UTC', moodCode: 'not-allowlisted', extra: true,
  }));
});

test('the deterministic parent listing mirror never grants child data access', async () => {
  await seedFixture({ membership: false });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, paths.listing('parent-a', 'child-a')), {
      parentUid: 'parent-a', childId: 'child-a', relationshipId: 'stale', status: 'accepted',
    });
  });
  const parent = dbFor('parent-a');
  await assertSucceeds(getDocs(collection(parent, 'parents', 'parent-a', 'children')));
  await assertFails(getDoc(doc(parent, paths.usage('child-a'))));
});

test('rule test fixture contains the expected local project identifier', () => {
  assert.equal(projectId, 'mindora-family-rules-local');
});
