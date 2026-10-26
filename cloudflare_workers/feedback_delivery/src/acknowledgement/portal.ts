/**
 * Project Arc — Feedback Review & Acknowledgement Portal
 *
 * Renders a secure, self-contained dark-mode administrative web interface
 * hosted directly on Cloudflare Workers edge.
 */

import { FeedbackItem } from '../brevo/types';
import {
  escapeHtml,
  formatCategoryTitle,
  formatModuleLabel,
  formatRatingStars,
  getCategoryBadgeColor,
} from '../utils/sanitizer';

export interface PortalOptions {
  feedback: FeedbackItem;
  token: string;
  firebaseApiKey: string;
  firebaseAuthDomain: string;
  firebaseProjectId: string;
}

export function renderAcknowledgementPortal(options: PortalOptions): string {
  const { feedback, token, firebaseApiKey, firebaseAuthDomain, firebaseProjectId } = options;

  const categoryTitle = formatCategoryTitle(feedback.category);
  const moduleLabel = formatModuleLabel(feedback.module);
  const badgeColor = getCategoryBadgeColor(feedback.category);

  let formattedDate = feedback.createdAt;
  try {
    formattedDate = new Date(feedback.createdAt).toUTCString();
  } catch {}

  let acknowledgedDateStr = '';
  if (feedback.acknowledgedAt) {
    try {
      acknowledgedDateStr = new Date(feedback.acknowledgedAt).toUTCString();
    } catch {
      acknowledgedDateStr = feedback.acknowledgedAt;
    }
  }

  const isAlreadyAcknowledged = feedback.status === 'acknowledged';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Project Arc — Review & Acknowledge Feedback</title>
  <style>
    :root {
      --bg: #0D0D0D;
      --card: #181818;
      --card-border: #2A2A2A;
      --accent: #D7FF2F;
      --accent-dim: rgba(215, 255, 47, 0.15);
      --text: #F3F4F6;
      --text-muted: #8E8E93;
      --danger: #FF5252;
      --success: #10B981;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
      -webkit-font-smoothing: antialiased;
    }
    .container {
      width: 100%;
      max-width: 620px;
      background: var(--card);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 20px 40px rgba(0,0,0,0.7);
    }
    .top-accent {
      height: 4px;
      background: linear-gradient(90deg, #D7FF2F 0%, #448AFF 100%);
    }
    .header {
      padding: 24px 28px;
      border-bottom: 1px solid var(--card-border);
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
    }
    .header h1 {
      font-size: 19px;
      font-weight: 800;
      letter-spacing: -0.3px;
    }
    .header h1 span { color: var(--accent); }
    .badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      background-color: ${badgeColor.bg};
      color: ${badgeColor.text};
      border: 1px solid ${badgeColor.border};
      white-space: nowrap;
    }
    .content { padding: 28px; }
    .section-title {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: var(--text-muted);
      margin-bottom: 8px;
    }
    .message-card {
      background: #202020;
      border: 1px solid #303030;
      border-left: 4px solid var(--accent);
      border-radius: 10px;
      padding: 16px 20px;
      font-size: 15px;
      line-height: 1.6;
      color: #EDEDED;
      margin-bottom: 24px;
      word-break: break-word;
    }
    .metadata-grid {
      background: #121212;
      border: 1px solid #242424;
      border-radius: 10px;
      padding: 14px 18px;
      margin-bottom: 24px;
      font-size: 13px;
    }
    .meta-row {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      border-bottom: 1px solid #1E1E1E;
    }
    .meta-row:last-child { border-bottom: none; }
    .meta-label { color: var(--text-muted); font-weight: 600; font-size: 12px; }
    .meta-val { color: #FFFFFF; font-weight: 600; text-align: right; }
    .mono { font-family: 'SFMono-Regular', Consolas, Menlo, monospace; font-size: 12px; color: #BBB; }
    
    .auth-box {
      background: #141414;
      border: 1px solid #282828;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 20px;
    }
    .auth-box h3 { font-size: 14px; font-weight: 700; margin-bottom: 6px; }
    .auth-box p { font-size: 12px; color: var(--text-muted); margin-bottom: 14px; }
    .form-group { margin-bottom: 12px; }
    .form-group label { display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); margin-bottom: 4px; }
    .form-control {
      width: 100%;
      padding: 10px 14px;
      background: #202020;
      border: 1px solid #333333;
      border-radius: 8px;
      color: #FFFFFF;
      font-size: 13px;
      outline: none;
    }
    .form-control:focus { border-color: var(--accent); }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 100%;
      padding: 14px 24px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
      letter-spacing: -0.2px;
    }
    .btn-accent {
      background: var(--accent);
      color: #141414;
      box-shadow: 0 4px 14px rgba(215, 255, 47, 0.35);
    }
    .btn-accent:hover:not(:disabled) {
      background: #E5FF5E;
      transform: translateY(-1px);
    }
    .btn-accent:disabled {
      opacity: 0.5;
      cursor: not-allowed;
      box-shadow: none;
    }
    .btn-secondary {
      background: #282828;
      color: #FFFFFF;
      padding: 10px 16px;
      font-size: 13px;
      margin-top: 8px;
    }
    .btn-secondary:hover { background: #353535; }

    .status-banner {
      border-radius: 10px;
      padding: 16px 20px;
      text-align: center;
      font-size: 14px;
      font-weight: 600;
      margin-bottom: 20px;
    }
    .banner-success {
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.4);
      color: #34D399;
    }
    .banner-warning {
      background: rgba(245, 158, 11, 0.15);
      border: 1px solid rgba(245, 158, 11, 0.4);
      color: #FBBF24;
    }
    .banner-error {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.4);
      color: #F87171;
    }

    .footer {
      padding: 16px 28px;
      background: #111111;
      border-top: 1px solid var(--card-border);
      text-align: center;
      font-size: 11px;
      color: #666666;
    }
  </style>
