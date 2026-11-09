import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../services/ai_service.dart';

class ParentAiAnalysisScreen extends StatefulWidget {
  const ParentAiAnalysisScreen({super.key});

  @override
  State<ParentAiAnalysisScreen> createState() => _ParentAiAnalysisScreenState();
}

class _ParentAiAnalysisScreenState extends State<ParentAiAnalysisScreen> {
  bool _isLoading = true;
  String? _error;

  String _childName = 'Çocuk';

  String _riskLevel = 'Analiz bekleniyor';

  double _riskProbability = 0;
  double _normalProbability = 0;

  double _screenTime = 0;
  int _dailyGoalMinutes = 150;

  double _sleepHours = 0;
  double _physicalActivityHours = 0;
  double _socialMediaHours = 0;
  double _gamingHours = 0;
  double _workStudyHours = 0;

  double _notificationsPerDay = 50;

  double _anxietyScore = 0;

  double _age = 15;
  String _gender = 'Other';

  // ============================================================
  // MOOD VERİLERİ
  // ============================================================

  String _mood = 'Henüz girilmedi';
  String _moodTitle = 'Bugün ruh hali kaydedilmedi';
  String _moodEmoji = '🙂';

  @override
  void initState() {
    super.initState();
    _loadAndAnalyze();
  }

  // ============================================================
  // ANALİZİ YÜKLE VE ÇALIŞTIR
  // ============================================================

  Future<void> _loadAndAnalyze() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final parent = FirebaseAuth.instance.currentUser;

      if (parent == null) {
        throw Exception('Oturum açmış parent bulunamadı.');
      }

      final firestore = FirebaseFirestore.instance;

      // ========================================================
      // 1. PARENT
      // ========================================================

      final parentDoc = await firestore
          .collection('users')
          .doc(parent.uid)
          .get();

      final parentData = parentDoc.data();

      String? childId;

      final childIds = parentData?['childIds'];

      if (childIds is List && childIds.isNotEmpty) {
        childId = childIds.first.toString();
      }

      // ========================================================
      // 2. childIds YOKSA parentId ÜZERİNDEN BUL
      // ========================================================

      if (childId == null) {
        final childQuery = await firestore
            .collection('users')
            .where('parentId', isEqualTo: parent.uid)
            .where('role', isEqualTo: 'child')
            .limit(1)
            .get();

        if (childQuery.docs.isNotEmpty) {
          childId = childQuery.docs.first.id;
        }
      }

      if (childId == null) {
        throw Exception('Bağlı çocuk bulunamadı.');
      }

      // ========================================================
      // 3. ÇOCUK PROFİLİ
      // ========================================================

      final childDoc = await firestore.collection('users').doc(childId).get();

      final childData = childDoc.data();

      if (childData != null) {
        _childName = childData['name']?.toString() ?? 'Çocuk';

        _age = _toDouble(childData['age'], 15);

        _gender = childData['gender']?.toString() ?? 'Other';

        if (_gender == 'Erkek') {
          _gender = 'Male';
        } else if (_gender == 'Kadın') {
          _gender = 'Female';
        }
      }

      // ========================================================
      // 4. BUGÜNÜN TARİHİ
      // ========================================================

      final now = DateTime.now();

      final dateId =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final userRef = firestore.collection('users').doc(childId);

      // ========================================================
      // 5. EKRAN SÜRESİ
      // ========================================================

      final screenTimeDoc = await userRef
          .collection('screenTime')
          .doc(dateId)
          .get();

      final screenTimeData = screenTimeDoc.data();

      if (screenTimeData != null) {
        final totalMinutes = _toDouble(screenTimeData['totalMinutes'], 0);

        final socialMinutes = _toDouble(
          screenTimeData['socialMediaMinutes'],
          0,
        );

        final gamingMinutes = _toDouble(screenTimeData['gamingMinutes'], 0);

        _screenTime = totalMinutes / 60;

        _socialMediaHours = socialMinutes / 60;

        _gamingHours = gamingMinutes / 60;

        // Günlük hedef için fallback
        _dailyGoalMinutes = _toDouble(
          screenTimeData['dailyGoalMinutes'],
          150,
        ).toInt();
      } else {
        _screenTime = 0;
        _socialMediaHours = 0;
        _gamingHours = 0;
        _dailyGoalMinutes = 150;
      }

