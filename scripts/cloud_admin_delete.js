/**
 * Direct GCP Identity Toolkit Admin API Call to Delete & Re-create Users
 */

const fs = require('fs');

const projectId = 'arc-productivity-shreyas';
const configPath = 'C:\\Users\\Shreyas\\.config\\configstore\\firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;
const apiKey = 'AIzaSyCTp6kyYEFN_yBX-cnRAR45E66dGk4UHVo';

async function deleteAccounts(uids) {
  console.log(`[Admin API] Deleting account UIDs:`, uids);
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchDelete`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ localIds: uids }),
  });
  const data = await res.json();
  console.log('[Admin API Delete Result]:', res.status, data);
}

async function createAccount(email, password, displayName) {
  console.log(`[Admin API] Creating fresh account for ${email}...`);
  const signUpUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`;
  const signUpRes = await fetch(signUpUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: email,
      password: password,
      returnSecureToken: true,
    }),
  });

  const signUpData = await signUpRes.json();
  if (signUpRes.ok) {
    console.log(`[SUCCESS] Created ${email} -> UID: ${signUpData.localId}`);
    
    // Set Display Name
    const updateUrl = `https://identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`;
    await fetch(updateUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        idToken: signUpData.idToken,
        displayName: displayName,
        returnSecureToken: true,
      }),
    });
  } else {
    console.error(`[ERROR] Failed to create ${email}:`, signUpData);
  }
}

async function main() {
  // Old UIDs for shreyas@arc.app and sachi@arc.app from cloud auth listing:
  // shreyas@arc.app -> u0xSvSMCmOYGrJK2GPfKYmpuUVl1
  // sachi@arc.app -> ncFYWudsifXfLza208CI16Lk3k23
  
  await deleteAccounts(['u0xSvSMCmOYGrJK2GPfKYmpuUVl1', 'ncFYWudsifXfLza208CI16Lk3k23']);

  // Re-create both with password 123456
  await createAccount('shreyas@arc.app', '123456', 'Shreyas');
  await createAccount('sachi@arc.app', '123456', 'Sachi');
}

main().catch(console.error);
