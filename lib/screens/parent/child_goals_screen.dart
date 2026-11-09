import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';

class ParentChildGoalsScreen extends StatefulWidget {
  const ParentChildGoalsScreen({super.key});

  @override
  State<ParentChildGoalsScreen> createState() => _ParentChildGoalsScreenState();
}

class _ParentChildGoalsScreenState extends State<ParentChildGoalsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String? _childId;
  String? _childName;

  int _currentGoalMinutes = 150;
  int _selectedGoalMinutes = 150;

  final List<int> _goalOptions = [60, 90, 120, 150, 180, 210, 240];

  @override
  void initState() {
    super.initState();
    _loadChildGoal();
  }

  // ============================================================
  // BUGÜNÜN TARİHİ
  // ============================================================

  String _getTodayId() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // ÇOCUK VE HEDEFİ YÜKLE
  // ============================================================

  Future<void> _loadChildGoal() async {
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
      // PARENT
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

      final List<dynamic> childIds = parentData?['childIds'] ?? [];

      if (childIds.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      final childId = childIds.first.toString();

      // ========================================================
      // ÇOCUK
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

      int goalMinutes = 150;

      // ========================================================
      // 1. ÖNCE KALICI HEDEFİ OKU
      // ========================================================

      final goalDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('goals')
          .doc('current')
          .get();

      if (goalDocument.exists) {
        final goalData = goalDocument.data();

        final value = goalData?['dailyScreenTimeGoal'];

        if (value is num) {
          goalMinutes = value.toInt();
        }
      }

      // ========================================================
      // ESKİ SİSTEMDEN VERİ VARSA FALLBACK
      // ========================================================

      if (!goalDocument.exists) {
        final screenTimeDocument = await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .collection('screenTime')
            .doc(_getTodayId())
            .get();

        if (screenTimeDocument.exists) {
          final data = screenTimeDocument.data();

          final value = data?['dailyGoalMinutes'];

          if (value is num) {
            goalMinutes = value.toInt();
          }
        }
      }

      // Geçersiz bir değer varsa varsayılan
      if (!_goalOptions.contains(goalMinutes)) {
        goalMinutes = 150;
      }

      if (!mounted) return;

      setState(() {
        _childId = childId;
        _childName = childName;

        _currentGoalMinutes = goalMinutes;

        _selectedGoalMinutes = goalMinutes;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hedef bilgisi alınırken '
            'bir hata oluştu.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HEDEFİ KAYDET
  // ============================================================

  Future<void> _saveGoal() async {
    if (_childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlı bir çocuk bulunamadı.')),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final childRef = firestore.collection('users').doc(_childId);

      final todayId = _getTodayId();

      // ========================================================
      // 1. KALICI HEDEF
      // ========================================================

      await childRef.collection('goals').doc('current').set({
        'dailyScreenTimeGoal': _selectedGoalMinutes,

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ========================================================
      // 2. BUGÜNKÜ SCREEN TIME HEDEFİ
      // ========================================================
      //
      // Böylece bugün kullanım ekranı da aynı hedefi gösterir.
      //

      await childRef.collection('screenTime').doc(todayId).set({
        'dailyGoalMinutes': _selectedGoalMinutes,

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ========================================================
      // 3. BAŞARILI
      // ========================================================

      if (!mounted) return;

      setState(() {
        _currentGoalMinutes = _selectedGoalMinutes;

        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Günlük hedef başarıyla güncellendi. 🎯')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hedef kaydedilirken '
            'bir hata oluştu.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SÜRE FORMATLAMA
  // ============================================================

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes dakika';
    }

    final hours = minutes ~/ 60;

    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '$hours saat';
    }

    return '$hours saat '
        '$remainingMinutes dakika';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B1D),

      appBar: AppBar(
        backgroundColor: const Color(0xFF100B1D),
        foregroundColor: const Color(0xFFF7F2FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Çocuk Hedefi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ==================================================
                  // ÇOCUK BİLGİSİ
                  // ==================================================

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,

                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),

                            shape: BoxShape.circle,
                          ),

                          child: const Icon(
                            Icons.child_care_rounded,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Text(
                                'Çocuğunuz',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                _childName ?? 'Çocuk',

                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // BAŞLIK
                  // ==================================================
                  const Text(
                    'Günlük Ekran Süresi Hedefi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Çocuğunuzun günlük ekran süresi '
                    'için bir hedef belirleyin.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // SEÇİLİ HEDEF
                  // ==================================================
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(24),

                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: const [Color(0xFF7B4DCE), Color(0xFF3C8EAA)],
                      ),

                      borderRadius: BorderRadius.circular(24),
                    ),

                    child: Column(
                      children: [
                        const Text(
                          'Seçilen Hedef',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _formatDuration(_selectedGoalMinutes),

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Mevcut hedef: '
                          '${_formatDuration(_currentGoalMinutes)}',

                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // HEDEF SEÇ
                  // ==================================================
                  const Text(
                    'Hedef Seç',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 14),

                  GridView.builder(
                    shrinkWrap: true,

                    physics: const NeverScrollableScrollPhysics(),

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.5,
                        ),

                    itemCount: _goalOptions.length,

                    itemBuilder: (context, index) {
                      final minutes = _goalOptions[index];

                      final isSelected = _selectedGoalMinutes == minutes;

                      return GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _selectedGoalMinutes = minutes;
                                });
                              },

                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),

                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.white,

                            borderRadius: BorderRadius.circular(16),

                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade200,

                              width: isSelected ? 2 : 1,
                            ),
                          ),

                          child: Center(
                            child: Text(
                              _formatDuration(minutes),

                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // KAYDET
                  // ==================================================
                  SizedBox(
                    width: double.infinity,

                    height: 56,

                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveGoal,

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
                              'HEDEFİ KAYDET',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
