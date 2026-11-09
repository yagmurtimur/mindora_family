import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';

class ChildMoodScreen extends StatefulWidget {
  const ChildMoodScreen({super.key});

  @override
  State<ChildMoodScreen> createState() => _ChildMoodScreenState();
}

class _ChildMoodScreenState extends State<ChildMoodScreen> {
  String? _selectedMood;

  bool _isSaving = false;

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😊', 'title': 'Mutlu', 'value': 'happy'},
    {'emoji': '🙂', 'title': 'İyi', 'value': 'good'},
    {'emoji': '😐', 'title': 'Normal', 'value': 'normal'},
    {'emoji': '😔', 'title': 'Üzgün', 'value': 'sad'},
    {'emoji': '😡', 'title': 'Kızgın', 'value': 'angry'},
  ];

  // ============================================================
  // RUH HALİNİ FIRESTORE'A KAYDET
  // ============================================================

  Future<void> _saveMood() async {
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bugün nasıl hissettiğini seç.')),
      );

      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı oturumu bulunamadı.')),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Bugünün tarihi
      final now = DateTime.now();

      final dateId =
          '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      // Seçilen mood bilgisini bul
      final selectedMoodData = _moods.firstWhere(
        (mood) => mood['value'] == _selectedMood,
      );

      // ========================================================
      // FIRESTORE
      // users
      //   └── childUID
      //       └── moods
      //           └── 2026-08-25
      // ========================================================

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .doc(dateId)
          .set({
            'mood': selectedMoodData['value'],
            'moodTitle': selectedMoodData['title'],
            'emoji': selectedMoodData['emoji'],
            'date': dateId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruh halin başarıyla kaydedildi. 💜')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ruh hali kaydedilemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,

      appBar: AppBar(title: const Text('Ruh Halim')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // BAŞLIK KARTI
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugün nasıl hissediyorsun?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Ruh halini seçerek kendini '
                    'daha iyi tanımaya başlayabilirsin.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Bugünkü Ruh Halin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // MOOD SEÇENEKLERİ
            // ==================================================
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: _moods.length,
              itemBuilder: (context, index) {
                final mood = _moods[index];

                final isSelected = _selectedMood == mood['value'];

                return GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _selectedMood = mood['value'];
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mood['emoji'],
                          style: const TextStyle(fontSize: 42),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          mood['title'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 28),

            // ==================================================
            // KAYDET
            // ==================================================
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMood,
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
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'RUH HALİMİ KAYDET',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // BİLGİ
            // ==================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_outline_rounded,
                    color: AppTheme.primaryColor,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      'Ruh halini düzenli takip etmek, '
                      'dijital alışkanlıklarınla kendini '
                      'daha iyi anlamana yardımcı olabilir.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
