import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/models/money_transaction_classification.dart';
import 'package:arc/features/money_tracker/models/parsed_money_transaction.dart';

/// Conservative local parser for incoming transaction events.
///
/// DESIGN PRINCIPLES:
/// - Favors false negatives over false positives.
/// - Only [MoneyTransactionClassification.confirmedDebit] with high confidence
///   is accepted as a candidate transaction.
/// - Explicitly rejects OTPs, credits, balance alerts, failed transactions,
///   promotional messages, and foreign-currency transactions.
/// - Never persists raw SMS text; masks sensitive account/card identifiers.
/// - Deterministic SHA-256 fingerprinting for duplicate detection.
class MoneyTransactionParser {
  // --- Rejection Regexes ---

  static final RegExp _otpPattern = RegExp(
    r'\b(?:otp|one time password|verification code|authentication code|login code|secret code|valid for \d+ (?:min|mins|minute|minutes))\b|'
    r'\b(?:do not share|don\x27t share|never share|never disclose)\b|'
    r'\b(?:is|as) your (?:verification|secret|login|one time|otp)\b|'
    r'\buse code \d+\b',
    caseSensitive: false,
  );

  static final RegExp _failedPattern = RegExp(
    r'\b(?:failed|declined|unsuccessful|could not be completed|transaction failed|payment failed|unsuccessful payment)\b|'
    r'\b(?:reversed|reversal of|has been reversed|will be refunded)\b',
    caseSensitive: false,
  );

  static final RegExp _creditPattern = RegExp(
    r'\b(?:credited to|credited with|credited for|credit to|credit of|received in|received from|'
    r'refund received|refund credited|cashback credited|cashback of|salary credited|deposited to|deposit of)\b|'
    r'\bcredited\b',
    caseSensitive: false,
  );

  static final RegExp _promotionalPattern = RegExp(
    r'\b(?:pre-approved|apply now|special offer|flat \d+% off|discount code|claim your|'
    r'loan offer|credit card offer|rewards? points? earned|eligible for loan|instant loan|click to apply)\b',
    caseSensitive: false,
  );

  static final RegExp _balanceOnlyPattern = RegExp(
    r'\b(?:available balance is|account balance is|avl bal|clear balance|mini statement|low balance|balance enquiry)\b',
    caseSensitive: false,
  );

  static final RegExp _foreignCurrencyPattern = RegExp(
    r'\b(?:USD|EUR|GBP|AUD|CAD)\b|[\$€£]',
    caseSensitive: false,
  );

  // --- Confirmed Debit Regexes ---

  static final RegExp _debitKeywordPattern = RegExp(
    r'\b(?:debited|spent|paid|withdrawn|purchase of|purchase at|atm (?:cash )?withdrawal|cash withdrawal of|upi payment)\b',
    caseSensitive: false,
  );

  static final RegExp _balanceAmountPattern = RegExp(
    r'(?:avl\.?\s*bal(?:ance)?|available\s*bal(?:ance)?|total\s*bal(?:ance)?|bal(?:ance)?(?:\s*is)?:?)\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Primary pattern: debit verb followed closely by amount
  static final RegExp _debitFollowedByAmount = RegExp(
    r'(?:debited\s*(?:by|with|for)?|spent|paid|withdrawn|purchase of|payment of|txn of|cash withdrawal of|upi payment of)\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Secondary pattern: amount followed by debit verb
  static final RegExp _amountFollowedByDebit = RegExp(
    r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:is\s*)?(?:debited|spent|paid|withdrawn)',
    caseSensitive: false,
  );

  // General INR amount pattern
  static final RegExp _inrAmountPattern = RegExp(
    r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Metadata Extraction Regexes
  static final RegExp _accountMaskPattern = RegExp(
    r'(?:A/c|Acct|Account|Card)(?:\s*(?:no\.?|ending|number)?)?\s*[*XxNn-]*(\d{3,4})\b',
    caseSensitive: false,
  );

  static final RegExp _referenceIdPattern = RegExp(
    r'\b(?:UPI(?:\s*Ref(?:\s*no\.?)?)?|Ref(?:\s*no\.?|\s*num|\s*number)?|Txn(?:\s*id|\s*no\.?)?|UTR|RRN)[#:\s]+([A-Za-z0-9]+)\b',
    caseSensitive: false,
  );

  static final RegExp _merchantPattern = RegExp(
    r'\b(?:to|at|towards|paid to|vpa|info:)\s+([A-Za-z0-9@\.\-_ ]{2,35})',
    caseSensitive: false,
  );

  static final RegExp _datePattern = RegExp(
    r'\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b|\b(\d{1,2}-[A-Za-z]{3}-\d{2,4})\b',
    caseSensitive: false,
  );

  /// Parses a raw event into a structured [ParsedMoneyTransaction].
  ///
  /// Guarantees that parsing never throws or crashes the pipeline.
  ParsedMoneyTransaction parse(MoneyAutomationRawEvent rawEvent) {
    try {
      final text = rawEvent.body.trim();
      final sender = rawEvent.sender.trim();

      if (text.isEmpty) {
        return _unknownResult(rawEvent, reason: 'Empty text');
      }

      // 1. STRICT RULE: Reject OTP messages unconditionally
      if (_otpPattern.hasMatch(text)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.otp,
          confidence: MoneyTransactionConfidence.high,
          amount: 0.0,
        );
      }

      // 2. Reject Failed / Declined / Reversed transactions
      if (_failedPattern.hasMatch(text)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.failed,
          confidence: MoneyTransactionConfidence.high,
          amount: 0.0,
        );
      }

      // 3. Reject Credit / Incoming money
      if (_creditPattern.hasMatch(text)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.credit,
          confidence: MoneyTransactionConfidence.high,
          amount: 0.0,
        );
      }

      // 4. Reject Promotional messages
      if (_promotionalPattern.hasMatch(text)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.promotional,
          confidence: MoneyTransactionConfidence.high,
          amount: 0.0,
        );
      }

