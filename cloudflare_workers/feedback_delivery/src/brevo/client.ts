/**
 * Brevo Transactional Email Client
 *
 * Dispatches transactional email through Brevo's v3 SMTP API with
 * cryptographically signed Review & Acknowledge feedback links.
 */

import { BrevoEmailRequest, FeedbackItem } from './types';
import { renderFeedbackEmail } from './template';
import { ValidatedConfig } from '../config';
import { SafeLogger } from '../utils/logger';
import { generateAcknowledgementToken } from '../utils/hmac';

export class BrevoClient {
  private readonly apiKey: string;
  private readonly senderEmail: string;
  private readonly senderName: string;
  private readonly recipientEmail: string;
  private readonly workerBaseUrl: string;
  private readonly cronSecret?: string;

  constructor(config: ValidatedConfig) {
    this.apiKey = config.brevoApiKey;
    this.senderEmail = config.senderEmail;
    this.senderName = config.senderName;
    this.recipientEmail = config.recipientEmail;
    this.workerBaseUrl = config.workerBaseUrl;
    this.cronSecret = config.cronSecret;
  }

  async sendFeedbackEmail(feedback: FeedbackItem): Promise<{ messageId: string }> {
    let ackToken: string | undefined;
    if (this.cronSecret) {
      ackToken = await generateAcknowledgementToken(feedback.id, this.cronSecret);
    }

    const { subject, htmlContent, textContent, ackUrl } = renderFeedbackEmail(feedback, {
      workerBaseUrl: this.workerBaseUrl,
      ackToken,
    });

    const payload: BrevoEmailRequest = {
      sender: {
        name: this.senderName,
        email: this.senderEmail,
      },
      to: [
        {
          name: 'Arc Administrator',
          email: this.recipientEmail, // Strictly restricted to configured recipient
        },
      ],
      subject,
      htmlContent,
      textContent,
      tags: ['arc-feedback', feedback.category],
    };

    SafeLogger.info('Dispatching feedback email via Brevo', {
      feedbackId: feedback.id,
      category: feedback.category,
      recipientDomain: this.recipientEmail.split('@')[1] || '[UNKNOWN]',
      hasAckUrl: Boolean(ackUrl),
    });

    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        accept: 'application/json',
        'api-key': this.apiKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(15000), // 15-second safety timeout
    });

    if (!response.ok) {
      const errorText = await response.text();
      SafeLogger.error('Brevo API email dispatch rejected', null, {
        status: response.status,
        feedbackId: feedback.id,
      });
      throw new Error(`Brevo API Error (${response.status}): ${errorText}`);
    }

    const data = (await response.json()) as { messageId: string };
    SafeLogger.info('Brevo email accepted for delivery', {
      feedbackId: feedback.id,
      messageId: data.messageId,
    });

    return { messageId: data.messageId };
  }
}
