import * as fs from 'fs';
import * as path from 'path';

const envPath = path.resolve('cloudflare_workers/feedback_delivery/.dev.vars');
const content = fs.readFileSync(envPath, 'utf8');

let cronSecret = '';
for (const line of content.split('\n')) {
  if (line.startsWith('CRON_SECRET=')) {
    cronSecret = line.slice('CRON_SECRET='.length).trim();
  }
}

async function testDispatch() {
  console.log('Calling POST /dispatch on Cloudflare Worker...');
  const res = await fetch('https://arc-feedback-delivery-worker.arc-feedback-shreyas.workers.dev/dispatch', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${cronSecret}`
    }
  });

  const text = await res.text();
  console.log('Status:', res.status);
  console.log('Response body:', text);
}

testDispatch();
