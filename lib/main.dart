import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StorageService().init();
  runApp(const CipherApp());
}

class CipherApp extends StatelessWidget {
  const CipherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cipher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: appBgBottom,
        colorScheme: const ColorScheme.dark(
          primary: appText,
          secondary: appText,
          surface: appBgBottom,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}