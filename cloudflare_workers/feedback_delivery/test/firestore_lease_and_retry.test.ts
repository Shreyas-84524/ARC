import { describe, it, expect, vi, beforeEach } from 'vitest';
import { FirestoreClient } from '../src/firestore/client';
import { ValidatedConfig } from '../src/config';
import { GoogleAuthService } from '../src/firestore/auth';
import { FeedbackItem } from '../src/brevo/types';

describe('Firestore Client & OCC Leasing Tests', () => {
  const mockConfig: ValidatedConfig = {
    brevoApiKey: 'test-key',
    senderEmail: 'test@arc.app',
    senderName: 'Arc Test',
    recipientEmail: 'admin@arc.app',
    firebaseProjectId: 'test-project',
    firebaseClientEmail: 'worker@test-project.iam.gserviceaccount.com',
    firebasePrivateKey: 'test-key',
    batchSize: 10,
    maxRetries: 3,
  };

  let mockAuthService: GoogleAuthService;
  let firestore: FirestoreClient;

  beforeEach(() => {
    vi.restoreAllMocks();
    mockAuthService = {
      getAccessToken: vi.fn().mockResolvedValue('mock-oauth-token'),
    } as unknown as GoogleAuthService;
    firestore = new FirestoreClient(mockConfig, mockAuthService);
  });

  it('filters out pending documents that currently hold an active lease', async () => {
    const futureTime = new Date(Date.now() + 60000).toISOString();
    const pastTime = new Date(Date.now() - 60000).toISOString();

    const mockResponse = [
      {
        document: {
          name: 'projects/test/databases/(default)/documents/feedback/doc-active-lease',
          fields: {
            feedbackId: { stringValue: 'doc-active-lease' },
            status: { stringValue: 'submitted' },
            dispatchLeaseUntil: { timestampValue: futureTime },
          },
          updateTime: '2026-10-25T14:00:00Z',
        },
      },
      {
        document: {
          name: 'projects/test/databases/(default)/documents/feedback/doc-available',
          fields: {
            feedbackId: { stringValue: 'doc-available' },
            status: { stringValue: 'submitted' },
            dispatchLeaseUntil: { timestampValue: pastTime },
          },
          updateTime: '2026-10-25T14:00:00Z',
        },
      },
    ];

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue(mockResponse),
    } as any);

    const pending = await firestore.getPendingFeedback(10);
    expect(pending.length).toBe(1);
    expect(pending[0].id).toBe('doc-available');
  });

  it('acquires exclusive lease when commit succeeds', async () => {
    const item: FeedbackItem = {
      id: 'fb-test-1',
      documentPath: 'projects/test/databases/(default)/documents/feedback/fb-test-1',
      updateTime: '2026-10-25T14:00:00Z',
      userId: 'u1',
      category: 'bug_report',
      module: 'tasks',
      message: 'Bug',
      appVersion: '1.0.0',
      createdAt: '2026-10-25T14:00:00Z',
      status: 'submitted',
      dispatchAttemptCount: 0,
      emailRetryCount: 0,
    };

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: vi.fn().mockResolvedValue({
        writeResults: [{ updateTime: '2026-10-25T14:05:00Z' }],
      }),
    } as any);

    const claimed = await firestore.claimLease(item);
    expect(claimed).toBe(true);
    expect(item.updateTime).toBe('2026-10-25T14:05:00Z');
  });

  it('fails lease claim gracefully on 409 conflict (preventing duplicate delivery)', async () => {
    const item: FeedbackItem = {
      id: 'fb-test-concurrent',
      documentPath: 'projects/test/databases/(default)/documents/feedback/fb-test-concurrent',
      updateTime: '2026-10-25T14:00:00Z',
      userId: 'u1',
      category: 'bug_report',
      module: 'tasks',
      message: 'Bug',
      appVersion: '1.0.0',
      createdAt: '2026-10-25T14:00:00Z',
      status: 'submitted',
      dispatchAttemptCount: 0,
      emailRetryCount: 0,
    };

    // Simulate OCC failure: Firestore returns 409 Conflict
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 409,
    } as any);

    const claimed = await firestore.claimLease(item);
    expect(claimed).toBe(false);
  });

  it('updates document status to emailed with messageId and cleans lease', async () => {
    const item: FeedbackItem = {
      id: 'fb-test-delivered',
      documentPath: 'projects/test/databases/(default)/documents/feedback/fb-test-delivered',
      updateTime: '2026-10-25T14:00:00Z',
      userId: 'u1',
      category: 'bug_report',
      module: 'tasks',
      message: 'Bug',
      appVersion: '1.0.0',
      createdAt: '2026-10-25T14:00:00Z',
      status: 'submitted',
      dispatchAttemptCount: 1,
      emailRetryCount: 0,
    };

    let capturedPayload: any;
    global.fetch = vi.fn().mockImplementation((_url, init) => {
      capturedPayload = JSON.parse(init.body);
      return Promise.resolve({
        ok: true,
        status: 200,
        json: vi.fn().mockResolvedValue({}),
      });
    });

    await firestore.markEmailed(item, '<msg-brevo-999@brevo.com>');

    expect(capturedPayload.writes[0].update.fields.status.stringValue).toBe('emailed');
    expect(capturedPayload.writes[0].update.fields.emailDeliveryMessageId.stringValue).toBe(
      '<msg-brevo-999@brevo.com>'
    );
    expect(capturedPayload.writes[0].update.fields.dispatchLeaseUntil.nullValue).toBeNull();
  });

  it('records failure metadata and applies backoff when retries exceed maxRetries', async () => {
    const item: FeedbackItem = {
      id: 'fb-test-failing',
      documentPath: 'projects/test/databases/(default)/documents/feedback/fb-test-failing',
      updateTime: '2026-10-25T14:00:00Z',
      userId: 'u1',
      category: 'bug_report',
      module: 'tasks',
      message: 'Bug',
      appVersion: '1.0.0',
      createdAt: '2026-10-25T14:00:00Z',
      status: 'submitted',
      dispatchAttemptCount: 3,
      emailRetryCount: 2, // 2 + 1 = 3 >= maxRetries (3)
    };

    let capturedPayload: any;
    global.fetch = vi.fn().mockImplementation((_url, init) => {
      capturedPayload = JSON.parse(init.body);
      return Promise.resolve({
        ok: true,
        status: 200,
        json: vi.fn().mockResolvedValue({}),
      });
    });

    await firestore.markFailed(item, 'Brevo 429 Rate Limit Exceeded', 3);

    expect(capturedPayload.writes[0].update.fields.status.stringValue).toBe('submitted');
    expect(capturedPayload.writes[0].update.fields.emailRetryCount.integerValue).toBe('3');
    expect(capturedPayload.writes[0].update.fields.emailLastError.stringValue).toBe(
      'Brevo 429 Rate Limit Exceeded'
    );
    // Backoff lease should be set
    expect(capturedPayload.writes[0].update.fields.dispatchLeaseUntil.timestampValue).toBeDefined();
  });
});
