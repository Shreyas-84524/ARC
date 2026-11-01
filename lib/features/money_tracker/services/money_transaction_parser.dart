import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/models/money_transaction_classification.dart';
import 'package:arc/features/money_tracker/models/parsed_money_transaction.dart';
import 'package:arc/features/money_tracker/services/money_sms_recognition_lexicon.dart';

/// Transaction direction detected during contextual disambiguation.
enum MoneyTransactionDirection { debit, credit, ambiguous, none }

/// Robust, extensible Indian financial SMS parser.
///
/// DESIGN PRINCIPLES:
/// - Favors false negatives over false positives.
/// - Deterministic, local-only, layered detection and contextual validation.
/// - Rejection rules strictly take precedence over generic debit matching.
/// - Only [MoneyTransactionClassification.confirmedDebit] with [MoneyTransactionConfidence.high]
///   is automatically recorded as an expense candidate.
/// - Sanitized diagnostics without persisting or logging raw SMS text, OTPs,
///   account numbers, reference IDs, or transaction amounts.
class MoneyTransactionParser {
  static final RegExp _lexiconDebitActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.debitActions,
      );
  static final RegExp _lexiconCreditActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.creditActions,
      );
  static final RegExp _lexiconFailureActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.failureActions,
      );
  static final RegExp _lexiconReversalActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.reversalActions,
      );
  static final RegExp _lexiconRequestActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.requestActions,
      );
  static final RegExp _lexiconBillReminderActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.billReminderActions,
      );
  static final RegExp _lexiconBalanceActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.balanceActions,
      );
  static final RegExp _lexiconOtpActions =
      MoneySmsRecognitionLexicon.phrasePattern(
        MoneySmsRecognitionLexicon.otpActions,
      );
  // --- Sanitized Parser Result Reasons ---
  static const String reasonConfirmedDebit = 'confirmed_debit';
  static const String reasonNoDebitAction = 'no_debit_action';
  static const String reasonAmountNotFound = 'amount_not_found';
  static const String reasonBalanceOnly = 'balance_only';
  static const String reasonCreditDetected = 'credit_detected';
  static const String reasonReversalDetected = 'reversal_detected';
  static const String reasonFailedTransaction = 'failed_transaction';
  static const String reasonOtpDetected = 'otp_detected';
  static const String reasonAmbiguousDirection = 'ambiguous_direction';
  static const String reasonPaymentRequest = 'payment_request';
  static const String reasonBillReminder = 'bill_reminder';
  static const String reasonUnsupportedCurrency = 'unsupported_currency';
  static const String reasonPromotionalOffer = 'promotional_offer';
  static const String reasonEmptyText = 'empty_text';

  // --- 1. OTP & Verification Patterns ---
  static final RegExp _otpPattern = RegExp(
    r'\b(?:otp|one time password|verification code|authentication code|login code|secret code|security code)\b|'
    r'\b(?:valid for|expires in|valid till)\s+\d+\s*(?:sec|secs|second|seconds|min|mins|minute|minutes|hr|hrs|hour|hours)\b|'
    r'\b(?:do not share|don\x27t share|never share|never disclose|strictly confidential)\s+(?:this\s+)?(?:otp|code|one time|secret|password)\b|'
    r'\b(?:is|as) your (?:verification|secret|login|one time|otp)\b|'
    r'\b(?:use code|enter code|secret code is)\s+\d+\b|'
    r'\buse\s+(?:otp|code)\b|'
    r'\b\d{4,8}\s+is your\s+(?:otp|verification|security code)\b|'
    r'\bfor your transaction at .* use otp\b|'
    r'\botp for (?:your )?(?:transaction|txn|card|purchase)\b|'
    r'\botp is \d+\b',
    caseSensitive: false,
  );

  // --- 2. Failed / Declined / Blocked Patterns ---
  static final RegExp _failedPattern = RegExp(
    r'\b(?:failed|declined|unsuccessful|could not be completed|transaction failed|payment failed|unsuccessful payment|payment was unsuccessful|timed out|cancelled|canceled|blocked|rejected|failed due to)\b',
    caseSensitive: false,
  );

  // --- 3. Reversal & Refund Patterns ---
  static final RegExp _reversalPattern = RegExp(
    r'\b(?:reversed|reversal of|has been reversed|reversed back|reversal credited|refund|refunded|refund of|will be refunded|refund received|refund credited|credited as refund|cashback credited|cashback of)\b',
    caseSensitive: false,
  );

  // --- 4. Payment Request Patterns ---
  static final RegExp _paymentRequestPattern = RegExp(
    r'\b(?:requested money|has requested|requested payment of|payment request of|mandate requested|collect request|is requesting|request to pay|to approve|click here to pay|pay now to complete|pay request)\b',
    caseSensitive: false,
  );

  // --- 5. Bill & Due-Date Reminder Patterns ---
  static final RegExp _billOrReminderPattern = RegExp(
    r'\b(?:bill generated|bill due|payment due|due date|minimum amount due|total amount due|total due|amount due is|outstanding balance|total outstanding|payment reminder|pay your bill|bill of rs|statement generated|e-statement)\b',
    caseSensitive: false,
  );

  // --- 6. Promotional & Loan Patterns ---
  static final RegExp _promotionalPattern = RegExp(
    r'\b(?:pre-approved|apply now|special offer|flat \d+% off|discount code|claim your|'
    r'loan offer|credit card offer|rewards? points? earned|eligible for loan|instant loan|click to apply|get personal loan|congratulations.*approved|exclusive offer|avail loan|car loan|home loan)\b',
    caseSensitive: false,
  );

  // --- 7. Non-Transactional Card/Account Notices ---
  static final RegExp _cardDispatchOrSecurityPattern = RegExp(
    r'\b(?:dispatched via|is dispatched|has been dispatched|airway bill|awb|courier|protect your (?:debit|credit) card|never share your (?:atm )?pin|keep your (?:debit|credit) card safe|welcome to .* debit card)\b',
    caseSensitive: false,
  );

  // --- 8. Foreign Currency Indicators ---
  static final RegExp _foreignCurrencyPattern = RegExp(
    r'\b(?:USD|EUR|GBP|AUD|CAD|AED|SGD|JPY|CHF)\b|[\$€£¥]',
    caseSensitive: false,
  );

  // --- 9. Balance Alert Keywords ---
  static final RegExp _balanceOnlyKeywords = RegExp(
    r'\b(?:available balance|account balance|avl bal|clear balance|mini statement|low balance|balance enquiry|current balance|ledger balance|bal in your a/c|balance in your a/c|balance for)\b',
    caseSensitive: false,
  );

  // --- 10. Credit Keywords ---
  // Matches incoming money keywords while avoiding "credit card" and "credit limit"
  static final RegExp _creditKeywords = RegExp(
    r'\b(?:credited|creditted|received|deposited|salary credited|credit(?!\s+(?:card|limit)))\b',
    caseSensitive: false,
  );

  // --- 11. Debit Action Keywords & Phrases ---
  static final RegExp _debitVerbsPattern = RegExp(
    r'\b(?:debited|debitted|deducted|spent|paid|withdrawn|transferred|sent|purchased)\b',
    caseSensitive: false,
  );

  static final RegExp _debitPhrasesPattern = RegExp(
    r'\b(?:auto-?debit(?:ed)?|autopay|mandate executed|card purchase|pos purchase|pos txn|'
    r'atm withdrawal|atm cash withdrawal|cash withdrawal|'
    r'upi payment|upi txn|upi transaction|'
    r'purchase of|purchase at|purchase on|'
    r'payment of|payment to|payment for|payment made|payment successful|payment done|'
    r'txn of|transaction of|txn done|transaction done|txn made|transaction made|'
    r'debited by|debited for|debited from|debited with|debited on|debited towards|'
    r'debitted by|debitted for|debitted from|debitted with|'
    r'is debited|was debited|has been debited|is debitted|was debitted|has been debitted|'
    r'debit of|debit from)\b',
    caseSensitive: false,
  );

  // --- 12. Balance / Limit / Due Clause Matcher ---
  // Matches and isolates balance sections to prevent false amount extraction.
  static final RegExp _balanceClausePattern = RegExp(
    r'(?:'
    r'(?:avl\.?|available|total|clear|ledger|current|remaining|new|updated|net|effective)?\s*bal(?:ance)?(?:\s*is)?:?|'
    r'(?:avl\.?|available|total|credit)\s*limit(?:\s*is)?:?|'
    r'(?:minimum|min\.?|total)?\s*amount\s*due(?:\s*is)?:?|'
    r'(?:total\s*)?outstanding(?:\s*bal(?:ance)?)?(?:\s*is)?:?|'
    r'\bbal\s*(?:is)?:?'
    r')\s*[:\s-]*'
    r'(?:'
    r'(?:INR|Rs\.?|Rs:|₹)\s*[\d, ]+(?:\.\d{1,2})?'
    r'|'
    r'[\d, ]+(?:\.\d{1,2})?\s*(?:INR|Rs\.?|₹)?'
    r')',
    caseSensitive: false,
  );

  // --- 13. Amount Regexes ---
  // Proximity Pattern A: Debit action followed closely by amount
  static final RegExp _debitActionFollowedByAmount = RegExp(
    r'(?:debited|debitted|deducted|spent|paid|withdrawn|transferred|sent|auto-?debit(?:ed)?|autopay|mandate executed|card purchase|pos purchase|pos txn|atm withdrawal|atm cash withdrawal|cash withdrawal|upi payment|upi txn|upi transaction|purchase of|purchased|payment of|txn of|transaction of|debit of)'
    r'(?:\s+(?:by|for|with|from|towards|at|of|on\s+[\w\d\-\/\.]+))*'
    r'\s*[:\s-]*'
    r'(?:'
    r'(?:INR|Rs\.?|Rs:|₹)\s*([\d, ]+(?:\.\d{1,2})?)'
    r'|'
    r'([\d, ]+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?|₹)'
    r')',
    caseSensitive: false,
  );

  // Proximity Pattern B: Amount followed by debit action
  static final RegExp _amountFollowedByDebitAction = RegExp(
    r'(?:'
    r'(?:INR|Rs\.?|Rs:|₹)\s*([\d, ]+(?:\.\d{1,2})?)'
    r'|'
    r'([\d, ]+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?|₹)'
    r')'
    r'\s*(?:(?:is|was|has\s+been)\s+)?'
    r'(?:debited|debitted|deducted|spent|paid|withdrawn|transferred|sent)',
    caseSensitive: false,
  );

  // General INR amount matches for fallback (run only after balance exclusion)
  static final RegExp _generalPrefixAmount = RegExp(
    r'(?:INR|Rs\.?|Rs:|₹)\s*([\d, ]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _generalSuffixAmount = RegExp(
    r'\b([\d, ]+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?|₹)\b',
    caseSensitive: false,
  );

  // --- 14. Metadata Extraction Regexes ---
  static final RegExp _accountMaskPattern = RegExp(
    r'(?:A/c|Acct|Account|Card)(?:\s*(?:no\.?|ending(?:\s*with)?|number)?)?\s*[*XxNn\.\s-]*(\d{3,4})\b',
    caseSensitive: false,
  );

  static final RegExp _referenceIdPattern = RegExp(
    r'\b(?:UPI\s*Ref(?:\s*No\.?|\s*num|\s*number)?|UPI\s*Reference|Ref(?:\s*No\.?|\s*num|\s*number)?|Reference(?:\s*No\.?|\s*num|\s*number)?|Txn(?:\s*Id|\s*no\.?)?|Transaction(?:\s*Id|\s*no\.?)?|UTR(?:\s*No\.?)?|RRN)\s*[:#=\s-]+([A-Za-z0-9]+)\b',
    caseSensitive: false,
  );

  static final RegExp _upiPathReferencePattern = RegExp(
    r'\bUPI\/(?:P2M\/|P2P\/)?(\d{10,16})\b',
    caseSensitive: false,
  );

  static final RegExp _merchantPattern = RegExp(
    r'\b(?:paid\s+to|sent\s+to|transferred\s+to|towards|vpa|info:|merchant|at|to)\s+([A-Za-z0-9@\.\-_&'
    r'\/ ]{2,50})',
    caseSensitive: false,
  );

  static final RegExp _datePatternWithSeparators = RegExp(
    r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b|\b(\d{1,2})[-/ ]([A-Za-z]{3})[-/ ](\d{2,4})\b',
    caseSensitive: false,
  );

  static final RegExp _compactDatePattern = RegExp(
    r'\b(\d{1,2})([A-Za-z]{3})(\d{2,4})\b',
    caseSensitive: false,
  );

  static final RegExp _timePattern = RegExp(
    r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b',
  );

  // Prose blacklist for reference IDs
  static const Set<String> _refProseBlacklist = {
    'PAYMENT',
    'PAYMENTS',
    'SUCCESSFUL',
    'SUCCESS',
    'TRANSACTION',
    'TXN',
    'FAILED',
    'PENDING',
    'ALERT',
    'USER',
    'BANK',
    'TRANSFER',
    'TRANSFERRED',
    'DEBITED',
    'CREDITED',
  };

  /// Parses a raw event into a structured [ParsedMoneyTransaction].
  ///
  /// Guarantees deterministic, safe behavior that never throws or crashes.
  ParsedMoneyTransaction parse(MoneyAutomationRawEvent rawEvent) {
    try {
      final normalizedText = normalizeText(rawEvent.body);
      final sender = rawEvent.sender.trim();

      if (normalizedText.isEmpty) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.low,
          reason: reasonEmptyText,
          amount: 0.0,
        );
      }

      // 1. Mandatory Rejection: OTP messages unconditionally
      if (isOtp(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.otp,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonOtpDetected,
          amount: 0.0,
        );
      }

      // 2. Mandatory Rejection: Failed / Declined / Blocked
      if (isFailed(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.failed,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonFailedTransaction,
          amount: 0.0,
        );
      }

      // 3. Mandatory Rejection: Reversals / Refunds
      if (isReversal(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.failed,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonReversalDetected,
          amount: 0.0,
        );
      }

      // 4. Mandatory Rejection: Payment requests not yet paid
      if (isPaymentRequest(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonPaymentRequest,
          amount: 0.0,
        );
      }

      // 5. Mandatory Rejection: Credit card bills, due-date reminders, statements
      if (isBillOrReminder(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonBillReminder,
          amount: 0.0,
        );
      }

      // 6. Mandatory Rejection: Promotional and loan offers
      if (isPromotional(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.promotional,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonPromotionalOffer,
          amount: 0.0,
        );
      }

      // 7. Contextual Direction Analysis (Debit vs Credit vs Ambiguous)
      final direction = detectDirection(normalizedText);

      if (direction == MoneyTransactionDirection.credit) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.credit,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonCreditDetected,
          amount: 0.0,
        );
      }

      if (direction == MoneyTransactionDirection.ambiguous) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.low,
          reason: reasonAmbiguousDirection,
          amount: 0.0,
        );
      }

      // 8. Balance-Only Rejection (no debit action)
      if (direction != MoneyTransactionDirection.debit &&
          isBalanceOnly(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.balanceAlert,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonBalanceOnly,
          amount: 0.0,
        );
      }

      // 9. Card Dispatch or Non-transactional Account Notice
      if (isCardDispatchOrSecurity(normalizedText) &&
          !hasDebitAction(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonNoDebitAction,
          amount: 0.0,
        );
      }

      // 10. Debit Action Verification
      if (!hasDebitAction(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.low,
          reason: reasonNoDebitAction,
          amount: 0.0,
        );
      }

      // 11. Foreign Currency Validation
      if (isUnsupportedForeignCurrency(normalizedText)) {
        return _buildResult(
          rawEvent: rawEvent,
          classification: MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.high,
          reason: reasonUnsupportedCurrency,
          amount: 0.0,
        );
      }

      // 12. Amount Extraction (with balance clause exclusion)
      final amount = extractAmount(normalizedText);
      if (amount == null || amount <= 0.0) {
        // If the original text only contained a balance amount, flag reasonBalanceOnly
        final hadBalanceClause = _balanceClausePattern.hasMatch(normalizedText);
        return _buildResult(
          rawEvent: rawEvent,
          classification: hadBalanceClause
              ? MoneyTransactionClassification.balanceAlert
              : MoneyTransactionClassification.unknown,
          confidence: MoneyTransactionConfidence.low,
          reason: hadBalanceClause ? reasonBalanceOnly : reasonAmountNotFound,
          amount: 0.0,
        );
      }

      // 13. Metadata Extraction
      final accountMask = extractAccountMask(normalizedText);
      final referenceId = extractReferenceId(normalizedText);
      final merchant = extractMerchant(normalizedText);
      final transactionDateTime =
          extractDateTime(normalizedText) ?? rawEvent.timestamp;

      // 14. Confidence Calculation
      final confidence = calculateConfidence(
        sender: sender,
        text: normalizedText,
        hasAccountMask: accountMask != null,
        hasReference: referenceId != null,
        hasMerchant: merchant != null,
        hasDateOrTime: extractDateTime(normalizedText) != null,
      );

      // 15. Fingerprint Generation
      final fingerprint = generateFingerprint(
        amount: amount,
        currency: 'INR',
        transactionDateTime: transactionDateTime,
        sender: sender,
        referenceId: referenceId,
        merchant: merchant,
        accountMask: accountMask,
        eventTimestamp: rawEvent.timestamp,
      );

      return ParsedMoneyTransaction(
        amount: amount,
        currency: 'INR',
        transactionDateTime: transactionDateTime,
        merchantOrDescription: merchant,
        referenceId: referenceId,
        sourceSender: sender,
        classification: MoneyTransactionClassification.confirmedDebit,
        confidence: confidence,
        fingerprint: fingerprint,
        accountMask: accountMask,
        parserReason: reasonConfirmedDebit,
      );
    } catch (e) {
      debugPrint('[MoneyTransactionParser] Exception during parsing: $e');
      return _buildResult(
        rawEvent: rawEvent,
        classification: MoneyTransactionClassification.unknown,
        confidence: MoneyTransactionConfidence.low,
        reason: 'exception',
        amount: 0.0,
      );
    }
  }

  // --- Helper Methods ---

  /// Normalizes whitespace and characters while preserving casing.
  static String normalizeText(String raw) {
    if (raw.isEmpty) return '';
    var text = raw.replaceAll(
      RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]'),
      ' ',
    );
    text = text.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  /// Identifies OTP and authentication messages.
  static bool isOtp(String text) =>
      _otpPattern.hasMatch(text) || _lexiconOtpActions.hasMatch(text);

  /// Identifies failed, declined, or cancelled transactions.
  static bool isFailed(String text) =>
      _failedPattern.hasMatch(text) || _lexiconFailureActions.hasMatch(text);

  /// Identifies reversal, refund, or cashback notices.
  static bool isReversal(String text) =>
      _reversalPattern.hasMatch(text) || _lexiconReversalActions.hasMatch(text);

  /// Identifies unfulfilled payment requests (e.g. UPI collect requests).
  static bool isPaymentRequest(String text) =>
      _paymentRequestPattern.hasMatch(text) ||
      _lexiconRequestActions.hasMatch(text);

  /// Identifies bill reminders, due-date notices, or credit card bills.
  static bool isBillOrReminder(String text) =>
      _billOrReminderPattern.hasMatch(text) ||
      _lexiconBillReminderActions.hasMatch(text);

  /// Identifies promotional and loan offers.
  static bool isPromotional(String text) => _promotionalPattern.hasMatch(text);

  /// Identifies card dispatch or security tip messages.
  static bool isCardDispatchOrSecurity(String text) =>
      _cardDispatchOrSecurityPattern.hasMatch(text);

  /// Identifies balance-only messages (alerts, enquiries).
  static bool isBalanceOnly(String text) =>
      _balanceOnlyKeywords.hasMatch(text) ||
      _lexiconBalanceActions.hasMatch(text);

  /// Checks if message contains foreign currency without clear INR debit amount.
  static bool isUnsupportedForeignCurrency(String text) {
    if (!_foreignCurrencyPattern.hasMatch(text)) return false;
    final upper = text.toUpperCase();
    final hasInr =
        upper.contains('INR') || text.contains('₹') || upper.contains('RS');
    if (!hasInr) return true;
    // Foreign currency present alongside INR: valid if INR is explicitly debited
    final inrDebited =
        RegExp(
          r'(?:INR|Rs\.?|₹)\s*[\d, ]+(?:\.\d{1,2})?\s*(?:debited|spent|paid)',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(
          r'(?:debited|spent|paid|withdrawn)\s+(?:as|for|by|with)?\s*(?:INR|Rs\.?|₹)',
          caseSensitive: false,
        ).hasMatch(text);
    return !inrDebited;
  }

  /// Evaluates transaction direction using context when debit and credit keywords co-occur.
  static MoneyTransactionDirection detectDirection(String text) {
    final lower = text.toLowerCase();
    final hasDebitWord =
        RegExp(
          r'\b(?:debit|debited|debitted|deducted|spent|paid|withdrawn|transferred|sent|purchased)\b',
        ).hasMatch(lower) ||
        _debitPhrasesPattern.hasMatch(text) ||
        _lexiconDebitActions.hasMatch(text);
    // Ignore "credit card" and "credit limit" as incoming credit words
    final hasCreditWord =
        _creditKeywords.hasMatch(lower) || _lexiconCreditActions.hasMatch(text);

    if (hasCreditWord && !hasDebitWord) {
      return MoneyTransactionDirection.credit;
    }
    if (hasDebitWord && !hasCreditWord) {
      return MoneyTransactionDirection.debit;
    }
    if (hasDebitWord && hasCreditWord) {
      // Both present: analyze context
      // Case 1: User's account debited, payee credited (e.g. "A/c **1234 debited by Rs 500 and credited to VPA...")
      final payeeCredited = RegExp(
        r'\b(?:and\s+)?credited\s+to\s+(?:vpa|payee|merchant|beneficiary|[a-zA-Z0-9._%+-]+@)\b',
        caseSensitive: false,
      ).hasMatch(text);
      final userAccountDebited = RegExp(
        r'\b(?:your\s+)?(?:a/c|account|card)\b.*?\b(?:is\s+|was\s+|has\s+been\s+)?debitt?ed\b|\bdebitt?ed\s+from\s+(?:your\s+)?(?:a/c|account|card)\b',
        caseSensitive: false,
      ).hasMatch(text);

      if (payeeCredited && userAccountDebited) {
        return MoneyTransactionDirection.debit;
      }

      // Case 2: User's account credited (e.g. "Your A/c is credited with Rs 500 debited from...")
      final userAccountCredited = RegExp(
        r'\b(?:your\s+)?(?:a/c|account|card)\b.*?\b(?:is\s+|was\s+|has\s+been\s+)?creditt?ed\b|\bcreditt?ed\s+(?:to|in|with)\s+(?:your\s+)?(?:a/c|account|card)\b',
        caseSensitive: false,
      ).hasMatch(text);

      if (userAccountCredited) {
        return MoneyTransactionDirection.credit;
      }

      return MoneyTransactionDirection.ambiguous;
    }

    return MoneyTransactionDirection.none;
  }

  /// Checks whether text contains a debit/spending action.
  static bool hasDebitAction(String text) {
    return _debitVerbsPattern.hasMatch(text) ||
        _debitPhrasesPattern.hasMatch(text) ||
        _lexiconDebitActions.hasMatch(text);
  }

  /// Excludes balance, limit, and due-amount clauses before amount extraction.
  static String excludeBalanceClauses(String text) {
    return text.replaceAll(_balanceClausePattern, ' ');
  }

  /// Extracts the transaction amount, giving precedence to proximity to debit action.
  static double? extractAmount(String text) {
    // 1. Strip balance and limit clauses so they do not interfere with extraction
    final cleanText = excludeBalanceClauses(text);

    // 2. Pattern A: Debit action followed by amount
    final matchA = _debitActionFollowedByAmount.firstMatch(cleanText);
    if (matchA != null) {
      final raw = matchA.group(1) ?? matchA.group(2);
      final parsed = _parseAmountNumber(raw);
      if (parsed != null && parsed > 0) return parsed;
    }

    // 3. Pattern B: Amount followed by debit action
    final matchB = _amountFollowedByDebitAction.firstMatch(cleanText);
    if (matchB != null) {
      final raw = matchB.group(1) ?? matchB.group(2);
      final parsed = _parseAmountNumber(raw);
      if (parsed != null && parsed > 0) return parsed;
    }

    // 4. Fallback: General INR amount in the non-balance text
    final prefixMatches = _generalPrefixAmount.allMatches(cleanText);
    for (final m in prefixMatches) {
      final parsed = _parseAmountNumber(m.group(1));
      if (parsed != null && parsed > 0) return parsed;
    }

    final suffixMatches = _generalSuffixAmount.allMatches(cleanText);
    for (final m in suffixMatches) {
      final parsed = _parseAmountNumber(m.group(1));
      if (parsed != null && parsed > 0) return parsed;
    }

    return null;
  }

  static double? _parseAmountNumber(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.trim();
    // Remove commas
    cleaned = cleaned.replaceAll(',', '');
    // Remove spaces between digits: e.g. "1 250.00" -> "1250.00"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d)\s+(\d)'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    // Remove any trailing periods
    cleaned = cleaned.replaceAll(RegExp(r'\.+$'), '');
    final val = double.tryParse(cleaned);
    if (val != null && val > 0 && val < 1000000000) {
      return val;
    }
    return null;
  }

  /// Extracts and masks the financial account/card identifier (e.g. "XXXX1234").
  static String? extractAccountMask(String text) {
    final match = _accountMaskPattern.firstMatch(text);
    if (match != null) {
      final digits = match.group(1);
      if (digits != null && digits.isNotEmpty) {
        return 'XXXX$digits';
      }
    }
    return null;
  }

  /// Extracts transaction reference identifier (Ref, UTR, RRN, Txn ID, UPI Ref).
  static String? extractReferenceId(String text) {
    for (final match in _referenceIdPattern.allMatches(text)) {
      final id = match.group(1)?.trim();
      if (id != null && id.length >= 4 && id.length <= 35) {
        if (!_refProseBlacklist.contains(id.toUpperCase()) &&
            RegExp(r'\d').hasMatch(id)) {
          return id;
        }
      }
    }

    final upiMatch = _upiPathReferencePattern.firstMatch(text);
    if (upiMatch != null) {
      final id = upiMatch.group(1);
      if (id != null && id.isNotEmpty) return id;
    }

    return null;
  }

  /// Extracts clean merchant or payee name and masks sensitive numbers.
  static String? extractMerchant(String text) {
    final match = _merchantPattern.firstMatch(text);
    if (match == null) return null;

    var candidate = match.group(1)?.trim();
    if (candidate == null || candidate.isEmpty) return null;

    // Remove noise clauses and subsequent metadata
    final noiseRegex = RegExp(
      r'[\.\s]+(?:on|via|using|dated|ref|utr|rrn|avl|bal|balance|upi\s+ref|a/c|card|from|txn|through|by)\b',
      caseSensitive: false,
    );
    final noiseMatch = noiseRegex.firstMatch(candidate);
    if (noiseMatch != null && noiseMatch.start > 0) {
      candidate = candidate.substring(0, noiseMatch.start).trim();
    }

    // Clean trailing punctuation
    candidate = candidate.replaceAll(RegExp(r'[\.,;:\-\/\s]+$'), '').trim();

    // Redact sensitive numbers inside merchant string (5+ digit accounts / phone numbers)
    candidate = candidate.replaceAllMapped(RegExp(r'\b\d{5,19}\b'), (m) {
      final val = m.group(0)!;
      return 'XXXX${val.substring(val.length - 4)}';
    });

    if (candidate.isEmpty) return null;
    final lower = candidate.toLowerCase();
    if (lower == 'your a/c' || lower == 'bank' || lower == 'account') {
      return null;
    }

    return candidate;
  }

  /// Extracts explicit transaction timestamp if available in the text.
  static DateTime? extractDateTime(String text) {
    int? day, month, year;

    final sepMatch = _datePatternWithSeparators.firstMatch(text);
    if (sepMatch != null) {
      final g1 = sepMatch.group(1);
      final g2 = sepMatch.group(2);
      final g3 = sepMatch.group(3);
      final g4 = sepMatch.group(4);
      final g5 = sepMatch.group(5);
      final g6 = sepMatch.group(6);

      if (g1 != null && g2 != null && g3 != null) {
        day = int.tryParse(g1);
        month = int.tryParse(g2);
        year = int.tryParse(g3);
      } else if (g4 != null && g5 != null && g6 != null) {
        day = int.tryParse(g4);
        month = _parseMonth(g5);
        year = int.tryParse(g6);
      }
    } else {
      final compactMatch = _compactDatePattern.firstMatch(text);
      if (compactMatch != null) {
        day = int.tryParse(compactMatch.group(1)!);
        month = _parseMonth(compactMatch.group(2)!);
        year = int.tryParse(compactMatch.group(3)!);
      }
    }

    if (day != null && month != null && year != null) {
      if (year < 100) year += 2000;
      try {
        final candidate = DateTime(year, month, day);
        if (candidate.year == year &&
            candidate.month == month &&
            candidate.day == day) {
          // Check for optional time
          final timeMatch = _timePattern.firstMatch(text);
          if (timeMatch != null) {
            final hour = int.tryParse(timeMatch.group(1)!) ?? 0;
            final minute = int.tryParse(timeMatch.group(2)!) ?? 0;
            final second = int.tryParse(timeMatch.group(3) ?? '0') ?? 0;
            if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
              return DateTime(year, month, day, hour, minute, second);
            }
          }
          return candidate;
        }
      } catch (_) {}
    }

    return null;
  }

  static int? _parseMonth(String input) {
    final numeric = int.tryParse(input);
    if (numeric != null && numeric >= 1 && numeric <= 12) return numeric;

    final months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[input.toLowerCase()];
  }

  /// Calculates classification confidence based on contextual corroborating signals.
  static MoneyTransactionConfidence calculateConfidence({
    required String sender,
    required String text,
    required bool hasAccountMask,
    required bool hasReference,
    required bool hasMerchant,
    required bool hasDateOrTime,
  }) {
    final isPersonalMobile = RegExp(
      r'^(\+91|0)?[6-9]\d{9}$',
    ).hasMatch(sender.trim());
    if (isPersonalMobile) {
      return MoneyTransactionConfidence.medium;
    }

    final isBankSender = _isBankSender(sender);
    final hasChannel = RegExp(
      r'\b(?:UPI|IMPS|NEFT|RTGS|ATM|POS|Card|Net\s*Banking|Mandate|Autopay|Wallet)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final hasBalance = _balanceClausePattern.hasMatch(text);

    int signals = 0;
    if (isBankSender) signals += 2;
    if (hasAccountMask) signals++;
    if (hasReference) signals++;
    if (hasMerchant) signals++;
    if (hasChannel) signals++;
    if (hasDateOrTime) signals++;
    if (hasBalance) signals++;

    if (signals >= 2 || (isBankSender && signals >= 1)) {
      return MoneyTransactionConfidence.high;
    } else if (signals >= 1) {
      return MoneyTransactionConfidence.medium;
    } else {
      return MoneyTransactionConfidence.low;
    }
  }

  static bool _isBankSender(String sender) {
    final clean = sender.trim().toUpperCase();
    if (clean.isEmpty) return false;

    // Standard Indian transactional SMS header format: e.g. "VK-HDFCBK", "AD-SBIINB"
    if (RegExp(r'^[A-Z]{2}-?[A-Z0-9]{3,9}$').hasMatch(clean)) {
      return true;
    }

    const bankKeywords = [
      'SBI',
      'HDFC',
      'ICICI',
      'AXIS',
      'KOTAK',
      'CANARA',
      'CANBNK',
      'BOB',
      'BARBOD',
      'PNB',
      'UNION',
      'IDBI',
      'INDIAN',
      'PAYTM',
      'YESB',
      'INDUS',
      'FEDERL',
      'RBL',
      'BHIM',
      'GPAY',
      'CREDIT',
      'BANK',
    ];
    return bankKeywords.any(clean.contains);
  }

  /// Generates a deterministic SHA-256 fingerprint for deduplication.
  static String generateFingerprint({
    required double amount,
    required String currency,
    required DateTime transactionDateTime,
    required String sender,
    String? referenceId,
    String? merchant,
    String? accountMask,
    DateTime? eventTimestamp,
  }) {
    final amtStr = amount.toStringAsFixed(2);
    final refStr = referenceId?.toUpperCase().trim() ?? '';
    final senderStr = sender.toUpperCase().trim();
    final merchStr = merchant?.toUpperCase().trim() ?? '';
    final acctStr = accountMask ?? '';
    final dateStr =
        '${transactionDateTime.year}-${transactionDateTime.month.toString().padLeft(2, '0')}-${transactionDateTime.day.toString().padLeft(2, '0')}';

    final occurrence = refStr.isEmpty
        ? '|${(eventTimestamp ?? transactionDateTime).millisecondsSinceEpoch}'
        : '';
    final signature =
        '$amtStr|$currency|$refStr|$senderStr|$merchStr|$acctStr|$dateStr$occurrence';
    final bytes = utf8.encode(signature);
    return sha256.convert(bytes).toString();
  }

  ParsedMoneyTransaction _buildResult({
    required MoneyAutomationRawEvent rawEvent,
    required MoneyTransactionClassification classification,
    required MoneyTransactionConfidence confidence,
    required String reason,
    required double amount,
  }) {
    final date = rawEvent.timestamp;
    final sender = rawEvent.sender;
    final fingerprint = generateFingerprint(
      amount: amount,
      currency: 'INR',
      transactionDateTime: date,
      sender: sender,
      eventTimestamp: rawEvent.timestamp,
    );

    return ParsedMoneyTransaction(
      amount: amount,
      currency: 'INR',
      transactionDateTime: date,
      sourceSender: sender,
      classification: classification,
      confidence: confidence,
      fingerprint: fingerprint,
      parserReason: reason,
    );
  }
}
