import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

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
        scaffoldBackgroundColor: appBgBottom,
        colorScheme: const ColorScheme.dark(
          primary: appText,
          secondary: appText,
          surface: appBgBottom,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}