/**
 * Cloud Firebase Auth direct REST API execution
 * Uses Firebase Web API Key to create / authenticate accounts on Firebase Auth Cloud for project arc-productivity-shreyas.
 */

const apiKey = 'AIzaSyCTp6kyYEFN_yBX-cnRAR45E66dGk4UHVo';

async function createOrResetAccount(email, password, displayName) {
  console.log(`[Cloud REST API] Processing ${email} (Password: ${password})...`);
  
  // 1. Try to sign up user
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
    console.log(`[Cloud REST API SUCCESS] Created fresh user ${email} on Cloud Firebase Auth! UID: ${signUpData.localId}`);
    
    // Update display name
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
    return signUpData.localId;
  }

  // If email exists, sign in with existing password or reset password
  if (signUpData.error && signUpData.error.message === 'EMAIL_EXISTS') {
    console.log(`[Cloud REST API] Account ${email} already exists on Cloud Firebase Auth. Logging in / updating password...`);
    
    // Try sign in with password
    const signInUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
    const signInRes = await fetch(signInUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: email,
        password: password,
        returnSecureToken: true,
      }),
    });

    const signInData = await signInRes.json();

    if (signInRes.ok) {
      console.log(`[Cloud REST API SUCCESS] Authenticated ${email} on Cloud Firebase Auth! UID: ${signInData.localId}`);
      return signInData.localId;
    } else {
      console.warn(`[Cloud REST API Warning] Sign in failed for ${email}: ${signInData.error.message}`);
    }
  } else {
    console.error(`[Cloud REST API Error] ${email}:`, signUpData);
  }
}

async function main() {
  console.log('==================================================');
  console.log('Starting Cloud Firebase Auth User Creation & Sync');
  console.log('==================================================\n');

  await createOrResetAccount('purushottam@arc.app', '123456', 'Purushottam');
  await createOrResetAccount('shreyas@arc.app', '123456', 'Shreyas');
  await createOrResetAccount('sachi@arc.app', '123456', 'Sachi');
  await createOrResetAccount('aman@arc.app', '123456', 'Aman');
  await createOrResetAccount('rohit@arc.app', '123456', 'Rohit');
  await createOrResetAccount('yash@arc.app', '123456', 'Yash');

  console.log('\n==================================================');
  console.log('Completed Cloud Firebase Auth Account Sync!');
  console.log('==================================================');
}

main().catch(console.error);
