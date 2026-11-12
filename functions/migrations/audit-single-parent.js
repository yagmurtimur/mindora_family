#!/usr/bin/env node

"use strict";

const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

function fail(message) {
  process.stderr.write(`Migration audit refused: ${message}\n`);
  process.exitCode = 1;
}

function parseArguments(args) {
  const allowed = new Set(["--dry-run", "--help"]);
  const unknown = args.find((arg) => !allowed.has(arg));

  if (unknown) {
    throw new Error(
        `${unknown} is not supported. This tool is audit-only and cannot write data.`,
    );
  }

  return {help: args.includes("--help")};
}

function requireLocalEmulator() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "";

  if (!/^(127\.0\.0\.1|localhost|::1):\d+$/.test(host)) {
    throw new Error(
        "FIRESTORE_EMULATOR_HOST must name a localhost Firestore emulator; " +
        "production access is intentionally disabled.",
    );
  }
}

function stringField(data, field) {
  return typeof data[field] === "string" && data[field].trim() ?
    data[field] : null;
}

function sorted(values) {
  return [...values].sort((left, right) => left.localeCompare(right));
}

function byChildAndParent(childId, parentId) {
  return `${childId}\u0000${parentId}`;
}

function parseGuardian(snapshot) {
  const path = snapshot.ref.path.split("/");

  if (path.length !== 4 || path[0] !== "children" ||
      path[2] !== "guardians") {
    return null;
  }

  return {childId: path[1], parentId: path[3], data: snapshot.data(), path: snapshot.ref.path};
}

function parseParentMirror(snapshot) {
  const path = snapshot.ref.path.split("/");

  if (path.length !== 4 || path[0] !== "parents" ||
      path[2] !== "children") {
    return null;
  }

  return {parentId: path[1], childId: path[3], data: snapshot.data(), path: snapshot.ref.path};
}

function parseGuardianState(snapshot) {
  const path = snapshot.ref.path.split("/");

  if (path.length !== 4 || path[0] !== "children" ||
      path[2] !== "guardianState") {
    return null;
  }

  return {childId: path[1], stateId: path[3], data: snapshot.data(), path: snapshot.ref.path};
}

function issue(path, reason, details) {
  return {path, reason, ...details};
}

