import 'money_transaction_classification.dart';

/// Structured local representation of a parsed transaction candidate.
///
/// PRIVACY & SECURITY RULES:
/// - Never store or reference the full raw SMS body here.
/// - Any financial account numbers or card numbers must be masked (e.g. "XXXX1234").
/// - [toString] is strictly sanitized to prevent leaking sensitive identifiers or amounts.
class ParsedMoneyTransaction {
  final double amount;
  final String currency;
  final DateTime transactionDateTime;
  final String? merchantOrDescription;
  final String? referenceId;
  final String sourceSender;
  final MoneyTransactionClassification classification;
  final MoneyTransactionConfidence confidence;
  final String fingerprint;
  final String? accountMask;

  const ParsedMoneyTransaction({
    required this.amount,
    this.currency = 'INR',
    required this.transactionDateTime,
    this.merchantOrDescription,
    this.referenceId,
    required this.sourceSender,
    required this.classification,
    required this.confidence,
    required this.fingerprint,
    this.accountMask,
  });

  bool get isConfirmedDebit =>
      classification == MoneyTransactionClassification.confirmedDebit &&
      confidence == MoneyTransactionConfidence.high;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedMoneyTransaction && other.fingerprint == fingerprint;
  }

  @override
  int get hashCode => fingerprint.hashCode;

  @override
  String toString() {
    // Sanitized representation: never print raw text or sensitive financial details
    final shortFp = fingerprint.length > 8 ? '${fingerprint.substring(0, 8)}...' : fingerprint;
    return 'ParsedMoneyTransaction(classification: ${classification.name}, confidence: ${confidence.name}, amount: $amount $currency, sender: $sourceSender, ref: ${referenceId != null ? "[REDACTED]" : "none"}, fp: $shortFp)';
  }
}
