import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Testi')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              await NotificationService.instance.showNotification(
                id: 999,
                title: 'Mindora Test Bildirimi',
                body: 'Kanka, bildirim sistemi çalışıyor! 💗',
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bildirim gönderme isteği tamamlandı.'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bildirim hatası: $e')),
                );
              }
            }
          },
          child: const Text('Test Bildirimi Gönder'),
        ),
      ),
    );
  }
}
