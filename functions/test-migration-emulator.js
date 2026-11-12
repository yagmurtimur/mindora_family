const assert = require("node:assert/strict");
const {execFileSync} = require("node:child_process");
const path = require("node:path");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const PROJECT = "mindora-migration-audit";
const app = initializeApp({projectId: PROJECT}, "migration-audit-test");
const db = getFirestore(app);

async function seed(pathValue, data) {
  await db.doc(pathValue).set(data);
}

async function run() {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST,
      "Bu test yalnızca Firestore Emulator ile çalıştırılabilir.");

  await Promise.all([
    seed("children/child-single", {childId: "child-single"}),
    seed("children/child-conflict", {childId: "child-conflict"}),
    seed("children/child-missing", {childId: "child-missing"}),
    seed("children/child-bad-lock", {childId: "child-bad-lock"}),
    seed("relationships/rel-single", {
      parentId: "parent-single", childId: "child-single", status: "accepted",
    }),
    seed("relationships/rel-conflict-a", {
      parentId: "parent-a", childId: "child-conflict", status: "accepted",
    }),
    seed("relationships/rel-conflict-b", {
      parentId: "parent-b", childId: "child-conflict", status: "accepted",
    }),
    seed("relationships/rel-missing", {
      parentId: "parent-missing", childId: "child-missing", status: "accepted",
    }),
    seed("relationships/rel-bad-lock", {
      parentId: "parent-lock", childId: "child-bad-lock", status: "accepted",
    }),
    seed("children/child-single/guardians/parent-single", {
      parentUid: "parent-single", childId: "child-single", relationshipId: "rel-single",
      status: "accepted",
    }),
    seed("parents/parent-single/children/child-single", {
      parentUid: "parent-single", childId: "child-single", relationshipId: "rel-single",
      status: "accepted",
    }),
    seed("children/child-bad-lock/guardians/parent-lock", {
      parentUid: "parent-lock", childId: "child-bad-lock", relationshipId: "rel-bad-lock",
      status: "accepted",
    }),
    seed("parents/parent-lock/children/child-bad-lock", {
      parentUid: "parent-lock", childId: "child-bad-lock", relationshipId: "rel-bad-lock",
      status: "accepted",
    }),
    seed("children/child-conflict/guardianState/active", {
      parentUid: "parent-a", childId: "child-conflict", relationshipId: "rel-conflict-a",
    }),
    seed("children/child-bad-lock/guardianState/active", {
      parentUid: "parent-wrong", childId: "child-bad-lock", relationshipId: "rel-wrong",
    }),
  ]);

  const script = path.join(__dirname, "migrations", "audit-single-parent.js");
  const output = execFileSync(process.execPath, [script, "--dry-run"], {
    encoding: "utf8",
    env: {...process.env, GCLOUD_PROJECT: PROJECT},
  });
  const report = JSON.parse(output);

  assert.equal(report.mode, "dry-run");
  assert.equal(report.summary.totalChildren, 4);
  assert.equal(report.summary.acceptedRelationships, 5);
  assert.equal(report.summary.singleActiveRelationshipCandidates, 3);
  assert.equal(report.summary.multiRelationshipConflicts, 1);
  assert.equal(report.summary.missingGuardians, 1);
  assert.equal(report.summary.missingParentMirrors, 1);
  assert.equal(report.summary.missingActiveLocks, 2);
  assert.equal(report.summary.activeLockInconsistencies, 2);
  assert.deepEqual(report.multiRelationshipConflicts[0].relationshipIds, [
    "rel-conflict-a", "rel-conflict-b",
  ]);

  assert.throws(() => execFileSync(process.execPath, [script, "--apply"], {
    encoding: "utf8",
    env: {...process.env, GCLOUD_PROJECT: PROJECT},
    stdio: "pipe",
  }), /Command failed/);
  console.log("PASS: Migration audit eski ilişki senaryolarını yalnızca raporluyor");
}

run().finally(() => deleteApp(app)).catch((error) => {
  console.error("TEST BAŞARISIZ:", error);
  process.exitCode = 1;
});
