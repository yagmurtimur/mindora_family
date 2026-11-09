import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ai_risk_trend_screen.dart';

class ParentAiHistoryScreen extends StatefulWidget {
  const ParentAiHistoryScreen({super.key});

  @override
  State<ParentAiHistoryScreen> createState() => _ParentAiHistoryScreenState();
}

class _ParentAiHistoryScreenState extends State<ParentAiHistoryScreen> {
  bool _isLoading = true;
  String? _error;

  String _childName = 'Çocuk';

  List<_AiHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ============================================================
  // VERİLERİ YÜKLE
  // ============================================================

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final parent = FirebaseAuth.instance.currentUser;

      if (parent == null) {
        throw Exception('Oturum açmış parent bulunamadı.');
      }

      final firestore = FirebaseFirestore.instance;

      // ========================================================
      // PARENT
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

      // childIds yoksa parentId üzerinden bul
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
      // ÇOCUK
      // ========================================================

      final childDoc = await firestore.collection('users').doc(childId).get();

      final childData = childDoc.data();

      if (childData != null) {
        _childName = childData['name']?.toString() ?? 'Çocuk';
      }

      // ========================================================
      // AI ANALİZLERİ
      // ========================================================

      final analysisSnapshot = await firestore
          .collection('users')
          .doc(childId)
          .collection('aiAnalysis')
          .get();

      final List<_AiHistoryItem> items = [];

      for (final document in analysisSnapshot.docs) {
        final data = document.data();

        items.add(
          _AiHistoryItem(
            dateId: document.id,
            riskLevel: data['riskLevel']?.toString() ?? 'Bilinmiyor',
            riskProbability: _toDouble(data['riskProbability'], 0),
            normalProbability: _toDouble(data['normalProbability'], 0),
            screenTime: _toDouble(data['screenTime'], 0),
            dailyGoalMinutes: _toDouble(data['dailyGoalMinutes'], 150).toInt(),
            sleepHours: _toDouble(data['sleepHours'], 0),
            socialMediaHours: _toDouble(data['socialMediaHours'], 0),
            gamingHours: _toDouble(data['gamingHours'], 0),
            mood: data['mood']?.toString() ?? 'Henüz girilmedi',
            moodTitle: data['moodTitle']?.toString() ?? 'Ruh hali kaydedilmedi',
            moodEmoji: data['moodEmoji']?.toString() ?? '🙂',
          ),
        );
      }

      // ========================================================
      // TARİHE GÖRE YENİDEN ESKİYE
      // ========================================================

      items.sort((a, b) => b.dateId.compareTo(a.dateId));

