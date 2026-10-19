package com.arc.arc.core.database

import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.security.VaultCryptoEngine
import java.util.Date

/**
 * Mappers between domain model [SecretNoteModel] and persistence entity [SecretNoteEntity].
 *
 * CRITICAL SECURITY INVARIANT:
 * Encrypts sensitive fields (title and full JSON payload) using authenticated AES-256-GCM
 * with unique 12-byte random nonces per operation.
 * Plaintext is never stored in [SecretNoteEntity].
 */
object SecretNoteMappers {

    /**
     * Encrypts and converts [SecretNoteModel] to an encrypted [SecretNoteEntity].
     */
    fun SecretNoteModel.toEntity(dek: ByteArray): SecretNoteEntity {
        require(dek.size == 32) { "DEK must be a 256-bit (32-byte) key" }

        val encryptedTitle = VaultCryptoEngine.encryptToString(
            plaintext = title,
            keyBytes = dek
        )

        val encryptedPayload = VaultCryptoEngine.encryptToString(
            plaintext = toJson(),
            keyBytes = dek
        )

        return SecretNoteEntity(
            id,
            ownerUid,
            encryptedTitle,
            encryptedPayload,
            color,
            createdAt.time,
            updatedAt.time
        )
    }

    /**
     * Decrypts and converts [SecretNoteEntity] to a decrypted [SecretNoteModel].
     * Throws [java.security.GeneralSecurityException] if ciphertext or tag is invalid.
     */
    fun SecretNoteEntity.toModel(dek: ByteArray): SecretNoteModel {
        require(dek.size == 32) { "DEK must be a 256-bit (32-byte) key" }

        val payloadJson = VaultCryptoEngine.decryptFromString(
            envelopeString = encryptedPayload,
            keyBytes = dek
        )
        val parsedModel = SecretNoteModel.fromJson(payloadJson)

        return parsedModel.copy(
            id = id,
            ownerUid = ownerUid,
            color = color,
            createdAt = Date(createdAt),
            updatedAt = Date(updatedAt)
        )
    }
}
