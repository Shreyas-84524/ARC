import 'package:flutter_test/flutter_test.dart';
import 'package:arc/core/utils/display_name_utils.dart';

void main() {
  group('DisplayNameUtils Unit Tests', () {
    test('normalize trims and collapses consecutive whitespace', () {
      expect(DisplayNameUtils.normalize('   Shreyas   Shigwan   '), 'Shreyas Shigwan');
      expect(DisplayNameUtils.normalize('Aman\t\nSharma'), 'Aman Sharma');
      expect(DisplayNameUtils.normalize('   Rohit   '), 'Rohit');
      expect(DisplayNameUtils.normalize(''), '');
    });

    test('extractFirstName extracts first word while preserving capitalization and script', () {
      expect(DisplayNameUtils.extractFirstName('Shreyas Shigwan'), 'Shreyas');
      expect(DisplayNameUtils.extractFirstName('Aman Sharma'), 'Aman');
      expect(DisplayNameUtils.extractFirstName('Sachi Patel'), 'Sachi');
      expect(DisplayNameUtils.extractFirstName('Rohit'), 'Rohit');
      expect(DisplayNameUtils.extractFirstName('  shreyas   shigwan  '), 'shreyas');
      expect(DisplayNameUtils.extractFirstName('   श्रेयस   शिगवण  '), 'श्रेयस');
      expect(DisplayNameUtils.extractFirstName('Anne-Marie Dubois'), 'Anne-Marie');
      expect(DisplayNameUtils.extractFirstName(''), 'User');
      expect(DisplayNameUtils.extractFirstName(null), 'User');
      expect(DisplayNameUtils.extractFirstName(null, fallback: 'Friend'), 'Friend');
    });

    test('validates valid standard names', () {
      expect(DisplayNameUtils.validate('Shreyas'), isNull);
      expect(DisplayNameUtils.validate('Shreyas Shigwan'), isNull);
      expect(DisplayNameUtils.validate('Aman Sharma'), isNull);
      expect(DisplayNameUtils.validate('Anne-Marie'), isNull);
      expect(DisplayNameUtils.validate("O'Connor"), isNull);
      expect(DisplayNameUtils.validate('Dr. A. Sharma'), isNull);
      expect(DisplayNameUtils.validate('Sachi Patel'), isNull);
    });

    test('validates legitimate international and Indian-language Unicode names', () {
      expect(DisplayNameUtils.validate('श्रेयस'), isNull);
      expect(DisplayNameUtils.validate('श्रेयस शिगवण'), isNull);
      expect(DisplayNameUtils.validate('अमन शर्मा'), isNull);
      expect(DisplayNameUtils.validate('रोहित'), isNull);
      expect(DisplayNameUtils.validate('సచి పటేల్'), isNull);
      expect(DisplayNameUtils.validate('José María'), isNull);
      expect(DisplayNameUtils.validate('Renée Dupont'), isNull);
    });

    test('rejects empty or whitespace-only names', () {
      expect(DisplayNameUtils.validate(''), 'Display name cannot be empty.');
      expect(DisplayNameUtils.validate('   '), 'Display name cannot be empty.');
      expect(DisplayNameUtils.validate(null), 'Display name cannot be empty.');
    });

    test('rejects names shorter than 2 characters or longer than 50 characters', () {
      expect(DisplayNameUtils.validate('A'), 'Display name must be at least 2 characters long.');
      expect(
        DisplayNameUtils.validate('A' * 51),
        'Display name cannot exceed 50 characters.',
      );
      expect(DisplayNameUtils.validate('A' * 50), isNull);
    });

    test('rejects names containing emojis or pictorial symbols', () {
      expect(DisplayNameUtils.validate('Shreyas 😊'), 'Display name cannot contain emojis or symbols.');
      expect(DisplayNameUtils.validate('Aman 🔥'), 'Display name cannot contain emojis or symbols.');
      expect(DisplayNameUtils.validate('🚀 Rohit'), 'Display name cannot contain emojis or symbols.');
      expect(DisplayNameUtils.validate('Sachi ✨'), 'Display name cannot contain emojis or symbols.');
      expect(DisplayNameUtils.validate('Star ⭐ User'), 'Display name cannot contain emojis or symbols.');
      expect(DisplayNameUtils.validate('Heart ❤️ Name'), 'Display name cannot contain emojis or symbols.');
    });

    test('rejects names containing disallowed symbols or markup', () {
      expect(DisplayNameUtils.validate('Shreyas @ Arc'), 'Display name can only contain letters, spaces, hyphens, periods, and apostrophes.');
      expect(DisplayNameUtils.validate('User #1'), 'Display name can only contain letters, spaces, hyphens, periods, and apostrophes.');
      expect(DisplayNameUtils.validate('<script>'), 'Display name can only contain letters, spaces, hyphens, periods, and apostrophes.');
      expect(DisplayNameUtils.validate('12345'), 'Display name can only contain letters, spaces, hyphens, periods, and apostrophes.');
    });
  });
}