async function buildReport(db) {
  const [children, relationships, guardianSnapshots, mirrorSnapshots,
    guardianStateSnapshots] = await Promise.all([
    db.collection("children").get(),
    db.collection("relationships").get(),
    db.collectionGroup("guardians").get(),
    db.collectionGroup("children").get(),
    db.collectionGroup("guardianState").get(),
  ]);

  const childIds = new Set(children.docs.map((snapshot) => snapshot.id));
  const childDocumentIds = new Set(children.docs.map((snapshot) => snapshot.id));
  const acceptedByChild = new Map();
  const acceptedById = new Map();
  const invalidAcceptedRelationships = [];

  for (const snapshot of relationships.docs) {
    const data = snapshot.data();
    if (data.status !== "accepted") {
      continue;
    }

    const parentId = stringField(data, "parentId");
    const childId = stringField(data, "childId");
    if (!parentId || !childId) {
      invalidAcceptedRelationships.push(issue(snapshot.ref.path,
          "acceptedRelationshipMissingParentOrChild", {parentId, childId}));
      continue;
    }

    const relationship = {id: snapshot.id, parentId, childId, path: snapshot.ref.path};
    childIds.add(childId);
    acceptedById.set(snapshot.id, relationship);
    const relationshipsForChild = acceptedByChild.get(childId) || [];
    relationshipsForChild.push(relationship);
    acceptedByChild.set(childId, relationshipsForChild);
  }

  const guardiansByKey = new Map();
  const guardianInconsistencies = [];
  for (const snapshot of guardianSnapshots.docs) {
    const guardian = parseGuardian(snapshot);
    if (!guardian) {
      guardianInconsistencies.push(issue(snapshot.ref.path,
          "unexpectedGuardianPath", {}));
      continue;
    }

    childIds.add(guardian.childId);
    const key = byChildAndParent(guardian.childId, guardian.parentId);
    const guardians = guardiansByKey.get(key) || [];
    guardians.push(guardian);
    guardiansByKey.set(key, guardians);

    const relationship = acceptedById.get(stringField(guardian.data, "relationshipId"));
    if (stringField(guardian.data, "parentUid") !== guardian.parentId ||
        stringField(guardian.data, "childId") !== guardian.childId) {
      guardianInconsistencies.push(issue(guardian.path,
          "guardianPathFieldsDoNotMatch", {}));
    }
    if (!relationship || relationship.parentId !== guardian.parentId ||
        relationship.childId !== guardian.childId ||
        guardian.data.status !== "accepted") {
      guardianInconsistencies.push(issue(guardian.path,
          "guardianDoesNotMatchAcceptedRelationship", {
            relationshipId: stringField(guardian.data, "relationshipId"),
          }));
    }
  }

  const mirrorsByKey = new Map();
  const parentMirrorInconsistencies = [];
  for (const snapshot of mirrorSnapshots.docs) {
    const mirror = parseParentMirror(snapshot);
    if (!mirror) {
      continue;
    }

    childIds.add(mirror.childId);
    const key = byChildAndParent(mirror.childId, mirror.parentId);
    const mirrors = mirrorsByKey.get(key) || [];
    mirrors.push(mirror);
    mirrorsByKey.set(key, mirrors);

    const relationship = acceptedById.get(stringField(mirror.data, "relationshipId"));
    if (stringField(mirror.data, "parentUid") !== mirror.parentId ||
        stringField(mirror.data, "childId") !== mirror.childId) {
      parentMirrorInconsistencies.push(issue(mirror.path,
          "parentMirrorPathFieldsDoNotMatch", {}));
    }
    if (!relationship || relationship.parentId !== mirror.parentId ||
        relationship.childId !== mirror.childId ||
        mirror.data.status !== "accepted") {
      parentMirrorInconsistencies.push(issue(mirror.path,
          "parentMirrorDoesNotMatchAcceptedRelationship", {
            relationshipId: stringField(mirror.data, "relationshipId"),
          }));
    }
  }

  const activeLocksByChild = new Map();
  const activeLockInconsistencies = [];
  for (const snapshot of guardianStateSnapshots.docs) {
    const guardianState = parseGuardianState(snapshot);
    if (!guardianState) {
      activeLockInconsistencies.push(issue(snapshot.ref.path,
          "unexpectedGuardianStatePath", {}));
      continue;
    }
    childIds.add(guardianState.childId);
    if (guardianState.stateId !== "active") {
      activeLockInconsistencies.push(issue(guardianState.path,
          "unexpectedGuardianStateDocument", {stateId: guardianState.stateId}));
      continue;
    }
    activeLocksByChild.set(guardianState.childId, guardianState);
  }

  const singleActiveRelationshipCandidates = [];
  const multiRelationshipConflicts = [];
  const missingGuardians = [];
  const missingParentMirrors = [];
  const missingActiveLocks = [];
  const missingChildDocuments = [];

  for (const childId of sorted(childIds)) {
    const relationshipsForChild = (acceptedByChild.get(childId) || [])
        .sort((left, right) => left.id.localeCompare(right.id));

    if (!childDocumentIds.has(childId)) {
      missingChildDocuments.push({childId});
    }

    if (relationshipsForChild.length > 1) {
      multiRelationshipConflicts.push({
        childId,
        relationshipIds: relationshipsForChild.map((relationship) => relationship.id),
        parentIds: relationshipsForChild.map((relationship) => relationship.parentId),
      });
    }

    const candidate = relationshipsForChild.length === 1 ?
      relationshipsForChild[0] : null;
    if (candidate) {
      singleActiveRelationshipCandidates.push(candidate);
      const key = byChildAndParent(childId, candidate.parentId);
      const guardianMatches = (guardiansByKey.get(key) || []).some((guardian) =>
        guardian.data.status === "accepted" &&
        stringField(guardian.data, "parentUid") === candidate.parentId &&
        stringField(guardian.data, "childId") === childId &&
        stringField(guardian.data, "relationshipId") === candidate.id,
      );
      const mirrorMatches = (mirrorsByKey.get(key) || []).some((mirror) =>
        mirror.data.status === "accepted" &&
        stringField(mirror.data, "parentUid") === candidate.parentId &&
        stringField(mirror.data, "childId") === childId &&
        stringField(mirror.data, "relationshipId") === candidate.id,
      );

      if (!guardianMatches) {
        missingGuardians.push({
          childId, parentId: candidate.parentId, relationshipId: candidate.id,
        });
      }
      if (!mirrorMatches) {
        missingParentMirrors.push({
          childId, parentId: candidate.parentId, relationshipId: candidate.id,
        });
      }
    }

    const activeLock = activeLocksByChild.get(childId);
    if (candidate && !activeLock) {
      missingActiveLocks.push({
        childId, parentId: candidate.parentId, relationshipId: candidate.id,
      });
    }
    if (activeLock) {
      const activeLockParentId = stringField(activeLock.data, "parentUid");
      const activeLockChildId = stringField(activeLock.data, "childId");
      const activeLockRelationshipId = stringField(activeLock.data, "relationshipId");
      if (!candidate || activeLockParentId !== candidate.parentId ||
          activeLockChildId !== childId ||
          activeLockRelationshipId !== candidate.id) {
        activeLockInconsistencies.push(issue(activeLock.path,
            "activeLockDoesNotMatchSingleAcceptedCandidate", {
              childId,
              parentId: activeLockParentId,
              relationshipId: activeLockRelationshipId,
              candidateRelationshipId: candidate?.id || null,
            }));
      }
    }
  }

  const acceptedRelationshipDocuments = relationships.docs.filter(
      (snapshot) => snapshot.data().status === "accepted",
  ).length;

  return {
    schemaVersion: 1,
    mode: "dry-run",
    productionAccess: "disabled: localhost Firestore emulator required",
    summary: {
      totalChildren: childIds.size,
      childDocuments: childDocumentIds.size,
      acceptedRelationships: acceptedRelationshipDocuments,
      singleActiveRelationshipCandidates: singleActiveRelationshipCandidates.length,
      multiRelationshipConflicts: multiRelationshipConflicts.length,
      missingGuardians: missingGuardians.length,
      missingParentMirrors: missingParentMirrors.length,
      missingActiveLocks: missingActiveLocks.length,
      activeLockInconsistencies: activeLockInconsistencies.length,
    },
    singleActiveRelationshipCandidates,
    multiRelationshipConflicts,
    missingGuardians,
    missingParentMirrors,
    missingActiveLocks,
    activeLockInconsistencies,
    guardianInconsistencies,
    parentMirrorInconsistencies,
    invalidAcceptedRelationships,
    missingChildDocuments,
  };
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    process.stdout.write("Usage: node migrations/audit-single-parent.js --dry-run\n");
    return;
  }

  requireLocalEmulator();
  if (!getApps().length) {
    initializeApp({projectId: process.env.GCLOUD_PROJECT || "mindora-migration-audit"});
  }

  const report = await buildReport(getFirestore());
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

if (require.main === module) {
  main().catch((error) => fail(error.message));
}

module.exports = {buildReport};
