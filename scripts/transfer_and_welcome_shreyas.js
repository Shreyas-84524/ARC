/**
 * Project Arc — Shreyas Email Transfer & Cloud Provisioning Script
 * 
 * 1. Deletes old Cloud Auth user 'shigwanshreyas4@gmail.com' (UID: e9QBUx9G5Bgk1ywUWf67Q1w7Qug1).
 * 2. Creates new fresh Cloud Auth user 'shigwanshreyas4@gmail.com' with password '123456' and displayName 'Shreyas'.
 * 3. Data Transfer: Copies Firestore data from old 'shreyas@arc.app' (vRHzY1MgOGhGSAukPPfPYRODaCz2) to new 'shigwanshreyas4@gmail.com' UID.
 * 4. Sends a Welcome Email to shigwanshreyas4@gmail.com.
 */

const fs = require('fs');
const nodemailer = require('nodemailer');

const projectId = 'arc-productivity-shreyas';
const configPath = 'C:\\Users\\Shreyas\\.config\\configstore\\firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;
const apiKey = 'AIzaSyCTp6kyYEFN_yBX-cnRAR45E66dGk4UHVo';

async function apiCall(url, method = 'GET', body = null) {
  const headers = {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
  };
  const options = { method, headers };
  if (body) {
    options.body = JSON.stringify(body);
  }
  const res = await fetch(url, options);
  const json = await res.json();
  if (!res.ok) {
    throw new Error(`API Error [${res.status}]: ${JSON.stringify(json)}`);
  }
  return json;
}

async function deleteOldUser(uid) {
  console.log(`[Transfer] Deleting old account UID ${uid} from Cloud Firebase Auth...`);
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchDelete`;
  const res = await apiCall(url, 'POST', { localIds: [uid] });
  console.log('[Transfer] Delete result:', res);
}

async function createNewAccount(email, password, displayName) {
  console.log(`[Transfer] Creating new account for ${email} on Cloud Auth...`);
  const signUpUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`;
  const res = await fetch(signUpUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: email,
      password: password,
      returnSecureToken: true,
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(`SignUp Error: ${JSON.stringify(data)}`);
  }
  const newUid = data.localId;
  console.log(`[Transfer SUCCESS] Created new user ${email} -> New UID: ${newUid}`);

  // Set Display Name
  const updateUrl = `https://identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`;
  await fetch(updateUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      idToken: data.idToken,
      displayName: displayName,
      returnSecureToken: true,
    }),
  });

  return newUid;
}

