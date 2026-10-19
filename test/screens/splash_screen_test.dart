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

  testWidgets(
      'SplashScreen renders at 0%, gates animation behind warmup, and transitions to HomeScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Initial frame verification: 3D outlined title, stickers, and 0% counter
    expect(find.text('Cipher!'), findsNWidgets(3));
    expect(find.text('FOREHEAD CHARADES'), findsOneWidget);
    expect(find.text('ACT • GUESS • LAUGH'), findsOneWidget);
    expect(find.text('PARTY READY'), findsOneWidget);
    expect(find.text('Warming up the party decks...'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(3));

    // Advance past post-frame warmup gate (150ms timeout + 400ms settle delay = 550ms)
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance halfway through the 3600ms progress duration (+1800ms = 50%)
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('50%'), findsNWidgets(3));

    // Advance to 100% completion (+1800ms)
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('100%'), findsNWidgets(3));
    expect(find.text("Let's Go!"), findsOneWidget);

    // Advance past 450ms hold delay at 100%
    await tester.pump(const Duration(milliseconds: 500));

    // Trigger route transition frame
    await tester.pump(const Duration(milliseconds: 50));

    // Complete the 400ms fade transition
    await tester.pump(const Duration(milliseconds: 450));

    // Verify transition to HomeScreen
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('Surprise me', skipOffstage: false), findsOneWidget);
  });
}
