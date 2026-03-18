import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';

void main() {
  runApp(const AcomApp());
}

class AcomApp extends StatelessWidget {
  const AcomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACOM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(), // 👈 CAMBIO AQUÍ
    );
  }
}