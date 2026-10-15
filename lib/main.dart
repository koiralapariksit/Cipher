import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'theme/luxury_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();
  runApp(const HeadsGuessApp());
}

class HeadsGuessApp extends StatelessWidget {
  const HeadsGuessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heads Guess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBlack,
        colorScheme: const ColorScheme.dark(
          primary: kGold,
          secondary: kGold,
          surface: kPanelBottom,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}