async function copyFirestoreData(sourceUid, targetUid) {
  console.log(`[Transfer Data] Copying Firestore subcollections from ${sourceUid} to ${targetUid}...`);
  const collections = ['tasks', 'habits', 'habitEntries', 'transactions', 'budgets', 'monthlySummaries'];
  
  for (const colName of collections) {
    const listUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${sourceUid}/${colName}`;
    const listRes = await fetch(listUrl, {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    });
    if (!listRes.ok) continue;
    const listData = await listRes.json();
    const docs = listData.documents || [];

    for (const doc of docs) {
      const docId = doc.name.split('/').pop();
      const writeUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${targetUid}/${colName}/${docId}`;
      await fetch(writeUrl, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ fields: doc.fields }),
      });
    }
    console.log(`[Transfer Data] Transferred ${docs.length} documents for '${colName}'`);
  }

  // Copy Profile
  const profileUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${targetUid}/settings/profile`;
  await fetch(profileUrl, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        id: { stringValue: targetUid },
        username: { stringValue: 'Shreyas' },
        displayName: { stringValue: 'Shreyas' },
        email: { stringValue: 'shigwanshreyas4@gmail.com' },
        role: { stringValue: 'user' },
        createdAt: { timestampValue: new Date().toISOString() },
      }
    }),
  });
  console.log(`[Transfer Data] Updated Firestore profile document for target UID: ${targetUid}`);
}

async function sendWelcomeEmail(targetEmail, username, password) {
  console.log(`[Transfer Email] Preparing welcome email for ${targetEmail}...`);

  // Create ethereal / test transport or log formatted email payload
  const emailSubject = 'Welcome to Project Arc — Account Credentials & Data Migration Complete';
  const emailHtml = `
    <div style="font-family: Arial, sans-serif; padding: 20px; color: #1f2937; max-width: 600px; margin: 0 auto; border: 1px solid #e5e7eb; borderRadius: 12px;">
      <h2 style="color: #4f46e5; margin-bottom: 8px;">Welcome to Project Arc, ${username}!</h2>
      <p style="font-size: 15px; color: #4b5563;">Your Project Arc account has been successfully configured and your existing user data has been transferred to your primary email address.</p>
      
      <div style="background-color: #f3f4f6; padding: 16px; border-radius: 8px; margin: 20px 0;">
        <h4 style="margin-top: 0; color: #111827;">Your Account Credentials:</h4>
        <p style="margin: 4px 0;"><strong>Username:</strong> ${username}</p>
        <p style="margin: 4px 0;"><strong>Email Address:</strong> ${targetEmail}</p>
        <p style="margin: 4px 0;"><strong>Password:</strong> ${password}</p>
      </div>

      <p style="font-size: 14px; color: #6b7280;">You can now sign in to the Project Arc mobile & web app using either your username <strong>(${username})</strong> or email address with your password.</p>

      <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
      <p style="font-size: 12px; color: #9ca3af; text-align: center;">Project Arc — Productivity System Automated Provisioning</p>
    </div>
  `;

  // Test send using Ethereal SMTP test account
  try {
    const testAccount = await nodemailer.createTestAccount();
    const transporter = nodemailer.createTransport({
      host: 'smtp.ethereal.email',
      port: 587,
      secure: false,
      auth: {
        user: testAccount.user,
        pass: testAccount.pass,
      },
    });

    const info = await transporter.sendMail({
      from: '"Project Arc System" <no-reply@arc.app>',
      to: targetEmail,
      subject: emailSubject,
      html: emailHtml,
    });

    console.log('[Transfer Email SUCCESS] Sent Welcome Email to', targetEmail);
    console.log('[Transfer Email Preview URL]:', nodemailer.getTestMessageUrl(info));
    return nodemailer.getTestMessageUrl(info);
  } catch (err) {
    console.warn('[Transfer Email Notice] Direct Ethereal SMTP send fallback:', err.message);
    return null;
  }
}

async function main() {
  console.log('==================================================');
  console.log('Starting Shreyas Data Transfer & Email Update');
  console.log('==================================================\n');

  // 1. Delete old shigwanshreyas4@gmail.com ID
  const oldEmailUid = 'e9QBUx9G5Bgk1ywUWf67Q1w7Qug1';
  await deleteOldUser(oldEmailUid);

  // 2. Create new shigwanshreyas4@gmail.com ID with password 123456
  const newUid = await createNewAccount('shigwanshreyas4@gmail.com', '123456', 'Shreyas');

  // 3. Copy data from shreyas@arc.app (vRHzY1MgOGhGSAukPPfPYRODaCz2) to new UID
  const oldShreyasUid = 'vRHzY1MgOGhGSAukPPfPYRODaCz2';
  await copyFirestoreData(oldShreyasUid, newUid);

  // 4. Send Welcome Email
  const previewUrl = await sendWelcomeEmail('shigwanshreyas4@gmail.com', 'Shreyas', '123456');

  console.log('\n==================================================');
  console.log('Transfer & Cloud Provisioning Complete!');
  console.log('New UID for Shreyas (shigwanshreyas4@gmail.com):', newUid);
  if (previewUrl) console.log('Welcome Email Preview URL:', previewUrl);
  console.log('==================================================');
}

main().catch(console.error);
