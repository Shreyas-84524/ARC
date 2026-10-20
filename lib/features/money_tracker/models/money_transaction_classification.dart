/// Classification result of an incoming transaction event.
///
/// Phase 3 strictly accepts only [confirmedDebit] with high confidence.
/// All other types ([credit], [otp], [failed], [balanceAlert], [promotional], [unknown])
/// are rejected from automatic entry.
enum MoneyTransactionClassification {
  confirmedDebit,
  credit,
  otp,
  failed,
  balanceAlert,
  promotional,
  unknown,
}

/// Confidence level of the classification.
///
/// Only [high] confidence confirmed debits proceed as accepted candidates.
enum MoneyTransactionConfidence {
  high,
  medium,
  low,
}
