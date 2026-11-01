import 'package:arc/features/notifications/screens/notification_center_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native TypeToken failures are replaced with a recovery message', () {
    const nativeError =
        'IllegalStateException: TypeToken must be created with a type argument '
        'at loadScheduledNotifications';

    final message = notificationErrorMessage(nativeError);

    expect(message, contains('Scheduled reminders could not be read'));
    expect(message, isNot(contains('IllegalStateException')));
    expect(message, isNot(contains('TypeToken')));
  });

  test('unknown failures use a short retry message', () {
    expect(
      notificationErrorMessage('SocketException: connection reset'),
      'Reminder status is temporarily unavailable. Pull down to retry.',
    );
  });
}
