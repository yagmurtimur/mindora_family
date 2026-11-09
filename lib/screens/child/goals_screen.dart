import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';

class ChildGoalsScreen extends StatefulWidget {
  const ChildGoalsScreen({super.key});

  @override
  State<ChildGoalsScreen> createState() => _ChildGoalsScreenState();
}

class _ChildGoalsScreenState extends State<ChildGoalsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  int _screenTimeMinutes = 0;
  int _dailyGoalMinutes = 150;

  double _sleepHours = 0;
  int _physicalActivityMinutes = 0;
  int _workStudyMinutes = 0;

  final TextEditingController _sleepController = TextEditingController();
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _studyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGoalData();
  }

  @override
  void dispose() {
    _sleepController.dispose();
    _activityController.dispose();
    _studyController.dispose();
    super.dispose();
  }

  String _getDateId() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadGoalData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      final dateId = _getDateId();

      // ------------------------------------------
      // EKRAN SÜRESİ
      // ------------------------------------------

      final screenTimeDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('screenTime')
          .doc(dateId)
          .get();

      // ------------------------------------------
      // GÜNLÜK VERİLER
      // ------------------------------------------

      final dailyStatsDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyStats')
          .doc(dateId)
          .get();

      int screenTime = 0;
      int dailyGoal = 150;

      double sleepHours = 0;
      int physicalActivityMinutes = 0;
      int workStudyMinutes = 0;

      if (screenTimeDocument.exists) {
        final data = screenTimeDocument.data();

        screenTime = _readInt(data?['totalMinutes']);

        dailyGoal = _readInt(data?['dailyGoalMinutes'], defaultValue: 150);
      }

      if (dailyStatsDocument.exists) {
        final data = dailyStatsDocument.data();

        sleepHours = _readDouble(data?['sleepHours']);

        physicalActivityMinutes = _readInt(data?['physicalActivityMinutes']);

        workStudyMinutes = _readInt(data?['workStudyMinutes']);
      }

      if (!mounted) return;

      setState(() {
        _screenTimeMinutes = screenTime;
        _dailyGoalMinutes = dailyGoal;

        _sleepHours = sleepHours;
        _physicalActivityMinutes = physicalActivityMinutes;
        _workStudyMinutes = workStudyMinutes;

        _sleepController.text = sleepHours > 0 ? sleepHours.toString() : '';

        _activityController.text = physicalActivityMinutes > 0
            ? physicalActivityMinutes.toString()
            : '';

        _studyController.text = workStudyMinutes > 0
            ? workStudyMinutes.toString()
            : '';

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hedef bilgileri alınırken bir hata oluştu.'),
        ),
      );
    }
  }

  int _readInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return defaultValue;
  }

  double _readDouble(dynamic value, {double defaultValue = 0}) {
    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return defaultValue;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes dakika';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '$hours saat';
    }

    return '$hours saat $remainingMinutes dakika';
  }

  double _progress(double current, double target) {
    if (target <= 0) {
      return 0;
    }

    final value = current / target;

    if (value > 1) {
      return 1;
    }

    return value;
  }

  Future<void> _saveDailyStats() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum açmış kullanıcı bulunamadı.')),
      );

      return;
    }

    final sleepText = _sleepController.text.trim().replaceAll(',', '.');

    final activityText = _activityController.text.trim();

    final studyText = _studyController.text.trim();

    final sleep = double.tryParse(sleepText);
    final activity = int.tryParse(activityText);
    final study = int.tryParse(studyText);

    if (sleep == null || sleep < 0 || sleep > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uyku süresini 0-24 saat arasında girin.'),
        ),
      );

      return;
    }

    if (activity == null || activity < 0 || activity > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hareket süresini 0-1440 dakika arasında girin.'),
        ),
      );

      return;
    }

    if (study == null || study < 0 || study > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ders çalışma süresini 0-1440 dakika arasında girin.'),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dateId = _getDateId();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyStats')
          .doc(dateId)
          .set({
            'sleepHours': sleep,
            'physicalActivityMinutes': activity,
            'workStudyMinutes': study,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _sleepHours = sleep;
        _physicalActivityMinutes = activity;
        _workStudyMinutes = study;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Günlük verilerin başarıyla kaydedildi. ✓'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veriler kaydedilirken bir hata oluştu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,

      appBar: AppBar(title: const Text('Hedeflerim')),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _loadGoalData,

              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // BUGÜNKÜ EKRAN SÜRESİ HEDEFİ
                    // ==========================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),

                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),

                        borderRadius: BorderRadius.circular(24),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Bugünkü Ekran Süresi Hedefim',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _formatDuration(_dailyGoalMinutes),

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            '${_formatDuration(_screenTimeMinutes)} '
                            '/ ${_formatDuration(_dailyGoalMinutes)}',

                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // EKRAN SÜRESİ İLERLEMESİ
                    // ==========================================
                    const Text(
                      'Ekran Süresi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text(
                                'Hedef ilerlemesi',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),

                              Text(
                                '${(_progress(_screenTimeMinutes.toDouble(), _dailyGoalMinutes.toDouble()) * 100).round()}%',

                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),

                            child: LinearProgressIndicator(
                              value: _progress(
                                _screenTimeMinutes.toDouble(),
                                _dailyGoalMinutes.toDouble(),
                              ),

                              minHeight: 12,

                              backgroundColor: const Color(0xFFE8E8E8),

                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==========================================
                    // GÜNLÜK VERİLER
                    // ==========================================
                    const Text(
                      'Bugünkü Verilerim',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Bu bilgileri girerek günlük '
                      'durumunu takip edebilir ve AI analizinin '
                      'daha doğru çalışmasına yardımcı olabilirsin.',

                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // UYKU
                    // ==========================================
                    _inputCard(
                      icon: Icons.bedtime_rounded,
                      title: 'Uyku',
                      subtitle: 'Dün gece kaç saat uyudun?',
                      controller: _sleepController,
                      suffix: 'saat',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // HAREKET
                    // ==========================================
                    _inputCard(
                      icon: Icons.directions_run_rounded,
                      title: 'Fiziksel Aktivite',
                      subtitle: 'Bugün kaç dakika hareket ettin?',
                      controller: _activityController,
                      suffix: 'dakika',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // DERS
                    // ==========================================
                    _inputCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Ders Çalışma',
                      subtitle: 'Bugün kaç dakika ders çalıştın?',
                      controller: _studyController,
                      suffix: 'dakika',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // KAYDET
                    // ==========================================
                    SizedBox(
                      width: double.infinity,
                      height: 56,

                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveDailyStats,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,

                          foregroundColor: Colors.white,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),

                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,

                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'VERİLERİ KAYDET',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==========================================
                    // ÖZET
                    // ==========================================
                    const Text(
                      'Bugünkü Durumum',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _summaryCard(
                      icon: Icons.bedtime_rounded,
                      title: 'Uyku',
                      value: _sleepHours > 0
                          ? '${_sleepHours.toStringAsFixed(1)} saat'
                          : 'Veri yok',
                      target: 'Hedef: 8 saat',
                      progress: _progress(_sleepHours, 8),
                    ),

                    _summaryCard(
                      icon: Icons.directions_run_rounded,
                      title: 'Hareket',
                      value: '$_physicalActivityMinutes dakika',
                      target: 'Hedef: 30 dakika',
                      progress: _progress(
                        _physicalActivityMinutes.toDouble(),
                        30,
                      ),
                    ),

                    _summaryCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Ders Çalışma',
                      value: _formatDuration(_workStudyMinutes),
                      target: 'Hedef: 2 saat',
                      progress: _progress(_workStudyMinutes.toDouble(), 120),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _inputCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String suffix,
    required TextInputType keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: AppTheme.primaryColor, size: 25),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),

          SizedBox(
            width: 90,

            child: TextField(
              controller: controller,
              keyboardType: keyboardType,

              textAlign: TextAlign.center,

              decoration: InputDecoration(
                suffixText: suffix,

                filled: true,

                fillColor: AppTheme.backgroundColor,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),

                  borderSide: BorderSide.none,
                ),

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String target,
    required double progress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 28),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      target,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),

            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,

              backgroundColor: const Color(0xFFE8E8E8),

              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
