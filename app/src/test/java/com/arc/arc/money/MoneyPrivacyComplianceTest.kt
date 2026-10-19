package com.arc.arc.money

import com.arc.arc.core.datastore.AppPreferences
import com.arc.arc.features.money.automation.MoneyAutomationRawEvent
import com.arc.arc.features.money.automation.MoneyTransactionParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.Date

class MoneyPrivacyComplianceTest {

    @Test
    fun manifest_containsZeroRestrictedSmsPermissions() {
        // Path to AndroidManifest.xml
        val manifestFile = File("src/main/AndroidManifest.xml")
        val altFile = File("app/src/main/AndroidManifest.xml")
        val target = if (manifestFile.exists()) manifestFile else altFile

        assertTrue("AndroidManifest.xml should exist", target.exists())
        val content = target.readText()

        assertFalse("Manifest MUST NOT declare RECEIVE_SMS", content.contains("android.permission.RECEIVE_SMS"))
        assertFalse("Manifest MUST NOT declare READ_SMS", content.contains("android.permission.READ_SMS"))
        assertFalse("Manifest MUST NOT declare SEND_SMS", content.contains("android.permission.SEND_SMS"))
    }

    @Test
    fun sanitizedLogging_neverExposesRawBodyOrOtp() {
        val secretBody = "Your OTP is 998811 for INR 5,000 to John Doe. Secret bank code 123456."
        val event = MoneyAutomationRawEvent(
            sender = "BANK",
            body = secretBody,
            timestamp = Date(),
        )

        val eventString = event.toString()
        assertFalse("Event toString must not expose raw text", eventString.contains(secretBody))
        assertFalse("Event toString must not expose OTP", eventString.contains("998811"))
        assertFalse("Event toString must not expose bank code", eventString.contains("123456"))
        assertTrue("Event toString must contain sender", eventString.contains("BANK"))

        val parser = MoneyTransactionParser()
        val parsed = parser.parse(
            MoneyAutomationRawEvent(
                sender = "HDFCBK",
                body = "INR 250.00 debited from A/c **9999 towards Swiggy. Ref 882211.",
            )
        )

        val parsedString = parsed.toString()
        assertFalse("Parsed toString must not expose full account details", parsedString.contains("9999"))
        assertTrue("Parsed toString must redact reference number", parsedString.contains("[REDACTED]"))
    }

    @Test
    fun accountNumberMasking_masksLeadingDigitsStrictly() {
        val parser = MoneyTransactionParser()
        val parsed = parser.parse(
            MoneyAutomationRawEvent(
                sender = "SBINB",
                body = "Account ending 4321 debited with INR 100.00 for Metro Rail. Ref 1122.",
            )
        )

        assertEquals("XXXX4321", parsed.accountMask)
    }

    @Test
    fun preferences_defaultSafelyToFalseForOptIn() {
        val prefs = AppPreferences()
        assertFalse("Money detection must default to disabled for explicit opt-in", prefs.isMoneyDetectionEnabled)
        assertFalse("Auto-save must default to disabled", prefs.isMoneyAutoSaveEnabled)
        assertFalse("Privacy notice seen must default to false", prefs.hasSeenMoneyPrivacyNotice)
    }
}
