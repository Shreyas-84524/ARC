package com.arc.arc.vault

import com.arc.arc.core.auth.DevFakeAuthRepository
import com.arc.arc.core.model.SecretNoteModel
import com.arc.arc.core.security.VaultAuthCoordinator
import com.arc.arc.core.security.VaultAuthState
import com.arc.arc.core.security.VaultLifecycleManager
import com.arc.arc.core.security.VaultPinManager
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class VaultUserIsolationTest {

    private lateinit var authRepository: DevFakeAuthRepository
    private lateinit var preferencesStore: InMemoryVaultPreferencesDataStore
    private lateinit var pinManager: VaultPinManager
    private lateinit var coordinator: VaultAuthCoordinator
    private lateinit var lifecycleManager: VaultLifecycleManager
    private lateinit var secretNoteRepository: InMemorySecretNoteRepository

    @Before
    fun setUp() {
        authRepository = DevFakeAuthRepository()
        preferencesStore = InMemoryVaultPreferencesDataStore()
        pinManager = VaultPinManager(preferencesStore)
        coordinator = VaultAuthCoordinator(pinManager, preferencesStore)
        lifecycleManager = VaultLifecycleManager(coordinator)
        secretNoteRepository = InMemorySecretNoteRepository()
    }

    @Test
    fun testCrossUserVaultIsolationAndSignOutZeroing() = runTest {
        // 1. User Alice logs in
        val aliceLogin = authRepository.signInWithEmailAndPassword("alice", "password")
        assertTrue(aliceLogin.isSuccess)
        val aliceUid = authRepository.currentUserSession!!.uid

        // Alice sets up vault
        val aliceSetup = coordinator.setupPin(aliceUid, "111222", 6)
        assertTrue(aliceSetup.isSuccess)
        val aliceDek = aliceSetup.getOrThrow()

        // Alice saves secret note
        val aliceNote = SecretNoteModel(
            id = "alice-note-1",
            ownerUid = aliceUid,
            title = "Alice Confidential",
            description = "Alice secret keys"
        )
        secretNoteRepository.saveNote(aliceNote, aliceDek)

        // Verify note is accessible by Alice
        val aliceNotes = secretNoteRepository.getNotes(aliceUid, aliceDek)
        assertEquals(1, aliceNotes.size)
        assertEquals("Alice Confidential", aliceNotes.first().title)

        // 2. Alice logs out -> lifecycle terminates session
        lifecycleManager.onUserSessionTerminated()
        authRepository.signOut()

        // Verify Vault is immediately locked and in-memory DEK is zeroed
        assertFalse(coordinator.isUnlocked)
        assertNull(coordinator.getActiveDek())

        // 3. User Bob logs in
        val bobLogin = authRepository.signInWithEmailAndPassword("bob", "password")
        assertTrue(bobLogin.isSuccess)
        val bobUid = authRepository.currentUserSession!!.uid

        // Bob's coordinator must start in unconfigured/locked state
        coordinator.refreshState(bobUid)
        assertEquals(VaultAuthState.Unconfigured, coordinator.authState.value)

        // Bob sets up his own PIN
        val bobSetup = coordinator.setupPin(bobUid, "999888", 6)
        assertTrue(bobSetup.isSuccess)
        val bobDek = bobSetup.getOrThrow()

        // Bob cannot see Alice's notes
        val bobNotes = secretNoteRepository.getNotes(bobUid, bobDek)
        assertTrue("Bob must see 0 notes belonging to Alice", bobNotes.isEmpty())
        assertNull(secretNoteRepository.getNoteById("alice-note-1", bobUid, bobDek))

        // Bob saves his own note
        val bobNote = SecretNoteModel(
            id = "bob-note-1",
            ownerUid = bobUid,
            title = "Bob Confidential",
            description = "Bob secrets"
        )
        secretNoteRepository.saveNote(bobNote, bobDek)

        assertEquals(1, secretNoteRepository.getNotes(bobUid, bobDek).size)

        // 4. Bob logs out and Alice logs back in
        lifecycleManager.onUserSessionTerminated()
        authRepository.signOut()
        assertFalse(coordinator.isUnlocked)

        authRepository.signInWithEmailAndPassword("alice", "password")
        coordinator.refreshState(aliceUid)
        assertEquals(VaultAuthState.Locked, coordinator.authState.value)

        // Alice unlocks with her PIN
        val aliceUnlock = coordinator.unlockWithPin(aliceUid, "111222")
        assertTrue(aliceUnlock.isSuccess)
        val aliceRestoredDek = aliceUnlock.getOrThrow()

        // Alice sees only her notes, never Bob's
        val aliceRestoredNotes = secretNoteRepository.getNotes(aliceUid, aliceRestoredDek)
        assertEquals(1, aliceRestoredNotes.size)
        assertEquals("Alice Confidential", aliceRestoredNotes.first().title)
        assertNull(secretNoteRepository.getNoteById("bob-note-1", aliceUid, aliceRestoredDek))
    }
}