      // ========================================================
      // 5.1 MERKEZİ GÜNLÜK HEDEF
      // ========================================================
      //
      // Parent tarafından belirlenen asıl hedef:
      //
      // users/{childId}/goals/current
      // dailyScreenTimeGoal
      //
      // Bu değer varsa screenTime içindeki günlük snapshot
      // değerinin üzerine yazılır.
      // ========================================================

      final goalDoc = await userRef.collection('goals').doc('current').get();

      if (goalDoc.exists) {
        final goalData = goalDoc.data();

        final goal = _toDouble(
          goalData?['dailyScreenTimeGoal'],
          _dailyGoalMinutes.toDouble(),
        ).toInt();

        if (goal > 0) {
          _dailyGoalMinutes = goal;
        }
      }

      // ========================================================
      // 6. GÜNLÜK VERİLER
      // ========================================================

      final dailyStatsDoc = await userRef
          .collection('dailyStats')
          .doc(dateId)
          .get();

      final dailyStatsData = dailyStatsDoc.data();

      if (dailyStatsData != null) {
        _sleepHours = _toDouble(dailyStatsData['sleepHours'], 0);

        final physicalActivityMinutes = _toDouble(
          dailyStatsData['physicalActivityMinutes'],
          0,
        );

        _physicalActivityHours = physicalActivityMinutes / 60;

        final workStudyMinutes = _toDouble(
          dailyStatsData['workStudyMinutes'],
          0,
        );

        _workStudyHours = workStudyMinutes / 60;
      } else {
        _sleepHours = 0;
        _physicalActivityHours = 0;
        _workStudyHours = 0;
      }

      // ========================================================
      // 7. ÖZ-DEĞERLENDİRME
      // ========================================================

      final assessmentDoc = await userRef
          .collection('assessments')
          .doc(dateId)
          .get();

      final assessmentData = assessmentDoc.data();

      if (assessmentData != null) {
        _anxietyScore = _toDouble(assessmentData['anxietyScore'], 0);
      } else {
        throw Exception(
          'Bugün için öz-değerlendirme bulunamadı. '
          'Çocuğun günlük değerlendirmeyi tamamlaması gerekiyor.',
        );
      }

      // ========================================================
      // 8. MOOD
      // ========================================================

      final moodDoc = await userRef.collection('moods').doc(dateId).get();

      final moodData = moodDoc.data();

      if (moodData != null) {
        _mood = moodData['mood']?.toString() ?? 'unknown';

        _moodTitle = moodData['moodTitle']?.toString() ?? 'Ruh hali kaydedildi';

        _moodEmoji = moodData['emoji']?.toString() ?? '🙂';
      } else {
        _mood = 'Henüz girilmedi';
        _moodTitle = 'Bugün ruh hali kaydedilmedi';
        _moodEmoji = '🙂';
      }

      // ========================================================
      // 9. AI TAHMİNİ
      // ========================================================
      //
      // Mood Random Forest modeline gönderilmiyor.
      //
      // Çünkü model mood feature'ı ile eğitilmedi.
      //
      // Günlük hedef de model feature'ı değildir.
      // Hedef, AI sonucunun yorumlanmasında bağlamsal
      // değişken olarak kullanılmaktadır.
      // ========================================================

      final apiResult = await AiService.predict(
        age: _age,
        gender: _gender,
        dailyScreenTime: _screenTime,
        sleepHours: _sleepHours,
        physicalActivityHours: _physicalActivityHours,
        socialMediaHours: _socialMediaHours,
        gamingHours: _gamingHours,
        workStudyHours: _workStudyHours,
        notificationsPerDay: _notificationsPerDay,
        anxietyScore: _anxietyScore,
      );

