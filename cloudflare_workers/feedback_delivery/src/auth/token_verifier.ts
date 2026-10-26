/**
 * Server-Side Firebase ID Token Verifier
 *
 * Validates RS256 JWT assertions against Google Identity Securetoken JWKS
 * using the native Web Crypto API (crypto.subtle) without third-party dependencies.
 */

export interface VerifiedFirebaseUser {
  uid: string;
  email?: string;
  isAdmin: boolean;
  claims: Record<string, unknown>;
}

interface JwkKey {
  kid: string;
  alg: string;
  kty: string;
  n: string;
  e: string;
}

interface JwksResponse {
  keys: JwkKey[];
}

let cachedJwks: { keys: JwkKey[]; expiresAt: number } | null = null;

async function getGooglePublicKeys(): Promise<JwkKey[]> {
  const now = Date.now();
  if (cachedJwks && cachedJwks.expiresAt > now) {
    return cachedJwks.keys;
  }

  const res = await fetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
  if (!res.ok) {
    throw new Error(`Failed to fetch Google Identity JWKS: ${res.status}`);
  }

  // Cache based on Cache-Control max-age or default to 6 hours
  const cacheControl = res.headers.get('cache-control') || '';
  const match = cacheControl.match(/max-age=(\d+)/);
  const maxAgeSeconds = match ? parseInt(match[1], 10) : 6 * 3600;

  const data = (await res.json()) as JwksResponse;
  cachedJwks = {
    keys: data.keys || [],
    expiresAt: now + maxAgeSeconds * 1000,
  };

  return cachedJwks.keys;
}

function base64UrlDecode(str: string): Uint8Array {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4 !== 0) {
    base64 += '=';
  }
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export async function verifyFirebaseIdToken(
  idToken: string,
  firebaseProjectId: string,
  _recipientEmail?: string
): Promise<VerifiedFirebaseUser> {
  if (!idToken || typeof idToken !== 'string') {
    throw new Error('Missing or invalid ID token.');
  }

  const parts = idToken.split('.');
  if (parts.length !== 3) {
    throw new Error('Malformed JWT structure: token must contain 3 segments.');
  }

  const [headerB64, payloadB64, signatureB64] = parts;

  // 1. Decode and validate header
  let header: { alg: string; kid: string };
  try {
    const headerJson = new TextDecoder().decode(base64UrlDecode(headerB64));
    header = JSON.parse(headerJson);
  } catch {
    throw new Error('Failed to parse JWT header.');
  }

  if (header.alg !== 'RS256') {
    throw new Error(`Unsupported JWT algorithm "${header.alg}". Expected RS256.`);
  }

  if (!header.kid) {
    throw new Error('JWT header missing required key ID (kid).');
  }

  // 2. Decode and validate payload
  let payload: Record<string, any>;
  try {
    const payloadJson = new TextDecoder().decode(base64UrlDecode(payloadB64));
    payload = JSON.parse(payloadJson);
  } catch {
    throw new Error('Failed to parse JWT payload.');
  }

  const nowSec = Math.floor(Date.now() / 1000);

  // Expiration check (with 60-second clock skew tolerance)
  if (typeof payload.exp !== 'number' || payload.exp < nowSec - 60) {
    throw new Error('Firebase ID token has expired.');
  }

  // Audience check
  if (payload.aud !== firebaseProjectId) {
    throw new Error(`Invalid audience: expected "${firebaseProjectId}", received "${payload.aud}".`);
  }

  // Issuer check
  const expectedIss = `https://securetoken.google.com/${firebaseProjectId}`;
  if (payload.iss !== expectedIss) {
    throw new Error(`Invalid issuer: expected "${expectedIss}", received "${payload.iss}".`);
  }

  // Subject (UID) check
  if (typeof payload.sub !== 'string' || !payload.sub) {
    throw new Error('Invalid subject (sub) claim in ID token.');
  }

  // 3. Cryptographic signature verification using Google Public JWKS
  const keys = await getGooglePublicKeys();
  const matchedKey = keys.find((k) => k.kid === header.kid);
  if (!matchedKey) {
    throw new Error(`No matching public key found in Google JWKS for kid: ${header.kid}`);
  }

  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    matchedKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  );

  const signedData = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signatureBytes = base64UrlDecode(signatureB64);

  const isSignatureValid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    signatureBytes,
    signedData
  );

  if (!isSignatureValid) {
    throw new Error('Cryptographic signature verification failed for Firebase ID token.');
  }

  // 4. Administrator authorization verification:
  // Strictly enforce cryptographically signed Firebase Auth Custom Claims:
  // { role: 'admin' } or { admin: true }
  // A matching email address alone NEVER grants administrator privileges.
  const hasRoleAdmin = payload.role === 'admin';
  const hasClaimAdmin = payload.admin === true;

  const isAdmin = hasRoleAdmin || hasClaimAdmin;

  return {
    uid: payload.sub,
    email: payload.email,
    isAdmin,
    claims: payload,
  };
}
