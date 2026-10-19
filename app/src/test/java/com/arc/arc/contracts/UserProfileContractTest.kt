package com.arc.arc.contracts

import com.arc.arc.core.model.DateTimeUtils
import com.arc.arc.core.model.UserProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Data contract tests verifying UserProfile compatibility with Flutter Auth and Firestore
 * `users/{uid}` schema.
 */
class UserProfileContractTest {

    @Test
    fun testUserProfileSerializationRoundTrip() {
        val now = Date(1773000000000L)
        val profile = UserProfile(
            id = "user-uid-admin",
            username = "Shreyas",
            displayName = "Shreyas Shigwan",
            email = "shigwanshreyas4@gmail.com",
            photoURL = "https://example.com/photo.png",
            authProvider = "google",
            role = "admin",
            createdAt = now,
            updatedAt = now,
            lastLoginAt = now,
        )

        val map = profile.toMap()
        assertEquals("user-uid-admin", map["id"])
        assertEquals("user-uid-admin", map["uid"])
        assertEquals("Shreyas", map["username"])
        assertEquals("Shreyas Shigwan", map["displayName"])
        assertEquals("shigwanshreyas4@gmail.com", map["email"])
        assertEquals("google", map["authProvider"])
        assertEquals("admin", map["role"])
        assertEquals(DateTimeUtils.formatIso(now), map["createdAt"])
        assertEquals(DateTimeUtils.formatIso(now), map["updatedAt"])
        assertEquals(DateTimeUtils.formatIso(now), map["lastLoginAt"])

        val restored = UserProfile.fromMap(map)
        assertEquals(profile.id, restored.id)
        assertEquals(profile.username, restored.username)
        assertEquals(profile.displayName, restored.displayName)
        assertEquals(profile.email, restored.email)
        assertEquals(profile.authProvider, restored.authProvider)
        assertEquals(profile.role, restored.role)
        assertTrue(restored.isAdmin)
    }

    @Test
    fun testKnownUsernamesAndStandardEmailGeneration() {
        assertTrue(UserProfile.isKnownUsername("Shreyas"))
        assertTrue(UserProfile.isKnownUsername("shreyas"))
        assertTrue(UserProfile.isKnownUsername("admin"))
        assertTrue(UserProfile.isKnownUsername("Aman"))
        assertFalse(UserProfile.isKnownUsername("unknown_random_user"))

        assertEquals("shigwanshreyas4@gmail.com", UserProfile.emailForUsername("Shreyas"))
        assertEquals("aman@arc.app", UserProfile.emailForUsername("Aman"))
        assertEquals("rohit@arc.app", UserProfile.emailForUsername("rohit"))
    }

    @Test
    fun testSparseProfileFallback() {
        val sparse = mapOf<String, Any?>(
            "uid" to "sparse-uid-123",
            "username" to "Aman",
        )

        val profile = UserProfile.fromMap(sparse)
        assertEquals("sparse-uid-123", profile.id)
        assertEquals("Aman", profile.username)
        assertEquals("Aman", profile.displayName)
        assertEquals("password", profile.authProvider)
        assertEquals("user", profile.role)
        assertFalse(profile.isAdmin)
        assertNull(profile.email)
    }
}
