/**
 * Project Arc — Feedback Delivery & Acknowledgement Cloudflare Worker
 *
 * Automatically dispatches pending feedback submissions from Cloud Firestore
 * to the administrator's email using Brevo's transactional email API, and hosts
 * the secure Review & Acknowledgement portal with server-side Firebase admin auth.
 */

import { Env, validateConfig, ValidatedConfig } from './config';
import { FirestoreClient } from './firestore/client';
import { BrevoClient } from './brevo/client';
import { SafeLogger } from './utils/logger';
import { verifyAcknowledgementToken } from './utils/hmac';
import { verifyFirebaseIdToken } from './auth/token_verifier';
import { renderAcknowledgementPortal } from './acknowledgement/portal';

export interface DispatchSummary {
  discovered: number;
  processed: number;
  succeeded: number;
  failed: number;
  skipped: number;
  durationMs: number;
}

export async function processFeedbackBatch(config: ValidatedConfig): Promise<DispatchSummary> {
  const startTime = Date.now();
  const firestore = new FirestoreClient(config);
  const brevo = new BrevoClient(config);

  const pendingItems = await firestore.getPendingFeedback(config.batchSize);

  let succeeded = 0;
  let failed = 0;
  let skipped = 0;

  for (const item of pendingItems) {
    // 1. Attempt atomic OCC lease claim to prevent duplicate delivery
    const leaseAcquired = await firestore.claimLease(item);
    if (!leaseAcquired) {
      skipped++;
      continue;
    }

    try {
      // 2. Dispatch email via Brevo transactional API (with secure ack CTA button)
      const result = await brevo.sendFeedbackEmail(item);

      // 3. Mark delivery confirmed in Firestore with retry protection
      let committed = false;
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          await firestore.markEmailed(item, result.messageId);
          committed = true;
          break;
        } catch (commitErr: any) {
          SafeLogger.warn('Transient error committing markEmailed; retrying commit', {
            feedbackId: item.id,
            attempt,
            error: commitErr?.message,
          });
          if (attempt < 3) {
            await new Promise((resolve) => setTimeout(resolve, attempt * 1000));
          }
        }
      }
      if (!committed) {
        throw new Error('Failed to record delivery status in Firestore after 3 attempts.');
      }
      succeeded++;
    } catch (err: any) {
      failed++;
      SafeLogger.error('Failed to dispatch feedback email', err, { feedbackId: item.id });
      // 4. Record error and release lease for retry
      await firestore.markFailed(item, err?.message || 'Unknown dispatch error', config.maxRetries);
    }
  }

  const durationMs = Date.now() - startTime;
  const summary: DispatchSummary = {
    discovered: pendingItems.length,
    processed: succeeded + failed,
    succeeded,
    failed,
    skipped,
    durationMs,
  };

  SafeLogger.info('Batch processing completed', summary as unknown as Record<string, unknown>);
  return summary;
}

