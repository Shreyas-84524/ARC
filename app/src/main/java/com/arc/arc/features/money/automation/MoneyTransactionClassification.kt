package com.arc.arc.features.money.automation

/**
 * Classification result of an incoming transaction event.
 *
 * Automatic entry strictly accepts only [CONFIRMED_DEBIT] with high confidence.
 * All other types ([CREDIT], [OTP], [FAILED], [BALANCE_ALERT], [PROMOTIONAL], [UNKNOWN])
 * are rejected from automatic entry.
 */
enum class MoneyTransactionClassification {
    CONFIRMED_DEBIT,
    CREDIT,
    OTP,
    FAILED,
    BALANCE_ALERT,
    PROMOTIONAL,
    UNKNOWN,
}

/**
 * Confidence level of the classification.
 *
 * Only [HIGH] confidence confirmed debits proceed as accepted candidates.
 */
enum class MoneyTransactionConfidence {
    HIGH,
    MEDIUM,
    LOW,
}
