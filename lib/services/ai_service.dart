import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'ai_api_result.dart';

class AiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<AiApiResult> predict({
    required double age,
    required String gender,
    required double dailyScreenTime,
    required double sleepHours,
    required double physicalActivityHours,
    required double socialMediaHours,
    required double gamingHours,
    required double workStudyHours,
    required double notificationsPerDay,
    required double anxietyScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'age': age,
          'gender': gender,
          'daily_screen_time': dailyScreenTime,
          'sleep_hours': sleepHours,
          'physical_activity_hours': physicalActivityHours,
          'social_media_hours': socialMediaHours,
          'gaming_hours': gamingHours,
          'work_study_hours': workStudyHours,
          'notifications_per_day': notificationsPerDay,
          'anxiety_score': anxietyScore,
        }),
      );

      if (response.statusCode != 200) {
        return AiApiResult.failure(
          'AI servisine ulaşılamadı (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded.containsKey('error')) {
        return AiApiResult.failure(
          decoded['error']?.toString() ?? 'Tahmin yapılamadı.',
        );
      }

      return AiApiResult.success(decoded);
    } catch (_) {
      return AiApiResult.failure(
        'AI servisine bağlanılamadı. Yerel API\'nin çalıştığından emin olun.',
      );
    }
  }
}
