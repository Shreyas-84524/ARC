/**
 * HTML Sanitization and Formatting Utilities
 *
 * Prevents HTML/script injection in transactional emails by converting
 * untrusted user narrative text into HTML-safe entities.
 */

export function escapeHtml(str: string): string {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export function formatCategoryTitle(category: string): string {
  switch (category) {
    case 'bug_report':
      return 'Bug Report';
    case 'feature_request':
      return 'Feature Request';
    case 'general_feedback':
      return 'General Feedback';
    case 'app_rating':
      return 'App Rating';
    default:
      return category
        .split('_')
        .map(w => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');
  }
}

export function getCategoryBadgeColor(category: string): { bg: string; text: string; border: string } {
  switch (category) {
    case 'bug_report':
      return { bg: '#2C1517', text: '#FF5252', border: '#7A1C22' };
    case 'feature_request':
      return { bg: '#1C260D', text: '#D7FF2F', border: '#4E6600' };
    case 'general_feedback':
      return { bg: '#0D2137', text: '#448AFF', border: '#154378' };
    case 'app_rating':
      return { bg: '#29200D', text: '#FFC857', border: '#705400' };
    default:
      return { bg: '#242424', text: '#E0E0E0', border: '#444444' };
  }
}

export function formatModuleLabel(module: string): string {
  const map: Record<string, string> = {
    general: 'General & Across App',
    task_manager: 'Task Manager',
    habit_tracker: 'Habit Tracker',
    money_tracker: 'Money Tracker',
    secret_notes: 'Secret Notes & Vault',
    account_auth: 'Account & Authentication',
    notifications: 'Notifications & Alerts',
    ui_ux: 'UI & Theme Design',
  };
  return map[module] || module;
}

export function formatRatingStars(rating?: number | null): string {
  if (rating == null || rating < 1) return 'Not Provided';
  const filled = '★'.repeat(Math.min(5, rating));
  const empty = '☆'.repeat(Math.max(0, 5 - rating));
  const labels: Record<number, string> = {
    1: 'Needs Improvement',
    2: 'Fair',
    3: 'Good',
    4: 'Great',
    5: 'Outstanding',
  };
  return `${filled}${empty} (${rating}/5 — ${labels[rating] || 'Rated'})`;
}
