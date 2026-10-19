package com.arc.arc.features.money.automation

import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.roundToLong

/**
 * Conservative local parser for incoming transaction events.
 *
 * DESIGN PRINCIPLES:
 * - Favors false negatives over false positives.
 * - Only [MoneyTransactionClassification.CONFIRMED_DEBIT] with high confidence
 *   is accepted as a candidate transaction.
 * - Explicitly rejects OTPs, credits, balance alerts, failed transactions,
 *   promotional messages, and foreign-currency transactions.
 * - Never persists raw SMS text; masks sensitive account/card identifiers.
 * - Deterministic SHA-256 fingerprinting for duplicate detection.
 * - All monetary values stored and computed in exact integer paise (Long).
 */
class MoneyTransactionParser {

    companion object {
        // --- Rejection Regexes ---

        private val OTP_PATTERN = Regex(
            """\b(?:otp|one time password|verification code|authentication code|login code|secret code|valid for \d+ (?:min|mins|minute|minutes))\b|""" +
                    """\b(?:do not share|don't share|never share|never disclose)\b|""" +
                    """\b(?:is|as) your (?:verification|secret|login|one time|otp)\b|""" +
                    """\buse code \d+\b""",
            RegexOption.IGNORE_CASE
        )

        private val FAILED_PATTERN = Regex(
            """\b(?:failed|declined|unsuccessful|could not be completed|transaction failed|payment failed|unsuccessful payment)\b|""" +
                    """\b(?:reversed|reversal of|has been reversed|will be refunded)\b""",
            RegexOption.IGNORE_CASE
        )

        private val CREDIT_PATTERN = Regex(
            """\b(?:credited to|credited with|credited for|credit to|credit of|received in|received from|""" +
                    """refund received|refund credited|cashback credited|cashback of|salary credited|deposited to|deposit of)\b|""" +
                    """\bcredited\b""",
            RegexOption.IGNORE_CASE
        )

        private val PROMOTIONAL_PATTERN = Regex(
            """\b(?:pre-approved|apply now|special offer|flat \d+% off|discount code|claim your|""" +
                    """loan offer|credit card offer|rewards? points? earned|eligible for loan|instant loan|click to apply)\b""",
            RegexOption.IGNORE_CASE
        )

        private val BALANCE_ONLY_PATTERN = Regex(
            """\b(?:available balance is|account balance is|avl bal|clear balance|mini statement|low balance|balance enquiry)\b""",
            RegexOption.IGNORE_CASE
        )

        private val FOREIGN_CURRENCY_PATTERN = Regex(
            """\b(?:USD|EUR|GBP|AUD|CAD)\b|[\$€£]""",
            RegexOption.IGNORE_CASE
        )

        // --- Confirmed Debit Regexes ---

        private val DEBIT_KEYWORD_PATTERN = Regex(
            """\b(?:debited|spent|paid|withdrawn|purchase of|purchase at|atm (?:cash )?withdrawal|cash withdrawal of|upi payment)\b""",
            RegexOption.IGNORE_CASE
        )

        private val BALANCE_AMOUNT_PATTERN = Regex(
            """(?:avl\.?\s*bal(?:ance)?|available\s*bal(?:ance)?|total\s*bal(?:ance)?|bal(?:ance)?(?:\s*is)?:?)\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)""",
            RegexOption.IGNORE_CASE
        )

        // Primary pattern: debit verb followed closely by amount
        private val DEBIT_FOLLOWED_BY_AMOUNT = Regex(
            """(?:debited\s*(?:by|with|for)?|spent|paid|withdrawn|purchase of|payment of|txn of|cash withdrawal of|upi payment of)\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)""",
            RegexOption.IGNORE_CASE
        )

        // Secondary pattern: amount followed by debit verb
        private val AMOUNT_FOLLOWED_BY_DEBIT = Regex(
            """(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:is\s*)?(?:debited|spent|paid|withdrawn)""",
            RegexOption.IGNORE_CASE
        )

        // General INR amount pattern
        private val INR_AMOUNT_PATTERN = Regex(
            """(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)""",
            RegexOption.IGNORE_CASE
        )

        // Metadata Extraction Regexes
        private val ACCOUNT_MASK_PATTERN = Regex(
            """(?:A/c|Acct|Account|Card)(?:\s*(?:no\.?|ending|number)?)?\s*[*XxNn-]*(\d{3,4})\b""",
            RegexOption.IGNORE_CASE
        )

        private val REFERENCE_ID_PATTERN = Regex(
            """\b(?:UPI(?:\s*Ref(?:\s*no\.?)?)?|Ref(?:\s*no\.?|\s*num|\s*number)?|Txn(?:\s*id|\s*no\.?)?|UTR|RRN)[#:\s]+([A-Za-z0-9]+)\b""",
            RegexOption.IGNORE_CASE
        )

        private val MERCHANT_PATTERN = Regex(
            """\b(?:to|at|towards|paid to|vpa|info:)\s+([A-Za-z0-9@\.\-_ ]{2,35})""",
            RegexOption.IGNORE_CASE
        )

        private val DATE_PATTERN = Regex(
            """\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b|\b(\d{1,2}-[A-Za-z]{3}-\d{2,4})\b""",
            RegexOption.IGNORE_CASE
        )
    }

