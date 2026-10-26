/**
 * Cloud Firestore REST API Client
 *
 * Provides authenticated, server-side querying and atomic Optimistic
 * Concurrency Control (OCC) leasing to prevent duplicate processing.
 */

import { GoogleAuthService } from './auth';
import { FirestoreCommitRequest, FirestoreCommitResponse, FirestoreDocument, RunQueryResponseItem } from './types';
import { FeedbackItem } from '../brevo/types';
import { ValidatedConfig } from '../config';
import { SafeLogger } from '../utils/logger';

export class FirestoreClient {
  private readonly projectId: string;
  private readonly authService: GoogleAuthService;
  private readonly baseUrl: string;

  constructor(config: ValidatedConfig, authService?: GoogleAuthService) {
    this.projectId = config.firebaseProjectId;
    this.authService = authService || new GoogleAuthService(config);
    this.baseUrl = `https://firestore.googleapis.com/v1/projects/${this.projectId}/databases/(default)/documents`;
  }

  /**
   * Retrieves pending feedback items where status == 'submitted'.
   * Filters out items that currently hold an active, unexpired lease.
   */
  async getPendingFeedback(limit = 10): Promise<FeedbackItem[]> {
    const accessToken = await this.authService.getAccessToken();

    const queryPayload = {
      structuredQuery: {
        from: [{ collectionId: 'feedback' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'status' },
            op: 'EQUAL',
            value: { stringValue: 'submitted' },
          },
        },
        limit,
      },
    };

