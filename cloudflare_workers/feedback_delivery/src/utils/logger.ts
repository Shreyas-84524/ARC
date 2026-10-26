/**
 * Privacy-Preserving Logger
 *
 * Ensures no sensitive user narratives, personal tokens, or API credentials
 * leak into Cloudflare Worker logs.
 */

export class SafeLogger {
  static info(message: string, meta?: Record<string, unknown>): void {
    const timestamp = new Date().toISOString();
    if (meta) {
      console.log(`[${timestamp}] [INFO] ${message}`, JSON.stringify(SafeLogger.sanitizeMeta(meta)));
    } else {
      console.log(`[${timestamp}] [INFO] ${message}`);
    }
  }

  static warn(message: string, meta?: Record<string, unknown>): void {
    const timestamp = new Date().toISOString();
    if (meta) {
      console.warn(`[${timestamp}] [WARN] ${message}`, JSON.stringify(SafeLogger.sanitizeMeta(meta)));
    } else {
      console.warn(`[${timestamp}] [WARN] ${message}`);
    }
  }

  static error(message: string, error?: unknown, meta?: Record<string, unknown>): void {
    const timestamp = new Date().toISOString();
    const errObj = error instanceof Error ? { name: error.name, message: error.message } : error;
    console.error(
      `[${timestamp}] [ERROR] ${message}`,
      JSON.stringify({
        error: errObj,
        ...(meta ? SafeLogger.sanitizeMeta(meta) : {}),
      })
    );
  }

  private static sanitizeMeta(meta: Record<string, unknown>): Record<string, unknown> {
    const sanitized: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(meta)) {
      // Exclude narrative message, tokens, or private keys
      if (
        key.toLowerCase().includes('message') ||
        key.toLowerCase().includes('key') ||
        key.toLowerCase().includes('secret') ||
        key.toLowerCase().includes('token') ||
        key.toLowerCase().includes('password')
      ) {
        sanitized[key] = '[REDACTED]';
      } else {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }
}
