package com.arc.arc.core.database

import com.arc.arc.core.model.BudgetModel
import com.arc.arc.core.model.TransactionModel
import java.util.Date

/**
 * Bi-directional mappers between Room persistence entities and Domain financial models.
 */
object TransactionMappers {

    fun TransactionEntity.toModel(): TransactionModel {
        return TransactionModel(
            id = id,
            ownerUid = ownerUid,
            amount = amount,
            type = type,
            category = category,
            date = Date(date),
            time = time,
            notes = notes,
            createdAt = Date(createdAt),
            source = source,
            automationFingerprint = automationFingerprint,
            amountPaise = amountPaise,
        )
    }

    fun TransactionModel.toEntity(): TransactionEntity {
        return TransactionEntity(
            id,
            ownerUid,
            amountPaise,
            amount,
            type,
            category,
            date.time,
            time,
            notes,
            createdAt.time,
            source,
            automationFingerprint,
        )
    }

    fun BudgetEntity.toModel(): BudgetModel {
        return BudgetModel(
            month = month,
            ownerUid = ownerUid,
            amount = amount,
            amountPaise = amountPaise,
            updatedAt = Date(updatedAt),
        )
    }

    fun BudgetModel.toEntity(): BudgetEntity {
        val budgetId = if (ownerUid.isNotBlank()) "${ownerUid}_$month" else month
        return BudgetEntity(
            budgetId,
            ownerUid,
            month,
            amountPaise,
            amount,
            updatedAt.time,
        )
    }
}
