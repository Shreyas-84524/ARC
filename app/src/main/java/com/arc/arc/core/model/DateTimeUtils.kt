package com.arc.arc.core.model

import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Robust ISO-8601 / RFC-3339 parsing and formatting utilities
 * compatible across all Android API levels (23+).
 */
object DateTimeUtils {
    private const val ISO_8601_MILLIS = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    private const val ISO_8601_SECONDS = "yyyy-MM-dd'T'HH:mm:ss"

    private val utcTimeZone = TimeZone.getTimeZone("UTC")

    fun nowIsoString(): String {
        return formatIso(Date())
    }

    fun formatIso(date: Date): String {
        val sdf = SimpleDateFormat(ISO_8601_MILLIS, Locale.US).apply {
            timeZone = utcTimeZone
        }
        return "${sdf.format(date)}Z"
    }

    fun parseIso(isoString: String?): Date? {
        if (isoString.isNullOrBlank()) return null
        val clean = isoString.trim()

        // Normalize trailing Z or offset
        val normalized = if (clean.endsWith("Z", ignoreCase = true)) {
            clean.substring(0, clean.length - 1)
        } else if (clean.contains("+") || (clean.lastIndexOf("-") > 10)) {
            // Trim timezone offset like +05:30 or -04:00 if present
            val plusIndex = clean.indexOf("+")
            if (plusIndex != -1) clean.substring(0, plusIndex)
            else {
                val lastMinus = clean.lastIndexOf("-")
                clean.substring(0, lastMinus)
            }
        } else {
            clean
        }

        // Try millis format first
        val formats = arrayOf(
            ISO_8601_MILLIS,
            ISO_8601_SECONDS,
            "yyyy-MM-dd"
        )

        for (pattern in formats) {
            try {
                val sdf = SimpleDateFormat(pattern, Locale.US).apply {
                    timeZone = utcTimeZone
                    isLenient = true
                }
                return sdf.parse(normalized)
            } catch (_: ParseException) {
                // Continue trying other patterns
            }
        }

        return null
    }

    fun toDateString(date: Date): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
        return sdf.format(date)
    }

    fun formatDisplayDate(date: Date): String {
        val sdf = SimpleDateFormat("MMM d, yyyy", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
        return sdf.format(date)
    }

    fun formatDisplayShort(date: Date): String {
        val sdf = SimpleDateFormat("MMM d", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
        return sdf.format(date)
    }
}
