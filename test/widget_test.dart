import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/main.dart';

void main() {
  testWidgets('App renders successfully and shows dashboard contents', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: ProjectArcApp(),
      ),
    );

    // Let all animations complete and timers settle
    await tester.pumpAndSettle();

    // Verify that the app launches and shows text from the dashboard.
    expect(find.textContaining("Today's Progress"), findsOneWidget);
  });
}