export default {
  /**
   * Scheduled Cron Handler (runs every 5 minutes)
   */
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    SafeLogger.info('Cron trigger initiated feedback delivery worker', {
      cron: event.cron,
      scheduledTime: new Date(event.scheduledTime).toISOString(),
    });

    try {
      const config = validateConfig(env);
      ctx.waitUntil(processFeedbackBatch(config));
    } catch (err: any) {
      SafeLogger.error('Worker cron execution aborted on configuration error', err);
    }
  },

  /**
   * HTTP Handler:
   * - GET  /health            : Public health check
   * - POST /dispatch          : Authorized manual dispatch trigger (Bearer CRON_SECRET)
   * - GET  /acknowledge       : Secure Review & Acknowledgement Web Portal
   * - POST /api/acknowledge   : Server-side authenticated acknowledgement endpoint
   */
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // 1. Health check endpoint
    if (request.method === 'GET' && url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          status: 'healthy',
          service: 'arc-feedback-delivery-worker',
          timestamp: new Date().toISOString(),
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // 2. Authorized manual dispatch endpoint
    if (request.method === 'POST' && url.pathname === '/dispatch') {
      let config: ValidatedConfig;
      try {
        config = validateConfig(env);
      } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Security Check: Enforce secret token authorization
      if (!config.cronSecret) {
        return new Response(
          JSON.stringify({
            error: 'Forbidden: Manual dispatch endpoint is disabled (no CRON_SECRET configured).',
          }),
          { status: 403, headers: { 'Content-Type': 'application/json' } }
        );
      }

      const authHeader = request.headers.get('Authorization') || '';
      const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';

      if (token !== config.cronSecret) {
        SafeLogger.warn('Unauthorized attempt on /dispatch endpoint', {
          origin: request.headers.get('cf-connecting-ip') || 'unknown',
        });
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      try {
        const summary = await processFeedbackBatch(config);
        return new Response(JSON.stringify({ success: true, summary }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      } catch (err: any) {
        SafeLogger.error('Manual dispatch processing failed', err);
        return new Response(JSON.stringify({ success: false, error: err.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    // 3. Review & Acknowledge Web Portal (GET /acknowledge)
    if (request.method === 'GET' && url.pathname === '/acknowledge') {
      let config: ValidatedConfig;
      try {
        config = validateConfig(env);
      } catch (err: any) {
        return new Response(`Worker configuration error: ${err.message}`, { status: 500 });
      }

      const feedbackId = url.searchParams.get('id');
      const token = url.searchParams.get('token');

      if (!feedbackId || !token) {
        return new Response(
          `<!DOCTYPE html><html><body style="background:#0D0D0D;color:#FFF;font-family:sans-serif;padding:40px;text-align:center;">
          <h2 style="color:#FF5252;">Invalid Acknowledgement Request</h2>
          <p style="color:#888;">Both feedback ID and acknowledgement token are required.</p>
          </body></html>`,
          { status: 400, headers: { 'Content-Type': 'text/html' } }
        );
      }

      // Verify HMAC cryptographic token to prevent ID guessing
      const isTokenValid = await verifyAcknowledgementToken(feedbackId, token, config.cronSecret || '');
      if (!isTokenValid) {
        SafeLogger.warn('Invalid acknowledgement token provided', { feedbackId });
        return new Response(
          `<!DOCTYPE html><html><body style="background:#0D0D0D;color:#FFF;font-family:sans-serif;padding:40px;text-align:center;">
          <h2 style="color:#FF5252;">Invalid or Expired Token</h2>
          <p style="color:#888;">This acknowledgement link is invalid or has expired.</p>
          </body></html>`,
          { status: 403, headers: { 'Content-Type': 'text/html' } }
        );
      }

      const firestore = new FirestoreClient(config);
      const feedback = await firestore.getFeedbackById(feedbackId);

      if (!feedback) {
        return new Response(
          `<!DOCTYPE html><html><body style="background:#0D0D0D;color:#FFF;font-family:sans-serif;padding:40px;text-align:center;">
          <h2 style="color:#FF5252;">Feedback Not Found</h2>
          <p style="color:#888;">The requested feedback document (${escapeHtml(feedbackId)}) does not exist in Cloud Firestore.</p>
          </body></html>`,
          { status: 404, headers: { 'Content-Type': 'text/html' } }
        );
      }

      const html = renderAcknowledgementPortal({
        feedback,
        token,
        firebaseApiKey: 'AIzaSyCZopGQ1B_PsRDUAlp6xLXpLlI8AeMEEcM',
        firebaseAuthDomain: 'arc-productivity-shreyas.firebaseapp.com',
        firebaseProjectId: config.firebaseProjectId,
      });

      return new Response(html, {
        status: 200,
        headers: {
          'Content-Type': 'text/html',
          'Cache-Control': 'no-store, no-cache, must-revalidate',
        },
      });
    }

    // 4. Secure Endpoint for Fetching Feedback Details (POST /api/feedback/details)
    // Protected by:
    // 1. HMAC token verification
    // 2. Firebase Auth RS256 ID Token signature verification
    // 3. Administrator custom claims check (role == 'admin' || admin == true)
    // Ensures confidential user narratives and contact emails are NEVER exposed to unauthenticated visitors.
    if (request.method === 'POST' && url.pathname === '/api/feedback/details') {
      let config: ValidatedConfig;
      try {
        config = validateConfig(env);
      } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      let body: { feedbackId?: string; token?: string };
      try {
        body = (await request.json()) as any;
      } catch {
        return new Response(JSON.stringify({ error: 'Malformed JSON payload.' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const { feedbackId, token } = body;
      if (!feedbackId || !token) {
        return new Response(JSON.stringify({ error: 'Missing feedbackId or token in request body.' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const isTokenValid = await verifyAcknowledgementToken(feedbackId, token, config.cronSecret || '');
      if (!isTokenValid) {
        SafeLogger.warn('Invalid acknowledgement token on details endpoint', { feedbackId });
        return new Response(JSON.stringify({ error: 'Invalid or forged acknowledgement token.' }), {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const authHeader = request.headers.get('Authorization') || '';
      if (!authHeader.startsWith('Bearer ')) {
        return new Response(
          JSON.stringify({
            error: 'Authentication required. Please sign in with your Firebase administrator account.',
          }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        );
      }

      const idToken = authHeader.slice(7).trim();
      let verifiedUser;
      try {
        verifiedUser = await verifyFirebaseIdToken(idToken, config.firebaseProjectId);
      } catch (err: any) {
        SafeLogger.warn('Firebase ID token verification failed', { error: err.message });
        return new Response(JSON.stringify({ error: err.message || 'Invalid Firebase ID token.' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      if (!verifiedUser.isAdmin) {
        SafeLogger.warn('Non-admin user attempted to access feedback details', {
          uid: verifiedUser.uid,
          email: verifiedUser.email,
          feedbackId,
        });
        return new Response(
          JSON.stringify({
            error: 'Forbidden: You do not have administrator privileges to inspect this feedback.',
          }),
          { status: 403, headers: { 'Content-Type': 'application/json' } }
        );
      }

      try {
        const firestore = new FirestoreClient(config);
        const feedback = await firestore.getFeedbackById(feedbackId);
        if (!feedback) {
          return new Response(JSON.stringify({ error: 'Feedback not found.' }), {
            status: 404,
            headers: { 'Content-Type': 'application/json' },
          });
        }

        return new Response(
          JSON.stringify({
            success: true,
            message: feedback.message,
            userId: feedback.userId,
            contactEmail: feedback.contactEmail,
            rating: feedback.rating,
          }),
          {
            status: 200,
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': 'no-store, no-cache, must-revalidate',
            },
          }
        );
      } catch (err: any) {
        SafeLogger.error('Failed to retrieve feedback details from Firestore', err, { feedbackId });
        return new Response(JSON.stringify({ error: err.message || 'Firestore query failed.' }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    // 5. Server-Side Authenticated Acknowledgement Endpoint (POST /api/acknowledge)
    if (request.method === 'POST' && url.pathname === '/api/acknowledge') {
      let config: ValidatedConfig;
      try {
        config = validateConfig(env);
      } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      let body: { feedbackId?: string; token?: string };
      try {
        body = (await request.json()) as any;
      } catch {
        return new Response(JSON.stringify({ error: 'Malformed JSON payload.' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const { feedbackId, token } = body;
      if (!feedbackId || !token) {
        return new Response(JSON.stringify({ error: 'Missing feedbackId or token in request body.' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Check 1: Cryptographic HMAC signature check
      const isTokenValid = await verifyAcknowledgementToken(feedbackId, token, config.cronSecret || '');
      if (!isTokenValid) {
        SafeLogger.warn('Invalid acknowledgement token on API endpoint', { feedbackId });
        return new Response(JSON.stringify({ error: 'Invalid or forged acknowledgement token.' }), {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Check 2: Require Firebase ID Token in Authorization header
      const authHeader = request.headers.get('Authorization') || '';
      if (!authHeader.startsWith('Bearer ')) {
        return new Response(
          JSON.stringify({
            error: 'Authentication required. Please sign in with your Firebase administrator account.',
          }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        );
      }

      const idToken = authHeader.slice(7).trim();

      // Check 3: Cryptographic verification of Firebase ID token & Administrator authorization
      let verifiedUser;
      try {
        verifiedUser = await verifyFirebaseIdToken(idToken, config.firebaseProjectId);
      } catch (err: any) {
        SafeLogger.warn('Firebase ID token verification failed', { error: err.message });
        return new Response(JSON.stringify({ error: err.message || 'Invalid Firebase ID token.' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      if (!verifiedUser.isAdmin) {
        SafeLogger.warn('Non-admin user attempted to acknowledge feedback', {
          uid: verifiedUser.uid,
          email: verifiedUser.email,
          feedbackId,
        });
        return new Response(
          JSON.stringify({
            error: 'Forbidden: You do not have administrator privileges to acknowledge feedback.',
          }),
          { status: 403, headers: { 'Content-Type': 'application/json' } }
        );
      }

      // Check 4: Transition status in Firestore
      try {
        const firestore = new FirestoreClient(config);
        const result = await firestore.acknowledgeFeedback(feedbackId);

        SafeLogger.info('Feedback acknowledgement completed by admin', {
          feedbackId,
          adminUid: verifiedUser.uid,
          alreadyAcknowledged: result.alreadyAcknowledged,
        });

        return new Response(
          JSON.stringify({
            success: true,
            message: result.alreadyAcknowledged
              ? 'Feedback was already acknowledged.'
              : 'Feedback successfully acknowledged.',
            status: 'acknowledged',
            acknowledgedAt: result.acknowledgedAt,
            alreadyAcknowledged: result.alreadyAcknowledged,
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      } catch (err: any) {
        SafeLogger.error('Feedback acknowledgement failed in Firestore', err, { feedbackId });
        return new Response(JSON.stringify({ error: err.message || 'Firestore update failed.' }), {
          status: err.message?.includes('not found') ? 404 : 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    return new Response(JSON.stringify({ error: 'Not Found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  },
};

function escapeHtml(str: string): string {
  if (!str) return '';
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
