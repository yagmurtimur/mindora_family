const crypto = require("crypto");

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");

const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

initializeApp();

const db = getFirestore();
const invitationSecret = defineSecret("INVITATION_HMAC_SECRET");

setGlobalOptions({
  maxInstances: 10,
  region: "europe-west1",
});

function getSecret() {
  const value = invitationSecret.value();
  if (!value || value.length < 32) {
    throw new HttpsError("failed-precondition", "Backend secret is not configured.");
  }
  return value;
}

function hash(value) {
  return crypto
      .createHmac("sha256", getSecret())
      .update(value)
      .digest("hex");
}

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return request.auth.uid;
}

async function requireRole(uid, role) {
  const snapshot = await db.collection("accounts").doc(uid).get();

  if (!snapshot.exists ||
      snapshot.data().role !== role ||
      snapshot.data().status !== "active") {
    throw new HttpsError("permission-denied", "Account is not authorized.");
  }

  return snapshot.data();
}

// Parent creates an invitation for an existing child account.
// The returned token is shown only once and must not be logged.
exports.createInvitation = onCall(
    {secrets: [invitationSecret]},
    async (request) => {
      const parentId = requireAuth(request);
      await requireRole(parentId, "parent");

      const childId = String(request.data?.childId || "").trim();

      if (!childId || childId === parentId || childId.length > 128) {
        throw new HttpsError("invalid-argument", "Invalid child account.");
      }

      await requireRole(childId, "child");

      const token = crypto.randomBytes(32).toString("base64url");
      const inviteRef = db.collection("relationshipInvitations").doc();
      const relationshipId = hash(`relationship:${parentId}:${childId}`);

      const now = Timestamp.now();
      const expiresAt = Timestamp.fromMillis(
          now.toMillis() + 7 * 24 * 60 * 60 * 1000,
      );

      await db.runTransaction(async (tx) => {
        const relationshipRef = db.collection("relationships")
            .doc(relationshipId);
        const guardianStateRef = db.collection("children").doc(childId)
            .collection("guardianState").doc("active");
        const [relationship, guardianState] = await Promise.all([
          tx.get(relationshipRef),
          tx.get(guardianStateRef),
        ]);

        if (relationship.exists && relationship.data().status === "accepted") {
          throw new HttpsError(
              "already-exists",
              "An active relationship already exists.",
          );
        }

        if (guardianState.exists) {
          throw new HttpsError(
              "already-exists",
              "This child already has an active parent.",
          );
        }

        tx.create(inviteRef, {
          parentId,
          childId,
          target: childId,
          status: "pending",
          tokenHash: hash(`invite:${token}`),
          hashAlgorithm: "HMAC-SHA-256",
          tokenKeyVersion: 1,
          tokenIssuedAt: now,
          createdAt: now,
          expiresAt,
        });
      });

      return {
        invitationId: inviteRef.id,
        token,
        expiresAt: expiresAt.toDate().toISOString(),
      };
    },
);

