import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/screens/home_screen.dart';
import 'package:heads_guess/screens/splash_screen.dart';
import 'package:heads_guess/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();
  });

  testWidgets('SplashScreen displays branding, badges, tips, and progress bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Initial branding and badge verification (triple-stacked neo-brutalist outlined text)
    expect(find.text('Cipher!'), findsNWidgets(3));
    expect(find.text('FOREHEAD CHARADES'), findsOneWidget);
    expect(find.text('ACT • GUESS • LAUGH'), findsOneWidget);
    expect(find.text('PARTY READY'), findsOneWidget);
    expect(find.text('Warming up the party decks...'), findsOneWidget);
    expect(find.text('1%'), findsNWidgets(3));

    // Advance periodic progress timer steps
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance to 100% completion and trigger navigation
    await tester.pump(const Duration(milliseconds: 2500));
    // Advance transition fade frames
    await tester.pump(const Duration(milliseconds: 400));

    // Verify transition to HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Surprise me'), findsOneWidget);
  });
}
