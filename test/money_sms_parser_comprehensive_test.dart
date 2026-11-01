import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/models/money_transaction_classification.dart';
import 'package:arc/features/money_tracker/services/money_deduplication_service.dart';
import 'package:arc/features/money_tracker/services/money_transaction_parser.dart';
import 'package:arc/features/money_tracker/services/money_sms_recognition_lexicon.dart';

MoneyAutomationRawEvent makeEvent(
  String body, {
  String sender = 'HDFCBK',
  DateTime? timestamp,
}) {
  return MoneyAutomationRawEvent(
    sender: sender,
    body: body,
    timestamp: timestamp ?? DateTime(2026, 10, 28, 14, 30),
    sourceType: 'sms',
  );
}

void main() {
  late MoneyTransactionParser parser;
  late MoneyDeduplicationService dedupService;

  setUp(() {
    parser = MoneyTransactionParser();
    dedupService = MoneyDeduplicationService();
    dedupService.initForUser('test_user_comprehensive');
  });

  tearDown(() {
    dedupService.clear();
  });

  group('0. Compositional recognition lexicon', () {
    test('supports more than 1,000 contextual debit phrase forms', () {
      expect(
        MoneySmsRecognitionLexicon.contextualDebitPhraseCapacity,
        greaterThanOrEqualTo(1000),
      );
    });

    final expandedDebitCases = <String>[
      'Your account was charged to Rs. 499 for a merchant purchase.',
      'INR 275 payment completed using UPI from your savings account.',
      'Wallet debited by Rs 80 for toll payment.',
      'Standing instruction executed for INR 1200 from account ending 7788.',
      'Rs. 650 fund transfer successful from your account via IMPS.',
      'Debit card purchase of INR 940 completed at TEST STORE.',
      'Rs 300 recharge successful using your linked account.',
      'Your fastag wallet was debited for INR 150.',
    ];

    for (final sms in expandedDebitCases) {
      test('recognizes expanded debit vocabulary: $sms', () {
        final result = parser.parse(makeEvent(sms));
        expect(
          result.classification,
          MoneyTransactionClassification.confirmedDebit,
        );
        expect(result.amount, greaterThan(0));
      });
    }

    test('expanded rejection vocabulary does not create expenses', () {
      final messages = [
        'Payment could not process for Rs 500 due to a technical issue.',
        'UPI collect request received for Rs 700. Tap to approve.',
        'Your current outstanding amount is Rs 900. Payment due tomorrow.',
        'Refund processed for Rs 450 and will be credited shortly.',
        'Your dynamic password is 123456 for transaction of Rs 200.',
      ];
      for (final sms in messages) {
        expect(parser.parse(makeEvent(sms)).isConfirmedDebit, isFalse);
      }
    });
  });

  group('1. Indian Bank SMS Coverage (Table-Driven)', () {
    final bankCases = <Map<String, dynamic>>[
      {
        'bank': 'SBI',
        'sender': 'SBIINB',
        'sms':
            'Dear SBI User, your A/c ending 1234 debited by Rs.500.00 on 28Oct26 by UPI to Swiggy Ref No 123456789012. Bal Rs 10,500.00 - SBI',
        'expectedAmount': 500.0,
        'expectedRef': '123456789012',
        'expectedMask': 'XXXX1234',
        'expectedMerchant': 'Swiggy',
      },
      {
        'bank': 'SBI (Format 2)',
        'sender': 'SBIINB',
        'sms':
            'Your A/C ending 9876 is debited for Rs 1,250.00 on 28-10-26 transfer to Amazon Pay. Ref No 9876543210. Bal: Rs 55,000.00',
        'expectedAmount': 1250.0,
        'expectedRef': '9876543210',
        'expectedMask': 'XXXX9876',
        'expectedMerchant': 'Amazon Pay',
      },
      {
        'bank': 'HDFC',
        'sender': 'HDFCBK',
        'sms':
            'HDFC Bank: Rs 450.00 debited from a/c **1234 on 12-10-26 to Swiggy. UPI Ref: 123456789012. Avl bal: Rs 15400.00',
        'expectedAmount': 450.0,
        'expectedRef': '123456789012',
        'expectedMask': 'XXXX1234',
        'expectedMerchant': 'Swiggy',
      },
      {
        'bank': 'HDFC (Card purchase)',
        'sender': 'HDFCBK',
        'sms':
            'ALERT: You have made a debit card purchase of INR 2,499.00 at RELIANCE RETAIL on 28-OCT-26 using Card ending 4321. Avl Bal: INR 35,000.00.',
        'expectedAmount': 2499.0,
        'expectedRef': null,
        'expectedMask': 'XXXX4321',
        'expectedMerchant': 'RELIANCE RETAIL',
      },
      {
        'bank': 'ICICI',
        'sender': 'ICICIB',
        'sms':
            'Dear Customer, your Account ending with 5678 has been debited with INR 850.00 on 28-Oct-26 towards UPI/9876543210/Zomato. UPI Ref no 234567890123. Avl Bal INR 4,200.50.',
        'expectedAmount': 850.0,
        'expectedRef': '234567890123',
        'expectedMask': 'XXXX5678',
        'expectedMerchant': 'Zomato',
      },
      {
        'bank': 'ICICI (Txn on card)',
        'sender': 'ICICIB',
        'sms':
            'ICICI Bank: Txn of INR 1,500.00 done on Debit Card ending 1234 at DMART on 28-Oct-26. Avl Limit: INR 45,000.00.',
        'expectedAmount': 1500.0,
        'expectedRef': null,
        'expectedMask': 'XXXX1234',
        'expectedMerchant': 'DMART',
      },
      {
        'bank': 'Axis',
        'sender': 'AXISBK',
        'sms':
            'Axis Bank: INR 320.00 debited from A/c no. XX9988 on 28-10-2026 14:35:10 via UPI to Uber. UTR: 345678901234. Available balance: INR 18,900.00.',
        'expectedAmount': 320.0,
        'expectedRef': '345678901234',
        'expectedMask': 'XXXX9988',
        'expectedMerchant': 'Uber',
      },
      {
        'bank': 'Kotak',
        'sender': 'KOTAKB',
        'sms':
            'Kotak Bank: Sent Rs 400.00 from Kotak Bank A/c ending 3456 to Swiggy on 28-10-2026. UPI Ref 456789012345. Balance: Rs 8,250.00.',
        'expectedAmount': 400.0,
        'expectedRef': '456789012345',
        'expectedMask': 'XXXX3456',
        'expectedMerchant': 'Swiggy',
      },
      {
        'bank': 'Canara',
        'sender': 'CANBNK',
        'sms':
            'Canara Bank: Your A/C ending 4567 debited by Rs 650.00 on 28-10-2026 15:20 through UPI to Flipkart. Ref: 567890123456. Avl Bal: Rs 14,350.00.',
        'expectedAmount': 650.0,
        'expectedRef': '567890123456',
        'expectedMask': 'XXXX4567',
        'expectedMerchant': 'Flipkart',
      },
      {
        'bank': 'Bank of Baroda',
        'sender': 'BOBTXN',
        'sms':
            'BOB Alert: A/c ...1234 debited for Rs.1,100.00 on 28-10-26 by UPI/P2M/678901234567/BigBasket. Bal:Rs.9,800.00.',
        'expectedAmount': 1100.0,
        'expectedRef': '678901234567',
        'expectedMask': 'XXXX1234',
        'expectedMerchant': null,
      },
      {
        'bank': 'Punjab National Bank',
        'sender': 'PNBSMS',
        'sms':
            'PNB SMS: Your A/c ending 6789 debited with Rs. 350.00 on 28-10-2026 via UPI to Cafe Coffee Day. UPI Ref 789012345678. Avl Bal Rs 6,400.00.',
        'expectedAmount': 350.0,
        'expectedRef': '789012345678',
        'expectedMask': 'XXXX6789',
        'expectedMerchant': 'Cafe Coffee Day',
      },
      {
        'bank': 'Union Bank',
        'sender': 'UNIONB',
        'sms':
            'Union Bank of India: A/c ending 7890 debited by INR 250.00 on 28-10-2026 by UPI to Dunzo. UTR No 890123456789. Avl Bal: INR 5,120.00.',
        'expectedAmount': 250.0,
        'expectedRef': '890123456789',
        'expectedMask': 'XXXX7890',
        'expectedMerchant': 'Dunzo',
      },
      {
        'bank': 'IDBI Bank',
        'sender': 'IDBIBK',
        'sms':
            'IDBI Bank: INR 800.00 debited from A/c ending 8901 on 28-10-2026 towards IMPS transfer to Merchant. Txn ID: 901234567890. Avl Bal: INR 11,200.00.',
        'expectedAmount': 800.0,
        'expectedRef': '901234567890',
        'expectedMask': 'XXXX8901',
        'expectedMerchant': 'Merchant',
      },
      {
        'bank': 'Indian Bank',
        'sender': 'INDBNK',
        'sms':
            'Indian Bank: Your A/C ending 9012 is debited by Rs 420.00 on 28-10-2026. Paid to BookMyShow. Ref 012345678901. Bal Rs 7,800.00.',
        'expectedAmount': 420.0,
        'expectedRef': '012345678901',
        'expectedMask': 'XXXX9012',
        'expectedMerchant': 'BookMyShow',
      },
      {
        'bank': 'Paytm Payments Bank',
        'sender': 'PAYTMB',
        'sms':
            'Paytm Bank: Rs. 150.00 paid from A/c ending 0123 to Chai Point via UPI. UPI Ref: 123450987654. Updated Bal: Rs. 1,450.00.',
        'expectedAmount': 150.0,
        'expectedRef': '123450987654',
        'expectedMask': 'XXXX0123',
        'expectedMerchant': 'Chai Point',
      },
    ];

    for (final testCase in bankCases) {
      test('Recognizes confirmed debit from ${testCase['bank']}', () {
        final event = makeEvent(
          testCase['sms'] as String,
          sender: testCase['sender'] as String,
        );
        final result = parser.parse(event);

        expect(
          result.classification,
          MoneyTransactionClassification.confirmedDebit,
        );
        expect(result.confidence, MoneyTransactionConfidence.high);
        expect(result.amount, testCase['expectedAmount']);
        expect(
          result.parserReason,
          MoneyTransactionParser.reasonConfirmedDebit,
        );
        expect(result.isConfirmedDebit, isTrue);

        if (testCase['expectedRef'] != null) {
          expect(result.referenceId, testCase['expectedRef']);
        }
        if (testCase['expectedMask'] != null) {
          expect(result.accountMask, testCase['expectedMask']);
        }
        if (testCase['expectedMerchant'] != null) {
          expect(
            result.merchantOrDescription,
            contains(testCase['expectedMerchant'] as String),
          );
        }
      });
    }
  });

  group('2. Channels and Transaction Types', () {
    test('ATM Cash Withdrawal', () {
      final event = makeEvent(
        'Rs 2,000.00 withdrawn at SBI ATM from A/c XX4321 on 12-10-26. Txn# 48921. Available Bal: Rs 8,000.00',
        sender: 'SBIINB',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 2000.0);
      expect(result.accountMask, 'XXXX4321');
      expect(result.referenceId, '48921');
    });

    test('Credit Card Purchase', () {
      final event = makeEvent(
        'Txn of Rs 1,200.00 done on Credit Card ending 5678 at PVR Cinemas on 28-10-26. Avl Limit: Rs 45,000.00',
        sender: 'HDFCBK',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 1200.0);
      expect(result.accountMask, 'XXXX5678');
      expect(result.merchantOrDescription, 'PVR Cinemas');
    });

    test('IMPS Transfer', () {
      final event = makeEvent(
        'Dear Customer, INR 5,000.00 transferred from A/c **4321 via IMPS to John Doe on 28-10-2026. Ref No: 456789012345. Avl Bal: INR 25,000.00.',
        sender: 'ICICIB',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 5000.0);
      expect(result.accountMask, 'XXXX4321');
      expect(result.referenceId, '456789012345');
    });

    test('NEFT Transfer', () {
      final event = makeEvent(
        'NEFT transaction: Rs 10,000.00 debited from A/c ending 7890 to Landlord on 28-10-26. UTR: 567890123456. Bal Rs 45,000.',
        sender: 'AXISBK',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 10000.0);
      expect(result.referenceId, '567890123456');
    });

    test('Auto-Debit Subscription', () {
      final event = makeEvent(
        'Auto-debit of INR 499.00 executed for your Spotify subscription from A/c **1234 on 28-10-26. Bal: INR 15,000.00.',
        sender: 'KOTAKB',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 499.0);
      expect(result.accountMask, 'XXXX1234');
    });

    test('Autopay Execution', () {
      final event = makeEvent(
        'Autopay successful: Rs. 199.00 debited from your A/c ending 5678 for Netflix. Ref: 234567890123.',
        sender: 'HDFCBK',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 199.0);
      expect(result.referenceId, '234567890123');
    });

    test('UPI Mandate Executed', () {
      final event = makeEvent(
        'Mandate executed: Rs. 1,500.00 debited from A/c XX9012 towards Mutual Fund. UTR 345678901234. Avl Bal Rs 20,000.',
        sender: 'SBIINB',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 1500.0);
      expect(result.referenceId, '345678901234');
    });
  });

  group('3. Spelling & Currency Format Variations', () {
    test('Spelling variation: debitted (two ts)', () {
      final event = makeEvent(
        'Your a/c **1234 is debitted by Rs. 500.00 on 28-10-26 to Coffee Shop. Ref 112233.',
      );
      final result = parser.parse(event);
      expect(result.isConfirmedDebit, isTrue);
      expect(result.amount, 500.0);
    });

    test('Spelling variation: creditted (two ts) rejected as credit', () {
      final event = makeEvent(
        'Your a/c **1234 is creditted with Rs. 500.00 on 28-10-26 from John. Ref 112233.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.credit);
      expect(result.isConfirmedDebit, isFalse);
      expect(result.parserReason, MoneyTransactionParser.reasonCreditDetected);
    });

    test('Currency format: ₹500 (no space)', () {
      final event = makeEvent(
        '₹500.00 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 500.0);
      expect(result.isConfirmedDebit, isTrue);
    });

    test('Currency format: ₹ 500 (with space)', () {
      final event = makeEvent(
        '₹ 500.00 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 500.0);
      expect(result.isConfirmedDebit, isTrue);
    });

    test('Currency format: Rs 500', () {
      final event = makeEvent(
        'Rs 500 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 500.0);
      expect(result.isConfirmedDebit, isTrue);
    });

    test('Currency format: Rs. 500', () {
      final event = makeEvent(
        'Rs. 500 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 500.0);
      expect(result.isConfirmedDebit, isTrue);
    });

    test('Currency format: Rs: 500', () {
      final event = makeEvent(
        'A/c XX1234 debited by Rs: 500 on 28-10-26 to Store. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 500.0);
      expect(result.isConfirmedDebit, isTrue);
    });

    test('Currency format: INR 500 and INR500', () {
      final event1 = makeEvent(
        'INR 500 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      expect(parser.parse(event1).amount, 500.0);

      final event2 = makeEvent(
        'INR500 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      expect(parser.parse(event2).amount, 500.0);
    });

    test('Currency format: 500 INR (suffix currency)', () {
      final event = makeEvent(
        '500 INR debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 500.0);
      expect(result.isConfirmedDebit, isTrue);
    });

    test('Currency format: Rs. 1,250.50 (comma thousands)', () {
      final event = makeEvent(
        'Rs. 1,250.50 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 1250.5);
      expect(result.isConfirmedDebit, isTrue);
    });

    test('Currency format: INR 1 250.00 (space thousands)', () {
      final event = makeEvent(
        'INR 1 250.00 debited from A/c XX1234 to Merchant. Ref 12345.',
      );
      final result = parser.parse(event);
      expect(result.amount, 1250.0);
      expect(result.isConfirmedDebit, isTrue);
    });
  });

  group('4. Mandatory Rejection Rules & Negative Cases', () {
    test('OTP containing a rupee amount is strictly rejected as OTP', () {
      final event = makeEvent(
        '123456 is your OTP for transaction of Rs 500.00 at Swiggy on your card ending 1234. Do not share.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.otp);
      expect(result.confidence, MoneyTransactionConfidence.high);
      expect(result.parserReason, MoneyTransactionParser.reasonOtpDetected);
      expect(result.isConfirmedDebit, isFalse);
      expect(result.amount, 0.0);
    });

    test('Failed UPI payment is rejected as failed_transaction', () {
      final event = makeEvent(
        'UPI payment of Rs. 450 to Merchant failed due to bank server issue. If debited, amount will be refunded.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.failed);
      expect(result.confidence, MoneyTransactionConfidence.high);
      expect(
        result.parserReason,
        MoneyTransactionParser.reasonFailedTransaction,
      );
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Reversed debit is rejected as reversal_detected', () {
      final event = makeEvent(
        'Transaction of Rs 500.00 on A/c ending 1234 has been reversed. Refund credited to your account.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.failed);
      expect(result.confidence, MoneyTransactionConfidence.high);
      expect(
        result.parserReason,
        MoneyTransactionParser.reasonReversalDetected,
      );
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Refund credited is rejected from auto-entry', () {
      final event = makeEvent(
        'Refund of INR 1,200.00 credited to your A/c ending 5678 from Amazon. Bal INR 15,000.00.',
      );
      final result = parser.parse(event);
      expect(
        result.classification == MoneyTransactionClassification.failed ||
            result.classification == MoneyTransactionClassification.credit,
        isTrue,
      );
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Balance alert is rejected as balance_only', () {
      final event = makeEvent(
        'Dear Customer, available balance in your A/c ending 1234 is INR 4,520.00 as on 15-10-26. Call 1800xxx for mini statement.',
      );
      final result = parser.parse(event);
      expect(
        result.classification,
        MoneyTransactionClassification.balanceAlert,
      );
      expect(result.confidence, MoneyTransactionConfidence.high);
      expect(result.parserReason, MoneyTransactionParser.reasonBalanceOnly);
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Credit card outstanding amount is rejected as bill_reminder', () {
      final event = makeEvent(
        'Dear Cardholder, your Credit Card statement is ready. Total amount due: Rs 24,500.00, Minimum due: Rs 1,500.00, Due date: 15-Nov-26.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.unknown);
      expect(result.confidence, MoneyTransactionConfidence.high);
      expect(result.parserReason, MoneyTransactionParser.reasonBillReminder);
      expect(result.isConfirmedDebit, isFalse);
    });

    test(
      'Payment request that has not been paid is rejected as payment_request',
      () {
        final event = makeEvent(
          'User XYZ (user@upi) has requested Rs 750.00 from you on GPay. Click here to pay or decline.',
        );
        final result = parser.parse(event);
        expect(result.classification, MoneyTransactionClassification.unknown);
        expect(result.confidence, MoneyTransactionConfidence.high);
        expect(
          result.parserReason,
          MoneyTransactionParser.reasonPaymentRequest,
        );
        expect(result.isConfirmedDebit, isFalse);
      },
    );

    test('Bill reminder is rejected as bill_reminder', () {
      final event = makeEvent(
        'Reminder: Electricity bill of Rs. 2,340.00 is due on 30-Oct-26. Pay now to avoid late fee.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.unknown);
      expect(result.confidence, MoneyTransactionConfidence.high);
      expect(result.parserReason, MoneyTransactionParser.reasonBillReminder);
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Promotional loan offer is rejected as promotional_offer', () {
      final event = makeEvent(
        'Congratulations! You are pre-approved for a personal loan of Rs 5,00,000. Apply now!',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.promotional);
      expect(result.confidence, MoneyTransactionConfidence.high);
      expect(
        result.parserReason,
        MoneyTransactionParser.reasonPromotionalOffer,
      );
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Debit card dispatch message is rejected (no debit action)', () {
      final event = makeEvent(
        'Your new Debit Card ending 4321 has been dispatched via Blue Dart AWB 987654321.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.unknown);
      expect(result.parserReason, MoneyTransactionParser.reasonNoDebitAction);
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Message containing "debit card" but no transaction is rejected', () {
      final event = makeEvent(
        'Protect your Debit Card ending 1234. Never share your ATM PIN or CVV with anyone.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.unknown);
      expect(result.parserReason, MoneyTransactionParser.reasonNoDebitAction);
      expect(result.isConfirmedDebit, isFalse);
    });

    test(
      'Multiple amounts where one is the balance isolates transaction amount',
      () {
        final event = makeEvent(
          'HDFC Bank: Rs 450.00 debited from a/c **1234 on 12-10-26 to Swiggy. UPI Ref: 123456789012. Avl bal: Rs 15400.00',
        );
        final result = parser.parse(event);
        expect(result.amount, 450.0);
        expect(result.isConfirmedDebit, isTrue);
      },
    );

    test(
      'Transaction amount equal to available balance is correctly extracted',
      () {
        final event = makeEvent(
          'Rs 500 debited from A/c XX1234. Avl Bal Rs 500.',
        );
        final result = parser.parse(event);
        expect(result.isConfirmedDebit, isTrue);
        expect(result.amount, 500.0);
      },
    );

    test('Message with ambiguous direction is rejected', () {
      final event = makeEvent(
        'Transfer debit/credit status alert: Rs 500 for A/c XX1234 on 28-10-26.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.unknown);
      expect(
        result.parserReason,
        MoneyTransactionParser.reasonAmbiguousDirection,
      );
      expect(result.isConfirmedDebit, isFalse);
    });

    test('Unsupported foreign currency is rejected', () {
      final event = makeEvent(
        'Transaction of USD 25.00 on your card ending 1234 at Steam.',
      );
      final result = parser.parse(event);
      expect(result.classification, MoneyTransactionClassification.unknown);
      expect(
        result.parserReason,
        MoneyTransactionParser.reasonUnsupportedCurrency,
      );
      expect(result.isConfirmedDebit, isFalse);
    });
  });

  group('5. Deduplication and Timestamps', () {
    test(
      'Two same-amount purchases at different times retain distinct fingerprints',
      () {
        final first = makeEvent(
          'Rs 500 debited to Store on 28-10-2026',
          timestamp: DateTime(2026, 10, 28, 10, 0),
        );
        final later = makeEvent(
          'Rs 500 debited to Store on 28-10-2026',
          timestamp: DateTime(2026, 10, 28, 14, 0),
        );

        final result1 = parser.parse(first);
        final result2 = parser.parse(later);

        expect(result1.fingerprint, isNot(result2.fingerprint));
        expect(result1.isConfirmedDebit, isTrue);
        expect(result2.isConfirmedDebit, isTrue);
      },
    );

    test(
      'Duplicate delivery of identical SMS event produces identical fingerprint',
      () {
        final event1 = makeEvent(
          'Rs 500 debited from A/c XX1234 to Store. Ref 998877',
        );
        final event2 = makeEvent(
          'Rs 500 debited from A/c XX1234 to Store. Ref 998877',
        );

        final result1 = parser.parse(event1);
        final result2 = parser.parse(event2);

        expect(result1.fingerprint, equals(result2.fingerprint));
      },
    );
  });

  group('6. Live-Device Regression Fixture', () {
    test(
      'Anonymized real failed bank message is now recognized as confirmedDebit with high confidence',
      () {
        // Anonymized representation of real-device bank SMS that previously produced 'unknown'
        final realMessage = makeEvent(
          'Dear SBI User, your A/c ending 1234 debited by Rs.500 on 28Oct26 by UPI to user@oksbi Ref No 123456789012. Bal Rs 1000.00 - SBI',
          sender: 'SBIINB',
        );

        final result = parser.parse(realMessage);

        expect(
          result.classification,
          MoneyTransactionClassification.confirmedDebit,
        );
        expect(result.confidence, MoneyTransactionConfidence.high);
        expect(result.amount, 500.0);
        expect(result.currency, 'INR');
        expect(result.accountMask, 'XXXX1234');
        expect(result.referenceId, '123456789012');
        expect(result.merchantOrDescription, 'user@oksbi');
        expect(
          result.parserReason,
          MoneyTransactionParser.reasonConfirmedDebit,
        );
        expect(result.isConfirmedDebit, isTrue);
      },
    );
  });
}