</head>
<body>

  <div class="container">
    <div class="top-accent"></div>
    
    <div class="header">
      <div>
        <h1>PROJECT <span>ARC</span></h1>
        <div style="font-size: 11px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; margin-top: 2px;">Administrator Feedback Portal</div>
      </div>
      <span class="badge">${escapeHtml(categoryTitle)}</span>
    </div>

    <div class="content">

      ${
        isAlreadyAcknowledged
          ? `<div class="status-banner banner-success">
              <div style="font-size: 20px; margin-bottom: 4px;">✓</div>
              <strong>This feedback was already acknowledged</strong>
              <div style="font-size: 12px; margin-top: 4px; opacity: 0.9;">${escapeHtml(acknowledgedDateStr)}</div>
             </div>`
          : ''
      }

      <div class="section-title">User Narrative</div>
      <div id="narrative-locked" class="auth-required-box" style="background:#1B1B1B;border:1px dashed #333;border-radius:10px;padding:24px 20px;text-align:center;color:var(--text-muted);margin-bottom:24px;">
        <div style="font-size: 26px; margin-bottom: 8px;">🔒</div>
        <strong style="color: #EDEDED; font-size: 14px;">Confidential Feedback Protected</strong>
        <p style="font-size: 12px; color: #888; margin-top: 6px; line-height: 1.5;">Sign in with your verified Project Arc administrator account below to decrypt and inspect the confidential user narrative and submitter identity.</p>
      </div>
      <div id="narrative-card" class="message-card" style="display: none; margin-bottom: 24px;"></div>

      <div class="section-title">Submission Details</div>
      <div class="metadata-grid">
        <div class="meta-row">
          <span class="meta-label">Module</span>
          <span class="meta-val">${escapeHtml(moduleLabel)}</span>
        </div>
        <div class="meta-row">
          <span class="meta-label">Rating</span>
          <span class="meta-val">${feedback.rating != null ? escapeHtml(formatRatingStars(feedback.rating)) : '<span style="color: #666;">None</span>'}</span>
        </div>
        <div class="meta-row">
          <span class="meta-label">Current Status</span>
          <span class="meta-val" id="status-val" style="text-transform: capitalize; color: ${isAlreadyAcknowledged ? 'var(--accent)' : '#448AFF'};">${escapeHtml(feedback.status)}</span>
        </div>
        <div class="meta-row">
          <span class="meta-label">Submitted At</span>
          <span class="meta-val">${escapeHtml(formattedDate)}</span>
        </div>
        <div class="meta-row">
          <span class="meta-label">Feedback ID</span>
          <span class="meta-val mono">${escapeHtml(feedback.id)}</span>
        </div>
        <div class="meta-row" id="meta-row-uid" style="display: none;">
          <span class="meta-label">Submitter UID</span>
          <span class="meta-val mono" id="meta-val-uid"></span>
        </div>
        <div class="meta-row" id="meta-row-email" style="display: none;">
          <span class="meta-label">Contact Email</span>
          <span class="meta-val" id="meta-val-email"></span>
        </div>
      </div>

      <!-- Action Area -->
      <div id="action-container">
        ${
          isAlreadyAcknowledged
            ? `<div style="text-align: center; color: var(--text-muted); font-size: 13px;">
                No further administrative action required.
               </div>`
            : `
          <!-- Dynamic Auth & Confirmation Card -->
          <div id="auth-section" class="auth-box">
            <h3>Administrator Sign-In</h3>
            <p>Authentication with your verified Project Arc administrator account is required to acknowledge this ticket.</p>
            
            <form id="login-form">
              <div class="form-group">
                <label for="admin-email">Admin Email</label>
                <input type="email" id="admin-email" class="form-control" required placeholder="admin@example.com" autocomplete="email">
              </div>
              <div class="form-group">
                <label for="admin-password">Password</label>
                <input type="password" id="admin-password" class="form-control" required placeholder="••••••••" autocomplete="current-password">
              </div>
              <button type="submit" id="btn-login" class="btn btn-secondary">Sign In to Continue</button>
            </form>
          </div>

          <div id="auth-status" style="display: none; margin-bottom: 16px;">
            <div style="display: flex; justify-content: space-between; align-items: center; background: #161616; padding: 12px 16px; border-radius: 8px; border: 1px solid #282828;">
              <div style="font-size: 12px;">
                <span style="color: var(--text-muted);">Signed in as:</span>
                <strong id="auth-email" style="color: #FFFFFF; margin-left: 6px;"></strong>
              </div>
              <button type="button" id="btn-switch" style="background: none; border: none; color: #448AFF; font-size: 12px; cursor: pointer; text-decoration: underline;">Switch Account</button>
            </div>
          </div>

          <div id="error-banner" class="status-banner banner-error" style="display: none;"></div>
          <div id="success-banner" class="status-banner banner-success" style="display: none;"></div>

          <button type="button" id="btn-acknowledge" class="btn btn-accent" disabled>
            Acknowledge Feedback
          </button>
          `
        }
      </div>

    </div>

    <div class="footer">
      Project Arc &bull; Spark Free Tier Secure Delivery &bull; Production Release
    </div>
  </div>

  <script>
    const FIREBASE_API_KEY = ${JSON.stringify(firebaseApiKey)};
    const FEEDBACK_ID = ${JSON.stringify(feedback.id)};
    const TOKEN = ${JSON.stringify(token)};

    let currentIdToken = localStorage.getItem('arc_admin_token') || '';
    let currentAdminEmail = localStorage.getItem('arc_admin_email') || '';

    const authSection = document.getElementById('auth-section');
    const authStatus = document.getElementById('auth-status');
    const authEmail = document.getElementById('auth-email');
    const btnSwitch = document.getElementById('btn-switch');
    const loginForm = document.getElementById('login-form');
    const btnLogin = document.getElementById('btn-login');
    const btnAcknowledge = document.getElementById('btn-acknowledge');
    const errorBanner = document.getElementById('error-banner');
    const successBanner = document.getElementById('success-banner');
    const statusVal = document.getElementById('status-val');

    function showError(msg) {
      if (errorBanner) {
        errorBanner.innerText = msg;
        errorBanner.style.display = 'block';
      }
      if (successBanner) successBanner.style.display = 'none';
    }

    function showSuccess(msg) {
      if (successBanner) {
        successBanner.innerHTML = '<div style="font-size: 20px; margin-bottom: 4px;">✓</div><strong>' + msg + '</strong>';
        successBanner.style.display = 'block';
      }
      if (errorBanner) errorBanner.style.display = 'none';
    }

    function updateAuthUi() {
      if (currentIdToken && currentAdminEmail) {
        if (authSection) authSection.style.display = 'none';
        if (authStatus) {
          authEmail.innerText = currentAdminEmail;
          authStatus.style.display = 'block';
        }
        loadFeedbackDetails(currentIdToken);
      } else {
        if (authSection) authSection.style.display = 'block';
        if (authStatus) authStatus.style.display = 'none';
        if (btnAcknowledge) btnAcknowledge.disabled = true;
        const narrativeCard = document.getElementById('narrative-card');
        const narrativeLocked = document.getElementById('narrative-locked');
        if (narrativeCard && narrativeLocked) {
          narrativeCard.style.display = 'none';
          narrativeLocked.style.display = 'block';
        }
        const rowUid = document.getElementById('meta-row-uid');
        if (rowUid) rowUid.style.display = 'none';
        const rowEmail = document.getElementById('meta-row-email');
        if (rowEmail) rowEmail.style.display = 'none';
      }
    }

    async function loadFeedbackDetails(token) {
      try {
        const res = await fetch('/api/feedback/details', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + token,
          },
          body: JSON.stringify({ feedbackId: FEEDBACK_ID, token: TOKEN })
        });
        if (!res.ok) {
          const errData = await res.json().catch(() => ({}));
          if (res.status === 401) {
            currentIdToken = '';
            localStorage.removeItem('arc_admin_token');
            updateAuthUi();
            throw new Error('Your session has expired. Please sign in again.');
          }
          if (res.status === 403) {
            throw new Error(errData.error || 'Access Denied: This account lacks administrator custom claims.');
          }
          throw new Error(errData.error || 'Failed to load feedback details.');
        }

        const data = await res.json();
        const narrativeCard = document.getElementById('narrative-card');
        const narrativeLocked = document.getElementById('narrative-locked');
        if (narrativeCard && narrativeLocked) {
          narrativeCard.innerHTML = (data.message || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '<br/>');
          narrativeCard.style.display = 'block';
          narrativeLocked.style.display = 'none';
        }
        if (data.userId) {
          const rowUid = document.getElementById('meta-row-uid');
          const valUid = document.getElementById('meta-val-uid');
          if (rowUid && valUid) {
            valUid.innerText = data.userId;
            rowUid.style.display = 'flex';
          }
        }
        if (data.contactEmail) {
          const rowEmail = document.getElementById('meta-row-email');
          const valEmail = document.getElementById('meta-val-email');
          if (rowEmail && valEmail) {
            valEmail.innerText = data.contactEmail;
            rowEmail.style.display = 'flex';
          }
        }
        if (btnAcknowledge) btnAcknowledge.disabled = false;
      } catch (err) {
        showError(err.message);
        if (btnAcknowledge) btnAcknowledge.disabled = true;
      }
    }

    if (btnSwitch) {
      btnSwitch.addEventListener('click', () => {
        currentIdToken = '';
        currentAdminEmail = '';
        localStorage.removeItem('arc_admin_token');
        localStorage.removeItem('arc_admin_email');
        updateAuthUi();
      });
    }

    if (loginForm) {
      loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('admin-email').value.trim();
        const password = document.getElementById('admin-password').value;
        if (!email || !password) return;

        btnLogin.disabled = true;
        btnLogin.innerText = 'Verifying credentials...';
        if (errorBanner) errorBanner.style.display = 'none';

        try {
          const res = await fetch('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + FIREBASE_API_KEY, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password, returnSecureToken: true })
          });

          const data = await res.json();
          if (!res.ok) {
            throw new Error(data.error?.message || 'Authentication failed. Please check credentials.');
          }

          currentIdToken = data.idToken;
          currentAdminEmail = data.email || email;
          localStorage.setItem('arc_admin_token', currentIdToken);
          localStorage.setItem('arc_admin_email', currentAdminEmail);
          updateAuthUi();
        } catch (err) {
          showError(err.message);
        } finally {
          btnLogin.disabled = false;
          btnLogin.innerText = 'Sign In to Continue';
        }
      });
    }

    if (btnAcknowledge) {
      btnAcknowledge.addEventListener('click', async () => {
        if (!currentIdToken) return;

        btnAcknowledge.disabled = true;
        btnAcknowledge.innerText = 'Acknowledging feedback...';
        if (errorBanner) errorBanner.style.display = 'none';

        try {
          const res = await fetch('/api/acknowledge', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ' + currentIdToken,
            },
            body: JSON.stringify({
              feedbackId: FEEDBACK_ID,
              token: TOKEN,
            })
          });

          const data = await res.json();
          if (!res.ok) {
            if (res.status === 401) {
              // Token expired, clear and re-prompt login
              currentIdToken = '';
              localStorage.removeItem('arc_admin_token');
              updateAuthUi();
              throw new Error('Your session has expired. Please sign in again.');
            }
            throw new Error(data.error || 'Failed to acknowledge feedback.');
          }

          showSuccess('Feedback Acknowledged Successfully! The submitting user will receive a thank-you notification upon active session.');
          if (statusVal) {
            statusVal.innerText = 'acknowledged';
            statusVal.style.color = 'var(--accent)';
          }
          btnAcknowledge.style.display = 'none';
          if (authStatus) authStatus.style.display = 'none';
        } catch (err) {
          showError(err.message);
          btnAcknowledge.disabled = false;
          btnAcknowledge.innerText = 'Acknowledge Feedback';
        }
      });
    }

    updateAuthUi();
  </script>
</body>
</html>`;
}
