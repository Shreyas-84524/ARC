/**
 * Direct Firebase Cloud Auth Provisioning & Re-creation Script
 * Initializes firebase-admin using OAuth access token from stored CLI session.
 */

const admin = require('firebase-admin');
const fs = require('fs');

const projectId = 'arc-productivity-shreyas';
const configPath = 'C:\\Users\\Shreyas\\.config\\configstore\\firebase-tools.json';

if (!fs.existsSync(configPath)) {
  console.error('[Cloud Sync Error] firebase-tools.json not found at:', configPath);
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;

if (!accessToken) {
  console.error('[Cloud Sync Error] No valid OAuth access_token found in firebase-tools.json.');
  process.exit(1);
}

console.log(`[Cloud Sync] Initializing Firebase Admin SDK for project '${projectId}'...`);

admin.initializeApp({
  credential: admin.credential.accessToken(accessToken),
  projectId: projectId,
});

const auth = admin.auth();
const db = admin.firestore();

const targetUsers = [
  { username: 'Shreyas', email: 'shreyas@arc.app', password: '123456', recreate: true },
  { username: 'Sachi', email: 'sachi@arc.app', password: '123456', recreate: true },
  { username: 'Purushottam', email: 'purushottam@arc.app', password: '123456', recreate: true },
  { username: 'Aman', email: 'aman@arc.app', password: '123456', recreate: false },
  { username: 'Rohit', email: 'rohit@arc.app', password: '123456', recreate: false },
  { username: 'Yash', email: 'yash@arc.app', password: '123456', recreate: false },
];

async function syncUsers() {
  console.log('[Cloud Sync] Executing Cloud Firebase Auth user setup...');

  for (const userDef of targetUsers) {
    let userRecord = null;
    try {
      userRecord = await auth.getUserByEmail(userDef.email);
    } catch (err) {
      if (err.code !== 'auth/user-not-found') {
        console.warn(`[Cloud Sync Warning] Error checking ${userDef.email}:`, err.message);
      }
    }

    if (userRecord && userDef.recreate) {
      console.log(`[Cloud Sync] Deleting existing Cloud Auth user for ${userDef.username} (UID: ${userRecord.uid})...`);
      await auth.deleteUser(userRecord.uid);
      
      // Delete old Firestore profile if exists
      try {
        await db.collection('users').doc(userRecord.uid).collection('settings').doc('profile').delete();
      } catch (e) {}

      // Re-create user fresh
      userRecord = await auth.createUser({
        email: userDef.email,
        password: userDef.password,
        displayName: userDef.username,
        emailVerified: true,
      });
      console.log(`[Cloud Sync] Created fresh Cloud Auth user for ${userDef.username} -> NEW UID: ${userRecord.uid}`);
    } else if (userRecord) {
      console.log(`[Cloud Sync] Existing Cloud Auth user for ${userDef.username} found (UID: ${userRecord.uid}). Updating password...`);
      await auth.updateUser(userRecord.uid, {
        password: userDef.password,
        displayName: userDef.username,
      });
    } else {
      console.log(`[Cloud Sync] Creating new Cloud Auth user for ${userDef.username}...`);
      userRecord = await auth.createUser({
        email: userDef.email,
        password: userDef.password,
        displayName: userDef.username,
        emailVerified: true,
      });
      console.log(`[Cloud Sync] Created new Cloud Auth user for ${userDef.username} -> UID: ${userRecord.uid}`);
    }

    // Provision Firestore User Profile
    const profileRef = db.collection('users').doc(userRecord.uid).collection('settings').doc('profile');
    await profileRef.set({
      id: userRecord.uid,
      username: userDef.username,
      displayName: userDef.username,
      email: userDef.email,
      role: 'user',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`[Cloud Sync] Updated Firestore profile document for ${userDef.username} (UID: ${userRecord.uid})`);
  }

  console.log('\n==================================================');
  console.log('[Cloud Sync Success] All Cloud Firebase Auth users synced!');
  console.log('==================================================\n');
}

syncUsers().catch(err => {
  console.error('[Cloud Sync Error] Execution failed:', err);
  process.exit(1);
});
