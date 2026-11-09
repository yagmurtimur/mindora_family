import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import 'settings_screen.dart';
import 'add_child_screen.dart';
import 'ai_analysis_screen.dart';
import 'child_goals_screen.dart';
import 'app_restrictions_screen.dart';
import 'parent_ai_history_screen.dart';
import 'recommendations_screen.dart';
import 'usage_screen.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _childName;
  String? _childId;

  int _screenTimeMinutes = 0;
  int _applicationCount = 0;

  String _riskLevel = 'Henüz analiz yok';
  double _riskProbability = 0;

  bool _isLoading = true;
  String? _errorMessage;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ============================================================
  // DASHBOARD VERİLERİNİ GETİR
  // ============================================================

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final parent = _auth.currentUser;

      if (parent == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage = 'Oturum bilgisi bulunamadı.';
        });

        return;
      }

      // --------------------------------------------------------
      // PARENT BİLGİLERİ
      // --------------------------------------------------------

      final parentDocument = await _firestore
          .collection('users')
          .doc(parent.uid)
          .get();

      if (!parentDocument.exists) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage = 'Kullanıcı bilgileri bulunamadı.';
        });

        return;
      }

      final parentData = parentDocument.data();

      String? childId;

      // --------------------------------------------------------
      // 1. childIds ALANINDAN ÇOCUK BUL
      // --------------------------------------------------------

      final dynamic childIdsData = parentData?['childIds'];

      if (childIdsData is List && childIdsData.isNotEmpty) {
        childId = childIdsData.first.toString();
      }

      // --------------------------------------------------------
      // 2. childIds YOKSA parentId ÜZERİNDEN BUL
      // --------------------------------------------------------

      if (childId == null || childId.isEmpty) {
        final childQuery = await _firestore
            .collection('users')
            .where('parentId', isEqualTo: parent.uid)
            .where('role', isEqualTo: 'child')
            .limit(1)
            .get();

        if (childQuery.docs.isNotEmpty) {
          childId = childQuery.docs.first.id;
        }
      }

      // --------------------------------------------------------
      // ÇOCUK BULUNAMADI
      // --------------------------------------------------------

      if (childId == null || childId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _childName = null;
          _childId = null;
          _screenTimeMinutes = 0;
          _applicationCount = 0;
          _riskLevel = 'Henüz analiz yok';
          _riskProbability = 0;
          _isLoading = false;
        });

        return;
      }

      // --------------------------------------------------------
      // ÇOCUK BİLGİLERİNİ GETİR
      // --------------------------------------------------------

      final childDocument = await _firestore
          .collection('users')
          .doc(childId)
          .get();

      if (!childDocument.exists) {
        if (!mounted) return;

        setState(() {
          _childName = null;
          _childId = null;
          _screenTimeMinutes = 0;
          _applicationCount = 0;
          _riskLevel = 'Henüz analiz yok';
          _riskProbability = 0;
          _isLoading = false;
        });

        return;
      }

      final childData = childDocument.data() ?? {};

      // --------------------------------------------------------
      // ÇOCUK ADI
      // --------------------------------------------------------

      String childName = 'Çocuğunuz';

      final dynamic name = childData['name'];

      if (name != null && name.toString().trim().isNotEmpty) {
        childName = name.toString();
      } else {
        final dynamic displayName = childData['displayName'];

        if (displayName != null && displayName.toString().trim().isNotEmpty) {
          childName = displayName.toString();
        }
      }

      // --------------------------------------------------------
      // EKRAN SÜRESİ
      // --------------------------------------------------------

      final int screenTime = _parseInt(
        childData['dailyScreenTime'] ??
            childData['screenTimeMinutes'] ??
            childData['screenTime'] ??
            0,
      );

      // --------------------------------------------------------
      // UYGULAMA SAYISI
      // --------------------------------------------------------

      int applicationCount = 0;

      final dynamic applications = childData['applications'];

      if (applications is List) {
        applicationCount = applications.length;
      } else {
        applicationCount = _parseInt(
          childData['applicationCount'] ?? childData['appCount'] ?? 0,
        );
      }

      // --------------------------------------------------------
      // RİSK BİLGİLERİ
      // --------------------------------------------------------

      String riskLevel =
          childData['riskLevel']?.toString() ?? 'Henüz analiz yok';

      double riskProbability = _parseDouble(
        childData['riskProbability'] ??
            childData['addictionProbability'] ??
            childData['probability'] ??
            0,
      );

      // Olasılık 0-1 arasında geldiyse yüzdeye çevir
      if (riskProbability > 0 && riskProbability <= 1) {
        riskProbability *= 100;
      }

      if (riskProbability > 100) {
        riskProbability = 100;
      }

      // --------------------------------------------------------
      // STATE GÜNCELLE
      // --------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _childName = childName;
        _childId = childId;
        _screenTimeMinutes = screenTime;
        _applicationCount = applicationCount;
        _riskLevel = riskLevel;
        _riskProbability = riskProbability;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Parent Dashboard Error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Veriler yüklenirken bir hata oluştu.';
      });
    }
  }

  // ============================================================
  // INTEGER PARSE
  // ============================================================

  int _parseInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  // ============================================================
  // DOUBLE PARSE
  // ============================================================

  double _parseDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ============================================================
  // DAKİKAYI SAATE ÇEVİR
  // ============================================================

  String _formatScreenTime(int minutes) {
    if (minutes <= 0) {
      return '0 dk';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      if (remainingMinutes > 0) {
        return '$hours sa $remainingMinutes dk';
      }

      return '$hours sa';
    }

    return '$remainingMinutes dk';
  }

  // ============================================================
  // RİSK RENGİ
  // ============================================================

  Color _getRiskColor() {
    final level = _riskLevel.toLowerCase();

    if (level.contains('yüksek') || level.contains('high')) {
      return Colors.red;
    }

    if (level.contains('orta') || level.contains('medium')) {
      return Colors.orange;
    }

    if (level.contains('düşük') || level.contains('low')) {
      return Colors.green;
    }

    return Colors.grey;
  }

  // ============================================================
  // SAYFA GEÇİŞİ
  // ============================================================

  void _openPage(Widget page) {
    if (_childId == null) return;

    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      _loadDashboardData();
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    return Scaffold(
      backgroundColor: const Color(0xFF151020),
      appBar: _buildAppBar(),
      drawer: isDesktop ? null : _buildNavigationDrawer(),
      body: Row(
        children: [
          if (isDesktop) _buildNavigationSidebar(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF171226),
                    Color(0xFF20162F),
                    Color(0xFF151020),
                  ],
                ),
              ),
              child: RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: const Color(0xFFB89AFF),
                backgroundColor: const Color(0xFF261D3B),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    return AppBar(
      backgroundColor: const Color(0xFF1A1429),
      foregroundColor: const Color(0xFFF4EEFF),
      elevation: 0,
      centerTitle: false,
      titleSpacing: isDesktop ? 24 : 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9A6BFF), Color(0xFF5D45D8)],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9A6BFF).withValues(alpha: 0.30),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mindora',
                style: TextStyle(
                  color: Color(0xFFF5F0FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'AİLE PANELİ',
                style: TextStyle(
                  color: Color(0xFFA99BBF),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _isLoading ? null : _loadDashboardData,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFFD8C9F6)),
        ),
        IconButton(
          tooltip: 'Ayarlar',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_outlined, color: Color(0xFFD8C9F6)),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildNavigationSidebar() {
    return Container(
      width: 238,
      decoration: const BoxDecoration(
        color: Color(0xFF191329),
        border: Border(right: BorderSide(color: Color(0xFF34264B))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 18, 28),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB78AFF), Color(0xFF6C4BE8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mindora',
                          style: TextStyle(
                            color: Color(0xFFF7F1FF),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Aile Paneli',
                          style: TextStyle(
                            color: Color(0xFFA99BBF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildNavItem(
              Icons.grid_view_rounded,
              'Ana Sayfa',
              selected: true,
              onTap: () {},
            ),
            _buildNavItem(
              Icons.query_stats_rounded,
              'Kullanım Takibi',
              onTap: () => _openPage(const ParentUsageScreen()),
            ),
            _buildNavItem(
              Icons.shield_moon_rounded,
              'Uygulama Kısıtlamaları',
              onTap: () {
                if (_childId != null)
                  _openPage(AppRestrictionsScreen(childId: _childId!));
              },
            ),
            _buildNavItem(
              Icons.track_changes_rounded,
              'Hedefler',
              onTap: () => _openPage(const ParentChildGoalsScreen()),
            ),
            _buildNavItem(
              Icons.psychology_alt_rounded,
              'Yapay Zekâ Analizi',
              onTap: () => _openPage(const ParentAiAnalysisScreen()),
            ),
            _buildNavItem(
              Icons.auto_awesome_rounded,
              'Öneriler',
              onTap: () => _openPage(const ParentRecommendationsScreen()),
            ),
            _buildNavItem(
              Icons.history_rounded,
              'Analiz Geçmişi',
              onTap: () => _openPage(const ParentAiHistoryScreen()),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7650D9).withValues(alpha: 0.22),
                    const Color(0xFF34264B).withValues(alpha: 0.45),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF8E6BE0).withValues(alpha: 0.25),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFD3A8FF),
                    size: 22,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Daha sağlıklı dijital alışkanlıklar için Mindora ile birlikte!',
                    style: TextStyle(
                      color: Color(0xFFE5DAFA),
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _buildNavItem(
              Icons.settings_outlined,
              'Ayarlar',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF191329),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 18),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'Mindora • Aile Paneli',
                style: TextStyle(
                  color: Color(0xFFF7F1FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildNavItem(
              Icons.grid_view_rounded,
              'Ana Sayfa',
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            _buildNavItem(
              Icons.query_stats_rounded,
              'Kullanım Takibi',
              onTap: () {
                Navigator.pop(context);
                _openPage(const ParentUsageScreen());
              },
            ),
            _buildNavItem(
              Icons.shield_moon_rounded,
              'Uygulama Kısıtlamaları',
              onTap: () {
                Navigator.pop(context);
                if (_childId != null)
                  _openPage(AppRestrictionsScreen(childId: _childId!));
              },
            ),
            _buildNavItem(
              Icons.track_changes_rounded,
              'Hedefler',
              onTap: () {
                Navigator.pop(context);
                _openPage(const ParentChildGoalsScreen());
              },
            ),
            _buildNavItem(
              Icons.psychology_alt_rounded,
              'Yapay Zekâ Analizi',
              onTap: () {
                Navigator.pop(context);
                _openPage(const ParentAiAnalysisScreen());
              },
            ),
            _buildNavItem(
              Icons.auto_awesome_rounded,
              'Öneriler',
              onTap: () {
                Navigator.pop(context);
                _openPage(const ParentRecommendationsScreen());
              },
            ),
            _buildNavItem(
              Icons.history_rounded,
              'Analiz Geçmişi',
              onTap: () {
                Navigator.pop(context);
                _openPage(const ParentAiHistoryScreen());
              },
            ),
            _buildNavItem(
              Icons.settings_outlined,
              'Ayarlar',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? const Color(0xFF6F4BD8).withValues(alpha: 0.30)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? const Color(0xFFA786FF).withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? const Color(0xFFD9C4FF)
                      : const Color(0xFFB5A8CE),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC9BEDD),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      return _buildErrorState();
    }

    if (_childId == null) {
      return _buildNoChildState();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width >= 1000 ? 28 : 18,
        22,
        MediaQuery.of(context).size.width >= 1000 ? 28 : 18,
        30,
      ),
      children: [
        _buildWelcomeSection(),

        const SizedBox(height: 22),

        _buildChildCard(),

        const SizedBox(height: 20),

        _buildStatsSection(),

        const SizedBox(height: 20),

        _buildRiskCard(),

        const SizedBox(height: 24),

        _buildSectionTitle(
          'Mindora Araçları',
          'Çocuğunuzun dijital alışkanlıklarını takip edin',
        ),

        const SizedBox(height: 14),

        _buildToolsGrid(),

        const SizedBox(height: 24),

        _buildAddChildButton(),

        const SizedBox(height: 20),

        _buildInfoCard(),
      ],
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF382451), Color(0xFF6743A8), Color(0xFF292044)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFB89AFF).withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C5AFF).withValues(alpha: 0.17),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: -12,
            child: Icon(
              Icons.blur_on_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            right: 36,
            bottom: -25,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 65,
              color: const Color(0xFFE2C5FF).withValues(alpha: 0.16),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.waving_hand_rounded,
                      color: Color(0xFFE6D6FF),
                      size: 15,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'MINDORA AİLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'Dijital dünyaya birlikte yön verin ✨',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Çocuğunuzun dijital alışkanlıklarını takip edin, sağlıklı bir denge kurmasına destek olun.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHILD CARD
  // ============================================================

  Widget _buildChildCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xCC29213B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF594571)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5545A8).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE9E5FF), Color(0xFFD9D2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Icon(
              Icons.face_rounded,
              size: 34,
              color: Color(0xFF6555D9),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BAĞLI ÇOCUK',
                  style: TextStyle(
                    color: const Color(0xFFC9BEDD),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _childName ?? 'Çocuğunuz',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF7F1FF),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mindora aile hesabı',
                  style: TextStyle(color: Color(0xFFC9BEDD), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F8EF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: Color(0xFF258653),
                ),
                SizedBox(width: 5),
                Text(
                  'Bağlı',
                  style: TextStyle(
                    color: Color(0xFF258653),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
  // STATS
  // ============================================================

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.phone_android_rounded,
            title: 'Ekran Süresi',
            value: _formatScreenTime(_screenTimeMinutes),
            color: const Color(0xFF6758D8),
            tint: const Color(0xFFF0EDFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.apps_rounded,
            title: 'Uygulamalar',
            value: '$_applicationCount',
            color: const Color(0xFF1B9B8A),
            tint: const Color(0xFFE5F8F4),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xCC29213B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFC9BEDD),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RISK CARD
  // ============================================================

  Widget _buildRiskCard() {
    final riskColor = _getRiskColor();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xCC29213B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.psychology_alt_rounded, color: riskColor),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dijital Bağımlılık Analizi',
                      style: TextStyle(
                        color: const Color(0xFFF4EEFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yapay zeka destekli değerlendirme',
                      style: TextStyle(
                        color: const Color(0xFFB9ACD2),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk Seviyesi',
                      style: TextStyle(
                        color: const Color(0xFFB9ACD2),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _riskLevel,
                      style: TextStyle(
                        color: riskColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              if (_riskProbability > 0)
                Text(
                  '${_riskProbability.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),

          if (_riskProbability > 0) ...[
            const SizedBox(height: 14),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _riskProbability / 100,
                minHeight: 7,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              ),
            ),
          ],

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _openPage(const ParentAiAnalysisScreen());
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                  color: AppTheme.primaryColor.withOpacity(0.40),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Detaylı Analizi Gör',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFFF7F1FF),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(color: const Color(0xFFC9BEDD), fontSize: 12),
        ),
      ],
    );
  }

  // ============================================================
  // TOOLS GRID
  // ============================================================

  Widget _buildToolsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.22,
      children: [
        _buildToolCard(
          icon: Icons.bar_chart_rounded,
          title: 'Kullanım',
          subtitle: 'Ekran süresi',
          onTap: () {
            _openPage(const ParentUsageScreen());
          },
        ),

        _buildToolCard(
          icon: Icons.app_blocking_rounded,
          title: 'Uygulama Kısıtlamaları',
          subtitle: 'Uygulamaları yönet',
          onTap: () {
            _openPage(AppRestrictionsScreen(childId: _childId!));
          },
        ),

        _buildToolCard(
          icon: Icons.track_changes_rounded,
          title: 'Hedefler',
          subtitle: 'Günlük hedefler',
          onTap: () {
            _openPage(const ParentChildGoalsScreen());
          },
        ),

        _buildToolCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Öneriler',
          subtitle: 'AI önerileri',
          onTap: () {
            _openPage(const ParentRecommendationsScreen());
          },
        ),

        _buildToolCard(
          icon: Icons.history_rounded,
          title: 'AI Geçmişi',
          subtitle: 'Analiz geçmişi',
          onTap: () {
            _openPage(const ParentAiHistoryScreen());
          },
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final palette = <Color>[
      const Color(0xFF6758D8),
      const Color(0xFFEA8B54),
      const Color(0xFF1B9B8A),
      const Color(0xFFDB6C9A),
      const Color(0xFF5689D9),
    ];
    final color = palette[title.hashCode.abs() % palette.length];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xCC29213B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.13)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.07),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF7F1FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFC9BEDD),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD CHILD
  // ============================================================

  Widget _buildAddChildButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddChildScreen()),
          ).then((_) {
            _loadDashboardData();
          });
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Yeni Çocuk Ekle'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xCC29213B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: const Color(0xFFC9BEDD),
            size: 20,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Mindora, çocuğunuzun dijital davranışlarını '
              'takip etmenize ve daha sağlıklı dijital '
              'alışkanlıklar oluşturmanıza yardımcı olur.',
              style: TextStyle(
                color: const Color(0xFFB9ACD2),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NO CHILD STATE
  // ============================================================

  Widget _buildNoChildState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),

        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor.withOpacity(0.10),
          ),
          child: Icon(
            Icons.family_restroom_rounded,
            size: 44,
            color: AppTheme.primaryColor,
          ),
        ),

        const SizedBox(height: 25),

        Text(
          'Henüz bağlı çocuk yok',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFF7F1FF),
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Çocuğunuzu Mindora hesabınıza bağlayarak '
          'dijital kullanımını takip etmeye başlayabilirsiniz.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFC9BEDD),
            fontSize: 13,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddChildScreen()),
              ).then((_) {
                _loadDashboardData();
              });
            },
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Çocuk Ekle'),
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
      ],
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),

        Icon(Icons.cloud_off_rounded, size: 60, color: const Color(0xFFC9BEDD)),

        const SizedBox(height: 20),

        Text(
          'Bir sorun oluştu',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFF7F1FF),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          _errorMessage ?? 'Veriler yüklenirken bir hata oluştu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: const Color(0xFFC9BEDD), fontSize: 13),
        ),

        const SizedBox(height: 25),

        Center(
          child: ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
