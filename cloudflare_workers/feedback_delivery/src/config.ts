/**
 * Cloudflare Worker Environment Configuration
 */

export interface Env {
  // Brevo Credentials & Destination
  BREVO_API_KEY: string;
  SENDER_EMAIL: string;
  SENDER_NAME?: string;
  RECIPIENT_EMAIL: string;

  // Firebase Service Account Credentials
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;

  // Optional Security & Tuning
  CRON_SECRET?: string;
  WORKER_BASE_URL?: string;
  BATCH_SIZE?: string;
  MAX_RETRIES?: string;
}

export interface ValidatedConfig {
  brevoApiKey: string;
  senderEmail: string;
  senderName: string;
  recipientEmail: string;
  firebaseProjectId: string;
  firebaseClientEmail: string;
  firebasePrivateKey: string;
  cronSecret?: string;
  workerBaseUrl: string;
  batchSize: number;
  maxRetries: number;
}

export function validateConfig(env: Env): ValidatedConfig {
  const missing: string[] = [];

  if (!env.BREVO_API_KEY) missing.push('BREVO_API_KEY');
  if (!env.SENDER_EMAIL) missing.push('SENDER_EMAIL');
  if (!env.RECIPIENT_EMAIL) missing.push('RECIPIENT_EMAIL');
  if (!env.FIREBASE_PROJECT_ID) missing.push('FIREBASE_PROJECT_ID');
  if (!env.FIREBASE_CLIENT_EMAIL) missing.push('FIREBASE_CLIENT_EMAIL');
  if (!env.FIREBASE_PRIVATE_KEY) missing.push('FIREBASE_PRIVATE_KEY');

  if (missing.length > 0) {
    throw new Error(`Missing required Cloudflare Worker configuration secrets: ${missing.join(', ')}`);
  }

  // Sanitize private key (normalize escaped newlines if passed in single-line format)
  let privateKey = env.FIREBASE_PRIVATE_KEY.trim();
  if (privateKey.includes('\\n')) {
    privateKey = privateKey.replace(/\\n/g, '\n');
  }

  return {
    brevoApiKey: env.BREVO_API_KEY.trim(),
    senderEmail: env.SENDER_EMAIL.trim(),
    senderName: (env.SENDER_NAME || 'Project Arc Feedback').trim(),
    recipientEmail: env.RECIPIENT_EMAIL.trim(),
    firebaseProjectId: env.FIREBASE_PROJECT_ID.trim(),
    firebaseClientEmail: env.FIREBASE_CLIENT_EMAIL.trim(),
    firebasePrivateKey: privateKey,
    cronSecret: env.CRON_SECRET?.trim(),
    workerBaseUrl: (env.WORKER_BASE_URL || 'https://arc-feedback-delivery-worker.arc-feedback-shreyas.workers.dev').trim().replace(/\/+$/, ''),
    batchSize: env.BATCH_SIZE ? parseInt(env.BATCH_SIZE, 10) || 10 : 10,
    maxRetries: env.MAX_RETRIES ? parseInt(env.MAX_RETRIES, 10) || 5 : 5,
  };
}
