import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../theme/app_theme.dart';

class ChildUsageScreen extends StatefulWidget {
  const ChildUsageScreen({super.key});

  @override
  State<ChildUsageScreen> createState() => _ChildUsageScreenState();
}

class _ChildUsageScreenState extends State<ChildUsageScreen> {
  static const MethodChannel _usageChannel = MethodChannel('mindora/usage');

  bool _isLoading = true;
  bool _isSyncing = false;

  int _totalMinutes = 0;
  int _socialMediaMinutes = 0;
  int _gamingMinutes = 0;
  int _videoMinutes = 0;

  int _dailyGoalMinutes = 150;

  List<DailyUsage> _history = [];

  @override
  void initState() {
    super.initState();
    _loadUsageData();
  }

  // ============================================================
  // BUGÜNÜN TARİH ID'Sİ
  // ============================================================

  String _todayId() {
    final today = DateTime.now();

    return '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // GERÇEK ANDROID KULLANIM VERİSİNİ AL
  // ============================================================

  Future<void> _syncRealUsageData() async {
    if (_isSyncing) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı.');
      }

      // --------------------------------------------------------
      // Android Usage Access kontrolü
      // --------------------------------------------------------

      final hasAccess =
          await _usageChannel.invokeMethod<bool>('hasUsageAccess') ?? false;

      if (!hasAccess) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kullanım erişimi gerekli. '
              'Android ayarlarından Mindora için izin ver.',
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // Android'den bugünün verilerini al
      // --------------------------------------------------------

      final result = await _usageChannel.invokeMethod('getTodayUsage');

      if (result == null) {
        throw Exception('Kullanım verisi alınamadı.');
      }

      final data = Map<String, dynamic>.from(result);

      final totalMinutes = (data['totalMinutes'] ?? 0).toInt();

      final socialMediaMinutes = (data['socialMediaMinutes'] ?? 0).toInt();

      final gamingMinutes = (data['gamingMinutes'] ?? 0).toInt();

      final videoMinutes = (data['videoMinutes'] ?? 0).toInt();

      // --------------------------------------------------------
      // Firebase'e kaydet
      // --------------------------------------------------------

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('screenTime')
          .doc(_todayId())
          .set({
            'totalMinutes': totalMinutes,

            'socialMediaMinutes': socialMediaMinutes,

            'gamingMinutes': gamingMinutes,

            'videoMinutes': videoMinutes,

            'dailyGoalMinutes': _dailyGoalMinutes,

            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // --------------------------------------------------------
      // Ekranı güncelle
      // --------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _totalMinutes = totalMinutes;

        _socialMediaMinutes = socialMediaMinutes;

        _gamingMinutes = gamingMinutes;

        _videoMinutes = videoMinutes;
      });

      await _loadHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerçek kullanım verileri güncellendi.')),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Android kullanım verisi alınamadı: '
            '${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler güncellenirken hata oluştu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // ============================================================
  // FIREBASE'DEN BUGÜNÜN VERİLERİNİ OKU
  // ============================================================

  Future<void> _loadUsageData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      // Önce Firebase'deki mevcut bugünkü veriyi oku.
      // Daha sonra kullanıcı isterse sync ile güncelleyebilir.

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('screenTime')
          .doc(_todayId())
          .get();

      if (!mounted) return;

      if (document.exists) {
        final data = document.data();

        setState(() {
          _totalMinutes = (data?['totalMinutes'] ?? 0).toInt();

          _socialMediaMinutes = (data?['socialMediaMinutes'] ?? 0).toInt();

          _gamingMinutes = (data?['gamingMinutes'] ?? 0).toInt();

          _videoMinutes = (data?['videoMinutes'] ?? 0).toInt();

          _dailyGoalMinutes = (data?['dailyGoalMinutes'] ?? 150).toInt();

          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }

      await _loadHistory();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kullanım verileri alınırken '
            'bir hata oluştu.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // GERÇEK VERİLERİ YENİLE
  // ============================================================

  Future<void> _refreshUsage() async {
    await _syncRealUsageData();

    if (!mounted) return;

    await _loadUsageData();
  }

  // ============================================================
  // GEÇMİŞ VERİLER
  // ============================================================

  Future<void> _loadHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('screenTime')
          .limit(30)
          .get();

      final List<DailyUsage> loadedHistory = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        loadedHistory.add(
          DailyUsage(
            date: doc.id,
            totalMinutes: (data['totalMinutes'] ?? 0).toInt(),
          ),
        );
      }

      loadedHistory.sort((a, b) => a.date.compareTo(b.date));

      // Son 7 gün
      final lastSeven = loadedHistory.length > 7
          ? loadedHistory.sublist(loadedHistory.length - 7)
          : loadedHistory;

      if (!mounted) return;

      setState(() {
        _history = lastSeven;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _history = [];
      });
    }
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
      return '$hours saat';
    }

