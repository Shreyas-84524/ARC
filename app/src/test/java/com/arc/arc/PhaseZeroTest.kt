package com.arc.arc

import org.junit.Assert.assertEquals
import org.junit.Test

class PhaseZeroTest {
    @Test
    fun projectIdentityIsStable() {
        assertEquals("com.arc.arc", MainActivity::class.java.packageName)
    }
}