    /**
     * Parses a raw event into a structured [ParsedMoneyTransaction].
     * Guarantees never throwing or crashing.
     */
    fun parse(rawEvent: MoneyAutomationRawEvent): ParsedMoneyTransaction {
        try {
            val text = rawEvent.body.trim()
            val sender = rawEvent.sender.trim()

            if (text.isEmpty()) {
                return unknownResult(rawEvent, "Empty text")
            }

            // 1. STRICT RULE: Reject OTP messages unconditionally
            if (OTP_PATTERN.containsMatchIn(text)) {
                return buildResult(
                    rawEvent = rawEvent,
                    classification = MoneyTransactionClassification.OTP,
                    confidence = MoneyTransactionConfidence.HIGH,
                    amountPaise = 0L,
                )
            }

            // 2. Reject Failed / Declined / Reversed transactions
            if (FAILED_PATTERN.containsMatchIn(text)) {
                return buildResult(
                    rawEvent = rawEvent,
                    classification = MoneyTransactionClassification.FAILED,
                    confidence = MoneyTransactionConfidence.HIGH,
                    amountPaise = 0L,
                )
            }

            // 3. Reject Credit / Incoming money
            if (CREDIT_PATTERN.containsMatchIn(text)) {
                return buildResult(
                    rawEvent = rawEvent,
                    classification = MoneyTransactionClassification.CREDIT,
                    confidence = MoneyTransactionConfidence.HIGH,
                    amountPaise = 0L,
                )
            }

            // 4. Reject Promotional messages
            if (PROMOTIONAL_PATTERN.containsMatchIn(text)) {
                return buildResult(
                    rawEvent = rawEvent,
                    classification = MoneyTransactionClassification.PROMOTIONAL,
                    confidence = MoneyTransactionConfidence.HIGH,
                    amountPaise = 0L,
                )
            }

            // 5. Reject Balance alerts (only balance keywords, no debit keywords)
            val hasDebitKeyword = DEBIT_KEYWORD_PATTERN.containsMatchIn(text)
            if (!hasDebitKeyword && BALANCE_ONLY_PATTERN.containsMatchIn(text)) {
                return buildResult(
                    rawEvent = rawEvent,
                    classification = MoneyTransactionClassification.BALANCE_ALERT,
                    confidence = MoneyTransactionConfidence.HIGH,
                    amountPaise = 0L,
                )
            }

            // 6. Reject unsupported foreign currencies
            if (FOREIGN_CURRENCY_PATTERN.containsMatchIn(text) &&
                !text.contains("INR", ignoreCase = true) &&
                !text.contains("₹") &&
                !text.contains("RS", ignoreCase = true)
            ) {
                return unknownResult(rawEvent, "Unsupported foreign currency")
            }

            // 7. Confirmed Debit Evaluation
            if (!hasDebitKeyword) {
                return unknownResult(rawEvent, "No debit keyword found")
            }

            // Extract transaction amount
            val amountPaise = extractAmountPaise(text)
            if (amountPaise == null || amountPaise <= 0L) {
                return unknownResult(rawEvent, "Unable to extract valid amount")
            }

            // Extract metadata
            val accountMask = extractAccountMask(text)
            val referenceId = extractReferenceId(text)
            val merchant = extractMerchant(text)
            val transactionDateTime = extractDateTime(text) ?: rawEvent.timestamp

            // Deterministic fingerprint calculation
            val fingerprint = generateFingerprint(
                amountPaise = amountPaise,
                currency = "INR",
                transactionDateTime = transactionDateTime,
                sender = sender,
                referenceId = referenceId,
                merchant = merchant,
                accountMask = accountMask,
            )

            return ParsedMoneyTransaction(
                amountPaise = amountPaise,
                currency = "INR",
                transactionDateTime = transactionDateTime,
                merchantOrDescription = merchant,
                referenceId = referenceId,
                sourceSender = sender,
                classification = MoneyTransactionClassification.CONFIRMED_DEBIT,
                confidence = MoneyTransactionConfidence.HIGH,
                fingerprint = fingerprint,
                accountMask = accountMask,
            )
        } catch (_: Exception) {
            return unknownResult(rawEvent, "Parsing exception")
        }
    }

