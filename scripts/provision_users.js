/**
 * Project Arc — User Provisioning & Reset Script
 * 
 * Deletes and re-creates specified user accounts ('Shreyas', 'Sachi') or provisions
 * all Project Arc users ('Shreyas', 'Purushottam', 'Sachi', 'Aman', 'Rohit', 'Yash') with password '123456'.
 * 
 * Usage (Backend / CI / Admin Environment):
 *   node scripts/provision_users.js [--recreate]
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const recreateUsers = process.argv.includes('--recreate') || true; // Recreate mode enabled

const usersToProvision = [
  {
    username: 'Shreyas',
    email: 'shreyas@arc.app',
    password: process.env.SHREYAS_PASSWORD || '123456',
    role: 'user',
    recreate: true, // Delete old account & create fresh ID
  },
  {
    username: 'Sachi',
    email: 'sachi@arc.app',
    password: process.env.SACHI_PASSWORD || '123456',
    role: 'user',
    recreate: true, // Delete old account & create fresh ID
  },
  {
    username: 'Purushottam',
    email: 'purushottam@arc.app',
    password: process.env.PURUSHOTTAM_PASSWORD || '123456',
    role: 'user',
  },
  {
    username: 'Aman',
    email: 'aman@arc.app',
    password: process.env.AMAN_PASSWORD || '123456',
    role: 'user',
  },
  {
    username: 'Rohit',
    email: 'rohit@arc.app',
    password: process.env.ROHIT_PASSWORD || '123456',
    role: 'user',
  },
  {
    username: 'Yash',
    email: 'yash@arc.app',
    password: process.env.YASH_PASSWORD || '123456',
    role: 'user',
  },
];

async function provisionUsers() {
  console.log('[Provisioning] Starting user account recreate & setup for Project Arc users...');

  for (const userDef of usersToProvision) {
    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(userDef.email);
      if (userDef.recreate) {
        console.log(`[Provisioning] Deleting existing Auth user for ${userDef.username} (UID: ${userRecord.uid})...`);
        await admin.auth().deleteUser(userRecord.uid);
        
        // Clean up old Firestore profile
        const db = admin.firestore();
        await db.collection('users').doc(userRecord.uid).delete().catch(() => {});

        // Re-create user fresh
        userRecord = await admin.auth().createUser({
          email: userDef.email,
          password: userDef.password,
          displayName: userDef.username,
        });
        console.log(`[Provisioning] Created new fresh Auth account for ${userDef.username} (New UID: ${userRecord.uid}).`);
      } else {
        console.log(`[Provisioning] Existing Auth account found for ${userDef.username} (UID: ${userRecord.uid}). Updating credentials...`);
        await admin.auth().updateUser(userRecord.uid, {
          password: userDef.password,
          displayName: userDef.username,
        });
      }
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        userRecord = await admin.auth().createUser({
          email: userDef.email,
          password: userDef.password,
          displayName: userDef.username,
        });
        console.log(`[Provisioning] Created new Firebase Auth account for ${userDef.username} (UID: ${userRecord.uid}).`);
      } else {
        throw error;
      }
    }

    // Set Firestore User Profile document
    const db = admin.firestore();
    const profileRef = db.collection('users').doc(userRecord.uid).collection('settings').doc('profile');

    await profileRef.set({
      id: userRecord.uid,
      username: userDef.username,
      displayName: userDef.username,
      email: userDef.email,
      role: userDef.role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`[Provisioning] User profile configured in Firestore for ${userDef.username}.`);
  }

  console.log('[Provisioning] All user accounts re-provisioned and updated successfully!');
}

provisionUsers().catch((err) => {
  console.error('[Provisioning Error] Failed to provision user accounts:', err);
  process.exit(1);
});
