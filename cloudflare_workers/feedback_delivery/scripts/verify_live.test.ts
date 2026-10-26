import { describe, it, expect } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import { GoogleAuthService } from '../src/firestore/auth';
import { ValidatedConfig } from '../src/config';

function loadEnv(): Record<string, string> {
  const filePath = path.resolve(__dirname, '../.dev.vars');
  const env: Record<string, string> = {};
  const content = fs.readFileSync(filePath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    let val = trimmed.slice(eqIdx + 1).trim();
    if (val.startsWith('"') && val.endsWith('"')) {
      val = val.slice(1, -1);
    } else if (val.startsWith("'") && val.endsWith("'")) {
      val = val.slice(1, -1);
    }
    env[key] = val.replace(/\\n/g, '\n');
  }
  return env;
}

describe('Live Credentials Verification', () => {
  const env = loadEnv();

  it('authenticates with Google Cloud and obtains an OAuth2 access token for Firestore', async () => {
    const config: ValidatedConfig = {
      brevoApiKey: env.BREVO_API_KEY,
      senderEmail: env.SENDER_EMAIL,
      senderName: env.SENDER_NAME || 'Project Arc Feedback',
      recipientEmail: env.RECIPIENT_EMAIL,
      firebaseProjectId: env.FIREBASE_PROJECT_ID,
      firebaseClientEmail: env.FIREBASE_CLIENT_EMAIL,
      firebasePrivateKey: env.FIREBASE_PRIVATE_KEY,
      batchSize: 10,
      maxRetries: 5,
    };

    const authService = new GoogleAuthService(config);
    const token = await authService.getAccessToken();
    expect(token).toBeDefined();
    expect(token.length).toBeGreaterThan(20);
    console.log('✓ Successfully authenticated with Google Cloud IAM. Access token obtained.');
  });

  it('validates Brevo API Key against Brevo account endpoint', async () => {
    const res = await fetch('https://api.brevo.com/v3/account', {
      headers: {
        accept: 'application/json',
        'api-key': env.BREVO_API_KEY,
      },
    });

    const bodyText = await res.text();
    console.log(`Brevo /account status: ${res.status}, response: ${bodyText}`);
    expect(res.ok).toBe(true);
    const data = (await res.json()) as any;
    console.log('✓ Connected to Brevo API. Account email:', data.email);
    console.log('  Plan type:', data.plan?.[0]?.type || 'Free');
  });

  it('checks configured Brevo senders list', async () => {
    const res = await fetch('https://api.brevo.com/v3/senders', {
      headers: {
        accept: 'application/json',
        'api-key': env.BREVO_API_KEY,
      },
    });

    expect(res.ok).toBe(true);
    const data = (await res.json()) as any;
    const senders: any[] = data.senders || [];
    const configured = (env.SENDER_EMAIL || '').toLowerCase();
    const matched = senders.find((s) => s.email.toLowerCase() === configured);
    console.log('  Available Brevo senders:', senders.map((s) => s.email).join(', '));
    if (matched) {
      console.log(`✓ SENDER_EMAIL (${env.SENDER_EMAIL}) is verified and active:`, matched.active);
    } else {
      console.warn(`! Warning: SENDER_EMAIL (${env.SENDER_EMAIL}) not found in Brevo senders list.`);
    }
  });
});