// Child accepts an invitation using its one-time token.
exports.acceptInvitation = onCall(
    {secrets: [invitationSecret]},
    async (request) => {
      const childId = requireAuth(request);
      await requireRole(childId, "child");

      const invitationId = String(request.data?.invitationId || "").trim();
      const token = String(request.data?.token || "");

      if (!invitationId || !token || token.length > 256) {
        throw new HttpsError("invalid-argument", "Invalid invitation.");
      }

      const inviteRef = db.collection("relationshipInvitations")
          .doc(invitationId);

      const inviteSnapshot = await inviteRef.get();

      if (!inviteSnapshot.exists) {
        throw new HttpsError("not-found", "Invitation is unavailable.");
      }

      const invite = inviteSnapshot.data();

      if (invite.childId !== childId ||
          invite.status !== "pending" ||
          !invite.expiresAt ||
          invite.expiresAt.toMillis() <= Date.now()) {
        throw new HttpsError("failed-precondition", "Invitation is unavailable.");
      }

      const expectedHash = Buffer.from(invite.tokenHash || "", "hex");
      const actualHash = Buffer.from(hash(`invite:${token}`), "hex");

      if (expectedHash.length !== actualHash.length ||
          !crypto.timingSafeEqual(expectedHash, actualHash)) {
        throw new HttpsError("permission-denied", "Invitation is unavailable.");
      }

      const parentId = invite.parentId;
      const relationshipId = hash(`relationship:${parentId}:${childId}`);

      const relationshipRef = db.collection("relationships")
          .doc(relationshipId);
      const guardianStateRef = db.collection("children").doc(childId)
          .collection("guardianState").doc("active");
      const guardianRef = db.collection("children").doc(childId)
          .collection("guardians").doc(parentId);
      const parentChildRef = db.collection("parents").doc(parentId)
          .collection("children").doc(childId);
      const revocationRef = db.collection("children").doc(childId)
          .collection("guardianRevocations").doc(parentId);

      await db.runTransaction(async (tx) => {
        const [currentInvite, parentAccount, childAccount, relationship,
          guardianState] =
          await Promise.all([
            tx.get(inviteRef),
            tx.get(db.collection("accounts").doc(parentId)),
            tx.get(db.collection("accounts").doc(childId)),
            tx.get(relationshipRef),
            tx.get(guardianStateRef),
          ]);

        if (!currentInvite.exists) {
          throw new HttpsError("failed-precondition", "Invitation is unavailable.");
        }

        const currentData = currentInvite.data();
        const currentTokenHash = Buffer.from(currentData.tokenHash || "", "hex");
        const suppliedTokenHash = Buffer.from(hash(`invite:${token}`), "hex");

        if (currentData.childId !== childId ||
            currentData.status !== "pending" ||
            !currentData.expiresAt ||
            currentData.expiresAt.toMillis() <= Date.now() ||
            currentTokenHash.length !== suppliedTokenHash.length ||
            !crypto.timingSafeEqual(currentTokenHash, suppliedTokenHash) ||
            !parentAccount.exists ||
            parentAccount.data().role !== "parent" ||
            parentAccount.data().status !== "active" ||
            !childAccount.exists ||
            childAccount.data().role !== "child" ||
            childAccount.data().status !== "active" ||
            relationship.exists && relationship.data().status === "accepted" ||
            guardianState.exists) {
          throw new HttpsError("failed-precondition", "Invitation is unavailable.");
        }

        const now = FieldValue.serverTimestamp();

        tx.set(relationshipRef, {
          parentId,
          childId,
          status: "accepted",
          acceptedAt: now,
          sourceInviteId: invitationId,
        });

        tx.create(guardianStateRef, {
          parentUid: parentId,
          childId,
          relationshipId,
          activatedAt: now,
        });

        tx.set(guardianRef, {
          parentUid: parentId,
          childId,
          relationshipId,
          status: "accepted",
          acceptedAt: now,
          allowedDataScopes: {
            profileRead: false,
            deviceRead: false,
            usageRead: false,
            usageDetailRead: false,
            goalsRead: false,
            policiesRead: false,
            moodRead: false,
            assessmentRead: false,
            analysisRead: false,
            recommendationsRead: false,
          },
          consentPolicyVersion: 1,
          updatedAt: now,
        });

        tx.set(parentChildRef, {
          parentUid: parentId,
          childId,
          relationshipId,
          status: "accepted",
          acceptedAt: now,
          updatedAt: now,
        });

        tx.delete(revocationRef);

        tx.update(inviteRef, {
          status: "accepted",
          consumedAt: now,
          resolvedAt: now,
          resolvedRelationshipId: relationshipId,
        });
      });

      return {success: true, relationshipId};
    },
);

// Parent revokes an active relationship.
exports.revokeRelationship = onCall(
    async (request) => {
      const parentId = requireAuth(request);
      await requireRole(parentId, "parent");

      const relationshipId = String(
          request.data?.relationshipId || "",
      ).trim();

      if (!relationshipId || relationshipId.length > 128) {
        throw new HttpsError("invalid-argument", "Invalid relationship.");
      }

      const relationshipRef = db.collection("relationships")
          .doc(relationshipId);

      await db.runTransaction(async (tx) => {
        const current = await tx.get(relationshipRef);

        if (!current.exists ||
            current.data().parentId !== parentId ||
            current.data().status !== "accepted") {
          throw new HttpsError("failed-precondition", "Relationship is unavailable.");
        }

        const childId = current.data().childId;
        const guardianStateRef = db.collection("children").doc(childId)
            .collection("guardianState").doc("active");
        const guardianState = await tx.get(guardianStateRef);

        if (!guardianState.exists ||
            guardianState.data().parentUid !== parentId ||
            guardianState.data().childId !== childId ||
            guardianState.data().relationshipId !== relationshipId) {
          throw new HttpsError("failed-precondition", "Relationship is unavailable.");
        }

        const guardianRef = db.collection("children").doc(childId)
            .collection("guardians").doc(parentId);
        const parentChildRef = db.collection("parents").doc(parentId)
            .collection("children").doc(childId);
        const revocationRef = db.collection("children").doc(childId)
            .collection("guardianRevocations").doc(parentId);

        const now = FieldValue.serverTimestamp();

        tx.update(relationshipRef, {
          status: "revoked",
          revokedAt: now,
          revokedBy: parentId,
        });

        tx.set(revocationRef, {
          parentUid: parentId,
          childId,
          relationshipId,
          revokedAt: now,
        });

        tx.delete(guardianRef);
        tx.delete(parentChildRef);
        tx.delete(guardianStateRef);
      });

      return {success: true};
    },
);
