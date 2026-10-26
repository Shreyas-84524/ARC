import { describe, it, expect } from 'vitest';
import {
  escapeHtml,
  formatCategoryTitle,
  formatModuleLabel,
  formatRatingStars,
  getCategoryBadgeColor,
} from '../src/utils/sanitizer';

describe('Sanitizer & Formatter Tests', () => {
  it('escapes HTML special characters to prevent injection', () => {
    const raw = '<script>alert("xss")</script> & \'test\'';
    const escaped = escapeHtml(raw);
    expect(escaped).toBe('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt; &amp; &#039;test&#039;');
  });

  it('handles empty or null string gracefully in escapeHtml', () => {
    expect(escapeHtml('')).toBe('');
  });

  it('formats categories properly', () => {
    expect(formatCategoryTitle('bug_report')).toBe('Bug Report');
    expect(formatCategoryTitle('feature_request')).toBe('Feature Request');
    expect(formatCategoryTitle('general_feedback')).toBe('General Feedback');
    expect(formatCategoryTitle('app_rating')).toBe('App Rating');
    expect(formatCategoryTitle('custom_category')).toBe('Custom Category');
  });

  it('maps module labels correctly', () => {
    expect(formatModuleLabel('task_manager')).toBe('Task Manager');
    expect(formatModuleLabel('habit_tracker')).toBe('Habit Tracker');
    expect(formatModuleLabel('money_tracker')).toBe('Money Tracker');
    expect(formatModuleLabel('secret_notes')).toBe('Secret Notes & Vault');
    expect(formatModuleLabel('account_auth')).toBe('Account & Authentication');
    expect(formatModuleLabel('notifications')).toBe('Notifications & Alerts');
    expect(formatModuleLabel('ui_ux')).toBe('UI & Theme Design');
    expect(formatModuleLabel('general')).toBe('General & Across App');
    expect(formatModuleLabel('unknown_module')).toBe('unknown_module');
  });

  it('formats star ratings correctly', () => {
    expect(formatRatingStars(5)).toBe('★★★★★ (5/5 — Outstanding)');
    expect(formatRatingStars(4)).toBe('★★★★☆ (4/5 — Great)');
    expect(formatRatingStars(3)).toBe('★★★☆☆ (3/5 — Good)');
    expect(formatRatingStars(2)).toBe('★★☆☆☆ (2/5 — Fair)');
    expect(formatRatingStars(1)).toBe('★☆☆☆☆ (1/5 — Needs Improvement)');
    expect(formatRatingStars(null)).toBe('Not Provided');
    expect(formatRatingStars(undefined)).toBe('Not Provided');
  });

  it('assigns distinctive badge colors per category', () => {
    const bug = getCategoryBadgeColor('bug_report');
    expect(bug.text).toBe('#FF5252');

    const feature = getCategoryBadgeColor('feature_request');
    expect(feature.text).toBe('#D7FF2F');

    const general = getCategoryBadgeColor('general_feedback');
    expect(general.text).toBe('#448AFF');

    const rating = getCategoryBadgeColor('app_rating');
    expect(rating.text).toBe('#FFC857');
  });
});
