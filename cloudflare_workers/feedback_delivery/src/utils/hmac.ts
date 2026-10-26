/**
 * Cryptographic HMAC Utility for Secure Acknowledgement Links
 *
 * Generates and verifies HMAC-SHA256 tokens using the Web Crypto API.
 */

function bufferToHex(buffer: ArrayBuffer): string {
  const byteArray = new Uint8Array(buffer);
  return Array.from(byteArray, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function generateAcknowledgementToken(feedbackId: string, secretKey: string): Promise<string> {
  const enc = new TextEncoder();
  const keyData = enc.encode(secretKey);
  const messageData = enc.encode(`arc_ack:${feedbackId}`);

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign('HMAC', cryptoKey, messageData);
  return bufferToHex(signature);
}

export async function verifyAcknowledgementToken(
  feedbackId: string,
  token: string,
  secretKey: string
): Promise<boolean> {
  if (!feedbackId || !token || !secretKey) return false;
  try {
    const expectedToken = await generateAcknowledgementToken(feedbackId, secretKey);
    // Constant-time comparison to prevent timing attacks
    if (expectedToken.length !== token.length) return false;
    let diff = 0;
    for (let i = 0; i < expectedToken.length; i++) {
      diff |= expectedToken.charCodeAt(i) ^ token.charCodeAt(i);
    }
    return diff === 0;
  } catch {
    return false;
  }
}
