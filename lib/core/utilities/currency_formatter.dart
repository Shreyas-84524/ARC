import 'package:intl/intl.dart';

/// Reusable utility for formatting currency amounts according to Indian conventions (INR - ₹).
class CurrencyFormatter {
  static const String symbol = '₹';

  /// Formats [amount] into Indian Rupee currency string (e.g. ₹1,250.00, ₹25,000.00, ₹1,50,000.00).
  /// [decimalDigits] defaults to 2.
  static String format(num amount, {int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  /// Formats [amount] without decimal digits (e.g. ₹1,50,000).
  static String formatCompact(num amount) {
    return format(amount, decimalDigits: 0);
  }
}
