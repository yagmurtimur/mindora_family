import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ParentRecommendationsScreen extends StatefulWidget {
  const ParentRecommendationsScreen({super.key});

  @override
  State<ParentRecommendationsScreen> createState() =>
      _ParentRecommendationsScreenState();
}

class _ParentRecommendationsScreenState
    extends State<ParentRecommendationsScreen> {
  bool _isLoading = true;

  String? _childId;
  String _childName = 'Çocuğunuz';

  int _screenTime = 0;
  int _dailyGoal = 150;

  double _riskProbability = 0;
  String _riskLevel = 'Bilinmiyor';

  double _sleepHours = 0;
  double _physicalActivityHours = 0;
  double _workStudyHours = 0;

  int _socialMediaMinutes = 0;
  int _gamingMinutes = 0;
  int _videoMinutes = 0;

  String? _mood;
  String? _moodTitle;
  String? _moodEmoji;

  List<_Recommendation> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ============================================================
  // TARİH
  // ============================================================

  String _getTodayId() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // VERİLERİ YÜKLE
  // ============================================================

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı.');
      }

      final firestore = FirebaseFirestore.instance;

      // --------------------------------------------------------
      // PARENT BİLGİSİ
      // --------------------------------------------------------

      final parentSnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final parentData = parentSnapshot.data();

      final childIds = parentData?['childIds'];

      if (childIds is! List || childIds.isEmpty) {
        throw Exception('Henüz bağlı bir çocuk bulunmuyor.');
      }

      final childId = childIds.first.toString();

      _childId = childId;

      // --------------------------------------------------------
      // ÇOCUK PROFİLİ
      // --------------------------------------------------------

      final childSnapshot = await firestore
          .collection('users')
          .doc(childId)
          .get();

      final childData = childSnapshot.data() ?? {};

      _childName =
          childData['name']?.toString() ??
          childData['displayName']?.toString() ??
          'Çocuğunuz';

      final dateId = _getTodayId();

      // --------------------------------------------------------
      // EKRAN SÜRESİ
      // --------------------------------------------------------

      final screenTimeSnapshot = await firestore
          .collection('users')
          .doc(childId)
          .collection('screenTime')
          .doc(dateId)
          .get();

      final screenTimeData = screenTimeSnapshot.data() ?? {};

      _screenTime = (screenTimeData['totalMinutes'] as num?)?.toInt() ?? 0;

      _dailyGoal = (screenTimeData['dailyGoalMinutes'] as num?)?.toInt() ?? 150;

      _socialMediaMinutes =
          (screenTimeData['socialMediaMinutes'] as num?)?.toInt() ?? 0;

      _gamingMinutes = (screenTimeData['gamingMinutes'] as num?)?.toInt() ?? 0;

      _videoMinutes = (screenTimeData['videoMinutes'] as num?)?.toInt() ?? 0;

      // --------------------------------------------------------
      // PARENT TARAFINDAN BELİRLENEN MERKEZİ HEDEF
      // --------------------------------------------------------

      final goalSnapshot = await firestore
          .collection('users')
          .doc(childId)
          .collection('goals')
          .doc('current')
          .get();

      if (goalSnapshot.exists) {
        final goalData = goalSnapshot.data();

        final goal = (goalData?['dailyScreenTimeGoal'] as num?)?.toInt();

        if (goal != null && goal > 0) {
          _dailyGoal = goal;
        }
      }

      // --------------------------------------------------------
      // AI ANALİZİ
      // --------------------------------------------------------

      final aiSnapshot = await firestore
          .collection('users')
          .doc(childId)
          .collection('aiAnalysis')
          .doc(dateId)
          .get();

      if (aiSnapshot.exists) {
        final aiData = aiSnapshot.data() ?? {};

        _riskLevel = aiData['riskLevel']?.toString() ?? 'Bilinmiyor';

        _riskProbability = (aiData['riskProbability'] as num?)?.toDouble() ?? 0;

        _sleepHours = (aiData['sleepHours'] as num?)?.toDouble() ?? 0;

        _physicalActivityHours =
            (aiData['physicalActivityHours'] as num?)?.toDouble() ?? 0;

        _workStudyHours = (aiData['workStudyHours'] as num?)?.toDouble() ?? 0;
      }

      // --------------------------------------------------------
      // MOOD
      // --------------------------------------------------------

      final moodSnapshot = await firestore
          .collection('users')
          .doc(childId)
          .collection('moods')
          .doc(dateId)
          .get();

      if (moodSnapshot.exists) {
        final moodData = moodSnapshot.data() ?? {};

        _mood = moodData['mood']?.toString();
        _moodTitle = moodData['moodTitle']?.toString();
        _moodEmoji = moodData['emoji']?.toString();
      }

      // --------------------------------------------------------
      // ÖNERİLERİ OLUŞTUR
      // --------------------------------------------------------

      _generateRecommendations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veriler yüklenirken hata oluştu: $e')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // ÖNERİ MOTORU
  // ============================================================

  void _generateRecommendations() {
    final List<_Recommendation> results = [];

    // ----------------------------------------------------------
    // EKRAN SÜRESİ
    // ----------------------------------------------------------

    if (_screenTime > _dailyGoal) {
      final exceeded = _screenTime - _dailyGoal;

      results.add(
        _Recommendation(
          icon: Icons.timer_outlined,
          title: 'Ekran süresi hedefi aşıldı',
          description:
              'Bugünkü kullanım günlük hedefin '
              '${exceeded} dakika üzerinde. '
              'Günün kalanında kısa dijital molalar '
              'planlamayı deneyebilirsiniz.',
        ),
      );
    } else if (_screenTime > 0 && _screenTime >= _dailyGoal * 0.8) {
      results.add(
        _Recommendation(
          icon: Icons.access_time_rounded,
          title: 'Ekran süresini takip edin',
          description:
              'Bugünkü kullanım günlük hedefe yaklaşıyor. '
              'Kalan zamanda ekran kullanımını kontrollü '
              'sürdürmek faydalı olabilir.',
        ),
      );
    } else {
      results.add(
        _Recommendation(
          icon: Icons.check_circle_outline,
          title: 'Ekran süresi hedef içerisinde',
          description:
              'Bugünkü ekran kullanımı belirlenen günlük '
              'hedef içerisinde görünüyor. Bu düzeni '
              'sürdürmeye çalışabilirsiniz.',
        ),
      );
    }

    // ----------------------------------------------------------
    // SOSYAL MEDYA
    // ----------------------------------------------------------

    if (_socialMediaMinutes >= 120) {
      results.add(
        _Recommendation(
          icon: Icons.people_alt_outlined,
          title: 'Sosyal medya kullanımına dikkat',
          description:
              'Bugünkü sosyal medya kullanımı yüksek '
              'görünüyor. Gün içerisinde sosyal medya '
              'için belirli zaman aralıkları oluşturmayı '
              'deneyebilirsiniz.',
        ),
      );
    }

    // ----------------------------------------------------------
    // OYUN
    // ----------------------------------------------------------

    if (_gamingMinutes >= 120) {
      results.add(
        _Recommendation(
          icon: Icons.sports_esports_outlined,
          title: 'Oyun süresine mola ekleyin',
          description:
              'Oyun kullanım süresi bugün yüksek görünüyor. '
              'Oyun seansları arasında kısa molalar '
              'verilmesini teşvik edebilirsiniz.',
        ),
      );
    }

    // ----------------------------------------------------------
    // VİDEO
    // ----------------------------------------------------------

    if (_videoMinutes >= 120) {
      results.add(
        _Recommendation(
          icon: Icons.play_circle_outline,
          title: 'Video izleme süresini dengeleyin',
          description:
              'Video içeriklerine ayrılan süre bugün yüksek. '
              'Ekran dışı bir aktiviteyle denge oluşturmayı '
              'deneyebilirsiniz.',
        ),
      );
    }

    // ----------------------------------------------------------
    // UYKU
    // ----------------------------------------------------------

    if (_sleepHours > 0 && _sleepHours < 7) {
      results.add(
        _Recommendation(
          icon: Icons.bedtime_outlined,
          title: 'Uyku düzenine dikkat edin',
          description:
              'Kaydedilen uyku süresi düşük görünüyor. '
              'Uyku öncesinde ekran kullanımını azaltmak '
              've düzenli bir uyku rutini oluşturmak '
              'faydalı olabilir.',
        ),
      );
    }

    // ----------------------------------------------------------
    // FİZİKSEL AKTİVİTE
    // ----------------------------------------------------------

    if (_physicalActivityHours > 0 && _physicalActivityHours < 1) {
      results.add(
        _Recommendation(
          icon: Icons.directions_walk_outlined,
          title: 'Fiziksel aktiviteyi artırın',
          description:
              'Bugünkü fiziksel aktivite süresi düşük '
              'görünüyor. Gün içerisinde kısa yürüyüşler '
              've ekran dışı aktiviteler planlayabilirsiniz.',
        ),
      );
    }

    // ----------------------------------------------------------
    // DERS / ÇALIŞMA
    // ----------------------------------------------------------

    if (_workStudyHours > 0 && _workStudyHours < 1) {
      results.add(
        _Recommendation(
          icon: Icons.menu_book_outlined,
          title: 'Ders ve çalışma zamanını destekleyin',
          description:
              'Bugünkü çalışma süresi düşük görünüyor. '
              'Kısa ve planlı çalışma aralıkları oluşturmayı '
              'deneyebilirsiniz.',
        ),
      );
    }

    // ----------------------------------------------------------
    // RİSK
    // ----------------------------------------------------------

    if (_riskLevel.toLowerCase().contains('riskli')) {
      results.add(
        _Recommendation(
          icon: Icons.warning_amber_rounded,
          title: 'Dijital kullanım riskini takip edin',
          description:
              'AI analizi çocuğun dijital kullanımında '
              'riskli bir düzey tespit etti. Ekran süresi, '
              'uyku ve günlük aktiviteleri birlikte '
              'takip etmeniz önerilir.',
        ),
      );
    }

    // ----------------------------------------------------------
    // MOOD
    // ----------------------------------------------------------

    if (_mood == 'sad' || _mood == 'angry') {
      results.add(
        _Recommendation(
          icon: Icons.favorite_border_rounded,
          title: 'Bugünkü ruh haline alan açın',
          description:
              '${_moodEmoji ?? ''} '
              '${_moodTitle ?? 'Bugün farklı bir ruh hali kaydedilmiş.'} '
              'Çocuğunuzla gününün nasıl geçtiği hakkında '
              'kısa ve yargılamadan bir sohbet etmeyi '
              'deneyebilirsiniz.',
        ),
      );
    }

    // ----------------------------------------------------------
    // GENEL AİLE ÖNERİSİ
    // ----------------------------------------------------------

    results.add(
      _Recommendation(
        icon: Icons.family_restroom_rounded,
        title: 'Birlikte dijital mola verin',
        description:
            'Ailece telefonlardan uzak geçirilecek kısa '
            'zamanlar belirlemek, sağlıklı dijital alışkanlık '
            'oluşturmaya yardımcı olabilir.',
      ),
    );

    // En fazla 7 öneri göster
    _recommendations = results.take(7).toList();
  }

  // ============================================================
  // DAKİKA FORMATLAMA
  // ============================================================

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes dk';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '$hours sa';
    }

    return '$hours sa $remaining dk';
  }

  // ============================================================
  // RİSK RENGİ
  // ============================================================

  Color _riskColor() {
    final risk = _riskLevel.toLowerCase();

    if (risk.contains('riskli')) {
      return Colors.red;
    }

    if (risk.contains('normal')) {
      return Colors.green;
    }

    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('AI Önerileri'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ==================================================
                  // ÇOCUK BİLGİSİ
                  // ==================================================

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _childName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bugünkü kişiselleştirilmiş öneriler',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // ÖZET
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bugünkü Durum',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: _SummaryItem(
                                icon: Icons.timer_outlined,
                                title: 'Ekran Süresi',
                                value: _formatMinutes(_screenTime),
                              ),
                            ),
                            Expanded(
                              child: _SummaryItem(
                                icon: Icons.flag_outlined,
                                title: 'Günlük Hedef',
                                value: _formatMinutes(_dailyGoal),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _SummaryItem(
                                icon: Icons.psychology_outlined,
                                title: 'AI Riski',
                                value: _riskLevel,
                              ),
                            ),
                            Expanded(
                              child: _SummaryItem(
                                icon: Icons.mood_outlined,
                                title: 'Ruh Hali',
                                value: _moodTitle ?? 'Kayıt yok',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // ÖNERİ BAŞLIĞI
                  // ==================================================
                  const Text(
                    'Kişiselleştirilmiş Öneriler',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // ÖNERİLER
                  // ==================================================
                  ..._recommendations.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              item.icon,
                              color: AppTheme.primaryColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==================================================
                  // AI BİLGİ NOTU
                  // ==================================================
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Öneriler; ekran süresi, '
                            'günlük hedef, AI analiz sonucu, '
                            'ruh hali ve günlük yaşam '
                            'verileri dikkate alınarak '
                            'oluşturulur.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ================================================================
// ÖNERİ MODELİ
// ================================================================

class _Recommendation {
  final IconData icon;
  final String title;
  final String description;

  _Recommendation({
    required this.icon,
    required this.title,
    required this.description,
  });
}

// ================================================================
// ÖZET ITEM
// ================================================================

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryColor),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
