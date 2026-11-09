import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/app_theme.dart';

class AiRiskTrendScreen extends StatefulWidget {
  const AiRiskTrendScreen({super.key});

  @override
  State<AiRiskTrendScreen> createState() => _AiRiskTrendScreenState();
}

class _AiRiskTrendScreenState extends State<AiRiskTrendScreen> {
  String? _childId;
  String _childName = 'Çocuk Profili';

  bool _isLoading = true;
  String? _errorMessage;

  List<_RiskData> _riskData = [];

  @override
  void initState() {
    super.initState();
    _loadRiskData();
  }

  // ============================================================
  // VERİLERİ GETİR
  // ============================================================

  Future<void> _loadRiskData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final parent = FirebaseAuth.instance.currentUser;

      if (parent == null) {
        throw Exception('Kullanıcı oturumu bulunamadı.');
      }

      // ========================================================
      // PARENT
      // ========================================================

      final parentDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(parent.uid)
          .get();

      if (!parentDocument.exists) {
        throw Exception('Ebeveyn profili bulunamadı.');
      }

      final parentData = parentDocument.data();

      String? childId;

      // ========================================================
      // childIds
      // ========================================================

      final childIds = parentData?['childIds'];

      if (childIds is List && childIds.isNotEmpty) {
        childId = childIds.first.toString();
      }

      // ========================================================
      // parentId ÜZERİNDEN BUL
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

      if (childId == null) {
        throw Exception('Bağlı çocuk bulunamadı.');
      }

      // ========================================================
      // ÇOCUK BİLGİSİ
      // ========================================================

      final childDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .get();

      final childData = childDocument.data();

      final childName = childData?['name']?.toString() ?? 'Çocuk Profili';

      // ========================================================
      // SON 7 GÜN
      // ========================================================

      final now = DateTime.now();

      final List<_RiskData> results = [];

      for (int i = 6; i >= 0; i--) {
        final date = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));

        final dateId =
            '${date.year}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

        final document = await FirebaseFirestore.instance
            .collection('users')
            .doc(childId)
            .collection('aiAnalysis')
            .doc(dateId)
            .get();

        if (document.exists) {
          final data = document.data();

          final probability = _readDouble(data?['riskProbability']);

          results.add(
            _RiskData(
              date: date,
              probability: probability,
              riskLevel: data?['riskLevel']?.toString() ?? 'Belirlenemedi',
            ),
          );
        } else {
          results.add(
            _RiskData(date: date, probability: null, riskLevel: 'Analiz yok'),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _childId = childId;
        _childName = childName;
        _riskData = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // DOUBLE OKUMA
  // ============================================================

  double _readDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // TARİH
  // ============================================================

  String _dayName(DateTime date) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return days[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}';
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
          'AI Risk Trendi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadRiskData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Colors.redAccent,
              ),

              const SizedBox(height: 16),

              const Text(
                'Veriler alınamadı',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFFC4B9D9)),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loadRiskData,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRiskData,

      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _buildChildCard(),

            const SizedBox(height: 20),

            _buildInfoCard(),

            const SizedBox(height: 20),

            _buildChartCard(),

            const SizedBox(height: 20),

            _buildDailyList(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ÇOCUK KARTI
  // ============================================================

  Widget _buildChildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: const [Color(0xFF7B4DCE), Color(0xFF3C8EAA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),

      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.psychology_rounded,
              color: const Color(0xFF211A38),
              size: 30,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Risk Analizi',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 4),

                Text(
                  _childName,
                  style: const TextStyle(
                    color: const Color(0xFF211A38),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
  // BİLGİ KARTI
  // ============================================================

  Widget _buildInfoCard() {
    final validData = _riskData
        .where((item) => item.probability != null)
        .toList();

    if (validData.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: const Color(0xFF211A38),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFB99AFF).withValues(alpha: 0.18),
          ),
        ),

        child: const Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 40,
              color: const Color(0xFFB99AFF),
            ),

            SizedBox(height: 10),

            Text(
              'Henüz AI analiz verisi yok.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final average =
        validData.map((item) => item.probability!).reduce((a, b) => a + b) /
        validData.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF211A38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB99AFF).withValues(alpha: 0.18),
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child: _InfoItem(
              title: 'Analiz',
              value: '${validData.length}/7',
              icon: Icons.analytics_rounded,
            ),
          ),

          Expanded(
            child: _InfoItem(
              title: 'Ortalama Risk',
              value: '%${(average * 100).round()}',
              icon: Icons.trending_up_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GRAFİK
  // ============================================================

  Widget _buildChartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),

      decoration: BoxDecoration(
        color: const Color(0xFF211A38),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFB99AFF).withValues(alpha: 0.18),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Son 7 Günlük Risk Trendi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF7F2FF),
              ),
            ),
          ),

          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'AI tarafından hesaplanan risk olasılığı',
              style: TextStyle(fontSize: 12, color: const Color(0xFFC4B9D9)),
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            height: 250,
            child: CustomPaint(
              painter: _RiskChartPainter(data: _riskData),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GÜNLÜK LİSTE
  // ============================================================

  Widget _buildDailyList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Günlük Analizler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        ..._riskData.reversed.map((item) => _buildDailyItem(item)),
      ],
    );
  }

  Widget _buildDailyItem(_RiskData item) {
    final hasData = item.probability != null;

    final probability = hasData ? item.probability! : 0;

    final isRisky = item.riskLevel.toLowerCase() == 'riskli';

    final Color color = !hasData
        ? const Color(0xFFC4B9D9)
        : isRisky
        ? Colors.red
        : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFF211A38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFB99AFF).withValues(alpha: 0.16),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),

            child: Icon(
              hasData ? Icons.psychology_rounded : Icons.remove_rounded,
              color: color,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dayName(item.date)} • '
                  '${_formatDate(item.date)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  item.riskLevel,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Text(
            hasData ? '%${(probability * 100).round()}' : '--',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INFO ITEM
