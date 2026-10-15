/// Transient, in-memory representation of an eligible incoming transaction event
/// captured locally by the device listener.
///
/// PRIVACY & SECURITY RULES:
/// - Raw event instances must exist ONLY in memory during transient handling.
/// - NEVER write this object or its [body] to Hive, Firestore, Firebase, or analytics.
/// - [toString] is strictly sanitized so that raw text, OTPs, amounts, or personal
///   data are never printed to debug consoles or log files.
class MoneyAutomationRawEvent {
  final String sender;
  final String body;
  final DateTime timestamp;
  final String sourceType;

  const MoneyAutomationRawEvent({
    required this.sender,
    required this.body,
    required this.timestamp,
    this.sourceType = 'sms',
  });

  factory MoneyAutomationRawEvent.fromMap(Map<dynamic, dynamic> map) {
    final senderStr = map['sender']?.toString() ?? 'UNKNOWN';
    final bodyStr = map['body']?.toString() ?? '';
    final rawTs = map['timestamp'];
    final DateTime eventTime;

    if (rawTs is int) {
      eventTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is String) {
      eventTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      eventTime = DateTime.now();
    }

    final source = map['sourceType']?.toString() ?? 'sms';

    return MoneyAutomationRawEvent(
      sender: senderStr,
      body: bodyStr,
      timestamp: eventTime,
      sourceType: source,
    );
  }

  @override
  String toString() {
    // Sanitized output: NEVER print [body] to prevent leaking sensitive bank texts or OTPs
    return 'MoneyAutomationRawEvent(sourceType: $sourceType, sender: $sender, length: ${body.length}, timestamp: $timestamp)';
  }
}
