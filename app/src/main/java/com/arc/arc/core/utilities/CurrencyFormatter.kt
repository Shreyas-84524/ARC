package com.arc.arc.core.utilities

import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale

/**
 * Currency formatter for Indian Rupee (INR) and financial minor units (paise).
 * All monetary displays are backed by integer paise ([Long]) to prevent floating-point inaccuracies.
 */
object CurrencyFormatter {
    const val SYMBOL = "₹"

    private val symbols = DecimalFormatSymbols(Locale.US).apply {
        decimalSeparator = '.'
        groupingSeparator = ','
    }

    private val decimalFormat = DecimalFormat("#,##0.00", symbols)
    private val wholeFormat = DecimalFormat("#,##0", symbols)

    /**
     * Formats an amount in paise to a readable INR string (e.g. 125075L -> "₹1,250.75").
     */
    fun formatPaise(paise: Long, includeDecimals: Boolean = true): String {
        val isNegative = paise < 0
        val absPaise = Math.abs(paise)
        val rupees = absPaise / 100.0
        val formatted = if (includeDecimals || absPaise % 100 != 0L) {
            decimalFormat.format(rupees)
        } else {
            wholeFormat.format(absPaise / 100)
        }
        return if (isNegative) "-$SYMBOL$formatted" else "$SYMBOL$formatted"
    }

    /**
     * Formats a double amount in INR (backward compatibility).
     */
    fun format(amount: Double, includeDecimals: Boolean = true): String {
        val paise = Math.round(amount * 100.0)
        return formatPaise(paise, includeDecimals)
    }

    /**
     * Parses a user-inputted string (e.g. "1250.75" or "1250") into exact paise.
     */
    fun parseToPaise(input: String): Long? {
        val clean = input.trim().replace(SYMBOL, "").replace(",", "")
        if (clean.isBlank()) return null
        return try {
            val parts = clean.split(".")
            val whole = parts[0].toLong()
            val fraction = if (parts.size > 1) {
                val fracStr = parts[1].padEnd(2, '0').take(2)
                fracStr.toLong()
            } else {
                0L
            }
            if (whole >= 0) {
                whole * 100L + fraction
            } else {
                whole * 100L - fraction
            }
        } catch (_: Exception) {
            null
        }
    }
}
