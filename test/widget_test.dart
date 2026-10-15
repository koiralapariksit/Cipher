import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const HeadsGuessApp());
    expect(find.text('Heads Guess'), findsOneWidget);
  });
}