      // 5. Reject Balance alerts (only balance keywords, no debit keywords)
      final hasDebitKeyword = _debitKeywordPattern.hasMatch(text);
      if (!hasDebitKeyword && _balanceOnlyPattern.hasMatch(text)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.balanceAlert,
          confidence: MoneyTransactionConfidence.high,
          amount: 0.0,
        );
      }

      // 6. Reject unsupported foreign currencies
      if (_foreignCurrencyPattern.hasMatch(text) &&
          !text.toUpperCase().contains('INR') &&
          !text.contains('₹') &&
          !text.toUpperCase().contains('RS')) {
        return _unknownResult(rawEvent, reason: 'Unsupported foreign currency');
      }

      // 7. Confirmed Debit Evaluation
      if (!hasDebitKeyword) {
        return _unknownResult(rawEvent, reason: 'No debit keyword found');
      }

      // Extract transaction amount
      final amount = _extractAmount(text);
      if (amount == null || amount <= 0.0) {
        return _unknownResult(rawEvent, reason: 'Unable to extract valid amount');
      }

      // Extract metadata
      final accountMask = _extractAccountMask(text);
      final referenceId = _extractReferenceId(text);
      final merchant = _extractMerchant(text);
      final transactionDateTime = _extractDateTime(text) ?? rawEvent.timestamp;

      // Deterministic fingerprint calculation
      final fingerprint = _generateFingerprint(
        amount: amount,
        currency: 'INR',
        transactionDateTime: transactionDateTime,
        sender: sender,
        referenceId: referenceId,
        merchant: merchant,
        accountMask: accountMask,
      );

      return ParsedMoneyTransaction(
        amount: amount,
        currency: 'INR',
        transactionDateTime: transactionDateTime,
        merchantOrDescription: merchant,
        referenceId: referenceId,
        sourceSender: sender,
        classification: MoneyTransactionClassification.confirmedDebit,
        confidence: MoneyTransactionConfidence.high,
        fingerprint: fingerprint,
        accountMask: accountMask,
      );
    } catch (e) {
      debugPrint('[MoneyTransactionParser] Safe failure handling: malformed event ignored ($e)');
      return _unknownResult(rawEvent, reason: 'Parsing exception: $e');
    }
  }

  /// Extracts the debit amount, carefully distinguishing from available balance.
  double? _extractAmount(String text) {
    // Collect the balance amount (if any) to avoid false extraction
    String? balanceStr;
    final balMatch = _balanceAmountPattern.firstMatch(text);
    if (balMatch != null) {
      balanceStr = balMatch.group(1)?.replaceAll(',', '');
    }

    // Try primary pattern (debit verb followed by amount)
    final directMatch = _debitFollowedByAmount.firstMatch(text);
    if (directMatch != null) {
      final rawStr = directMatch.group(1)?.replaceAll(',', '');
      if (rawStr != null && rawStr != balanceStr) {
        final val = double.tryParse(rawStr);
        if (val != null && val > 0) return val;
      }
    }

    // Try secondary pattern (amount followed by debit verb)
    final reverseMatch = _amountFollowedByDebit.firstMatch(text);
    if (reverseMatch != null) {
      final rawStr = reverseMatch.group(1)?.replaceAll(',', '');
      if (rawStr != null && rawStr != balanceStr) {
        final val = double.tryParse(rawStr);
        if (val != null && val > 0) return val;
      }
    }

    // Fallback: look for general INR amount that is not the balance amount
    final allInrMatches = _inrAmountPattern.allMatches(text);
    for (final match in allInrMatches) {
      final rawStr = match.group(1)?.replaceAll(',', '');
      if (rawStr != null && rawStr != balanceStr) {
        final val = double.tryParse(rawStr);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  /// Extracts and masks the financial account/card identifier (e.g. "XXXX1234").
  String? _extractAccountMask(String text) {
    final match = _accountMaskPattern.firstMatch(text);
    if (match != null) {
      final digits = match.group(1);
      if (digits != null && digits.isNotEmpty) {
        return 'XXXX$digits';
      }
    }
    return null;
  }

  /// Extracts transaction reference identifier.
  String? _extractReferenceId(String text) {
    final match = _referenceIdPattern.firstMatch(text);
    if (match != null) {
      final id = match.group(1)?.trim();
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  /// Extracts clean merchant/payee and masks any embedded card/account numbers.
  String? _extractMerchant(String text) {
    final match = _merchantPattern.firstMatch(text);
    if (match == null) return null;

    var candidate = match.group(1)?.trim();
    if (candidate == null || candidate.isEmpty) return null;

    // Remove noise words at the end
    final noiseWords = [
      ' on ', ' via ', ' using ', ' dated ', ' ref ', ' avl ', ' bal ',
      ' upi ', ' a/c ', ' card ', ' from '
    ];
    for (final noise in noiseWords) {
      final idx = candidate!.toLowerCase().indexOf(noise);
      if (idx > 0) {
        candidate = candidate.substring(0, idx).trim();
      }
    }

    // Clean trailing punctuation
    candidate = candidate?.replaceAll(RegExp(r'[\.,;:\-]+$'), '').trim();

    // Redact sensitive numbers inside merchant string (e.g. 5+ digit accounts)
    if (candidate != null) {
      candidate = candidate.replaceAllMapped(RegExp(r'\b\d{5,19}\b'), (m) {
        final val = m.group(0)!;
        return 'XXXX${val.substring(val.length - 4)}';
      });
    }

    return (candidate != null && candidate.isNotEmpty) ? candidate : null;
  }

  /// Extracts explicit transaction timestamp if available in the text.
  DateTime? _extractDateTime(String text) {
    final match = _datePattern.firstMatch(text);
    if (match == null) return null;

    final dateStr = match.group(0);
    if (dateStr == null) return null;

    try {
      // Format: dd-MM-yy or dd-MM-yyyy or dd/MM/yyyy
      final parts = dateStr.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = _parseMonth(parts[1]);
        var year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
          return DateTime(year, month, day);
        }
      }
    } catch (_) {
      // Fallback to rawEvent.timestamp
    }
    return null;
  }

  int? _parseMonth(String input) {
    final numeric = int.tryParse(input);
    if (numeric != null && numeric >= 1 && numeric <= 12) return numeric;

    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    return months[input.toLowerCase()];
  }

  /// Generates a deterministic SHA-256 fingerprint for deduplication.
  String _generateFingerprint({
    required double amount,
    required String currency,
    required DateTime transactionDateTime,
    required String sender,
    String? referenceId,
    String? merchant,
    String? accountMask,
  }) {
    final amtStr = amount.toStringAsFixed(2);
    final refStr = referenceId?.toUpperCase().trim() ?? '';
    final senderStr = sender.toUpperCase().trim();
    final merchStr = merchant?.toUpperCase().trim() ?? '';
    final acctStr = accountMask ?? '';
    final dateStr =
        '${transactionDateTime.year}-${transactionDateTime.month.toString().padLeft(2, '0')}-${transactionDateTime.day.toString().padLeft(2, '0')}';

    final signature = '$amtStr|$currency|$refStr|$senderStr|$merchStr|$acctStr|$dateStr';
    final bytes = utf8.encode(signature);
    return sha256.convert(bytes).toString();
  }

  ParsedMoneyTransaction _buildResult({
    required MoneyAutomationRawEvent rawEvent,
    required MoneyTransactionClassification classification,
    required MoneyTransactionConfidence confidence,
    required double amount,
  }) {
    final date = rawEvent.timestamp;
    final sender = rawEvent.sender;
    final fingerprint = _generateFingerprint(
      amount: amount,
      currency: 'INR',
      transactionDateTime: date,
      sender: sender,
    );

    return ParsedMoneyTransaction(
      amount: amount,
      currency: 'INR',
      transactionDateTime: date,
      sourceSender: sender,
      classification: classification,
      confidence: confidence,
      fingerprint: fingerprint,
    );
  }

  ParsedMoneyTransaction _unknownResult(MoneyAutomationRawEvent rawEvent, {required String reason}) {
    return _buildResult(
      rawEvent: rawEvent,
      classification: MoneyTransactionClassification.unknown,
      confidence: MoneyTransactionConfidence.low,
      amount: 0.0,
    );
  }
}