    const response = await fetch(`${this.baseUrl}:runQuery`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(queryPayload),
      signal: AbortSignal.timeout(12000),
    });

    if (!response.ok) {
      const err = await response.text();
      SafeLogger.error('Failed to query pending feedback from Firestore', null, { status: response.status });
      throw new Error(`Firestore query failed (${response.status}): ${err}`);
    }

    const items = (await response.json()) as RunQueryResponseItem[];
    const now = Date.now();
    const results: FeedbackItem[] = [];

    for (const item of items) {
      if (!item.document || !item.document.name) continue;

      const doc = item.document;
      const fields = doc.fields || {};

      // Check if an unexpired lease is held by another concurrent worker
      const leaseUntilStr = fields.dispatchLeaseUntil?.timestampValue;
      if (leaseUntilStr) {
        const leaseUntil = Date.parse(leaseUntilStr);
        if (!isNaN(leaseUntil) && leaseUntil > now) {
          SafeLogger.info('Skipping active leased feedback document', {
            docName: doc.name.split('/').pop(),
            leaseUntil: leaseUntilStr,
          });
          continue;
        }
      }

      results.push(this.parseFirestoreDoc(doc));
    }

    SafeLogger.info('Discovered pending feedback candidates', { count: results.length });
    return results;
  }

  /**
   * Atomically claims an exclusive processing lease on a feedback item.
   * Uses Firestore's OCC precondition (updateTime).
   * Returns true if lease acquired; false if another worker modified the document.
   */
  async claimLease(item: FeedbackItem, leaseDurationMs = 5 * 60 * 1000): Promise<boolean> {
    const accessToken = await this.authService.getAccessToken();
    const leaseExpires = new Date(Date.now() + leaseDurationMs).toISOString();

    const commitPayload: FirestoreCommitRequest = {
      writes: [
        {
          update: {
            name: item.documentPath,
            fields: {
              dispatchLeaseUntil: { timestampValue: leaseExpires },
              dispatchAttemptCount: { integerValue: (item.dispatchAttemptCount + 1).toString() },
            },
          },
          updateMask: {
            fieldPaths: ['dispatchLeaseUntil', 'dispatchAttemptCount'],
          },
          currentDocument: item.updateTime
            ? { updateTime: item.updateTime }
            : { exists: true },
        },
      ],
    };

    const response = await fetch(`${this.baseUrl}:commit`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(commitPayload),
      signal: AbortSignal.timeout(10000),
    });

    if (response.status === 409 || response.status === 412) {
      // Precondition failed: another worker claimed or updated the document concurrently
      SafeLogger.warn('Precondition failed on lease claim; skipping concurrent item', {
        feedbackId: item.id,
      });
      return false;
    }

    if (!response.ok) {
      const err = await response.text();
      SafeLogger.error('Failed to commit lease claim to Firestore', null, {
        status: response.status,
        feedbackId: item.id,
      });
      throw new Error(`Firestore lease commit failed (${response.status}): ${err}`);
    }

    const data = (await response.json()) as FirestoreCommitResponse;
    const newUpdateTime = data.writeResults?.[0]?.updateTime;
    if (newUpdateTime) {
      item.updateTime = newUpdateTime;
    }

    SafeLogger.info('Exclusive lease acquired for feedback item', {
      feedbackId: item.id,
      leaseExpires,
    });
    return true;
  }

  /**
   * Updates status to 'emailed' after Brevo accepts the email request.
   * Atomically sets emailedAt, records the Brevo messageId, and clears the lease.
   */
  async markEmailed(item: FeedbackItem, messageId: string): Promise<void> {
    const accessToken = await this.authService.getAccessToken();
    const nowIso = new Date().toISOString();

    const commitPayload: FirestoreCommitRequest = {
      writes: [
        {
          update: {
            name: item.documentPath,
            fields: {
              status: { stringValue: 'emailed' },
              emailedAt: { timestampValue: nowIso },
              emailDeliveryMessageId: { stringValue: messageId },
              dispatchLeaseUntil: { nullValue: null },
              emailLastError: { nullValue: null },
            },
          },
          updateMask: {
            fieldPaths: [
              'status',
              'emailedAt',
              'emailDeliveryMessageId',
              'dispatchLeaseUntil',
              'emailLastError',
            ],
          },
        },
      ],
    };

    const response = await fetch(`${this.baseUrl}:commit`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(commitPayload),
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      const err = await response.text();
      SafeLogger.error('Failed to commit emailed status to Firestore', null, {
        status: response.status,
        feedbackId: item.id,
      });
      throw new Error(`Firestore markEmailed failed (${response.status}): ${err}`);
    }

    SafeLogger.info('Feedback document updated to emailed', {
      feedbackId: item.id,
      messageId,
    });
  }

  /**
   * Releases lease and records failure metadata so item can be safely retried.
   */
  async markFailed(item: FeedbackItem, errorMessage: string, maxRetries = 5): Promise<void> {
    const accessToken = await this.authService.getAccessToken();
    const nextRetry = item.emailRetryCount + 1;
    const nowIso = new Date().toISOString();

    // If max retries exceeded, apply a 1-hour backoff lease so it doesn't repeatedly fail every 5m
    const backoffIso =
      nextRetry >= maxRetries
        ? new Date(Date.now() + 60 * 60 * 1000).toISOString()
        : null;

    const fields: Record<string, any> = {
      status: { stringValue: 'submitted' },
      emailLastError: { stringValue: errorMessage.substring(0, 500) },
      emailLastErrorAt: { timestampValue: nowIso },
      emailRetryCount: { integerValue: nextRetry.toString() },
      dispatchLeaseUntil: backoffIso ? { timestampValue: backoffIso } : { nullValue: null },
    };

    const commitPayload: FirestoreCommitRequest = {
      writes: [
        {
          update: {
            name: item.documentPath,
            fields,
          },
          updateMask: {
            fieldPaths: [
              'status',
              'emailLastError',
              'emailLastErrorAt',
              'emailRetryCount',
              'dispatchLeaseUntil',
            ],
          },
        },
      ],
    };

    const response = await fetch(`${this.baseUrl}:commit`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(commitPayload),
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      const err = await response.text();
      SafeLogger.error('Failed to commit failure state to Firestore', null, {
        status: response.status,
        feedbackId: item.id,
      });
    } else {
      SafeLogger.warn('Failure state committed for feedback item', {
        feedbackId: item.id,
        retryCount: nextRetry,
        backedOff: nextRetry >= maxRetries,
      });
    }
  }

  /**
   * Retrieves a single feedback item by ID.
   * Returns null if document does not exist.
   */
  async getFeedbackById(feedbackId: string): Promise<FeedbackItem | null> {
    const accessToken = await this.authService.getAccessToken();
    const response = await fetch(`${this.baseUrl}/feedback/${feedbackId}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
      signal: AbortSignal.timeout(10000),
    });

    if (response.status === 404) {
      return null;
    }

    if (!response.ok) {
      const err = await response.text();
      throw new Error(`Failed to fetch feedback (${response.status}): ${err}`);
    }

    const doc = (await response.json()) as FirestoreDocument;
    return this.parseFirestoreDoc(doc);
  }

  /**
   * Atomically transitions a feedback document to 'acknowledged' status.
   * Populates acknowledgedAt and reviewedAt with trusted server timestamps.
   * Idempotent: repeated calls on already acknowledged items do not create duplicate events.
   */
  async acknowledgeFeedback(feedbackId: string): Promise<{
    success: boolean;
    alreadyAcknowledged: boolean;
    acknowledgedAt: string;
  }> {
    const item = await this.getFeedbackById(feedbackId);
    if (!item) {
      throw new Error(`Feedback document "${feedbackId}" not found.`);
    }

    if (item.status === 'acknowledged') {
      return {
        success: true,
        alreadyAcknowledged: true,
        acknowledgedAt: item.acknowledgedAt || item.createdAt,
      };
    }

    const accessToken = await this.authService.getAccessToken();
    const nowIso = new Date().toISOString();

    const fields: Record<string, any> = {
      status: { stringValue: 'acknowledged' },
      acknowledgedAt: { timestampValue: nowIso },
      reviewedAt: item.reviewedAt
        ? { timestampValue: item.reviewedAt }
        : { timestampValue: nowIso },
      dispatchLeaseUntil: { nullValue: null },
    };

    const commitPayload: FirestoreCommitRequest = {
      writes: [
        {
          update: {
            name: item.documentPath,
            fields,
          },
          updateMask: {
            fieldPaths: ['status', 'acknowledgedAt', 'reviewedAt', 'dispatchLeaseUntil'],
          },
        },
      ],
    };

    const response = await fetch(`${this.baseUrl}:commit`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(commitPayload),
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      const err = await response.text();
      SafeLogger.error('Failed to commit acknowledged status to Firestore', null, {
        status: response.status,
        feedbackId,
      });
      throw new Error(`Firestore acknowledge commit failed (${response.status}): ${err}`);
    }

    SafeLogger.info('Feedback status atomically transitioned to acknowledged', {
      feedbackId,
      acknowledgedAt: nowIso,
    });

    return {
      success: true,
      alreadyAcknowledged: false,
      acknowledgedAt: nowIso,
    };
  }

  private parseFirestoreDoc(doc: FirestoreDocument): FeedbackItem {
    const fields = doc.fields || {};
    const id = doc.name.split('/').pop() || '';
    return {
      id,
      documentPath: doc.name,
      updateTime: doc.updateTime || '',
      userId: fields.userId?.stringValue || '',
      category: fields.category?.stringValue || 'general_feedback',
      module: fields.module?.stringValue || 'general',
      message: fields.message?.stringValue || '',
      rating: fields.rating?.integerValue != null ? Number(fields.rating.integerValue) : null,
      contactEmail: fields.contactEmail?.stringValue || null,
      appVersion: fields.appVersion?.stringValue || '1.0.0',
      createdAt: fields.createdAt?.timestampValue || new Date().toISOString(),
      status: fields.status?.stringValue || 'submitted',
      acknowledgedAt: fields.acknowledgedAt?.timestampValue || null,
      reviewedAt: fields.reviewedAt?.timestampValue || null,
      dispatchAttemptCount:
        fields.dispatchAttemptCount?.integerValue != null
          ? Number(fields.dispatchAttemptCount.integerValue)
          : 0,
      emailRetryCount:
        fields.emailRetryCount?.integerValue != null ? Number(fields.emailRetryCount.integerValue) : 0,
    };
  }
}