    /**
     * Infers category from merchant name or text context.
     */
    fun inferCategory(merchant: String?, text: String = ""): String {
        val combined = "${merchant ?: ""} $text".lowercase(Locale.US)
        return when {
            combined.contains("swiggy") || combined.contains("zomato") || combined.contains("mcdonald") ||
                    combined.contains("starbucks") || combined.contains("kfc") || combined.contains("food") ||
                    combined.contains("restaurant") || combined.contains("cafe") || combined.contains("dining") -> "Food"

            combined.contains("uber") || combined.contains("ola") || combined.contains("irctc") ||
                    combined.contains("metro") || combined.contains("rapido") || combined.contains("travel") ||
                    combined.contains("flight") || combined.contains("makemytrip") || combined.contains("redbus") -> "Travel"

            combined.contains("amazon") || combined.contains("flipkart") || combined.contains("myntra") ||
                    combined.contains("ajio") || combined.contains("nykaa") || combined.contains("shopping") ||
                    combined.contains("store") || combined.contains("mart") -> "Shopping"

            combined.contains("fuel") || combined.contains("petrol") || combined.contains("diesel") ||
                    combined.contains("iocl") || combined.contains("bpcl") || combined.contains("hpcl") ||
                    combined.contains("shell") -> "Fuel"

            combined.contains("electricity") || combined.contains("bescom") || combined.contains("bill") ||
                    combined.contains("recharge") || combined.contains("airtel") || combined.contains("jio") ||
                    combined.contains("broadband") || combined.contains("water") -> "Bills"

            combined.contains("netflix") || combined.contains("spotify") || combined.contains("hotstar") ||
                    combined.contains("cinema") || combined.contains("pvr") || combined.contains("inox") ||
                    combined.contains("prime") || combined.contains("entertainment") -> "Entertainment"

            combined.contains("apollo") || combined.contains("pharmacy") || combined.contains("1mg") ||
                    combined.contains("hospital") || combined.contains("clinic") || combined.contains("med") -> "Health"

            combined.contains("udemy") || combined.contains("coursera") || combined.contains("school") ||
                    combined.contains("college") || combined.contains("fees") || combined.contains("education") -> "Education"

            else -> "Other"
        }
    }

    private fun extractAmountPaise(text: String): Long? {
        var balanceStr: String? = null
        val balMatch = BALANCE_AMOUNT_PATTERN.find(text)
        if (balMatch != null) {
            balanceStr = balMatch.groupValues.getOrNull(1)?.replace(",", "")
        }

        // Primary: debit followed by amount
        val directMatch = DEBIT_FOLLOWED_BY_AMOUNT.find(text)
        if (directMatch != null) {
            val rawStr = directMatch.groupValues.getOrNull(1)?.replace(",", "")
            if (rawStr != null && rawStr != balanceStr) {
                parseDecimalToPaise(rawStr)?.let { return it }
            }
        }

        // Secondary: amount followed by debit
        val reverseMatch = AMOUNT_FOLLOWED_BY_DEBIT.find(text)
        if (reverseMatch != null) {
            val rawStr = reverseMatch.groupValues.getOrNull(1)?.replace(",", "")
            if (rawStr != null && rawStr != balanceStr) {
                parseDecimalToPaise(rawStr)?.let { return it }
            }
        }

        // Fallback: general INR amount not matching balance
        val allMatches = INR_AMOUNT_PATTERN.findAll(text)
        for (match in allMatches) {
            val rawStr = match.groupValues.getOrNull(1)?.replace(",", "")
            if (rawStr != null && rawStr != balanceStr) {
                parseDecimalToPaise(rawStr)?.let { return it }
            }
        }

        return null
    }

    private fun parseDecimalToPaise(raw: String): Long? {
        val clean = raw.trim()
        val d = clean.toDoubleOrNull() ?: return null
        if (d <= 0.0) return null
        return (d * 100.0).roundToLong()
    }

