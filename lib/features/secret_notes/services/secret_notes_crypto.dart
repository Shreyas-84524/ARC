import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// - NO uploading PINs, salts, or hashes
// - NO logging raw PINs or secrets
// All cryptographic derivations are strictly local.

class SecretNotesCrypto {
  static const int defaultIterations = 100000;
  static const int legacyIterations = 10000;
  static const int saltByteLength = 32;
  static const int derivedKeyLength = 32;

  /// Generates a cryptographically secure random salt of [length] bytes.
  static Uint8List generateSalt([int length = saltByteLength]) {
    final random = Random.secure();
    final salt = Uint8List(length);
    for (int i = 0; i < length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Derives a key using PBKDF2 with HMAC-SHA256 according to RFC 2898.
  static Uint8List pbkdf2HmacSha256({
    required String pin,
    required Uint8List salt,
    int iterations = defaultIterations,
    int keyLength = derivedKeyLength,
  }) {
    final passwordBytes = utf8.encode(pin);
    final hmac = Hmac(sha256, passwordBytes);
    final numBlocks = (keyLength / 32).ceil();
    final result = BytesBuilder(copy: false);

    for (int blockIndex = 1; blockIndex <= numBlocks; blockIndex++) {
      // U_1 = PRF(Password, Salt || INT_32_BE(blockIndex))
      final blockIndexBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, blockIndex, Endian.big);

      final initialInput = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..setRange(salt.length, salt.length + 4, blockIndexBytes);

      var u = Uint8List.fromList(hmac.convert(initialInput).bytes);
      final blockResult = Uint8List.fromList(u);

      for (int i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < blockResult.length; k++) {
          blockResult[k] ^= u[k];
        }
      }

      result.add(blockResult);
    }

    final fullKey = result.takeBytes();
    return fullKey.sublist(0, keyLength);
  }

  /// Constant-time comparison to prevent timing attacks.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Encodes bytes to hex string.
  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Decodes hex string to Uint8List.
  static Uint8List hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
