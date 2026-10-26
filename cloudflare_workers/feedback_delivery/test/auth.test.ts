import { describe, it, expect, vi } from 'vitest';
import { generateKeyPairSync } from 'crypto';
import { GoogleAuthService } from '../src/firestore/auth';
import { ValidatedConfig } from '../src/config';

describe('GoogleAuthService RS256 WebCrypto Tests', () => {
  // Generate a valid ephemeral RSA key pair for testing Web Crypto import and signing
  const { privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });

  const mockConfig: ValidatedConfig = {
    brevoApiKey: 'test',
    senderEmail: 'test@arc.app',
    senderName: 'Test',
    recipientEmail: 'admin@arc.app',
    firebaseProjectId: 'test-project',
    firebaseClientEmail: 'test-sa@test-project.iam.gserviceaccount.com',
    firebasePrivateKey: privateKey,
    batchSize: 10,
    maxRetries: 3,
  };

  it('exchanges signed JWT for Google OAuth2 access token and caches it', async () => {
    const authService = new GoogleAuthService(mockConfig);

    let tokenRequestCount = 0;
    global.fetch = vi.fn().mockImplementation((url, init) => {
      tokenRequestCount++;
      const body = new URLSearchParams(init.body);
      const assertion = body.get('assertion');
      expect(assertion).toBeDefined();

      // Verify JWT structure: header.payload.signature
      const parts = assertion!.split('.');
      expect(parts.length).toBe(3);

      const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
      const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));

      expect(header.alg).toBe('RS256');
      expect(payload.iss).toBe(mockConfig.firebaseClientEmail);
      expect(payload.scope).toBe('https://www.googleapis.com/auth/datastore');

      return Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ access_token: 'valid-ya29-token', expires_in: 3600 }),
      });
    });

    // Call 1: makes network call
    const token1 = await authService.getAccessToken();
    expect(token1).toBe('valid-ya29-token');
    expect(tokenRequestCount).toBe(1);

    // Call 2: should use memory cache (zero network calls)
    const token2 = await authService.getAccessToken();
    expect(token2).toBe('valid-ya29-token');
    expect(tokenRequestCount).toBe(1);
  });
});
