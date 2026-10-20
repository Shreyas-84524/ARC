const fs = require('fs');

const projectId = 'arc-productivity-shreyas';
const configPath = 'C:\\Users\\Shreyas\\.config\\configstore\\firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens.access_token;

async function test() {
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts`;
  console.log('Fetching:', url);
  const res = await fetch(url, {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  console.log('Status:', res.status, res.statusText);
  const text = await res.text();
  console.log('Response body:', text);
}

test();
