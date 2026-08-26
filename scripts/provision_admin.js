/**
 * Project Arc — Initial Admin Provisioning Script
 * 
 * Usage (Backend / CI Environment Only):
 *   node scripts/provision_admin.js
 * 
 * SECURITY:
 *   This script runs ONLY in a trusted backend/admin environment using the Firebase Admin SDK.
 *   DO NOT bundle or commit service-account credentials into the Flutter application codebase or APK.
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK (reads GOOGLE_APPLICATION_CREDENTIALS environment variable)
if (!admin.apps.length) {
  admin.initializeApp();
}

async function provisionAdminAccount() {
  const adminEmail = 'admin@arc.app';
  const initialAdminPassword = process.env.ADMIN_INITIAL_PASSWORD || '143926004';
  const adminUsername = 'ADMIN';

  console.log(`[Provisioning] Initializing admin account provisioning for: ${adminEmail}...`);

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(adminEmail);
    console.log(`[Provisioning] Existing admin Auth account found (UID: ${userRecord.uid}).`);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      userRecord = await admin.auth().createUser({
        email: adminEmail,
        password: initialAdminPassword,
        displayName: adminUsername,
      });
      console.log(`[Provisioning] Created new Firebase Auth admin account (UID: ${userRecord.uid}).`);
    } else {
      throw error;
    }
  }

  // 1. Set Custom User Claim: role = 'admin'
  await admin.auth().setCustomUserClaims(userRecord.uid, { role: 'admin' });
  console.log(`[Provisioning] Successfully assigned custom claim { role: 'admin' } to UID: ${userRecord.uid}.`);

  // 2. Set Firestore User Profile document
  const db = admin.firestore();
  const profileRef = db.collection('users').doc(userRecord.uid).collection('settings').doc('profile');

  await profileRef.set({
    id: userRecord.uid,
    username: adminUsername,
    displayName: adminUsername,
    email: adminEmail,
    role: 'admin',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`[Provisioning] Successfully updated Firestore admin profile document.`);
  console.log(`[Provisioning] ADMIN account provisioning complete!`);
}

provisionAdminAccount().catch((err) => {
  console.error('[Provisioning Error] Failed to provision admin account:', err);
  process.exit(1);
});
