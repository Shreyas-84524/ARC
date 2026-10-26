/**
 * Transactional Email Template Generator for Project Arc Feedback
 *
 * Implements clean, dark-mode branded HTML with full XSS escaping,
 * secure Review & Acknowledge CTA button, and fallback plain text formatting.
 */

import { FeedbackItem } from './types';
import {
  escapeHtml,
  formatCategoryTitle,
  formatModuleLabel,
  formatRatingStars,
  getCategoryBadgeColor,
} from '../utils/sanitizer';

export interface RenderedEmail {
  subject: string;
  htmlContent: string;
  textContent: string;
  ackUrl?: string;
}

export interface RenderEmailOptions {
  workerBaseUrl?: string;
  ackToken?: string;
}

export function renderFeedbackEmail(
  feedback: FeedbackItem,
  options?: RenderEmailOptions
): RenderedEmail {
  const categoryTitle = formatCategoryTitle(feedback.category);
  const moduleLabel = formatModuleLabel(feedback.module);
  const badgeColor = getCategoryBadgeColor(feedback.category);

  // Subject requirement: [ARC Feedback] {{category}} — {{module}}
  const subject = `[ARC Feedback] ${categoryTitle} — ${moduleLabel}`;

  // Formatted date string
  let formattedDate = feedback.createdAt;
  try {
    const d = new Date(feedback.createdAt);
    formattedDate = d.toUTCString();
  } catch {
    // Keep raw string if parsing fails
  }

  const escapedMessage = escapeHtml(feedback.message).replace(/\n/g, '<br/>');
  const escapedFeedbackId = escapeHtml(feedback.id);
  const escapedUserId = escapeHtml(feedback.userId);
  const escapedAppVersion = escapeHtml(feedback.appVersion);
  const escapedContactEmail = feedback.contactEmail
    ? escapeHtml(feedback.contactEmail)
    : '<span style="color: #888888; font-style: italic;">Not provided</span>';

  const ratingHtml =
    feedback.rating != null
      ? `<span style="color: #FFC857; font-weight: bold;">${formatRatingStars(feedback.rating)}</span>`
      : '<span style="color: #888888; font-style: italic;">None</span>';

  // Construct secure Review & Acknowledge URL
  let ackUrl: string | undefined;
  if (options?.workerBaseUrl && options?.ackToken) {
    const base = options.workerBaseUrl.replace(/\/+$/, '');
    ackUrl = `${base}/acknowledge?id=${encodeURIComponent(feedback.id)}&token=${encodeURIComponent(options.ackToken)}`;
  }

  const ctaButtonHtml = ackUrl
    ? `
              <!-- Review & Acknowledge CTA Button -->
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-top: 24px;">
                <tr>
                  <td align="center">
                    <a href="${escapeHtml(ackUrl)}" target="_blank" rel="noopener noreferrer" style="display: inline-block; background-color: #D7FF2F; color: #141414; font-size: 14px; font-weight: 700; text-decoration: none; padding: 14px 30px; border-radius: 8px; letter-spacing: -0.2px; box-shadow: 0 4px 14px rgba(215, 255, 47, 0.35);">
                      Review &amp; Acknowledge Feedback &rarr;
                    </a>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top: 10px; font-size: 11px; color: #888888;">
                    Secure administrator authentication required before status transition
                  </td>
                </tr>
              </table>`
    : '';

  // 1. Responsive Branded HTML Body
  const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0E0E0E; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #0E0E0E; padding: 32px 16px;">
    <tr>
      <td align="center">
        <!-- Main Container -->
        <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #1A1A1A; border: 1px solid #2E2E2E; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 30px rgba(0,0,0,0.6);">
          
          <!-- Top Accent Line -->
          <tr>
            <td style="height: 4px; background: linear-gradient(90deg, #D7FF2F 0%, #448AFF 100%); font-size: 0; line-height: 0;">&nbsp;</td>
          </tr>

          <!-- Header -->
          <tr>
            <td style="padding: 24px 28px 16px 28px; border-bottom: 1px solid #282828;">
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <span style="font-size: 20px; font-weight: 800; letter-spacing: -0.5px; color: #FFFFFF;">PROJECT <span style="color: #D7FF2F;">ARC</span></span>
                    <span style="font-size: 11px; text-transform: uppercase; letter-spacing: 1.5px; color: #888888; margin-left: 10px; font-weight: 600;">Feedback System</span>
                  </td>
                  <td align="right">
                    <span style="display: inline-block; padding: 4px 12px; border-radius: 999px; background-color: ${badgeColor.bg}; color: ${badgeColor.text}; border: 1px solid ${badgeColor.border}; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">
                      ${escapeHtml(categoryTitle)}
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Content Body -->
          <tr>
            <td style="padding: 24px 28px;">
              
              <!-- Message Box -->
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom: 24px;">
                <tr>
                  <td style="font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: #9E9E9E; font-weight: 700; padding-bottom: 8px;">
                    User Narrative
                  </td>
                </tr>
                <tr>
                  <td style="background-color: #242424; border: 1px solid #333333; border-left: 4px solid #D7FF2F; border-radius: 8px; padding: 18px 20px; font-size: 15px; line-height: 1.6; color: #EDEDED; word-break: break-word;">
                    ${escapedMessage}
                  </td>
                </tr>
              </table>

              <!-- Metadata Grid -->
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #141414; border: 1px solid #242424; border-radius: 10px; padding: 16px 20px;">
                <tr>
                  <td width="35%" style="padding: 8px 0; font-size: 12px; color: #888888; font-weight: 600;">Module</td>
                  <td width="65%" style="padding: 8px 0; font-size: 13px; color: #FFFFFF; font-weight: 600;">${escapeHtml(moduleLabel)}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12px; color: #888888; font-weight: 600; border-top: 1px solid #202020;">Rating</td>
                  <td style="padding: 8px 0; font-size: 13px; border-top: 1px solid #202020;">${ratingHtml}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12px; color: #888888; font-weight: 600; border-top: 1px solid #202020;">Contact Email</td>
                  <td style="padding: 8px 0; font-size: 13px; color: #448AFF; border-top: 1px solid #202020;">${escapedContactEmail}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12px; color: #888888; font-weight: 600; border-top: 1px solid #202020;">App Version</td>
                  <td style="padding: 8px 0; font-size: 13px; color: #CCCCCC; font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace; border-top: 1px solid #202020;">${escapedAppVersion}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12px; color: #888888; font-weight: 600; border-top: 1px solid #202020;">Submitted At</td>
                  <td style="padding: 8px 0; font-size: 13px; color: #CCCCCC; border-top: 1px solid #202020;">${escapeHtml(formattedDate)}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12px; color: #888888; font-weight: 600; border-top: 1px solid #202020;">Submitted By (UID)</td>
                  <td style="padding: 8px 0; font-size: 12px; color: #9E9E9E; font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace; border-top: 1px solid #202020;">${escapedUserId}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12px; color: #888888; font-weight: 600; border-top: 1px solid #202020;">Feedback ID</td>
                  <td style="padding: 8px 0; font-size: 12px; color: #9E9E9E; font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace; border-top: 1px solid #202020;">${escapedFeedbackId}</td>
                </tr>
              </table>

              ${ctaButtonHtml}

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 20px 28px; background-color: #121212; border-top: 1px solid #242424; text-align: center; font-size: 11px; color: #666666; line-height: 1.5;">
              Delivered automatically via Cloudflare Workers Free & Brevo Transactional API.<br/>
              Project Arc &bull; Spark Plan Compatible Infrastructure &bull; Phase 4
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  // 2. Clean Plain Text Body
  const textContent = `=====================================================
PROJECT ARC — IN-APP FEEDBACK SUBMISSION
=====================================================

Subject:       ${subject}
Category:      ${categoryTitle}
Module:        ${moduleLabel}
Feedback ID:   ${feedback.id}
Submitted By:  ${feedback.userId}
Contact Email: ${feedback.contactEmail || 'Not provided'}
Rating:        ${formatRatingStars(feedback.rating)}
App Version:   ${feedback.appVersion}
Submitted At:  ${formattedDate}

-----------------------------------------------------
FEEDBACK NARRATIVE:
-----------------------------------------------------
${feedback.message}
${
  ackUrl
    ? `
-----------------------------------------------------
REVIEW & ACKNOWLEDGE FEEDBACK:
${ackUrl}
(Requires administrator authentication)`
    : ''
}

-----------------------------------------------------
Automated delivery via Cloudflare Workers & Brevo
Phase 4 Feedback Infrastructure
=====================================================`;

  return { subject, htmlContent, textContent, ackUrl };
}
