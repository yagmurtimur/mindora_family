import 'package:flutter/material.dart';
import '../../services/ios_screen_time_service.dart';

class IosBridgeTestScreen extends StatefulWidget {
  const IosBridgeTestScreen({super.key});

  @override
  State<IosBridgeTestScreen> createState() => _IosBridgeTestScreenState();
}

class _IosBridgeTestScreenState extends State<IosBridgeTestScreen> {
  final IosScreenTimeService _service = IosScreenTimeService();

  String _message = 'Henüz test edilmedi.';
  bool _loading = false;

  Future<void> _testBridge() async {
    setState(() {
      _loading = true;
      _message = 'Bağlantı deneniyor...';
    });

    try {
      final result = await _service.ping();
      setState(() {
        _message = 'BAŞARILI\n$result';
      });
    } catch (e) {
      setState(() {
        _message = 'HATA\n$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iOS Bridge Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _testBridge,
                child: Text(
                  _loading ? 'Test ediliyor...' : 'iOS Bağlantısını Test Et',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
