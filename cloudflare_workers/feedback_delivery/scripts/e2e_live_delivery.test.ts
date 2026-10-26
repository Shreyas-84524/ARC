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

describe('End-to-End Live Delivery Verification', () => {
  const env = loadEnv();
  const config: ValidatedConfig = {
    brevoApiKey: env.BREVO_API_KEY,
    senderEmail: env.SENDER_EMAIL,
    senderName: env.SENDER_NAME || 'Project Arc Feedback',
    recipientEmail: env.RECIPIENT_EMAIL,
    firebaseProjectId: env.FIREBASE_PROJECT_ID,
    firebaseClientEmail: env.FIREBASE_CLIENT_EMAIL,
    firebasePrivateKey: env.FIREBASE_PRIVATE_KEY,
    cronSecret: env.CRON_SECRET,
    batchSize: 10,
    maxRetries: 5,
  };

  const authService = new GoogleAuthService(config);
  const workerBaseUrl = 'https://arc-feedback-delivery-worker.arc-feedback-shreyas.workers.dev';
  const feedbackId = `e2e-phase3-${Date.now()}`;

  it('verifies Cloudflare Worker health endpoint', async () => {
    const res = await fetch(`${workerBaseUrl}/health`);
    expect(res.ok).toBe(true);
    const data = (await res.json()) as any;
    expect(data.status).toBe('healthy');
    console.log('✓ Worker is healthy:', data);
  });

  it('creates a test feedback document in Firestore', async () => {
    const token = await authService.getAccessToken();
    const docUrl = `https://firestore.googleapis.com/v1/projects/${config.firebaseProjectId}/databases/(default)/documents/feedback?documentId=${feedbackId}`;
    const now = new Date().toISOString();

    const payload = {
      fields: {
        feedbackId: { stringValue: feedbackId },
        userId: { stringValue: 'test-admin-e2e-verifier' },
        category: { stringValue: 'feature_request' },
        module: { stringValue: 'analytics' },
        message: { stringValue: 'E2E delivery verification test for Phase 3 Cloudflare Worker + Brevo integration.' },
        rating: { integerValue: '5' },
        contactEmail: { stringValue: config.recipientEmail },
        appVersion: { stringValue: '1.0.0+1' },
        createdAt: { timestampValue: now },
        status: { stringValue: 'submitted' },
        notificationDelivered: { booleanValue: false },
      },
    };

    const res = await fetch(docUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const bodyText = await res.text();
    console.log(`Firestore create document status: ${res.status}`);
    expect(res.ok).toBe(true);
    console.log(`✓ Test document created: feedback/${feedbackId}`);
  });

  it('triggers Worker dispatch endpoint and inspects processing summary', async () => {
    const res = await fetch(`${workerBaseUrl}/dispatch`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.cronSecret}`,
      },
    });

    const bodyText = await res.text();
    console.log(`Worker dispatch response (${res.status}):`, bodyText);
    expect(res.ok).toBe(true);
    const data = JSON.parse(bodyText);
    expect(data.success).toBe(true);
    expect(data.summary.discovered).toBeGreaterThanOrEqual(1);
    console.log('✓ Dispatch executed. Summary:', data.summary);
  });

  it('inspects the Firestore document status after dispatch', async () => {
    const token = await authService.getAccessToken();
    const docUrl = `https://firestore.googleapis.com/v1/projects/${config.firebaseProjectId}/databases/(default)/documents/feedback/${feedbackId}`;

    const res = await fetch(docUrl, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    expect(res.ok).toBe(true);
    const doc = (await res.json()) as any;
    const fields = doc.fields || {};

    console.log('Post-dispatch Firestore Document State:');
    console.log('  status:', fields.status?.stringValue);
    console.log('  emailedAt:', fields.emailedAt?.timestampValue);
    console.log('  emailDeliveryMessageId:', fields.emailDeliveryMessageId?.stringValue);
    console.log('  emailLastError:', fields.emailLastError?.stringValue);
    console.log('  dispatchAttemptCount:', fields.dispatchAttemptCount?.integerValue);

    // If Brevo IP blocking is active, it will have status: 'submitted' and emailLastError with 401 unrecognised IP
    // If Brevo accepted it, status will be 'emailed'
    if (fields.status?.stringValue === 'emailed') {
      console.log('🎉 SUCCESS: Email delivery accepted and document updated to "emailed"!');
      expect(fields.status?.stringValue).toBe('emailed');
      expect(fields.emailDeliveryMessageId?.stringValue).toBeDefined();
    } else {
      console.warn('⚠️ Document was not marked as emailed. Last error:', fields.emailLastError?.stringValue);
      expect(fields.status?.stringValue).toBe('emailed');
    }
  });
});