      if (!apiResult.success) {
        throw Exception(apiResult.errorMessage ?? 'AI analizi tamamlanamadı.');
      }

      final result = apiResult.data as Map<String, dynamic>;

      // ========================================================
      // 10. AI SONUÇLARI
      // ========================================================

      final prediction = _toDouble(result['prediction'], 0).toInt();

      final riskLevel = result['risk_level']?.toString() ?? 'Bilinmiyor';

      final riskProbability = _toDouble(result['risk_probability'], 0);

      final normalProbability = _toDouble(result['normal_probability'], 0);

      // ========================================================
      // 11. FIREBASE'E KAYDET
      // ========================================================

      await userRef.collection('aiAnalysis').doc(dateId).set({
        // ----------------------------------------------------
        // AI SONUCU
        // ----------------------------------------------------

        'prediction': prediction,

        'riskLevel': riskLevel,

        'riskProbability': riskProbability,

        'normalProbability': normalProbability,

        // ----------------------------------------------------
        // ÇOCUK BİLGİLERİ
        // ----------------------------------------------------
        'age': _age,

        'gender': _gender,

        // ----------------------------------------------------
        // KULLANIM
        // ----------------------------------------------------
        'screenTime': _screenTime,

        'dailyGoalMinutes': _dailyGoalMinutes,

        'socialMediaHours': _socialMediaHours,

        'gamingHours': _gamingHours,

        // ----------------------------------------------------
        // GÜNLÜK YAŞAM
        // ----------------------------------------------------
        'sleepHours': _sleepHours,

        'physicalActivityHours': _physicalActivityHours,

        'workStudyHours': _workStudyHours,

        // ----------------------------------------------------
        // ÖZ-DEĞERLENDİRME
        // ----------------------------------------------------
        'anxietyScore': _anxietyScore,

        // ----------------------------------------------------
        // BİLDİRİM
        // ----------------------------------------------------
        'notificationsPerDay': _notificationsPerDay,

        // ----------------------------------------------------
        // MOOD
        // ----------------------------------------------------
        'mood': _mood,

        'moodTitle': _moodTitle,

        'moodEmoji': _moodEmoji,

        // ----------------------------------------------------
        // ANALİZ ZAMANI
        // ----------------------------------------------------
        'analyzedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ========================================================
      // 12. EKRANI GÜNCELLE
      // ========================================================

      if (!mounted) return;

      setState(() {
        _riskLevel = riskLevel;

        _riskProbability = riskProbability;

        _normalProbability = normalProbability;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // DOUBLE OKUMA
  // ============================================================

  double _toDouble(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  // ============================================================
  // RİSK AÇIKLAMASI
  // ============================================================

  String _getRiskDescription() {
    if (_riskLevel == 'Riskli') {
      return 'Yapay zekâ analizine göre '
          'dijital kullanım alışkanlıklarında '
          'dikkat edilmesi gereken noktalar bulunuyor.';
    }

    if (_riskLevel == 'Normal') {
      return 'Yapay zekâ analizine göre '
          'dijital kullanım alışkanlıklarında '
          'belirgin bir risk görülmedi.';
    }

    return 'AI analizi henüz tamamlanmadı.';
  }

  // ============================================================
  // RİSK RENGİ
  // ============================================================

  Color _getRiskColor() {
    if (_riskLevel == 'Riskli') {
      return Colors.red;
    }

    if (_riskLevel == 'Normal') {
      return Colors.green;
    }

    return Colors.orange;
  }

  // ============================================================
  // YÜZDE
  // ============================================================

  String _formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  // ============================================================
  // MOOD RENGİ
  // ============================================================

  Color _getMoodColor() {
    switch (_mood) {
      case 'happy':
        return Colors.green;

      case 'good':
        return Colors.lightGreen;

      case 'normal':
        return Colors.blue;

      case 'sad':
        return Colors.indigo;

      case 'angry':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // DAKİKA FORMATLAMA
  // ============================================================

  String _formatGoal() {
    if (_dailyGoalMinutes < 60) {
      return '$_dailyGoalMinutes dk';
    }

    final hours = _dailyGoalMinutes ~/ 60;

    final minutes = _dailyGoalMinutes % 60;

    if (minutes == 0) {
      return '$hours saat';
    }

    return '$hours saat $minutes dk';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor();

    return Scaffold(
      backgroundColor: const Color(0xFF100B1D),

      appBar: AppBar(
        backgroundColor: const Color(0xFF100B1D),
        foregroundColor: const Color(0xFFF7F2FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'AI Analizi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadAndAnalyze,

              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    // ==================================================
                    // ÇOCUK ADI
                    // ==================================================

                    Text(
                      '$_childName için AI analizi',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // RİSK SONUCU
                    // ==================================================
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(28),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(24),
                      ),

                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,

                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),

                            child: Icon(
                              Icons.psychology_rounded,
                              size: 58,
                              color: riskColor,
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            _riskLevel,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _getRiskDescription(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFC4B9D9),
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Risk olasılığı: '
                            '${_formatPercentage(_riskProbability)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Normal olasılığı: '
                            '${_formatPercentage(_normalProbability)}',
                            style: TextStyle(
                              color: const Color(0xFFC4B9D9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // BUGÜNKÜ RUH HALİ
                    // ==================================================
                    _buildMoodCard(),

                    const SizedBox(height: 20),

                    // ==================================================
                    // ANALİZ FAKTÖRLERİ
                    // ==================================================
                    _factor(
                      icon: Icons.timer_outlined,
                      title: 'Ekran Süresi',
                      value: '${_screenTime.toStringAsFixed(1)} saat',
                    ),

                    _factor(
                      icon: Icons.flag_outlined,
                      title: 'Günlük Ekran Süresi Hedefi',
                      value: _formatGoal(),
                    ),

                    _factor(
                      icon: Icons.phone_android,
                      title: 'Sosyal Medya',
                      value: '${_socialMediaHours.toStringAsFixed(1)} saat',
                    ),

                    _factor(
                      icon: Icons.sports_esports_outlined,
                      title: 'Oyun',
                      value: '${_gamingHours.toStringAsFixed(1)} saat',
                    ),

                    _factor(
                      icon: Icons.bedtime_outlined,
                      title: 'Uyku Süresi',
                      value: '${_sleepHours.toStringAsFixed(1)} saat',
                    ),

                    _factor(
                      icon: Icons.directions_run_outlined,
                      title: 'Fiziksel Aktivite',
                      value:
                          '${_physicalActivityHours.toStringAsFixed(1)} saat',
                    ),

                    _factor(
                      icon: Icons.menu_book_outlined,
                      title: 'Ders Çalışma',
                      value: '${_workStudyHours.toStringAsFixed(1)} saat',
                    ),

                    _factor(
                      icon: Icons.psychology_outlined,
                      title: 'Anksiyete Öz-Değerlendirmesi',
                      value: '${_anxietyScore.toStringAsFixed(1)} / 10',
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // YENİDEN ANALİZ
                    // ==================================================
                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton.icon(
                        onPressed: _loadAndAnalyze,

                        icon: const Icon(Icons.refresh),

                        label: const Text('Analizi Yenile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // MOOD KARTI
  // ============================================================

  Widget _buildMoodCard() {
    final moodColor = _getMoodColor();

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF211A38),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(
              color: moodColor.withValues(alpha: 0.1),

              shape: BoxShape.circle,
            ),

            child: Center(
              child: Text(_moodEmoji, style: const TextStyle(fontSize: 30)),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Bugünkü Ruh Hali',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  _moodTitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HATA EKRANI
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),

            const SizedBox(height: 16),

            const Text(
              'AI analizi yapılamadı',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(_error ?? 'Bilinmeyen hata', textAlign: TextAlign.center),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loadAndAnalyze,

              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FAKTÖR KARTI
  // ============================================================

  Widget _factor({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFF211A38),

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