      // Son 30 analiz
      _history = items.take(30).toList();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  double _toDouble(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  // ============================================================
  // TARİH FORMATLAMA
  // ============================================================

  String _formatDate(String dateId) {
    final parts = dateId.split('-');

    if (parts.length != 3) {
      return dateId;
    }

    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    final month = int.tryParse(parts[1]);

    if (month == null || month < 1 || month > 12) {
      return dateId;
    }

    return '${int.parse(parts[2])} '
        '${months[month - 1]} '
        '${parts[0]}';
  }

  // ============================================================
  // RİSK RENGİ
  // ============================================================

  Color _riskColor(String riskLevel) {
    if (riskLevel == 'Riskli') {
      return Colors.red;
    }

    if (riskLevel == 'Normal') {
      return Colors.green;
    }

    return Colors.orange;
  }

  // ============================================================
  // YÜZDE
  // ============================================================

  String _percentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,

      appBar: AppBar(
        title: const Text('AI Analiz Geçmişi'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _history.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ==================================================
                  // BAŞLIK
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
                            color: AppTheme.primaryColor.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),

                          child: Icon(
                            Icons.history_rounded,
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
                                'Son analizler',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Analiz Geçmişi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // ==================================================
                  // 7 GÜNLÜK AI RİSK TRENDİ
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AiRiskTrendScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.trending_up_rounded),
                      label: const Text('7 Günlük Risk Trendini Gör'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ANALİZLER
                  // ==================================================
                  ..._history.map((item) => _buildHistoryCard(item)),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // ANALİZ KARTI
  // ============================================================

  Widget _buildHistoryCard(_AiHistoryItem item) {
    final riskColor = _riskColor(item.riskLevel);

    return GestureDetector(
      onTap: () {
        _showDetail(item);
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 14),

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),

        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,

                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),

                  child: Icon(Icons.psychology_rounded, color: riskColor),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(item.dateId),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        item.riskLevel,
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  _percentage(item.riskProbability),
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(height: 1),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _smallInfo(
                    Icons.timer_outlined,
                    'Ekran',
                    '${item.screenTime.toStringAsFixed(1)} sa',
                  ),
                ),

                Expanded(
                  child: _smallInfo(
                    Icons.flag_outlined,
                    'Hedef',
                    '${(item.dailyGoalMinutes / 60).toStringAsFixed(1)} sa',
                  ),
                ),

                Expanded(
                  child: _smallInfo(
                    Icons.mood_outlined,
                    'Ruh Hali',
                    item.moodEmoji,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Detayları görüntüle',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // KÜÇÜK BİLGİ
  // ============================================================

  Widget _smallInfo(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),

        const SizedBox(height: 5),

        Text(
          title,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),

        const SizedBox(height: 2),

        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ============================================================
  // DETAY PENCERESİ
  // ============================================================

  void _showDetail(_AiHistoryItem item) {
    final riskColor = _riskColor(item.riskLevel);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),

          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),

          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  _formatDate(item.dateId),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        size: 55,
                        color: riskColor,
                      ),

                      const SizedBox(height: 10),

                      Text(
                        item.riskLevel,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Risk olasılığı: '
                        '${_percentage(item.riskProbability)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      Text(
                        'Normal olasılığı: '
                        '${_percentage(item.normalProbability)}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _detailRow(
                  Icons.timer_outlined,
                  'Ekran Süresi',
                  '${item.screenTime.toStringAsFixed(1)} saat',
                ),

                _detailRow(
                  Icons.flag_outlined,
                  'Günlük Hedef',
                  '${(item.dailyGoalMinutes / 60).toStringAsFixed(1)} saat',
                ),

                _detailRow(
                  Icons.phone_android,
                  'Sosyal Medya',
                  '${item.socialMediaHours.toStringAsFixed(1)} saat',
                ),

                _detailRow(
                  Icons.sports_esports_outlined,
                  'Oyun',
                  '${item.gamingHours.toStringAsFixed(1)} saat',
                ),

                _detailRow(
                  Icons.bedtime_outlined,
                  'Uyku',
                  '${item.sleepHours.toStringAsFixed(1)} saat',
                ),

                _detailRow(
                  Icons.mood_outlined,
                  'Ruh Hali',
                  '${item.moodEmoji} ${item.moodTitle}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DETAY SATIRI
  // ============================================================

  Widget _detailRow(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOŞ EKRAN
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(Icons.history_rounded, size: 70, color: Colors.grey.shade400),

            const SizedBox(height: 18),

            const Text(
              'Henüz AI analiz geçmişi yok',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              'AI analizi çalıştırıldığında '
              'sonuçlar burada tarih bazlı '
              'olarak görüntülenecek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HATA
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
              'Geçmiş yüklenemedi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(_error ?? 'Bilinmeyen hata', textAlign: TextAlign.center),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loadHistory,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// AI HISTORY MODEL
// ================================================================

class _AiHistoryItem {
  final String dateId;
  final String riskLevel;

  final double riskProbability;
  final double normalProbability;

  final double screenTime;
  final int dailyGoalMinutes;

  final double sleepHours;
  final double socialMediaHours;
  final double gamingHours;

  final String mood;
  final String moodTitle;
  final String moodEmoji;

  _AiHistoryItem({
    required this.dateId,
    required this.riskLevel,
    required this.riskProbability,
    required this.normalProbability,
    required this.screenTime,
    required this.dailyGoalMinutes,
    required this.sleepHours,
    required this.socialMediaHours,
    required this.gamingHours,
    required this.mood,
    required this.moodTitle,
    required this.moodEmoji,
  });
}