    private fun extractAccountMask(text: String): String? {
        val match = ACCOUNT_MASK_PATTERN.find(text) ?: return null
        val digits = match.groupValues.getOrNull(1) ?: return null
        return if (digits.isNotBlank()) "XXXX$digits" else null
    }

    private fun extractReferenceId(text: String): String? {
        val match = REFERENCE_ID_PATTERN.find(text) ?: return null
        val id = match.groupValues.getOrNull(1)?.trim()
        return if (!id.isNullOrBlank()) id else null
    }

    private fun extractMerchant(text: String): String? {
        val match = MERCHANT_PATTERN.find(text) ?: return null
        var candidate = match.groupValues.getOrNull(1)?.trim() ?: return null

        val noiseWords = listOf(
            " on ", " via ", " using ", " dated ", " ref ", " avl ", " bal ",
            " upi ", " a/c ", " card ", " from "
        )
        for (noise in noiseWords) {
            val idx = candidate.indexOf(noise, ignoreCase = true)
            if (idx > 0) {
                candidate = candidate.substring(0, idx).trim()
            }
        }

        candidate = candidate.replace(Regex("""[\.,;:\-]+$"""), "").trim()

        // Redact 5+ digit account numbers embedded in merchant string
        candidate = candidate.replace(Regex("""\b\d{5,19}\b""")) { m ->
            val v = m.value
            "XXXX${v.takeLast(4)}"
        }

        return candidate.ifBlank { null }
    }

    private fun extractDateTime(text: String): Date? {
        val match = DATE_PATTERN.find(text) ?: return null
        val dateStr = match.value.ifBlank { return null }

        try {
            val parts = dateStr.split(Regex("[-/]"))
            if (parts.size == 3) {
                val day = parts[0].toIntOrNull()
                val month = parseMonth(parts[1])
                var year = parts[2].toIntOrNull()

                if (day != null && month != null && year != null) {
                    if (year < 100) year += 2000
                    val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
                        clear()
                        set(year, month - 1, day, 12, 0, 0)
                    }
                    return cal.time
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun parseMonth(input: String): Int? {
        input.toIntOrNull()?.let {
            if (it in 1..12) return it
        }
        val months = mapOf(
            "jan" to 1, "feb" to 2, "mar" to 3, "apr" to 4, "may" to 5, "jun" to 6,
            "jul" to 7, "aug" to 8, "sep" to 9, "oct" to 10, "nov" to 11, "dec" to 12
        )
        return months[input.lowercase(Locale.US)]
    }

    private fun generateFingerprint(
        amountPaise: Long,
        currency: String,
        transactionDateTime: Date,
        sender: String,
        referenceId: String? = null,
        merchant: String? = null,
        accountMask: String? = null,
    ): String {
        val amtStr = String.format(Locale.US, "%.2f", amountPaise / 100.0)
        val refStr = referenceId?.uppercase()?.trim() ?: ""
        val senderStr = sender.uppercase().trim()
        val merchStr = merchant?.uppercase()?.trim() ?: ""
        val acctStr = accountMask ?: ""

        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val dateStr = sdf.format(transactionDateTime)

        val signature = "$amtStr|$currency|$refStr|$senderStr|$merchStr|$acctStr|$dateStr"
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(signature.toByteArray(Charsets.UTF_8))
        return hash.joinToString("") { "%02x".format(it) }
    }

    private fun buildResult(
        rawEvent: MoneyAutomationRawEvent,
        classification: MoneyTransactionClassification,
        confidence: MoneyTransactionConfidence,
        amountPaise: Long,
    ): ParsedMoneyTransaction {
        val date = rawEvent.timestamp
        val sender = rawEvent.sender
        val fingerprint = generateFingerprint(
            amountPaise = amountPaise,
            currency = "INR",
            transactionDateTime = date,
            sender = sender,
        )

        return ParsedMoneyTransaction(
            amountPaise = amountPaise,
            currency = "INR",
            transactionDateTime = date,
            sourceSender = sender,
            classification = classification,
            confidence = confidence,
            fingerprint = fingerprint,
        )
    }

    private fun unknownResult(rawEvent: MoneyAutomationRawEvent, reason: String): ParsedMoneyTransaction {
        return buildResult(
            rawEvent = rawEvent,
            classification = MoneyTransactionClassification.UNKNOWN,
            confidence = MoneyTransactionConfidence.LOW,
            amountPaise = 0L,
        )
    }
}
