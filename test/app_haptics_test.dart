import 'package:arc/core/services/app_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.arc.arc/haptics');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('preserves the four configured haptic strengths on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });

    await AppHaptics.selectionClick();
    await AppHaptics.lightImpact();
    await AppHaptics.mediumImpact();
    await AppHaptics.heavyImpact();

    expect(calls.map((call) => call.method), everyElement('vibrate'));
    expect(calls.map((call) => call.arguments['type']), <String>[
      'selectionClick',
      'lightImpact',
      'mediumImpact',
      'heavyImpact',
    ]);
  });
}
