/**
 * Permanent deletion script for old shreyas@arc.app ID (vRHzY1MgOGhGSAukPPfPYRODaCz2) from Cloud Firebase Auth.
 */

const fs = require('fs');

const projectId = 'arc-productivity-shreyas';
const configPath = 'C:\\Users\\Shreyas\\.config\\configstore\\firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;

async function deleteAccount(uid) {
  console.log(`[Delete Script] Permanently deleting old user UID ${uid} (shreyas@arc.app) from Cloud Firebase Auth...`);
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchDelete`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ localIds: [uid] }),
  });
  const data = await res.json();
  console.log('[Delete Script Result]:', res.status, data);
}

deleteAccount('vRHzY1MgOGhGSAukPPfPYRODaCz2').catch(console.error);
