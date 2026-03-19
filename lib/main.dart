import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar .env
  await dotenv.load(fileName: '.env');

  // Inicializar Firebase
  await FirebaseService.init();

  // Orientación solo vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Barra de estado transparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

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
      home: const SplashScreen(),
    );
  }
}