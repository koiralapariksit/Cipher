import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/main.dart';
import 'package:heads_guess/screens/home_screen.dart';
import 'package:heads_guess/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();
  });

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const CipherApp());
    expect(find.textContaining('Cipher'), findsWidgets);

    // Pump through the 3600ms arcade progress, hold delay, and fade transition
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
  });
}