    return '$hours saat '
        '$remainingMinutes dk';
  }

  // ============================================================
  // HEDEF İLERLEMESİ
  // ============================================================

  double get _progress {
    if (_dailyGoalMinutes <= 0) {
      return 0;
    }

    final value = _totalMinutes / _dailyGoalMinutes;

    if (value > 1) {
      return 1;
    }

    return value;
  }

  // ============================================================
  // HEDEF YÜZDESİ
  // ============================================================

  int get _progressPercentage {
    if (_dailyGoalMinutes <= 0) {
      return 0;
    }

    return ((_totalMinutes / _dailyGoalMinutes) * 100).round();
  }

  // ============================================================
  // 7 GÜNLÜK ORTALAMA
  // ============================================================

  int get _weeklyAverage {
    if (_history.isEmpty) {
      return 0;
    }

    final total = _history.fold<int>(0, (sum, item) => sum + item.totalMinutes);

    return (total / _history.length).round();
  }

  // ============================================================
  // KATEGORİ TOPLAMI
  // ============================================================

  int get _categoryTotal {
    return _socialMediaMinutes + _gamingMinutes + _videoMinutes;
  }

  // ============================================================
  // KATEGORİ YÜZDESİ
  // ============================================================

  double _categoryPercentage(int value) {
    if (_totalMinutes <= 0) {
      return 0;
    }

    return value / _totalMinutes;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,

      appBar: AppBar(
        title: const Text('Kullanımım'),

        actions: [
          IconButton(
            tooltip: 'Gerçek verileri güncelle',

            onPressed: _isSyncing ? null : _syncRealUsageData,

            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _refreshUsage,

              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // BUGÜNKÜ TOPLAM
                    // ==================================================

                    _buildTodayCard(),

                    const SizedBox(height: 20),

                    // ==================================================
                    // HEDEF
                    // ==================================================
                    _buildGoalCard(),

                    const SizedBox(height: 28),

                    // ==================================================
                    // KATEGORİLER
                    // ==================================================
                    const Text(
                      'Bugünkü Kullanım',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _usageItem(
                      Icons.smartphone_rounded,
                      'Sosyal Medya',
                      _socialMediaMinutes,
                    ),

                    _usageItem(
                      Icons.sports_esports_rounded,
                      'Oyun',
                      _gamingMinutes,
                    ),

                    _usageItem(
                      Icons.ondemand_video_rounded,
                      'Video',
                      _videoMinutes,
                    ),

                    const SizedBox(height: 8),

                    _buildCategoryCard(),

                    const SizedBox(height: 28),

                    // ==================================================
                    // HAFTALIK ÖZET
                    // ==================================================
                    const Text(
                      'Haftalık Özet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildWeeklySummary(),

                    const SizedBox(height: 20),

                    // ==================================================
                    // GRAFİK
                    // ==================================================
                    _buildChart(),

                    const SizedBox(height: 24),

                    // ==================================================
                    // GEÇMİŞ
                    // ==================================================
                    const Text(
                      'Geçmiş Kullanım',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildHistoryList(),

                    const SizedBox(height: 20),

                    // ==================================================
                    // BİLGİ
                    // ==================================================
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // BUGÜNKÜ TOPLAM KARTI
  // ============================================================

  Widget _buildTodayCard() {
    final isOverGoal = _totalMinutes > _dailyGoalMinutes;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),

        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Bugünkü Ekran Sürem',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),

          const SizedBox(height: 8),

          Text(
            _formatDuration(_totalMinutes),

            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            isOverGoal
                ? 'Günlük hedefini aştın.'
                : 'Günlük hedefinin altında '
                      'kalıyorsun 🎉',

            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEDEF KARTI
  // ============================================================

  Widget _buildGoalCard() {
    final isOver = _totalMinutes > _dailyGoalMinutes;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppTheme.primaryColor),

              const SizedBox(width: 10),

              const Expanded(
                child: Text(
                  'Günlük Ekran Süresi Hedefi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              Text(
                '$_progressPercentage%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: _progress,

              minHeight: 10,

              backgroundColor: const Color(0xFFE8E8E8),

              color: isOver ? Colors.red : AppTheme.primaryColor,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(
                _formatDuration(_totalMinutes),

                style: const TextStyle(fontSize: 13),
              ),

              Text(
                'Hedef: '
                '${_formatDuration(_dailyGoalMinutes)}',

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
  // KATEGORİ KARTI
  // ============================================================

  Widget _buildCategoryCard() {
    final otherMinutes = (_totalMinutes - _categoryTotal).clamp(
      0,
      _totalMinutes,
    );

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Kategori Dağılımı',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 18),

          _categoryRow(
            icon: Icons.smartphone_rounded,
            title: 'Sosyal Medya',
            minutes: _socialMediaMinutes,
          ),

          const SizedBox(height: 12),

          _categoryRow(
            icon: Icons.sports_esports_rounded,
            title: 'Oyun',
            minutes: _gamingMinutes,
          ),

          const SizedBox(height: 12),

          _categoryRow(
            icon: Icons.ondemand_video_rounded,
            title: 'Video',
            minutes: _videoMinutes,
          ),

          const SizedBox(height: 12),

          _categoryRow(
            icon: Icons.apps_rounded,
            title: 'Diğer',
            minutes: otherMinutes,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KATEGORİ SATIRI
  // ============================================================

  Widget _categoryRow({
    required IconData icon,
    required String title,
    required int minutes,
  }) {
    final percentage = _categoryPercentage(minutes);

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.primaryColor),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            Text(
              _formatDuration(minutes),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(width: 8),

            Text(
              '${(percentage * 100).round()}%',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(10),

          child: LinearProgressIndicator(
            value: percentage,

            minHeight: 6,

            backgroundColor: const Color(0xFFEAEAEA),

            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HAFTALIK ÖZET
  // ============================================================

  Widget _buildWeeklySummary() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.calendar_view_week,
            title: '7 Günlük Ortalama',
            value: _formatDuration(_weeklyAverage),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _summaryCard(
            icon: Icons.history_rounded,
            title: 'Kayıtlı Gün',
            value: '${_history.length} gün',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ÖZET KARTI
  // ============================================================

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: AppTheme.primaryColor),

          const SizedBox(height: 12),

          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GRAFİK
  // ============================================================

  Widget _buildChart() {
    if (_history.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(24),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(20),
        ),

        child: const Column(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: AppTheme.primaryColor,
            ),

            SizedBox(height: 10),

            Text(
              'Henüz geçmiş kullanım verisi yok.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final maxValue = _history
        .map((e) => e.totalMinutes)
        .fold<int>(
          0,
          (previous, current) => current > previous ? current : previous,
        );

    final chartMax = maxValue < 60 ? 60.0 : maxValue * 1.25;

    return Container(
      width: double.infinity,

      height: 280,

      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),
      ),

      child: LineChart(
        LineChartData(
          minY: 0,

          maxY: chartMax,

          gridData: const FlGridData(show: true, drawVerticalLine: false),

          borderData: FlBorderData(show: false),

          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,

                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()} dk',
                    style: const TextStyle(fontSize: 9),
                  );
                },
              ),
            ),

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,

                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 || index >= _history.length) {
                    return const SizedBox();
                  }

                  final date = _history[index].date;

                  final parts = date.split('-');

                  if (parts.length == 3) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),

                      child: Text(
                        '${parts[2]}/${parts[1]}',
                        style: const TextStyle(fontSize: 9),
                      ),
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ),

          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                _history.length,
                (index) => FlSpot(
                  index.toDouble(),
                  _history[index].totalMinutes.toDouble(),
                ),
              ),

              isCurved: true,

              barWidth: 3,

              dotData: const FlDotData(show: true),

              belowBarData: BarAreaData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GEÇMİŞ LİSTESİ
  // ============================================================

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(20),
        ),

        child: const Text(
          'Geçmiş kullanım kaydı bulunmuyor.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final reversedHistory = _history.reversed.toList();

    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          for (int i = 0; i < reversedHistory.length; i++)
            _historyItem(
              reversedHistory[i],
              isLast: i == reversedHistory.length - 1,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // GEÇMİŞ ITEM
  // ============================================================

  Widget _historyItem(DailyUsage usage, {required bool isLast}) {
    String formattedDate = usage.date;

    final parts = usage.date.split('-');

    if (parts.length == 3) {
      formattedDate = '${parts[2]}.${parts[1]}.${parts[0]}';
    }

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),

      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),

              borderRadius: BorderRadius.circular(12),
            ),

            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  formattedDate,

                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Toplam ekran süresi',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          Text(
            _formatDuration(usage.totalMinutes),

            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KULLANIM ITEM
  // ============================================================

  Widget _usageItem(IconData icon, String title, int minutes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Text(
            _formatDuration(minutes),

            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BİLGİ KARTI
  // ============================================================

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(16),
      ),

      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'Kullanım verilerin Android cihazından '
              'alınır ve Mindora analizleri için '
              'güvenli şekilde kaydedilir. '
              'Verileri güncellemek için sağ üstteki '
              'senkronizasyon butonunu kullanabilirsin.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GÜNLÜK KULLANIM MODELİ
// ============================================================

class DailyUsage {
  final String date;
  final int totalMinutes;

  DailyUsage({required this.date, required this.totalMinutes});
}
