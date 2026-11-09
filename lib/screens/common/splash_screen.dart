import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Test edebilmemiz için otomatik geçişi şimdilik kapattık.
    // Test bitince eski 2 saniyelik geçişi geri ekleyebiliriz.
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.instance.showNotification(
        id: 1,
        title: 'Mindora Family',
        body: 'Bildirim sistemi başarıyla çalışıyor! 🎉',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test bildirimi gönderildi!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bildirim gönderilemedi: $e')));
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Mindora Family',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dijital yaşamda birlikte daha dengeli',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendTestNotification,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Test Bildirimi Gönder'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _goToLogin,
                child: const Text('Giriş ekranına geç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
