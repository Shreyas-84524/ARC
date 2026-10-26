import { describe, it, expect, vi, beforeEach } from 'vitest';
import worker, { processFeedbackBatch } from '../src/index';
import { Env, ValidatedConfig } from '../src/config';

describe('Cloudflare Worker HTTP & Dispatch Flow Tests', () => {
  const mockConfig: ValidatedConfig = {
    brevoApiKey: 'test-brevo-key',
    senderEmail: 'feedback@test.arc',
    senderName: 'Arc Feedback Test',
    recipientEmail: 'admin@arc.test',
    firebaseProjectId: 'test-project',
    firebaseClientEmail: 'worker@test-project.iam.gserviceaccount.com',
    firebasePrivateKey: 'test-key',
    cronSecret: 'super-secret-token-123',
    batchSize: 5,
    maxRetries: 3,
  };

  const mockEnv: Env = {
    BREVO_API_KEY: 'test-brevo-key',
    SENDER_EMAIL: 'feedback@test.arc',
    RECIPIENT_EMAIL: 'admin@arc.test',
    FIREBASE_PROJECT_ID: 'test-project',
    FIREBASE_CLIENT_EMAIL: 'worker@test-project.iam.gserviceaccount.com',
    FIREBASE_PRIVATE_KEY: 'test-key',
    CRON_SECRET: 'super-secret-token-123',
    BATCH_SIZE: '5',
    MAX_RETRIES: '3',
  };

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('GET /health returns 200 with service health metadata', async () => {
    const request = new Request('http://localhost/health', { method: 'GET' });
    const response = await worker.fetch(request, mockEnv, {} as ExecutionContext);

    expect(response.status).toBe(200);
    const body = (await response.json()) as any;
    expect(body.status).toBe('healthy');
    expect(body.service).toBe('arc-feedback-delivery-worker');
  });

  it('POST /dispatch blocks requests without valid Authorization header', async () => {
    // Missing header
    const req1 = new Request('http://localhost/dispatch', { method: 'POST' });
    const res1 = await worker.fetch(req1, mockEnv, {} as ExecutionContext);
    expect(res1.status).toBe(401);

    // Wrong token
    const req2 = new Request('http://localhost/dispatch', {
      method: 'POST',
      headers: { Authorization: 'Bearer wrong-token' },
    });
    const res2 = await worker.fetch(req2, mockEnv, {} as ExecutionContext);
    expect(res2.status).toBe(401);
  });

  it('POST /dispatch rejects if no CRON_SECRET is configured to protect endpoint', async () => {
    const insecureEnv: Env = { ...mockEnv, CRON_SECRET: undefined };
    const req = new Request('http://localhost/dispatch', {
      method: 'POST',
      headers: { Authorization: 'Bearer any' },
    });
    const res = await worker.fetch(req, insecureEnv, {} as ExecutionContext);
    expect(res.status).toBe(403);
    const body = (await res.json()) as any;
    expect(body.error).toContain('Forbidden');
  });

  it('Returns 404 for unknown endpoints', async () => {
    const req = new Request('http://localhost/unknown-path', { method: 'GET' });
    const res = await worker.fetch(req, mockEnv, {} as ExecutionContext);
    expect(res.status).toBe(404);
  });
});
