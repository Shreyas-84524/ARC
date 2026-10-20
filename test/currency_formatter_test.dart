import 'package:flutter_test/flutter_test.dart';
import 'package:arc/core/utilities/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formats standard monetary amounts correctly according to Indian numbering system', () {
      expect(CurrencyFormatter.format(500), equals('₹500.00'));
      expect(CurrencyFormatter.format(0), equals('₹0.00'));
      expect(CurrencyFormatter.format(1250), equals('₹1,250.00'));
      expect(CurrencyFormatter.format(25000), equals('₹25,000.00'));
      expect(CurrencyFormatter.format(150000), equals('₹1,50,000.00'));
    });

    test('formats amounts with custom decimal digits', () {
      expect(CurrencyFormatter.format(150000, decimalDigits: 0), equals('₹1,50,000'));
      expect(CurrencyFormatter.format(500, decimalDigits: 0), equals('₹500'));
      expect(CurrencyFormatter.formatCompact(25000), equals('₹25,000'));
    });
  });
}
