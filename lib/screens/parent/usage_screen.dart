import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';

class ParentUsageScreen extends StatefulWidget {
  const ParentUsageScreen({super.key});

  @override
  State<ParentUsageScreen> createState() => _ParentUsageScreenState();
}

class _ParentUsageScreenState extends State<ParentUsageScreen> {
  bool _isLoading = true;

  String? _childId;
  String? _childName;

  int _todayMinutes = 0;
  int _yesterdayMinutes = 0;

  int _socialMediaMinutes = 0;
  int _gamingMinutes = 0;
  int _videoMinutes = 0;

  int _dailyGoalMinutes = 150;

  List<int> _weeklyMinutes = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _loadUsageData();
  }

  // ============================================================
  // TÜM KULLANIM VERİLERİNİ GETİR
  // ============================================================

  Future<void> _loadUsageData() async {
    try {
      final parent = FirebaseAuth.instance.currentUser;

      if (parent == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      // ========================================================
      // 1. PARENT
      // ========================================================

      final parentDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(parent.uid)
          .get();

      if (!parentDocument.exists) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      final parentData = parentDocument.data();

      String? childId;

      final dynamic childIdsData = parentData?['childIds'];

      if (childIdsData is List && childIdsData.isNotEmpty) {
        childId = childIdsData.first.toString();
      }

      // ========================================================
      // 2. childIds YOKSA parentId İLE BUL
      // ========================================================

      if (childId == null) {
        final childQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('parentId', isEqualTo: parent.uid)
            .where('role', isEqualTo: 'child')
            .limit(1)
            .get();

        if (childQuery.docs.isNotEmpty) {
          childId = childQuery.docs.first.id;
        }
      }

      // ========================================================
      // 3. ÇOCUK YOK
      // ========================================================

      if (childId == null) {
        if (!mounted) return;

        setState(() {
          _childId = null;
          _childName = null;
          _todayMinutes = 0;
          _yesterdayMinutes = 0;
          _socialMediaMinutes = 0;
          _gamingMinutes = 0;
          _videoMinutes = 0;
          _dailyGoalMinutes = 150;
          _weeklyMinutes = List.filled(7, 0);
          _isLoading = false;
        });

        return;
      }

      // ========================================================
      // 4. ÇOCUK BİLGİSİ
      // ========================================================

      final childDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .get();

      if (!childDocument.exists) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      final childData = childDocument.data();

      final childName = childData?['name']?.toString() ?? 'Çocuk';

      // ========================================================
      // 5. BUGÜN
      // ========================================================

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      final todayId = _dateId(today);

      final todayDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('screenTime')
          .doc(todayId)
          .get();

      int todayMinutes = 0;
      int socialMediaMinutes = 0;
      int gamingMinutes = 0;
      int videoMinutes = 0;
      int dailyGoalMinutes = 150;

      if (todayDocument.exists) {
        final data = todayDocument.data();

        todayMinutes = _readInt(data?['totalMinutes']);

        socialMediaMinutes = _readInt(data?['socialMediaMinutes']);

        gamingMinutes = _readInt(data?['gamingMinutes']);

        videoMinutes = _readInt(data?['videoMinutes']);

        dailyGoalMinutes = _readInt(
          data?['dailyGoalMinutes'],
          defaultValue: 150,
        );

        if (dailyGoalMinutes <= 0) {
          dailyGoalMinutes = 150;
        }
      }

      // ========================================================
      // 6. DÜN
      // ========================================================

      final yesterday = today.subtract(const Duration(days: 1));

      final yesterdayId = _dateId(yesterday);

      final yesterdayDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('screenTime')
          .doc(yesterdayId)
          .get();

      int yesterdayMinutes = 0;

      if (yesterdayDocument.exists) {
        final data = yesterdayDocument.data();

        yesterdayMinutes = _readInt(data?['totalMinutes']);
      }

      // ========================================================
      // 7. SON 7 GÜN
      // ========================================================

      final weeklyMinutes = List<int>.filled(7, 0);

      for (int i = 6; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));

        final dateId = _dateId(date);

        final document = await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .collection('screenTime')
            .doc(dateId)
            .get();

        final index = 6 - i;

        if (document.exists) {
          final data = document.data();

          weeklyMinutes[index] = _readInt(data?['totalMinutes']);
        }
      }

      // ========================================================
      // 8. EKRANA AKTAR
      // ========================================================

      if (!mounted) return;

      setState(() {
        _childId = childId;
        _childName = childName;

        _todayMinutes = todayMinutes;
        _yesterdayMinutes = yesterdayMinutes;

        _socialMediaMinutes = socialMediaMinutes;

        _gamingMinutes = gamingMinutes;

        _videoMinutes = videoMinutes;

        _dailyGoalMinutes = dailyGoalMinutes;

        _weeklyMinutes = weeklyMinutes;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanım verileri alınırken hata oluştu: $e')),
      );
    }
  }

  // ============================================================
  // TARİH ID
  // ============================================================

  String _dateId(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // SAYI OKUMA
  // ============================================================

  int _readInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  // ============================================================
  // SÜRE FORMATLAMA
  // ============================================================

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes dk';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}s';
    }

    return '${hours}s ${remainingMinutes}dk';
  }

  // ============================================================
  // DÜNE GÖRE DEĞİŞİM
  // ============================================================

  String _dailyChangeText() {
    if (_yesterdayMinutes == 0) {
      if (_todayMinutes == 0) {
        return 'Dün ve bugün kullanım yok';
      }

      return 'Düne göre yeni kullanım';
    }

    final difference = _todayMinutes - _yesterdayMinutes;

    final percentage = ((difference.abs() / _yesterdayMinutes) * 100).round();

    if (difference > 0) {
      return 'Düne göre %$percentage daha fazla';
    }

    if (difference < 0) {
      return 'Düne göre %$percentage daha az';
    }

    return 'Düne göre değişiklik yok';
  }

  // ============================================================
  // GÜN İSİMLERİ
  // ============================================================

  String _dayName(int index) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return days[index];
  }

  // ============================================================
  // HAFTALIK ORTALAMA
  // ============================================================

  double _weeklyAverage() {
    if (_weeklyMinutes.isEmpty) {
      return 0;
    }

    final total = _weeklyMinutes.fold<int>(0, (sum, value) => sum + value);

    return total / _weeklyMinutes.length;
  }

  // ============================================================
  // HAFTALIK MAKSİMUM
  // ============================================================

  double _maxWeeklyValue() {
    final maxValue = _weeklyMinutes.fold<int>(
      0,
      (previous, current) => current > previous ? current : previous,
    );

    if (maxValue == 0) {
      return 60;
    }

    return maxValue.toDouble();
  }

  // ============================================================
  // HEDEF İLERLEMESİ
  // ============================================================

  double _goalProgress() {
    if (_dailyGoalMinutes <= 0) {
      return 0;
    }

    final progress = _todayMinutes / _dailyGoalMinutes;

    if (progress > 1) {
      return 1;
    }

    return progress;
  }

  // ============================================================
  // HEDEF DURUMU
  // ============================================================

  String _goalStatus() {
    if (_todayMinutes == 0) {
      return 'Bugün henüz kullanım verisi yok';
    }

    if (_todayMinutes < _dailyGoalMinutes) {
      final remaining = _dailyGoalMinutes - _todayMinutes;

      return 'Hedefe $remaining dakika kaldı';
    }

    if (_todayMinutes == _dailyGoalMinutes) {
      return 'Günlük hedefe ulaşıldı';
    }

    final exceeded = _todayMinutes - _dailyGoalMinutes;

    return 'Hedef $exceeded dakika aşıldı';
  }

  // ============================================================
  // KATEGORİ TOPLAMI
  // ============================================================

  int _categoryTotal() {
    return _socialMediaMinutes + _gamingMinutes + _videoMinutes;
  }

  // ============================================================
  // KATEGORİ YÜZDESİ
  // ============================================================

  String _categoryPercentage(int value) {
    final total = _categoryTotal();

    if (total == 0 || value == 0) {
      return '%0';
    }

    final percentage = ((value / total) * 100).round();

    return '%$percentage';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF100D1C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF171126),
          foregroundColor: Color(0xFFF7F2FF),
          elevation: 0,
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: const Color(0xFFF7F2FF),
          displayColor: const Color(0xFFF7F2FF),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF100D1C),

        appBar: AppBar(
          title: const Text('Kullanım Analizi'),

          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });

                _loadUsageData();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),

        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : RefreshIndicator(
                onRefresh: _loadUsageData,

                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // ==================================================
                      // ÖZET
                      // ==================================================

                      _summaryCard(),

                      const SizedBox(height: 20),

                      // ==================================================
                      // HEDEF DURUMU
                      // ==================================================
                      _goalStatusCard(),

                      const SizedBox(height: 24),

                      // ==================================================
                      // HAFTALIK ANALİZ
                      // ==================================================
                      const Text(
                        'Haftalık Ekran Süresi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF7F2FF),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _weeklyAverageCard(),

                      const SizedBox(height: 14),

                      _weeklyChart(),

                      const SizedBox(height: 24),

                      // ==================================================
                      // KATEGORİLER
                      // ==================================================
                      const Text(
                        'Kullanım Kategorileri',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF7F2FF),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _category(
                        icon: Icons.smartphone_rounded,
                        title: 'Sosyal Medya',
                        value: _formatDuration(_socialMediaMinutes),
                        percentage: _categoryPercentage(_socialMediaMinutes),
                      ),

                      _category(
                        icon: Icons.sports_esports_rounded,
                        title: 'Oyun',
                        value: _formatDuration(_gamingMinutes),
                        percentage: _categoryPercentage(_gamingMinutes),
                      ),

                      _category(
                        icon: Icons.ondemand_video_rounded,
                        title: 'Video',
                        value: _formatDuration(_videoMinutes),
                        percentage: _categoryPercentage(_videoMinutes),
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // KATEGORİ ÖZETİ
                      // ==================================================
                      _categorySummary(),

                      const SizedBox(height: 24),

                      // ==================================================
                      // GÜNLÜK HEDEF
                      // ==================================================
                      _goalCard(),

                      const SizedBox(height: 20),

                      // ==================================================
                      // BİLGİ
                      // ==================================================
                      _infoCard(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // ÖZET KARTI
  // ============================================================

  Widget _summaryCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6542D8),
            const Color(0xFF9B63FF),
            const Color(0xFF452B88),
          ],
        ),

        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Bugünkü Toplam',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),

          const SizedBox(height: 8),

          Text(
            _formatDuration(_todayMinutes),
            style: const TextStyle(
              color: const Color(0xFF211A32),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _dailyChangeText(),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 6),

          if (_childName != null)
            Text(
              _childName!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // HEDEF DURUM KARTI
  // ============================================================

  Widget _goalStatusCard() {
    final exceeded = _todayMinutes > _dailyGoalMinutes;

    final Color iconColor = exceeded ? Colors.orange : Colors.green;

    final Color iconBackground = exceeded
        ? Colors.orange.shade50
        : Colors.green.shade50;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFF211A32),
        border: Border.all(
          color: const Color(0xFF8E6BFF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6BFF).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),

            child: Icon(
              exceeded
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: iconColor,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Günlük Kullanım Durumu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),

                const SizedBox(height: 4),

                Text(
                  _goalStatus(),
                  style: TextStyle(
                    color: const Color(0xFFB9B0D0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HAFTALIK ORTALAMA
  // ============================================================

  Widget _weeklyAverageCard() {
    final average = _weeklyAverage();

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFF211A32),
        border: Border.all(
          color: const Color(0xFF8E6BFF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6BFF).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.analytics_outlined,
              color: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  '7 Günlük Ortalama',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),

                const SizedBox(height: 4),

                Text(
                  _formatDuration(average.round()),
                  style: TextStyle(
                    color: const Color(0xFFB9B0D0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HAFTALIK GRAFİK
  // ============================================================

  Widget _weeklyChart() {
    final maxValue = _maxWeeklyValue();

    return Container(
      height: 235,
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),

      decoration: BoxDecoration(
        color: const Color(0xFF211A32),
        border: Border.all(
          color: const Color(0xFF8E6BFF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6BFF).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,

        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: List.generate(7, (index) {
          final minutes = _weeklyMinutes[index];

          final normalized = minutes / maxValue;

          return _bar(_dayName(index), normalized, minutes);
        }),
      ),
    );
  }

  // ============================================================
  // GRAFİK BAR
  // ============================================================

  Widget _bar(String day, double value, int minutes) {
    final height = value == 0 ? 4.0 : 125 * value;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,

        children: [
          if (minutes > 0)
            Text(
              _formatDuration(minutes),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
            ),

          const SizedBox(height: 4),

          Container(
            width: 24,
            height: height,

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB38CFF), Color(0xFF7048F5)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          const SizedBox(height: 8),

          Text(day, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // ============================================================
  // KATEGORİ
  // ============================================================

  Widget _category({
    required IconData icon,
    required String title,
    required String value,
    required String percentage,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFF211A32),
        border: Border.all(
          color: const Color(0xFF8E6BFF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6BFF).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 3),

                Text(
                  percentage,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFFA79BBF),
                  ),
                ),
              ],
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KATEGORİ ÖZETİ
  // ============================================================

  Widget _categorySummary() {
    final total = _categoryTotal();

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFF211A32),
        border: Border.all(
          color: const Color(0xFF8E6BFF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6BFF).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Kategori Özeti',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            total == 0
                ? 'Kategori kullanım verisi bulunmuyor.'
                : 'Takip edilen kategorilerde toplam '
                      '${_formatDuration(total)} kullanım bulunuyor.',
            style: TextStyle(color: const Color(0xFFB9B0D0), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEDEF KARTI
  // ============================================================

  Widget _goalCard() {
    final progress = _goalProgress();

    final bool exceeded = _todayMinutes > _dailyGoalMinutes;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF211A32),
        border: Border.all(
          color: const Color(0xFF8E6BFF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E6BFF).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppTheme.primaryColor),

              const SizedBox(width: 10),

              const Text(
                'Günlük Hedef',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,

              backgroundColor: const Color(0xFF3B304F),

              color: exceeded
                  ? const Color(0xFFFFA66D)
                  : const Color(0xFF9B78FF),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(
                _formatDuration(_todayMinutes),
                style: const TextStyle(fontSize: 13),
              ),

              Text(
                _formatDuration(_dailyGoalMinutes),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BİLGİ KARTI
  // ============================================================

  Widget _infoCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Kullanım verileri çocuğun cihazındaki '
              'ekran süresi kayıtlarından alınır. '
              'Grafik ve öneriler mevcut günlük verilere '
              'göre güncellenir.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: const Color(0xFFC8BEDC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
