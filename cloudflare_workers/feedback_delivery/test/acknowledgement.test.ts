import { describe, it, expect, vi, beforeEach } from 'vitest';
import { generateAcknowledgementToken, verifyAcknowledgementToken } from '../src/utils/hmac';
import { renderFeedbackEmail } from '../src/brevo/template';
import { FeedbackItem } from '../src/brevo/types';
import worker from '../src/index';

describe('Phase 4: Feedback Acknowledgement & Worker Routes', () => {
  const secretKey = 'test-cron-secret-12345';
  const sampleFeedback: FeedbackItem = {
    id: 'fb-ack-101',
    documentPath: 'projects/arc-test/databases/(default)/documents/feedback/fb-ack-101',
    updateTime: '2026-10-26T12:00:00Z',
    userId: 'user-submitter-777',
    category: 'bug_report',
    module: 'task_manager',
    message: 'Task due date picker crashes when selecting end of month.',
    rating: 2,
    contactEmail: 'user@example.com',
    appVersion: '1.3.5',
    createdAt: '2026-10-26T12:00:00Z',
    status: 'emailed',
    dispatchAttemptCount: 1,
    emailRetryCount: 0,
  };

  describe('HMAC Token Generation and Verification', () => {
    it('generates a deterministic HMAC-SHA256 signature', async () => {
      const token1 = await generateAcknowledgementToken('fb-ack-101', secretKey);
      const token2 = await generateAcknowledgementToken('fb-ack-101', secretKey);
      expect(token1).toBe(token2);
      expect(token1.length).toBe(64); // 32 bytes hex = 64 chars
    });

    it('verifies a valid token successfully', async () => {
      const token = await generateAcknowledgementToken('fb-ack-101', secretKey);
      const isValid = await verifyAcknowledgementToken('fb-ack-101', token, secretKey);
      expect(isValid).toBe(true);
    });

    it('rejects an invalid, tampered, or mismatched token', async () => {
      const token = await generateAcknowledgementToken('fb-ack-101', secretKey);
      const isMismatched = await verifyAcknowledgementToken('fb-different-id', token, secretKey);
      expect(isMismatched).toBe(false);

      const isTampered = await verifyAcknowledgementToken(
        'fb-ack-101',
        token.replace(/^./, token[0] === 'a' ? 'b' : 'a'),
        secretKey
      );
      expect(isTampered).toBe(false);
    });
  });

  describe('Email Template Review & Acknowledge CTA', () => {
    it('generates an email containing the secure Review & Acknowledge button and URL', async () => {
      const token = await generateAcknowledgementToken('fb-ack-101', secretKey);
      const workerBaseUrl = 'https://arc-feedback-delivery-worker.arc-feedback-shreyas.workers.dev';

      const rendered = renderFeedbackEmail(sampleFeedback, {
        workerBaseUrl,
        ackToken: token,
      });

      expect(rendered.ackUrl).toBeDefined();
      expect(rendered.ackUrl).toContain('/acknowledge?id=fb-ack-101&token=');
      expect(rendered.htmlContent).toContain('Review &amp; Acknowledge Feedback');
      expect(rendered.htmlContent).toContain(rendered.ackUrl.replace('&', '&amp;'));
      expect(rendered.textContent).toContain('REVIEW & ACKNOWLEDGE FEEDBACK:');
      expect(rendered.textContent).toContain(rendered.ackUrl);
    });

    it('omits acknowledgement button if workerBaseUrl or ackToken are not provided', () => {
      const rendered = renderFeedbackEmail(sampleFeedback);
      expect(rendered.ackUrl).toBeUndefined();
      expect(rendered.htmlContent).not.toContain('Review &amp; Acknowledge Feedback');
    });
  });

  describe('Worker Endpoints Security & Authorization', () => {
    const env: any = {
      BREVO_API_KEY: 'test-brevo-key',
      SENDER_EMAIL: 'sender@arc.app',
      RECIPIENT_EMAIL: 'admin@arc.app',
      FIREBASE_PROJECT_ID: 'arc-test-project',
      FIREBASE_CLIENT_EMAIL: 'sa@arc-test-project.iam.gserviceaccount.com',
      FIREBASE_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC3\n-----END PRIVATE KEY-----',
      CRON_SECRET: secretKey,
    };

    const ctx: any = { waitUntil: vi.fn() };

    it('GET /acknowledge returns 400 when id or token are missing', async () => {
      const req = new Request('https://worker.dev/acknowledge');
      const res = await worker.fetch(req, env, ctx);
      expect(res.status).toBe(400);
      const text = await res.text();
      expect(text).toContain('Invalid Acknowledgement Request');
    });

    it('GET /acknowledge returns 403 when HMAC token is invalid', async () => {
      const req = new Request('https://worker.dev/acknowledge?id=fb-1&token=invalid-hmac');
      const res = await worker.fetch(req, env, ctx);
      expect(res.status).toBe(403);
      const text = await res.text();
      expect(text).toContain('Invalid or Expired Token');
    });

    it('POST /api/acknowledge returns 400 when body is missing required fields', async () => {
      const req = new Request('https://worker.dev/api/acknowledge', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
      const res = await worker.fetch(req, env, ctx);
      expect(res.status).toBe(400);
      const data = (await res.json()) as any;
      expect(data.error).toContain('Missing feedbackId or token');
    });

    it('POST /api/acknowledge returns 403 when HMAC token is forged', async () => {
      const req = new Request('https://worker.dev/api/acknowledge', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedbackId: 'fb-1', token: 'bad-token' }),
      });
      const res = await worker.fetch(req, env, ctx);
      expect(res.status).toBe(403);
      const data = (await res.json()) as any;
      expect(data.error).toContain('Invalid or forged acknowledgement token');
    });

    it('POST /api/acknowledge returns 401 when Authorization header is absent', async () => {
      const validToken = await generateAcknowledgementToken('fb-1', secretKey);
      const req = new Request('https://worker.dev/api/acknowledge', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedbackId: 'fb-1', token: validToken }),
      });
      const res = await worker.fetch(req, env, ctx);
      expect(res.status).toBe(401);
      const data = (await res.json()) as any;
      expect(data.error).toContain('Authentication required');
    });

    it('POST /api/feedback/details returns 401 when Authorization header is absent', async () => {
      const validToken = await generateAcknowledgementToken('fb-1', secretKey);
      const req = new Request('https://worker.dev/api/feedback/details', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedbackId: 'fb-1', token: validToken }),
      });
      const res = await worker.fetch(req, env, ctx);
      expect(res.status).toBe(401);
      const data = (await res.json()) as any;
      expect(data.error).toContain('Authentication required');
    });

    it('POST /api/feedback/details returns 403 when HMAC token is invalid', async () => {
      const req = new Request('https://worker.dev/api/feedback/details', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedbackId: 'fb-1', token: 'forged-token' }),
      });
      const res = await worker.fetch(req, env, ctx);
      expect(res.status).toBe(403);
      const data = (await res.json()) as any;
      expect(data.error).toContain('Invalid or forged acknowledgement token');
    });
  });
});
