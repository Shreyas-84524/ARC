package com.arc.arc.features.money.automation

import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

/**
 * Local deduplication service ensuring no duplicate transactions are processed.
 *
 * RULES:
 * - If a [referenceId] is present, duplicate check prioritizes it.
 * - If [referenceId] is absent, uses the deterministic [fingerprint].
 * - Scoped to the active user to ensure complete multi-user isolation.
 * - Maintains an in-memory working cache backed by user isolation.
 */
class MoneyDeduplicationService {

    companion object {
        private val userFingerprintsStorage = ConcurrentHashMap<String, MutableSet<String>>()
        private val userReferenceIdsStorage = ConcurrentHashMap<String, MutableSet<String>>()

        fun resetStorage() {
            userFingerprintsStorage.clear()
            userReferenceIdsStorage.clear()
        }
    }

    private val processedFingerprints = Collections.synchronizedSet(mutableSetOf<String>())
    private val processedReferenceIds = Collections.synchronizedSet(mutableSetOf<String>())
    private var currentUserId: String? = null

    val cachedFingerprints: Set<String>
        get() = synchronized(processedFingerprints) { processedFingerprints.toSet() }

    val cachedReferenceIds: Set<String>
        get() = synchronized(processedReferenceIds) { processedReferenceIds.toSet() }

    /**
     * Initializes deduplication cache for the current user.
     */
    fun initForUser(userId: String?) {
        currentUserId = userId
        processedFingerprints.clear()
        processedReferenceIds.clear()

        if (userId.isNullOrBlank()) return

        val fps = userFingerprintsStorage[userId]
        if (fps != null) {
            processedFingerprints.addAll(fps)
        }
        val refs = userReferenceIdsStorage[userId]
        if (refs != null) {
            processedReferenceIds.addAll(refs)
        }
    }

    /**
     * Checks if the transaction has already been processed.
     */
    fun isDuplicate(fingerprint: String, referenceId: String? = null): Boolean {
        if (!referenceId.isNullOrBlank()) {
            val normalizedRef = referenceId.trim().uppercase()
            if (processedReferenceIds.contains(normalizedRef)) {
                return true
            }
        }
        return processedFingerprints.contains(fingerprint)
    }

    /**
     * Records the transaction fingerprint and reference ID as processed.
     */
    fun recordProcessed(fingerprint: String, referenceId: String? = null) {
        processedFingerprints.add(fingerprint)
        if (!referenceId.isNullOrBlank()) {
            processedReferenceIds.add(referenceId.trim().uppercase())
        }

        val uid = currentUserId
        if (!uid.isNullOrBlank()) {
            val userFps = userFingerprintsStorage.computeIfAbsent(uid) { ConcurrentHashMap.newKeySet() }
            userFps.add(fingerprint)

            if (!referenceId.isNullOrBlank()) {
                val userRefs = userReferenceIdsStorage.computeIfAbsent(uid) { ConcurrentHashMap.newKeySet() }
                userRefs.add(referenceId.trim().uppercase())
            }
        }
    }

    /**
     * Clears in-memory sets upon user sign-out.
     */
    fun clear() {
        processedFingerprints.clear()
        processedReferenceIds.clear()
        currentUserId = null
    }
}
