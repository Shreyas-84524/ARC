const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp,
} = require('@firebase/firestore');

const PROJECT_ID = 'arc-productivity-shreyas';
const RULES_PATH = path.resolve(__dirname, '../firestore.rules');

async function runTestSuite() {
  console.log('===============================================================');
  console.log('Project Arc — Cloud Firestore Security Rules Verification Suite');
  console.log('Target Project: ' + PROJECT_ID);
  console.log('Rules File:     ' + RULES_PATH);
  console.log('===============================================================\n');

  const rulesContent = fs.readFileSync(RULES_PATH, 'utf8');

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: rulesContent,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  let passedTests = 0;
  let totalTests = 10;

  try {
    // -------------------------------------------------------------
    // Test 1: Authenticated user creates valid feedback
    // -------------------------------------------------------------
    console.log('[TEST 1] Authenticated user creates valid feedback...');
    const aliceContext = testEnv.authenticatedContext('user_alice');
    const aliceDb = aliceContext.firestore();

    const validFeedbackDoc = doc(aliceDb, 'feedback', 'fb_valid_alice');
    await assertSucceeds(
      setDoc(validFeedbackDoc, {
        feedbackId: 'fb_valid_alice',
        userId: 'user_alice',
        category: 'bug_report',
        module: 'task_manager',
        message: 'Sync stopped working when cellular data is limited',
        rating: 4,
        contactEmail: 'alice@arc.app',
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        emailedAt: null,
        reviewedAt: null,
        acknowledgedAt: null,
        notificationDelivered: false,
      })
    );
    console.log('  PASS: Authenticated user successfully submitted valid feedback.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 2: Unauthenticated submission is rejected
    // -------------------------------------------------------------
    console.log('[TEST 2] Unauthenticated submission is rejected...');
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const unauthDoc = doc(unauthDb, 'feedback', 'fb_unauth');
    await assertFails(
      setDoc(unauthDoc, {
        feedbackId: 'fb_unauth',
        userId: 'user_anonymous',
        category: 'general_feedback',
        module: 'app',
        message: 'Anonymous feedback',
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        notificationDelivered: false,
      })
    );
    console.log('  PASS: Unauthenticated feedback submission rejected.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 3: User A cannot read User B's feedback (Author can read own)
    // -------------------------------------------------------------
    console.log('[TEST 3] User A cannot read User B feedback...');
    const bobContext = testEnv.authenticatedContext('user_bob');
    const bobDb = bobContext.firestore();

    // Bob tries to read Alice's feedback
    await assertFails(getDoc(doc(bobDb, 'feedback', 'fb_valid_alice')));

    // Alice reads her own feedback
    await assertSucceeds(getDoc(doc(aliceDb, 'feedback', 'fb_valid_alice')));
    console.log('  PASS: User-isolated boundary enforced: cross-user read denied, owner read allowed.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 4: User cannot forge another UID
    // -------------------------------------------------------------
    console.log('[TEST 4] User cannot forge another UID...');
    const forgeDoc = doc(aliceDb, 'feedback', 'fb_forged_uid');
    await assertFails(
      setDoc(forgeDoc, {
        feedbackId: 'fb_forged_uid',
        userId: 'user_bob', // Alice forging Bob's UID
        category: 'feature_request',
        module: 'money_tracker',
        message: 'Alice impersonating Bob',
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        notificationDelivered: false,
      })
    );
    console.log('  PASS: User ID spoofing rejected.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 5: User cannot change feedback status after submission
    // -------------------------------------------------------------
    console.log('[TEST 5] User cannot change feedback status after submission...');
    await assertFails(
      updateDoc(validFeedbackDoc, {
        status: 'reviewed',
      })
    );
    console.log('  PASS: Normal user update of feedback status rejected.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 6: User cannot set reviewed/acknowledged timestamps or forged delivery
    // -------------------------------------------------------------
    console.log('[TEST 6] User cannot set reviewed/acknowledged timestamps or markers...');
    const forgeTimestampDoc = doc(aliceDb, 'feedback', 'fb_forge_timestamps');
    await assertFails(
      setDoc(forgeTimestampDoc, {
        feedbackId: 'fb_forge_timestamps',
        userId: 'user_alice',
        category: 'bug_report',
        module: 'tasks',
        message: 'Trying to mark as reviewed during creation',
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        reviewedAt: serverTimestamp(), // Forged!
        notificationDelivered: false,
      })
    );
    await assertFails(
      updateDoc(validFeedbackDoc, {
        reviewedAt: serverTimestamp(),
        acknowledgedAt: serverTimestamp(),
        notificationDelivered: true,
      })
    );
    console.log('  PASS: Forged review timestamps and delivery markers rejected.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 7: User cannot impersonate an administrator via client profile
    // -------------------------------------------------------------
    console.log('[TEST 7] User cannot gain feedback admin access via profile tampering...');
    // Alice places role: 'admin' in her own profile
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminFirestore = context.firestore();
      await setDoc(doc(adminFirestore, 'users', 'user_alice', 'settings', 'profile'), {
        role: 'admin',
      });
    });

    // Alice still does NOT have custom claims token.role == 'admin'
    // Alice tries to read Bob's feedback or update status
    const bobFeedbackDoc = doc(bobDb, 'feedback', 'fb_bob_001');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminFirestore = context.firestore();
      await setDoc(doc(adminFirestore, 'feedback', 'fb_bob_001'), {
        feedbackId: 'fb_bob_001',
        userId: 'user_bob',
        category: 'app_rating',
        module: 'general',
        message: 'Great app',
        rating: 5,
        appVersion: '1.3.5',
        createdAt: Timestamp.now(),
        status: 'submitted',
        notificationDelivered: false,
      });
    });

    // Alice attempts to read Bob's feedback relying on profile role == 'admin'
    await assertFails(getDoc(doc(aliceDb, 'feedback', 'fb_bob_001')));
    // Alice attempts to update Bob's feedback status
    await assertFails(updateDoc(doc(aliceDb, 'feedback', 'fb_bob_001'), { status: 'reviewed' }));
    console.log('  PASS: Client-controlled document role tampering rejected for feedback admin access.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 8: Authorized admin access works via custom claims
    // -------------------------------------------------------------
    console.log('[TEST 8] Authorized admin access works via custom claims...');
    const adminContext = testEnv.authenticatedContext('admin_user', {
      role: 'admin',
    });
    const adminDb = adminContext.firestore();

    // Admin reads feedback across users
    await assertSucceeds(getDoc(doc(adminDb, 'feedback', 'fb_bob_001')));
    await assertSucceeds(getDoc(doc(adminDb, 'feedback', 'fb_valid_alice')));

    // Admin updates review and acknowledgement fields
    await assertSucceeds(
      updateDoc(doc(adminDb, 'feedback', 'fb_bob_001'), {
        status: 'reviewed',
        reviewedAt: serverTimestamp(),
      })
    );
    await assertSucceeds(
      updateDoc(doc(adminDb, 'feedback', 'fb_bob_001'), {
        status: 'acknowledged',
        acknowledgedAt: serverTimestamp(),
      })
    );

    // Admin cannot delete feedback
    await assertFails(deleteDoc(doc(adminDb, 'feedback', 'fb_bob_001')));

    // Admin cannot alter core immutable fields (e.g. message or userId)
    await assertFails(
      updateDoc(doc(adminDb, 'feedback', 'fb_bob_001'), {
        message: 'Tampered message by admin',
      })
    );
    console.log('  PASS: Authorized admin can read all, update review/acknowledgement, but cannot delete or tamper core fields.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 9: Invalid categories and oversized messages are rejected
    // -------------------------------------------------------------
    console.log('[TEST 9] Invalid categories and oversized messages are rejected...');
    // Invalid category
    await assertFails(
      setDoc(doc(aliceDb, 'feedback', 'fb_bad_cat'), {
        feedbackId: 'fb_bad_cat',
        userId: 'user_alice',
        category: 'unsupported_category',
        module: 'tasks',
        message: 'Normal message',
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        notificationDelivered: false,
      })
    );

    // Oversized message (> 5000 characters)
    const longMsg = 'X'.repeat(5001);
    await assertFails(
      setDoc(doc(aliceDb, 'feedback', 'fb_oversized'), {
        feedbackId: 'fb_oversized',
        userId: 'user_alice',
        category: 'bug_report',
        module: 'tasks',
        message: longMsg,
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        notificationDelivered: false,
      })
    );

    // Invalid rating (> 5)
    await assertFails(
      setDoc(doc(aliceDb, 'feedback', 'fb_bad_rating'), {
        feedbackId: 'fb_bad_rating',
        userId: 'user_alice',
        category: 'app_rating',
        module: 'app',
        message: 'Rating 99',
        rating: 99,
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        notificationDelivered: false,
      })
    );

    // Unknown field injection
    await assertFails(
      setDoc(doc(aliceDb, 'feedback', 'fb_extra_field'), {
        feedbackId: 'fb_extra_field',
        userId: 'user_alice',
        category: 'general_feedback',
        module: 'general',
        message: 'Field injection',
        appVersion: '1.3.5',
        createdAt: serverTimestamp(),
        status: 'submitted',
        notificationDelivered: false,
        maliciousField: true,
      })
    );
    console.log('  PASS: Invalid category, oversized message, invalid rating, and field injection rejected.\n');
    passedTests++;

    // -------------------------------------------------------------
    // Test 10: Existing collection security rules continue working
    // -------------------------------------------------------------
    console.log('[TEST 10] Existing collection security rules continue working...');
    // User-scoped data boundary: Alice writes and reads her own tasks
    const aliceTaskDoc = doc(aliceDb, 'users', 'user_alice', 'tasks', 'task_1');
    await assertSucceeds(setDoc(aliceTaskDoc, { title: 'Alice Task' }));
    await assertSucceeds(getDoc(aliceTaskDoc));

    // Bob cannot read or write Alice's tasks
    const bobAccessingAliceTask = doc(bobDb, 'users', 'user_alice', 'tasks', 'task_1');
    await assertFails(getDoc(bobAccessingAliceTask));
    await assertFails(setDoc(bobAccessingAliceTask, { title: 'Tampered' }));

    // Legacy backup collections: authenticated read allowed, unauthenticated denied
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminFirestore = context.firestore();
      await setDoc(doc(adminFirestore, 'tasks', 'legacy_1'), { title: 'Legacy Task' });
    });
    await assertSucceeds(getDoc(doc(aliceDb, 'tasks', 'legacy_1')));
    await assertFails(getDoc(doc(unauthDb, 'tasks', 'legacy_1')));

    // Admin logs: Admin can write/read, normal user (Bob) cannot
    const adminLogDoc = doc(adminDb, 'admin_logs', 'log_001');
    await assertSucceeds(setDoc(adminLogDoc, { action: 'TEST_LOG', timestamp: serverTimestamp() }));
    const bobAdminLogDoc = doc(bobDb, 'admin_logs', 'log_001');
    await assertFails(getDoc(bobAdminLogDoc));
    await assertFails(setDoc(bobAdminLogDoc, { action: 'FORGED_LOG' }));

    console.log('  PASS: Existing user boundary, admin logs, and legacy collections function as specified.\n');
    passedTests++;

    console.log('===============================================================');
    console.log(`ALL TESTS PASSED: ${passedTests}/${totalTests} scenarios verified!`);
    console.log('===============================================================');
  } finally {
    await testEnv.cleanup();
  }
}

runTestSuite().catch((err) => {
  console.error('Test Suite Failed with error:', err);
  process.exit(1);
});
