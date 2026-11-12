import 'dart:io';
import 'package:flutter/services.dart';

class IosScreenTimeService {
  static const MethodChannel _channel = MethodChannel('mindora/screen_time');

  Future<Map<String, dynamic>> ping() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Bu servis yalnızca iOS içindir.');
    }

    final result = await _channel.invokeMapMethod<String, dynamic>('ping');

    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'iOS servisinden yanıt alınamadı.',
      );
    }

    return result;
  }
}
