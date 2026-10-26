/**
 * Google Cloud Service Account OAuth 2.0 Authenticator
 *
 * Implements RFC 7523 JWT Bearer assertion exchange using the native
 * Web Crypto API (SubtleCrypto) for RS256 signatures in Cloudflare Workers.
 */

import { ValidatedConfig } from '../config';
import { SafeLogger } from '../utils/logger';

function base64UrlEncode(input: Uint8Array | string): string {
  const binary = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let str = '';
  for (let i = 0; i < binary.length; i++) {
    str += String.fromCharCode(binary[i]);
  }
  return btoa(str)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleanPem = pem
    .replace(/-----BEGIN[ A-Z_-]+-----/g, '')
    .replace(/-----END[ A-Z_-]+-----/g, '')
    .replace(/\s+/g, '');
  const binaryStr = atob(cleanPem);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }
  return bytes.buffer;
}

export class GoogleAuthService {
  private readonly clientEmail: string;
  private readonly privateKeyPem: string;
  private cachedToken: string | null = null;
  private tokenExpiresAt = 0;
  private cryptoKey: CryptoKey | null = null;

  constructor(config: ValidatedConfig) {
    this.clientEmail = config.firebaseClientEmail;
    this.privateKeyPem = config.firebasePrivateKey;
  }

  private async getCryptoKey(): Promise<CryptoKey> {
    if (this.cryptoKey) return this.cryptoKey;

    const derBuffer = pemToArrayBuffer(this.privateKeyPem);
    this.cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      derBuffer,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256',
      },
      false,
      ['sign']
    );

    return this.cryptoKey;
  }

  private async createSignedJwt(): Promise<string> {
    const key = await this.getCryptoKey();
    const now = Math.floor(Date.now() / 1000);

    const header = {
      alg: 'RS256',
      typ: 'JWT',
    };

    const payload = {
      iss: this.clientEmail,
      sub: this.clientEmail,
      aud: 'https://oauth2.googleapis.com/token',
      scope: 'https://www.googleapis.com/auth/datastore',
      iat: now,
      exp: now + 3600, // 1 hour validity
    };

    const headerEncoded = base64UrlEncode(JSON.stringify(header));
    const payloadEncoded = base64UrlEncode(JSON.stringify(payload));
    const signingInput = `${headerEncoded}.${payloadEncoded}`;

    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(signingInput)
    );

    const signatureEncoded = base64UrlEncode(new Uint8Array(signature));
    return `${signingInput}.${signatureEncoded}`;
  }

  /**
   * Retrieves a valid Google OAuth2 access token, using the memory cache
   * when still unexpired (5-minute safety margin).
   */
  async getAccessToken(): Promise<string> {
    const now = Date.now();
    if (this.cachedToken && now < this.tokenExpiresAt) {
      return this.cachedToken;
    }

    SafeLogger.info('Generating new Google OAuth2 access token for Firestore');
    const assertion = await this.createSignedJwt();

    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      const errText = await response.text();
      SafeLogger.error('Google OAuth token exchange failed', null, { status: response.status });
      throw new Error(`Google OAuth token exchange failed (${response.status}): ${errText}`);
    }

    const data = (await response.json()) as { access_token: string; expires_in: number };
    this.cachedToken = data.access_token;
    // Expire 5 minutes early to avoid edge-of-expiry race conditions
    this.tokenExpiresAt = now + (data.expires_in - 300) * 1000;

    return this.cachedToken;
  }
}
