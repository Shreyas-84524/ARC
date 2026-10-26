/**
 * Brevo (Sendinblue) API Types & Normalized Feedback Model
 */

export interface FeedbackItem {
  id: string;
  documentPath: string;
  updateTime: string;
  userId: string;
  category: string;
  module: string;
  message: string;
  rating?: number | null;
  contactEmail?: string | null;
  appVersion: string;
  createdAt: string; // ISO 8601 string
  status: string;
  acknowledgedAt?: string | null;
  reviewedAt?: string | null;
  dispatchAttemptCount: number;
  emailRetryCount: number;
}

export interface BrevoSender {
  name: string;
  email: string;
}

export interface BrevoRecipient {
  name?: string;
  email: string;
}

export interface BrevoEmailRequest {
  sender: BrevoSender;
  to: BrevoRecipient[];
  subject: string;
  htmlContent: string;
  textContent: string;
  tags?: string[];
}

export interface BrevoEmailResponse {
  messageId: string;
}

export interface BrevoErrorResponse {
  code: string;
  message: string;
}
