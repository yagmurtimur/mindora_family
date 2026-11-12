const assert = require("node:assert/strict");

const PROJECT = "mindora-b8cfd";
const AUTH = "http://127.0.0.1:9099";
const DB = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const FN = `http://127.0.0.1:5001/${PROJECT}/europe-west1`;

async function createUser(label, role) {
  const response = await fetch(
      `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          email: `${label}-${Date.now()}@example.com`,
          password: "TestPassword123!",
          returnSecureToken: true,
        }),
      },
  );
  const user = await response.json();
  assert.ok(user.localId, JSON.stringify(user));

  await fetch(`${DB}/accounts/${user.localId}`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer owner",
    },
    body: JSON.stringify({
      fields: {
        role: {stringValue: role},
        status: {stringValue: "active"},
      },
    }),
  });

  return {uid: user.localId, token: user.idToken};
}

async function call(name, token, data) {
  const response = await fetch(`${FN}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
    },
    body: JSON.stringify({data}),
  });
  return response.json();
}

async function getAsOwner(path) {
  const response = await fetch(`${DB}/${path}`, {
    headers: {"Authorization": "Bearer owner"},
  });
  return response.json();
}

async function run() {
  const parent = await createUser("parent", "parent");
  const secondParent = await createUser("second-parent", "parent");
  const child = await createUser("child", "child");
  const other = await createUser("other", "child");

  const invitation = await call("createInvitation", parent.token, {
    childId: child.uid,
  });
  assert.ok(invitation.result?.token, JSON.stringify(invitation));
  console.log("PASS: Davet oluşturuldu");

  const wrong = await call("acceptInvitation", other.token, {
    invitationId: invitation.result.invitationId,
    token: invitation.result.token,
  });
  assert.ok(wrong.error, "Yanlış çocuk daveti kabul edebildi");
  console.log("PASS: Yanlış çocuk reddedildi");

  const accepted = await call("acceptInvitation", child.token, {
    invitationId: invitation.result.invitationId,
    token: invitation.result.token,
  });
  assert.equal(accepted.result?.success, true, JSON.stringify(accepted));
  console.log("PASS: Doğru çocuk daveti kabul etti");

  const secondParentInvite = await call("createInvitation", secondParent.token, {
    childId: child.uid,
  });
  assert.ok(secondParentInvite.error, "İkinci ebeveyn aktif çocuğa davet oluşturabildi");
  console.log("PASS: İkinci ebeveyn aktif çocuğa davet oluşturamadı");

  const repeated = await call("acceptInvitation", child.token, {
    invitationId: invitation.result.invitationId,
    token: invitation.result.token,
  });
  assert.ok(repeated.error, "Davet ikinci kez kabul edildi");
  console.log("PASS: Tekrar kullanım engellendi");

  const revoked = await call("revokeRelationship", parent.token, {
    relationshipId: accepted.result.relationshipId,
  });
  assert.equal(revoked.result?.success, true, JSON.stringify(revoked));
  console.log("PASS: İlişki iptal edildi");

  const revokedGuardian = await getAsOwner(
      `children/${child.uid}/guardians/${parent.uid}`,
  );
  const revokedState = await getAsOwner(
      `children/${child.uid}/guardianState/active`,
  );
  assert.equal(revokedGuardian.error?.status, "NOT_FOUND",
      "Eski ebeveynin guardian erişimi kaldırılmadı");
  assert.equal(revokedState.error?.status, "NOT_FOUND",
      "Aktif ebeveyn kilidi kaldırılmadı");
  console.log("PASS: Eski ebeveyn erişimi ve aktif kilit kaldırıldı");

  const oldParentInvite = await call("createInvitation", parent.token, {
    childId: child.uid,
  });
  assert.ok(oldParentInvite.result?.token, JSON.stringify(oldParentInvite));
  console.log("PASS: Eski ebeveyn iptal sonrası yeni davet oluşturabildi");

  const oldParentAccess = await call("revokeRelationship", parent.token, {
    relationshipId: accepted.result.relationshipId,
  });
  assert.ok(oldParentAccess.error, "Eski ebeveyn iptal edilen ilişkiyi tekrar yönetebildi");
  console.log("PASS: Eski ebeveynin iptal edilen ilişkide erişimi kaldırıldı");

  const second = await call("createInvitation", secondParent.token, {
    childId: child.uid,
  });
  assert.ok(second.result?.token, JSON.stringify(second));
  console.log("PASS: İptal sonrası ikinci ebeveyn davet oluşturdu");

  const reaccepted = await call("acceptInvitation", child.token, {
    invitationId: second.result.invitationId,
    token: second.result.token,
  });
  assert.equal(reaccepted.result?.success, true, JSON.stringify(reaccepted));
  console.log("PASS: İkinci ebeveyn ilişkisi kabul edildi");

  const concurrentParentA = await createUser("concurrent-parent-a", "parent");
  const concurrentParentB = await createUser("concurrent-parent-b", "parent");
  const concurrentInviteA = await call("createInvitation", concurrentParentA.token, {
    childId: other.uid,
  });
  const concurrentInviteB = await call("createInvitation", concurrentParentB.token, {
    childId: other.uid,
  });
  assert.ok(concurrentInviteA.result?.token, JSON.stringify(concurrentInviteA));
  assert.ok(concurrentInviteB.result?.token, JSON.stringify(concurrentInviteB));

  const [attempt1, attempt2] = await Promise.all([
    call("acceptInvitation", other.token, {
      invitationId: concurrentInviteA.result.invitationId,
      token: concurrentInviteA.result.token,
    }),
    call("acceptInvitation", other.token, {
      invitationId: concurrentInviteB.result.invitationId,
      token: concurrentInviteB.result.token,
    }),
  ]);

  const successes = [attempt1, attempt2].filter(
      (result) => result.result?.success === true,
  );
  assert.equal(successes.length, 1, "Eşzamanlı kabul iki kez başarılı oldu");
  console.log("PASS: Eşzamanlı kabul yalnızca bir kez başarılı");

  const storedResponse = await fetch(
      `${DB}/relationshipInvitations/${concurrentInviteA.result.invitationId}`,
      {headers: {"Authorization": "Bearer owner"}},
  );
  const stored = await storedResponse.json();
  assert.ok(stored.fields?.tokenHash, "Token hash saklanmamış");
  assert.equal(stored.fields?.token, undefined, "Ham token Firestore'da saklanmış");
  console.log("PASS: Firestore'da ham token yerine hash saklanıyor");

  console.log("\\nTÜM TESTLER BAŞARILI");
}

run().catch((error) => {
  console.error("\nTEST BAŞARISIZ:", error);
  process.exitCode = 1;
});
