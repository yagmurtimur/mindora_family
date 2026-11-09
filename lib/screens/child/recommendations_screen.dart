import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ChildRecommendationsScreen extends StatefulWidget {
  const ChildRecommendationsScreen({super.key});

  @override
  State<ChildRecommendationsScreen> createState() =>
      _ChildRecommendationsScreenState();
}

class _ChildRecommendationsScreenState
    extends State<ChildRecommendationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;

  List<Map<String, dynamic>> _recommendations = [];

  double _screenTime = 0;
  double _dailyGoal = 120;

  double _sleepHours = 0;
  double _physicalActivityMinutes = 0;
  double _workStudyMinutes = 0;

  double _socialMediaMinutes = 0;
  double _gamingMinutes = 0;
  double _videoMinutes = 0;

  double _anxietyScore = 0;

  String _riskLevel = 'Henüz analiz yok';
  double _riskProbability = 0;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  String get _dateId {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadRecommendations() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);

      // ------------------------------------------------------------
      // 1. EKRAN SÜRESİ
      // ------------------------------------------------------------

      final screenTimeSnapshot = await userRef
          .collection('screenTime')
          .doc(_dateId)
          .get();

      if (screenTimeSnapshot.exists) {
        final data = screenTimeSnapshot.data();

        _screenTime = _toDouble(data?['totalMinutes']);
        _dailyGoal = _toDouble(data?['dailyGoalMinutes']);

        if (_dailyGoal <= 0) {
          _dailyGoal = 120;
        }

        _socialMediaMinutes = _toDouble(data?['socialMediaMinutes']);

        _gamingMinutes = _toDouble(data?['gamingMinutes']);

        _videoMinutes = _toDouble(data?['videoMinutes']);
      }

      // ------------------------------------------------------------
      // 2. GÜNLÜK İSTATİSTİKLER
      // ------------------------------------------------------------

      final dailyStatsSnapshot = await userRef
          .collection('dailyStats')
          .doc(_dateId)
          .get();

      if (dailyStatsSnapshot.exists) {
        final data = dailyStatsSnapshot.data();

        _sleepHours = _toDouble(data?['sleepHours']);

        _physicalActivityMinutes = _toDouble(data?['physicalActivityMinutes']);

        _workStudyMinutes = _toDouble(data?['workStudyMinutes']);
      }

      // ------------------------------------------------------------
      // 3. ÖZ DEĞERLENDİRME
      // ------------------------------------------------------------

      final assessmentSnapshot = await userRef
          .collection('assessments')
          .doc(_dateId)
          .get();

      if (assessmentSnapshot.exists) {
        final data = assessmentSnapshot.data();

        _anxietyScore = _toDouble(data?['anxietyScore']);
      }

      // ------------------------------------------------------------
      // 4. AI ANALİZİ
      // ------------------------------------------------------------

      final aiSnapshot = await userRef
          .collection('aiAnalysis')
          .doc(_dateId)
          .get();

      if (aiSnapshot.exists) {
        final data = aiSnapshot.data();

        _riskLevel = data?['riskLevel']?.toString() ?? 'Belirlenemedi';

        _riskProbability = _toDouble(data?['riskProbability']);
      }

      // ------------------------------------------------------------
      // 5. ÖNERİLERİ OLUŞTUR
      // ------------------------------------------------------------

      final generatedRecommendations = _generateRecommendations();

      _recommendations = generatedRecommendations;

      // ------------------------------------------------------------
      // 6. FIREBASE'E KAYDET
      // ------------------------------------------------------------

      await _saveRecommendations();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Öneriler yüklenirken hata: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Öneriler yüklenirken bir hata oluştu.'),
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // SAYISAL DEĞER DÖNÜŞTÜRME
  // ------------------------------------------------------------

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value.toDouble();
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ------------------------------------------------------------
  // ÖNERİLERİ OLUŞTUR
  // ------------------------------------------------------------

  List<Map<String, dynamic>> _generateRecommendations() {
    final List<Map<String, dynamic>> recommendations = [];

    // ------------------------------------------------------------
    // RİSK DURUMU
    // ------------------------------------------------------------

    if (_riskLevel == 'Riskli' || _riskProbability >= 0.70) {
      recommendations.add({
        'icon': Icons.warning_amber_rounded,
        'title': 'Telefon kullanımına dikkat et',
        'description':
            'Bugünkü verilerine göre telefon kullanımını biraz azaltmak '
            've gün içinde daha fazla ekran molası vermek faydalı olabilir.',
        'category': 'risk',
      });
    } else if (_riskLevel == 'Normal' || _riskProbability < 0.40) {
      recommendations.add({
        'icon': Icons.check_circle_outline_rounded,
        'title': 'Dijital dengen iyi gidiyor',
        'description':
            'Bugünkü kullanım verilerin dengeli görünüyor. '
            'Bu düzeni korumaya ve ekran kullanımını kontrollü '
            'şekilde sürdürmeye devam edebilirsin.',
        'category': 'risk',
      });
    }

    // ------------------------------------------------------------
    // EKRAN SÜRESİ
    // ------------------------------------------------------------

    if (_screenTime > _dailyGoal && _dailyGoal > 0) {
      final difference = (_screenTime - _dailyGoal).round();

      recommendations.add({
        'icon': Icons.phone_android_rounded,
        'title': 'Ekran sürene biraz ara ver',
        'description':
            'Bugün ekran süren hedefinin yaklaşık $difference dakika '
            'üzerinde. Kısa telefon molaları vermeyi deneyebilirsin.',
        'category': 'screenTime',
      });
    } else if (_screenTime > 0 && _screenTime <= _dailyGoal) {
      recommendations.add({
        'icon': Icons.timer_outlined,
        'title': 'Ekran süreni dengede tut',
        'description':
            'Bugünkü ekran süren hedefinin içinde. '
            'Bu dengeyi korumak için gün boyunca kısa molalar vermeye devam et.',
        'category': 'screenTime',
      });
    }

    // ------------------------------------------------------------
    // SOSYAL MEDYA
    // ------------------------------------------------------------

    if (_socialMediaMinutes >= 120) {
      recommendations.add({
        'icon': Icons.people_alt_rounded,
        'title': 'Sosyal medyaya mola ver',
        'description':
            'Bugün sosyal medya kullanımın oldukça yüksek. '
            'Bir süre bildirimleri kapatıp telefondan uzaklaşmayı deneyebilirsin.',
        'category': 'socialMedia',
      });
    } else if (_socialMediaMinutes >= 60) {
      recommendations.add({
        'icon': Icons.notifications_none_rounded,
        'title': 'Bildirimlerini azalt',
        'description':
            'Sosyal medya kullanımını daha kontrollü tutmak için '
            'gereksiz bildirimleri kapatmayı deneyebilirsin.',
        'category': 'socialMedia',
      });
    }

    // ------------------------------------------------------------
    // OYUN
    // ------------------------------------------------------------

    if (_gamingMinutes >= 120) {
      recommendations.add({
        'icon': Icons.sports_esports_rounded,
        'title': 'Oyun sürene sınır koy',
        'description':
            'Bugünkü oyun süren yüksek görünüyor. '
            'Bir sonraki oyun seansından önce kısa bir mola vermeyi deneyebilirsin.',
        'category': 'gaming',
      });
    } else if (_gamingMinutes >= 60) {
      recommendations.add({
        'icon': Icons.gamepad_rounded,
        'title': 'Oyun molalarını planla',
        'description':
            'Oyun oynarken belirli aralıklarla mola vermek '
            'gün içindeki ekran kullanımını dengelemene yardımcı olabilir.',
        'category': 'gaming',
      });
    }

    // ------------------------------------------------------------
    // VİDEO
    // ------------------------------------------------------------

    if (_videoMinutes >= 120) {
      recommendations.add({
        'icon': Icons.play_circle_outline_rounded,
        'title': 'Video izlemeye ara ver',
        'description':
            'Bugün video içeriklerinde geçirdiğin süre yüksek. '
            'Bir süre ekran yerine farklı bir aktivite deneyebilirsin.',
        'category': 'video',
      });
    }

    // ------------------------------------------------------------
    // UYKU
    // ------------------------------------------------------------

    if (_sleepHours > 0 && _sleepHours < 7) {
      recommendations.add({
        'icon': Icons.bedtime_rounded,
        'title': 'Uyku düzenine dikkat et',
        'description':
            'Son kaydettiğin uyku süresi düşük görünüyor. '
            'Uyumadan önce ekran kullanımını azaltıp daha düzenli '
            'bir uyku rutini oluşturmayı deneyebilirsin.',
        'category': 'sleep',
      });
    } else if (_sleepHours >= 7) {
      recommendations.add({
        'icon': Icons.nightlight_round,
        'title': 'Uyku düzenini koru',
        'description':
            'Kaydettiğin uyku süresi iyi bir düzeyde. '
            'Uyku öncesinde ekran kullanımını sınırlayarak bu düzeni koruyabilirsin.',
        'category': 'sleep',
      });
    }

    // ------------------------------------------------------------
    // FİZİKSEL AKTİVİTE
    // ------------------------------------------------------------

    if (_physicalActivityMinutes < 30) {
      recommendations.add({
        'icon': Icons.directions_run_rounded,
        'title': 'Biraz hareket et',
        'description':
            'Bugünkü fiziksel aktiviten düşük görünüyor. '
            '10-15 dakikalık kısa bir yürüyüş veya esneme molası verebilirsin.',
        'category': 'activity',
      });
    } else {
      recommendations.add({
        'icon': Icons.directions_walk_rounded,
        'title': 'Hareket etmeye devam et',
        'description':
            'Bugün fiziksel aktivite yaptığını görüyoruz. '
            'Kısa hareket molalarını gün içinde sürdürmeye devam et.',
        'category': 'activity',
      });
    }

    // ------------------------------------------------------------
    // DERS / ÇALIŞMA
    // ------------------------------------------------------------

    if (_workStudyMinutes < 60) {
      recommendations.add({
        'icon': Icons.menu_book_rounded,
        'title': 'Kısa bir çalışma zamanı ayır',
        'description':
            'Bugünkü çalışma süren düşük görünüyor. '
            'Telefonunu bir süre kenara bırakıp 25-30 dakikalık '
            'odaklanma seansı deneyebilirsin.',
        'category': 'study',
      });
    } else {
      recommendations.add({
        'icon': Icons.auto_stories_rounded,
        'title': 'Çalışma rutinini koru',
        'description':
            'Bugün ders veya çalışma için zaman ayırmışsın. '
            'Odaklanma süreni korumak için planlı molalar vermeyi unutma.',
        'category': 'study',
      });
    }

    // ------------------------------------------------------------
    // ÖZ DEĞERLENDİRME
    // ------------------------------------------------------------

    if (_anxietyScore >= 7) {
      recommendations.add({
        'icon': Icons.self_improvement_rounded,
        'title': 'Kendine biraz zaman ayır',
        'description':
            'Öz-değerlendirmendeki puanın yüksek görünüyor. '
            'Bir süre ekranlardan uzaklaşıp nefes egzersizi, '
            'yürüyüş veya sevdiğin sakin bir aktivite yapmayı deneyebilirsin.',
        'category': 'wellbeing',
      });
    } else if (_anxietyScore >= 4) {
      recommendations.add({
        'icon': Icons.spa_rounded,
        'title': 'Kısa bir rahatlama molası ver',
        'description':
            'Kendini nasıl hissettiğini takip etmek önemli. '
            'Gün içinde birkaç dakikalık sakin bir mola vermeyi deneyebilirsin.',
        'category': 'wellbeing',
      });
    }

    // ------------------------------------------------------------
    // HİÇ VERİ YOKSA
    // ------------------------------------------------------------

    if (recommendations.isEmpty) {
      recommendations.add({
        'icon': Icons.auto_awesome_rounded,
        'title': 'Bugün kendine zaman ayır',
        'description':
            'Telefonundan biraz uzaklaşıp sevdiğin bir aktiviteye '
            '30 dakika ayırmayı deneyebilirsin.',
        'category': 'general',
      });
    }

    // Çok fazla öneri oluşmasını engelle
    if (recommendations.length > 8) {
      return recommendations.take(8).toList();
    }

    return recommendations;
  }

  // ------------------------------------------------------------
  // FIREBASE'E ÖNERİLERİ KAYDET
  // ------------------------------------------------------------

  Future<void> _saveRecommendations() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final recommendationData = _recommendations.map((recommendation) {
        return {
          'title': recommendation['title'],
          'description': recommendation['description'],
          'category': recommendation['category'],
          'icon': recommendation['icon'].codePoint,
        };
      }).toList();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('recommendations')
          .doc(_dateId)
          .set({
            'recommendations': recommendationData,
            'riskLevel': _riskLevel,
            'riskProbability': _riskProbability,
            'screenTime': _screenTime,
            'dailyGoal': _dailyGoal,
            'sleepHours': _sleepHours,
            'physicalActivityMinutes': _physicalActivityMinutes,
            'workStudyMinutes': _workStudyMinutes,
            'socialMediaMinutes': _socialMediaMinutes,
            'gamingMinutes': _gamingMinutes,
            'videoMinutes': _videoMinutes,
            'anxietyScore': _anxietyScore,
            'generatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Öneriler Firebase kaydedilirken hata: $e');
    }
  }

  // ------------------------------------------------------------
  // EKRAN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Öneriler')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecommendations,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildTodayRecommendation(),

                  const SizedBox(height: 24),

                  const Text(
                    'Sana Özel Öneriler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 14),

                  ..._recommendations.map(
                    (recommendation) => _recommendation(
                      icon: recommendation['icon'],
                      title: recommendation['title'],
                      description: recommendation['description'],
                    ),
                  ),

                  const SizedBox(height: 10),

                  _buildDataSummary(),
                ],
              ),
            ),
    );
  }

  // ------------------------------------------------------------
  // BUGÜNÜN ÖNERİSİ
  // ------------------------------------------------------------

  Widget _buildTodayRecommendation() {
    if (_recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstRecommendation = _recommendations.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),

          const SizedBox(height: 14),

          const Text(
            'Bugünün Önerisi ✨',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            firstRecommendation['description'],
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ÖNERİ KARTI
  // ------------------------------------------------------------

  Widget _recommendation({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // VERİ ÖZETİ
  // ------------------------------------------------------------

  Widget _buildDataSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugünkü Verilerin',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),

          const SizedBox(height: 16),

          _summaryRow(
            Icons.phone_android_rounded,
            'Ekran süresi',
            '${_screenTime.round()} dk',
          ),

          _summaryRow(
            Icons.bedtime_rounded,
            'Uyku',
            _sleepHours > 0
                ? '${_sleepHours.toStringAsFixed(1)} saat'
                : 'Veri yok',
          ),

          _summaryRow(
            Icons.directions_run_rounded,
            'Fiziksel aktivite',
            '${_physicalActivityMinutes.round()} dk',
          ),

          _summaryRow(
            Icons.menu_book_rounded,
            'Ders / çalışma',
            '${_workStudyMinutes.round()} dk',
          ),

          _summaryRow(
            Icons.people_alt_rounded,
            'Sosyal medya',
            '${_socialMediaMinutes.round()} dk',
          ),

          _summaryRow(
            Icons.sports_esports_rounded,
            'Oyun',
            '${_gamingMinutes.round()} dk',
          ),

          if (_riskLevel != 'Henüz analiz yok')
            _summaryRow(Icons.analytics_rounded, 'AI risk durumu', _riskLevel),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),

          const SizedBox(width: 10),

          Expanded(
            child: Text(title, style: TextStyle(color: Colors.grey.shade700)),
          ),

          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