// ============================================================

class _InfoItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFB99AFF), size: 27),

        const SizedBox(height: 7),

        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 3),

        Text(
          title,
          style: TextStyle(fontSize: 12, color: const Color(0xFFC4B9D9)),
        ),
      ],
    );
  }
}

// ============================================================
// RİSK DATA
// ============================================================

class _RiskData {
  final DateTime date;
  final double? probability;
  final String riskLevel;

  _RiskData({
    required this.date,
    required this.probability,
    required this.riskLevel,
  });
}

// ============================================================
// GRAFİK PAINTER
// ============================================================

class _RiskChartPainter extends CustomPainter {
  final List<_RiskData> data;

  _RiskChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 42.0;
    const bottomPadding = 35.0;
    const topPadding = 10.0;
    const rightPadding = 10.0;

    final chartWidth = size.width - leftPadding - rightPadding;

    final chartHeight = size.height - topPadding - bottomPadding;

    final paint = Paint()
      ..color = const Color(0xFF69E8E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final gridPaint = Paint()
      ..color = const Color(0xFFB99AFF).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // ========================================================
    // Y GRID
    // ========================================================

    for (int i = 0; i <= 5; i++) {
      final ratio = i / 5;

      final y = topPadding + chartHeight * ratio;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final percentage = 100 - (i * 20);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$percentage%',
          style: const TextStyle(fontSize: 10, color: const Color(0xFFC4B9D9)),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // ========================================================
    // VERİ NOKTALARI
    // ========================================================

    final validPoints = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final item = data[i];

      if (item.probability == null) {
        continue;
      }

      final x = data.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + (chartWidth / (data.length - 1)) * i;

      final probability = item.probability!.clamp(0.0, 1.0);

      final y = topPadding + chartHeight * (1 - probability);

      validPoints.add(Offset(x, y));
    }

    // ========================================================
    // ÇİZGİ
    // ========================================================

    if (validPoints.length >= 2) {
      final path = Path();

      path.moveTo(validPoints.first.dx, validPoints.first.dy);

      for (int i = 1; i < validPoints.length; i++) {
        path.lineTo(validPoints[i].dx, validPoints[i].dy);
      }

      canvas.drawPath(path, paint);
    }

    // ========================================================
    // NOKTALAR
    // ========================================================

    for (final point in validPoints) {
      final circlePaint = Paint()
        ..color = const Color(0xFF69E8E0)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point, 5, circlePaint);
    }

    // ========================================================
    // X LABELS
    // ========================================================

    for (int i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + (chartWidth / (data.length - 1)) * i;

      final textPainter = TextPainter(
        text: TextSpan(
          text: _dayName(data[i].date),
          style: const TextStyle(fontSize: 10, color: const Color(0xFFC4B9D9)),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 22),
      );
    }
  }

  String _dayName(DateTime date) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return days[date.weekday - 1];
  }

  @override
  bool shouldRepaint(covariant _RiskChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
