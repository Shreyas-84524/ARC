package com.arc.arc.money

import com.arc.arc.features.money.automation.MoneyAutomationRawEvent
import com.arc.arc.features.money.automation.MoneyDeduplicationService
import com.arc.arc.features.money.automation.MoneyTransactionClassification
import com.arc.arc.features.money.automation.MoneyTransactionConfidence
import com.arc.arc.features.money.automation.MoneyTransactionParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Date

class MoneyTransactionParserTest {

    private lateinit var parser: MoneyTransactionParser
    private lateinit var deduplicationService: MoneyDeduplicationService

    @Before
    fun setup() {
        parser = MoneyTransactionParser()
        deduplicationService = MoneyDeduplicationService()
        MoneyDeduplicationService.resetStorage()
    }

    @Test
    fun parse_hdfcBankDebit_extractsConfirmedDebitWithCorrectPaiseAndMerchant() {
        val raw = MoneyAutomationRawEvent(
            sender = "HDFCBK",
            body = "Dear Customer, INR 1,450.50 debited from A/c **1234 on 12-OCT-26 towards SWIGGY. UPI Ref 6284910284. Avl Bal INR 45,230.50",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertTrue(result.isConfirmedDebit)
        assertEquals(MoneyTransactionClassification.CONFIRMED_DEBIT, result.classification)
        assertEquals(MoneyTransactionConfidence.HIGH, result.confidence)
        assertEquals(145050L, result.amountPaise) // ₹1,450.50
        assertEquals("XXXX1234", result.accountMask)
        assertEquals("6284910284", result.referenceId)
        assertNotNull(result.merchantOrDescription)
        assertTrue(result.merchantOrDescription!!.contains("SWIGGY", ignoreCase = true))

        val category = parser.inferCategory(result.merchantOrDescription, raw.body)
        assertEquals("Food", category)
    }

    @Test
    fun parse_sbiBankDebit_extractsTravelExpense() {
        val raw = MoneyAutomationRawEvent(
            sender = "SBIINB",
            body = "Your A/c ending 9876 debited by Rs.2,500.00 on 10/10/2026 for Uber Rides. Ref no 99881122. Bal: Rs.12,000.00",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertTrue(result.isConfirmedDebit)
        assertEquals(250000L, result.amountPaise) // ₹2,500.00
        assertEquals("XXXX9876", result.accountMask)
        assertEquals("99881122", result.referenceId)

        val category = parser.inferCategory(result.merchantOrDescription, raw.body)
        assertEquals("Travel", category)
    }

    @Test
    fun parse_iciciBankDebit_extractsFuelExpense() {
        val raw = MoneyAutomationRawEvent(
            sender = "ICICIB",
            body = "Acct XX4321 debited with INR 350.00 at Shell Fuel Station on 05-10-26. Txn id 883719. Avl bal INR 10,000.00",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertTrue(result.isConfirmedDebit)
        assertEquals(35000L, result.amountPaise) // ₹350.00
        assertEquals("XXXX4321", result.accountMask)
        assertEquals("883719", result.referenceId)

        val category = parser.inferCategory(result.merchantOrDescription, raw.body)
        assertEquals("Fuel", category)
    }

    @Test
    fun parse_otpMessage_unconditionallyRejectsAsOtp() {
        val raw = MoneyAutomationRawEvent(
            sender = "VM-HDFCBK",
            body = "Your OTP for transaction of INR 500.00 at Amazon is 492019. Valid for 10 mins. Do not share with anyone.",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertFalse(result.isConfirmedDebit)
        assertEquals(MoneyTransactionClassification.OTP, result.classification)
        assertEquals(MoneyTransactionConfidence.HIGH, result.confidence)
        assertEquals(0L, result.amountPaise)
    }

    @Test
    fun parse_creditMessage_unconditionallyRejectsAsCredit() {
        val raw = MoneyAutomationRawEvent(
            sender = "AXISBK",
            body = "Salary of Rs. 85,000.00 credited to A/c **1234 on 01-10-2026. Avl bal INR 1,20,000.00",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertFalse(result.isConfirmedDebit)
        assertEquals(MoneyTransactionClassification.CREDIT, result.classification)
        assertEquals(0L, result.amountPaise)
    }

    @Test
    fun parse_failedTransaction_unconditionallyRejectsAsFailed() {
        val raw = MoneyAutomationRawEvent(
            sender = "KOTAKB",
            body = "Transaction failed! INR 1,200.00 could not be completed for PVR Cinemas. Amount reversed.",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertFalse(result.isConfirmedDebit)
        assertEquals(MoneyTransactionClassification.FAILED, result.classification)
        assertEquals(0L, result.amountPaise)
    }

    @Test
    fun parse_promotionalMessage_unconditionallyRejectsAsPromotional() {
        val raw = MoneyAutomationRawEvent(
            sender = "BAJAJF",
            body = "Pre-approved loan offer of Rs. 5,00,000 at flat 10% off. Apply now to claim your cash!",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertFalse(result.isConfirmedDebit)
        assertEquals(MoneyTransactionClassification.PROMOTIONAL, result.classification)
        assertEquals(0L, result.amountPaise)
    }

    @Test
    fun parse_balanceOnlyAlert_rejectsAsBalanceAlert() {
        val raw = MoneyAutomationRawEvent(
            sender = "PNBSMS",
            body = "Available balance for A/c 1234 is INR 25,000.00 as of 15-10-26. Mini statement available.",
            timestamp = Date(),
        )

        val result = parser.parse(raw)

        assertFalse(result.isConfirmedDebit)
        assertEquals(MoneyTransactionClassification.BALANCE_ALERT, result.classification)
        assertEquals(0L, result.amountPaise)
    }

    @Test
    fun deduplication_deterministicFingerprintAndUserIsolation() {
        val raw = MoneyAutomationRawEvent(
            sender = "HDFCBK",
            body = "INR 250.00 debited from A/c **1111 on 15-10-26 towards Starbucks. Ref 11223344",
            timestamp = Date(),
        )

        val parsed1 = parser.parse(raw)
        val parsed2 = parser.parse(raw)

        // Same event produces exact same deterministic fingerprint
        assertEquals(parsed1.fingerprint, parsed2.fingerprint)

        // User A context
        deduplicationService.initForUser("user_a")
        assertFalse(deduplicationService.isDuplicate(parsed1.fingerprint, parsed1.referenceId))

        deduplicationService.recordProcessed(parsed1.fingerprint, parsed1.referenceId)
        assertTrue(deduplicationService.isDuplicate(parsed2.fingerprint, parsed2.referenceId))

        // User B context (isolation: should NOT be blocked by User A's transactions)
        deduplicationService.initForUser("user_b")
        assertFalse(deduplicationService.isDuplicate(parsed1.fingerprint, parsed1.referenceId))
    }

    @Test
    fun toTransactionModel_convertsParsedResultIntoValidTransactionModel() {
        val raw = MoneyAutomationRawEvent(
            sender = "HDFCBK",
            body = "INR 999.00 debited from A/c **4444 on 15-10-26 towards Netflix. Ref 99887766",
            timestamp = Date(),
        )

        val parsed = parser.parse(raw)
        val txModel = parsed.toTransactionModel(
            ownerUid = "user_shreyas",
            category = "Entertainment",
        )

        assertEquals("user_shreyas", txModel.ownerUid)
        assertEquals(99900L, txModel.amountPaise)
        assertEquals("Expense", txModel.type)
        assertEquals("Entertainment", txModel.category)
        assertEquals("sms_auto", txModel.source)
        assertEquals(parsed.fingerprint, txModel.automationFingerprint)
        assertTrue(txModel.notes.contains("Netflix"))
    }
}
