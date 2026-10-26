import { describe, it, expect, vi, beforeEach } from 'vitest';
import { generateKeyPairSync, createSign } from 'crypto';
import { verifyFirebaseIdToken } from '../src/auth/token_verifier';

describe('Firebase ID Token Verifier & Custom Claims Security', () => {
  const projectId = 'arc-test-project';
  const kid = 'test-rsa-kid-1';

  // Generate an ephemeral RSA key pair for cryptographic testing
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });

  const jwk = publicKey.export({ format: 'jwk' }) as any;
  jwk.kid = kid;
  jwk.alg = 'RS256';

  beforeEach(() => {
    // Mock Google Identity Securetoken JWKS endpoint
    global.fetch = vi.fn().mockImplementation((url: string) => {
      if (url.includes('securetoken@system.gserviceaccount.com')) {
        return Promise.resolve({
          ok: true,
          headers: new Headers({ 'cache-control': 'public, max-age=3600' }),
          json: () => Promise.resolve({ keys: [jwk] }),
        });
      }
      return Promise.resolve({ ok: false, status: 404 });
    });
  });

  function createSignedIdToken(payloadObj: Record<string, any>, headerOverride?: Record<string, any>): string {
    const header = headerOverride || { alg: 'RS256', kid };
    const headerB64 = Buffer.from(JSON.stringify(header)).toString('base64url');
    const payloadB64 = Buffer.from(JSON.stringify(payloadObj)).toString('base64url');
    const dataToSign = `${headerB64}.${payloadB64}`;

    const signer = createSign('RSA-SHA256');
    signer.update(dataToSign);
    const signatureB64 = signer.sign(privateKey).toString('base64url');

    return `${dataToSign}.${signatureB64}`;
  }

  it('rejects a user with matching admin email if custom claim is absent (CRITICAL SECURITY FIX)', async () => {
    const nowSec = Math.floor(Date.now() / 1000);
    const token = createSignedIdToken({
      sub: 'user-normal-123',
      email: 'admin@arc.app', // Matching email!
      aud: projectId,
      iss: `https://securetoken.google.com/${projectId}`,
      exp: nowSec + 3600,
      auth_time: nowSec,
      // NOTE: NO role: 'admin' and NO admin: true!
    });

    const verified = await verifyFirebaseIdToken(token, projectId);
    expect(verified.uid).toBe('user-normal-123');
    expect(verified.email).toBe('admin@arc.app');
    expect(verified.isAdmin).toBe(false); // MUST BE FALSE! Email matching does NOT grant admin!
  });

  it('grants administrator privileges when trusted custom claim { role: "admin" } is present', async () => {
    const nowSec = Math.floor(Date.now() / 1000);
    const token = createSignedIdToken({
      sub: 'user-admin-456',
      email: 'admin@arc.app',
      role: 'admin', // Trusted custom claim!
      aud: projectId,
      iss: `https://securetoken.google.com/${projectId}`,
      exp: nowSec + 3600,
      auth_time: nowSec,
    });

    const verified = await verifyFirebaseIdToken(token, projectId);
    expect(verified.uid).toBe('user-admin-456');
    expect(verified.isAdmin).toBe(true);
  });

  it('grants administrator privileges when trusted custom claim { admin: true } is present', async () => {
    const nowSec = Math.floor(Date.now() / 1000);
    const token = createSignedIdToken({
      sub: 'user-admin-789',
      email: 'any-admin-email@custom.domain',
      admin: true, // Trusted boolean claim!
      aud: projectId,
      iss: `https://securetoken.google.com/${projectId}`,
      exp: nowSec + 3600,
      auth_time: nowSec,
    });

    const verified = await verifyFirebaseIdToken(token, projectId);
    expect(verified.uid).toBe('user-admin-789');
    expect(verified.isAdmin).toBe(true);
  });

  it('rejects expired Firebase ID tokens', async () => {
    const pastSec = Math.floor(Date.now() / 1000) - 300; // 5 minutes ago
    const token = createSignedIdToken({
      sub: 'user-admin-999',
      role: 'admin',
      aud: projectId,
      iss: `https://securetoken.google.com/${projectId}`,
      exp: pastSec,
    });

    await expect(verifyFirebaseIdToken(token, projectId)).rejects.toThrow('expired');
  });

  it('rejects tokens issued for an incorrect audience or Firebase project', async () => {
    const nowSec = Math.floor(Date.now() / 1000);
    const token = createSignedIdToken({
      sub: 'user-admin-999',
      role: 'admin',
      aud: 'different-project-id',
      iss: `https://securetoken.google.com/${projectId}`,
      exp: nowSec + 3600,
    });

    await expect(verifyFirebaseIdToken(token, projectId)).rejects.toThrow('Invalid audience');
  });

  it('rejects tokens with forged cryptographic signatures', async () => {
    const nowSec = Math.floor(Date.now() / 1000);
    const validToken = createSignedIdToken({
      sub: 'user-admin-999',
      role: 'admin',
      aud: projectId,
      iss: `https://securetoken.google.com/${projectId}`,
      exp: nowSec + 3600,
    });

    // Tamper payload segment
    const parts = validToken.split('.');
    const tamperedPayload = Buffer.from(
      JSON.stringify({ sub: 'user-hacker-666', role: 'admin', aud: projectId, iss: `https://securetoken.google.com/${projectId}`, exp: nowSec + 3600 })
    ).toString('base64url');
    const forgedToken = `${parts[0]}.${tamperedPayload}.${parts[2]}`;

    await expect(verifyFirebaseIdToken(forgedToken, projectId)).rejects.toThrow('Cryptographic signature verification failed');
  });
});
