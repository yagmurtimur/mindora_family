import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'screens/common/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.instance.initialize();

  runApp(const MindoraFamilyApp());
}

class MindoraFamilyApp extends StatelessWidget {
  const MindoraFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mindora Family',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
