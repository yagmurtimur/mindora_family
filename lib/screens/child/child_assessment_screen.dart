import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';

class ChildAssessmentScreen extends StatefulWidget {
  const ChildAssessmentScreen({super.key});

  @override
  State<ChildAssessmentScreen> createState() => _ChildAssessmentScreenState();
}

class _ChildAssessmentScreenState extends State<ChildAssessmentScreen> {
  bool _isSaving = false;

  // Soruların puanları
  double _anxietyScore = 5;
  double _stressScore = 5;
  double _digitalControlScore = 5;
  double _phoneDiscomfortScore = 5;

  String _getDateId() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAssessment() async {
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
      // Dört sorunun ortalaması
      final anxietyScore =
          (_anxietyScore +
              _stressScore +
              _digitalControlScore +
              _phoneDiscomfortScore) /
          4;

      final dateId = _getDateId();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assessments')
          .doc(dateId)
          .set({
            'anxietyScore': double.parse(anxietyScore.toStringAsFixed(2)),
            'stressScore': _stressScore,
            'digitalControlScore': _digitalControlScore,
            'phoneDiscomfortScore': _phoneDiscomfortScore,
            'date': dateId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Değerlendirmen başarıyla kaydedildi. 💜'),
        ),
      );

      // Birkaç saniye sonra geri dön
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Değerlendirme kaydedilemedi: $e')),
      );
    }
  }

  Widget _buildQuestionCard({
    required int questionNumber,
    required String question,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$questionNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Text(
              description,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hiç',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              Text(
                '${value.round()}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),

              const Text(
                'Çok fazla',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),

          Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: AppTheme.primaryColor,
            inactiveColor: Colors.grey.shade200,
            label: value.round().toString(),
            onChanged: _isSaving ? null : onChanged,
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              11,
              (index) => Text(
                '$index',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,

      appBar: AppBar(title: const Text('Günlük Değerlendirme')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // =========================================
            // BAŞLIK
            // =========================================

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
                  Icon(Icons.psychology_rounded, color: Colors.white, size: 42),

                  SizedBox(height: 14),

                  Text(
                    'Bugün kendini nasıl hissediyorsun?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),

                  SizedBox(height: 10),

                  Text(
                    'Aşağıdaki soruları 0 ile 10 '
                    'arasında değerlendir. Bu değerlendirme '
                    'dijital alışkanlıklarını daha iyi '
                    'anlamamıza yardımcı olur.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            const Text(
              'Kendini Değerlendir',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Her soruda sana en uygun puanı seç.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),

            const SizedBox(height: 18),

            // =========================================
            // SORU 1
            // =========================================
            _buildQuestionCard(
              questionNumber: 1,
              question: 'Son günlerde kendini ne kadar kaygılı hissediyorsun?',
              description:
                  'Günlük hayatında endişe veya kaygı hissetme düzeyin.',
              value: _anxietyScore,
              onChanged: (value) {
                setState(() {
                  _anxietyScore = value;
                });
              },
            ),

            // =========================================
            // SORU 2
            // =========================================
            _buildQuestionCard(
              questionNumber: 2,
              question: 'Bugün ne kadar stresli hissediyorsun?',
              description:
                  'Gün içinde yaşadığın stres veya baskı düzeyini değerlendir.',
              value: _stressScore,
              onChanged: (value) {
                setState(() {
                  _stressScore = value;
                });
              },
            ),

            // =========================================
            // SORU 3
            // =========================================
            _buildQuestionCard(
              questionNumber: 3,
              question:
                  'Telefon kullanımını kontrol etmekte ne kadar zorlanıyorsun?',
              description:
                  'Telefonu bırakmak veya kullanım süreni sınırlamak ne kadar zor?',
              value: _digitalControlScore,
              onChanged: (value) {
                setState(() {
                  _digitalControlScore = value;
                });
              },
            ),

            // =========================================
            // SORU 4
            // =========================================
            _buildQuestionCard(
              questionNumber: 4,
              question:
                  'Telefonunu kullanamadığında ne kadar huzursuz hissediyorsun?',
              description:
                  'Telefondan uzak kaldığında yaşadığın rahatsızlık düzeyini değerlendir.',
              value: _phoneDiscomfortScore,
              onChanged: (value) {
                setState(() {
                  _phoneDiscomfortScore = value;
                });
              },
            ),

            const SizedBox(height: 8),

            // =========================================
            // BİLGİ KARTI
            // =========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.white,
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
                      'Bu değerlendirme bir tıbbi tanı '
                      'değildir. Veriler, Mindora içerisinde '
                      'dijital kullanım alışkanlıklarını '
                      'analiz etmeye yardımcı olmak amacıyla kullanılır.',
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

            const SizedBox(height: 24),

            // =========================================
            // KAYDET
            // =========================================
            SizedBox(
              width: double.infinity,
              height: 56,

              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAssessment,

                icon: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.check_rounded),

                label: Text(
                  _isSaving ? 'KAYDEDİLİYOR...' : 'DEĞERLENDİRMEYİ KAYDET',
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,

                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
