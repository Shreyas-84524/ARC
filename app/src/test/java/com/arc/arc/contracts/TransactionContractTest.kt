package com.arc.arc.contracts

import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.DateTimeUtils
import com.arc.arc.core.model.MonthlySummaryModel
import com.arc.arc.core.model.TransactionModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Data contract tests verifying Transaction, Budget, and MonthlySummary models
 * compatibility with Flutter Hive Type 3 and Firestore users/{uid} schemas.
 */
class TransactionContractTest {

    @Test
    fun testCompleteTransactionSerializationRoundTrip() {
        val now = Date(1773000000000L)
        val txDate = Date(1772900000000L)

        val tx = TransactionModel(
            id = "tx-uuid-555",
            ownerUid = "uid-fin-001",
            amount = 1250.75,
            type = "Expense",
            category = "Food",
            date = txDate,
            time = "12:30",
            notes = "Lunch with team",
            createdAt = now,
            source = "manual",
            automationFingerprint = null,
        )

        val map = tx.toMap()
        assertEquals("tx-uuid-555", map["id"])
        assertEquals(1250.75, map["amount"] as Double, 0.001)
        assertEquals("Expense", map["type"])
        assertEquals("Food", map["category"])
        assertEquals(DateTimeUtils.formatIso(txDate), map["date"])
        assertEquals("12:30", map["time"])
        assertEquals("Lunch with team", map["notes"])
        assertEquals(DateTimeUtils.formatIso(now), map["createdAt"])
        assertEquals("manual", map["source"])
        assertNull(map["automationFingerprint"])

        val restored = TransactionModel.fromMap(map, ownerUid = "uid-fin-001")
        assertEquals(tx.id, restored.id)
        assertEquals(tx.ownerUid, restored.ownerUid)
        assertEquals(tx.amount, restored.amount, 0.001)
        assertEquals(tx.type, restored.type)
        assertEquals(tx.category, restored.category)
        assertEquals(tx.time, restored.time)
        assertEquals(tx.notes, restored.notes)
        assertEquals(tx.source, restored.source)
        assertFalse(restored.isIncome)
        assertTrue(restored.isExpense)
        assertEquals(125075L, restored.amountPaise)
    }

    @Test
    fun testAutoDetectedSmsTransactionContract() {
        val now = Date(1773000000000L)
        val tx = TransactionModel(
            id = "tx-auto-999",
            ownerUid = "uid-fin-002",
            amount = 45000.0,
            type = "Income",
            category = "Salary",
            date = now,
            time = "09:00",
            notes = "Salary credited",
            createdAt = now,
            source = "sms_auto",
            automationFingerprint = "sms_hash_abc123xyz",
        )

        val map = tx.toMap()
        assertEquals("sms_auto", map["source"])
        assertEquals("sms_hash_abc123xyz", map["automationFingerprint"])

        val restored = TransactionModel.fromMap(map, ownerUid = "uid-fin-002")
        assertEquals("sms_auto", restored.source)
        assertEquals("sms_hash_abc123xyz", restored.automationFingerprint)
        assertTrue(restored.isIncome)
        assertFalse(restored.isExpense)
        assertEquals(4500000L, restored.amountPaise)
    }

    @Test
    fun testTransactionSparseDocumentDefaults() {
        val sparse = mapOf<String, Any?>(
            "id" to "tx-sparse",
            "amount" to 50, // int in map
        )

        val restored = TransactionModel.fromMap(sparse, ownerUid = "uid-0")
        assertEquals("tx-sparse", restored.id)
        assertEquals(50.0, restored.amount, 0.001)
        assertEquals(5000L, restored.amountPaise)
        assertEquals("Expense", restored.type)
        assertEquals("Other", restored.category)
        assertEquals("manual", restored.source)
        assertNotNull(restored.date)
        assertNotNull(restored.createdAt)
    }

    @Test
    fun testFinancialPaiseExactness() {
        // Non-negotiable rule 8: Avoid floating-point arithmetic errors
        val tx1 = TransactionModel.fromPaise(
            amountPaise = 10010L, // 100.10
            type = "Expense",
            category = "Food",
        )
        val tx2 = TransactionModel.fromPaise(
            amountPaise = 20020L, // 200.20
            type = "Expense",
            category = "Travel",
        )
        val totalPaise = tx1.amountPaise + tx2.amountPaise
        assertEquals(30030L, totalPaise)
        assertEquals(300.30, totalPaise.toDouble() / 100.0, 0.0001)
    }

    @Test
    fun testBudgetModelContractAndMapRoundTrip() {
        val now = Date(1773000000000L)
        val budget = BudgetModel(
            month = "2026-10",
            ownerUid = "uid-fin-003",
            amount = 50000.0,
            updatedAt = now,
        )

        assertEquals("2026-10", budget.month)
        assertEquals(5000000L, budget.amountPaise)

        val map = budget.toMap()
        assertEquals("2026-10", map["month"])
        assertEquals(50000.0, map["amount"])

        val restored = BudgetModel.fromMap(map, ownerUid = "uid-fin-003")
        assertEquals(budget.month, restored.month)
        assertEquals(budget.ownerUid, restored.ownerUid)
        assertEquals(budget.amount, restored.amount, 0.001)
        assertEquals(budget.amountPaise, restored.amountPaise)
    }

    @Test
    fun testMonthlySummaryModelContractAndSavingsCalculation() {
        val now = Date(1773000000000L)
        val summary = MonthlySummaryModel.fromPaise(
            month = "2026-10",
            ownerUid = "uid-fin-004",
            monthlyBudgetPaise = 5000000L, // 50,000.00
            totalIncomePaise = 7500000L,   // 75,000.00
            totalExpensesPaise = 3245000L, // 32,450.00
            updatedAt = now,
        )

        assertEquals(4255000L, summary.savingsPaise) // 75000 - 32450 = 42550
        assertEquals(42550.0, summary.savings, 0.001)
        assertEquals(50000.0, summary.monthlyBudget, 0.001)
        assertEquals(75000.0, summary.totalIncome, 0.001)
        assertEquals(32450.0, summary.totalExpenses, 0.001)

        val map = summary.toMap()
        assertEquals("2026-10", map["month"])
        assertEquals(50000.0, map["monthlyBudget"])
        assertEquals(75000.0, map["totalIncome"])
        assertEquals(32450.0, map["totalExpenses"])
        assertEquals(42550.0, map["savings"])

        val restored = MonthlySummaryModel.fromMap(map, ownerUid = "uid-fin-004")
        assertEquals(summary.month, restored.month)
        assertEquals(summary.ownerUid, restored.ownerUid)
        assertEquals(summary.monthlyBudgetPaise, restored.monthlyBudgetPaise)
        assertEquals(summary.totalIncomePaise, restored.totalIncomePaise)
        assertEquals(summary.totalExpensesPaise, restored.totalExpensesPaise)
        assertEquals(summary.savingsPaise, restored.savingsPaise)
    }
}
