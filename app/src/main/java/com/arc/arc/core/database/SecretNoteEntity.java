package com.arc.arc.core.database;

import androidx.annotation.NonNull;
import androidx.room.Entity;
import androidx.room.Index;
import androidx.room.PrimaryKey;

/**
 * Room persistence entity for ARC Secret Vault notes.
 *
 * CRITICAL SECURITY INVARIANT:
 * Neither note titles nor note payloads are EVER stored in plaintext.
 * [encryptedTitle] and [encryptedPayload] contain authenticated Base64-encoded
 * AES-256-GCM versioned envelopes: [Version(1 byte)][IV(12 bytes)][Ciphertext + Tag(N bytes)].
 */
@Entity(
    tableName = "secret_notes",
    indices = {
        @Index("ownerUid"),
        @Index({"ownerUid", "updatedAt"})
    }
)
public class SecretNoteEntity {
    @PrimaryKey
    @NonNull
    public String id;

    @NonNull
    public String ownerUid;

    @NonNull
    public String encryptedTitle;

    @NonNull
    public String encryptedPayload;

    @NonNull
    public String color;

    public long createdAt;

    public long updatedAt;

    public SecretNoteEntity(
        @NonNull String id,
        @NonNull String ownerUid,
        @NonNull String encryptedTitle,
        @NonNull String encryptedPayload,
        @NonNull String color,
        long createdAt,
        long updatedAt
    ) {
        this.id = id;
        this.ownerUid = ownerUid;
        this.encryptedTitle = encryptedTitle;
        this.encryptedPayload = encryptedPayload;
        this.color = color;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }
}
