import { describe, it, expect } from 'vitest';
import { renderFeedbackEmail } from '../src/brevo/template';
import { FeedbackItem } from '../src/brevo/types';

describe('Brevo Email Template Tests', () => {
  const baseItem: FeedbackItem = {
    id: 'fb-test-12345',
    documentPath: 'projects/test/databases/(default)/documents/feedback/fb-test-12345',
    updateTime: '2026-10-25T14:30:00Z',
    userId: 'user_xyz789',
    category: 'bug_report',
    module: 'task_manager',
    message: 'App crashed when filtering by priority <tag>',
    rating: 2,
    contactEmail: 'tester@example.com',
    appVersion: '1.2.0+5',
    createdAt: '2026-10-25T14:30:00.000Z',
    status: 'submitted',
    dispatchAttemptCount: 0,
    emailRetryCount: 0,
  };

  it('generates correct subject line format [ARC Feedback] {{category}} — {{module}}', () => {
    const rendered = renderFeedbackEmail(baseItem);
    expect(rendered.subject).toBe('[ARC Feedback] Bug Report — Task Manager');
  });

  it('renders all four feedback categories with correct subjects', () => {
    const categories = [
      { cat: 'bug_report', mod: 'habit_tracker', expected: '[ARC Feedback] Bug Report — Habit Tracker' },
      { cat: 'feature_request', mod: 'money_tracker', expected: '[ARC Feedback] Feature Request — Money Tracker' },
      { cat: 'general_feedback', mod: 'general', expected: '[ARC Feedback] General Feedback — General & Across App' },
      { cat: 'app_rating', mod: 'ui_ux', expected: '[ARC Feedback] App Rating — UI & Theme Design' },
    ];

    for (const { cat, mod, expected } of categories) {
      const rendered = renderFeedbackEmail({ ...baseItem, category: cat, module: mod });
      expect(rendered.subject).toBe(expected);
    }
  });

  it('escapes user narrative in HTML to prevent XSS injection', () => {
    const dangerousItem: FeedbackItem = {
      ...baseItem,
      message: 'Hello <script>malicious()</script> & "quotes" \'apostrophe\'',
    };
    const rendered = renderFeedbackEmail(dangerousItem);

    expect(rendered.htmlContent).toContain('&lt;script&gt;malicious()&lt;/script&gt;');
    expect(rendered.htmlContent).toContain('&amp;');
    expect(rendered.htmlContent).toContain('&quot;quotes&quot;');
    expect(rendered.htmlContent).toContain('&#039;apostrophe&#039;');
    expect(rendered.htmlContent).not.toContain('<script>');
  });

  it('includes all mandatory metadata fields in HTML and plain text', () => {
    const rendered = renderFeedbackEmail(baseItem);

    // HTML assertions
    expect(rendered.htmlContent).toContain('fb-test-12345');
    expect(rendered.htmlContent).toContain('user_xyz789');
    expect(rendered.htmlContent).toContain('Task Manager');
    expect(rendered.htmlContent).toContain('1.2.0+5');
    expect(rendered.htmlContent).toContain('tester@example.com');
    expect(rendered.htmlContent).toContain('★★☆☆☆ (2/5 — Fair)');

    // Plain text assertions
    expect(rendered.textContent).toContain('fb-test-12345');
    expect(rendered.textContent).toContain('user_xyz789');
    expect(rendered.textContent).toContain('Task Manager');
    expect(rendered.textContent).toContain('App crashed when filtering by priority <tag>');
  });

  it('handles null rating and null contact email gracefully', () => {
    const itemWithoutOptionalFields: FeedbackItem = {
      ...baseItem,
      rating: null,
      contactEmail: null,
    };
    const rendered = renderFeedbackEmail(itemWithoutOptionalFields);

    expect(rendered.htmlContent).toContain('Not provided');
    expect(rendered.textContent).toContain('Contact Email: Not provided');
    expect(rendered.textContent).toContain('Rating:        Not Provided');
  });
});
