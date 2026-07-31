import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'package:tecnigo/screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'package:tecnigo/theme/app_theme.dart';  

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TecniGoApp());
}

class TecniGoApp extends StatelessWidget {
  const TecniGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: AppTheme.dark,

      home: const LoginScreen(),
    );
  }
}