import 'package:flutter_test/flutter_test.dart';
import 'package:nila_dance_tracker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Dance tracker dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const NilaDanceApp());
    await tester.pumpAndSettle();

    expect(find.text("Nila's Dance Tracker"), findsOneWidget);
    expect(find.text('Hey Nila! 💜'), findsOneWidget);
    expect(find.text('Start Practice'), findsOneWidget);
  });
}