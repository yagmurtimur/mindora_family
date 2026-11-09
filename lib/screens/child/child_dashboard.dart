import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'usage_screen.dart';
import 'goals_screen.dart';
import 'recommendations_screen.dart';
import 'mood_screen.dart';
import 'child_assessment_screen.dart';
import 'profile_screen.dart';

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends State<ChildDashboard> {
  String? _childName;
  bool _isLoading = true;
  int _totalMinutes = 0;
  int _dailyGoalMinutes = 150;

  static const Color _ink = Color(0xFF29234D);
  static const Color _purple = Color(0xFF8067F7);
  static const Color _pink = Color(0xFFFF78B7);
  static const Color _cyan = Color(0xFF57D9D0);
  static const Color _yellow = Color(0xFFFFD66B);
  static const Color _background = Color(0xFFFFF8FE);

  @override
  void initState() {
    super.initState();
    _loadChildProfile();
  }

  Future<void> _loadChildProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final today = DateTime.now();
      final dateId =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      final usageDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('screenTime')
          .doc(dateId)
          .get();

      if (!mounted) return;
      final userData = userDocument.data();
      final usageData = usageDocument.data();

      setState(() {
        _childName = userData?['name']?.toString() ?? 'Çocuk';
        _totalMinutes = (usageData?['totalMinutes'] ?? 0).toInt();
        _dailyGoalMinutes = (usageData?['dailyGoalMinutes'] ?? 150).toInt();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _childName = 'Çocuk';
        _totalMinutes = 0;
        _dailyGoalMinutes = 150;
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes dakika';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours saat';
    return '$hours saat $remainingMinutes dakika';
  }

  Future<void> _openUsageScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChildUsageScreen()),
    );
    await _loadChildProfile();
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final safeGoal = _dailyGoalMinutes > 0 ? _dailyGoalMinutes : 1;
    final progress = (_totalMinutes / safeGoal).clamp(0.0, 1.0);
    final remaining = (_dailyGoalMinutes - _totalMinutes).clamp(0, _dailyGoalMinutes);
    final goalReached = _dailyGoalMinutes > 0 && _totalMinutes >= _dailyGoalMinutes;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SELAM! 👋',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: _purple,
                )),
            Text(
              _isLoading ? 'Benim Dünyam' : 'Merhaba, ${_childName ?? 'Arkadaşım'}!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Bildirimler',
              onPressed: () {},
              icon: const Icon(Icons.notifications_rounded, color: _purple),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _purple,
        onRefresh: _loadChildProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 22),
              const _SectionHeading(
                title: 'Bugünkü maceram ✨',
                subtitle: 'Küçük adımlar, harika işler!',
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.smartphone_rounded,
                      title: 'Ekran sürem',
                      value: _formatDuration(_totalMinutes),
                      color: _purple,
                      paleColor: const Color(0xFFF0ECFF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.flag_rounded,
                      title: 'Günlük hedefim',
                      value: _formatDuration(_dailyGoalMinutes),
                      color: const Color(0xFFE99A24),
                      paleColor: const Color(0xFFFFF3D3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildProgressCard(progress, remaining, goalReached),
              const SizedBox(height: 24),
              const _SectionHeading(
                title: 'Ne yapmak istersin? 🎈',
                subtitle: 'Birini seç ve keşfet!',
              ),
              const SizedBox(height: 13),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.34,
                children: [
                  _QuickAction(
                    icon: Icons.insights_rounded,
                    title: 'Kullanımım',
                    subtitle: 'Bugün neler yaptım?',
                    color: const Color(0xFF6C63E8),
                    paleColor: const Color(0xFFF0EDFF),
                    onTap: _openUsageScreen,
                  ),
                  _QuickAction(
                    icon: Icons.emoji_emotions_rounded,
                    title: 'Ruh halim',
                    subtitle: 'Nasıl hissediyorum?',
                    color: const Color(0xFFE9579D),
                    paleColor: const Color(0xFFFFEAF4),
                    onTap: () => _open(const ChildMoodScreen()),
                  ),
                  _QuickAction(
                    icon: Icons.flag_rounded,
                    title: 'Hedeflerim',
                    subtitle: 'Yıldızları topla!',
                    color: const Color(0xFFE99A24),
                    paleColor: const Color(0xFFFFF4D9),
                    onTap: () => _open(const ChildGoalsScreen()),
                  ),
                  _QuickAction(
                    icon: Icons.lightbulb_rounded,
                    title: 'Öneriler',
                    subtitle: 'Yeni fikirler keşfet',
                    color: const Color(0xFF20AFA8),
                    paleColor: const Color(0xFFE4FBF7),
                    onTap: () => _open(const ChildRecommendationsScreen()),
                  ),
                  _QuickAction(
                    icon: Icons.psychology_rounded,
                    title: 'Kendimi tanıyorum',
                    subtitle: 'Mini değerlendirme',
                    color: const Color(0xFF8B65D9),
                    paleColor: const Color(0xFFF2EBFF),
                    onTap: () => _open(const ChildAssessmentScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFFFD8E9)),
                ),
                child: const Row(
                  children: [
                    Text('🌈', style: TextStyle(fontSize: 29)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unutma: Ekran dışında da keşfedilecek kocaman bir dünya var!',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFECE7FF),
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            _open(const ChildGoalsScreen());
          } else if (index == 2) {
            _open(const ChildProfileScreen());
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: _purple),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded, color: _purple),
            label: 'Hedefler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _purple),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_purple, _pink, Color(0xFFFFA86B)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _pink.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 0,
            child: Icon(Icons.auto_awesome_rounded,
                color: Colors.white54, size: 34),
          ),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 35),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoading
                          ? 'Maceraya hazır mısın?'
                          : 'Merhaba, ${_childName ?? 'Arkadaşım'}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Bugün kendin için harika bir şey yap! ⭐',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double progress, int remaining, bool goalReached) {
    final percent = (progress * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE8E1FF)),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFECE7FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: _purple, size: 25),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Günün hedefi',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 13,
              backgroundColor: const Color(0xFFF0EDFA),
              valueColor: AlwaysStoppedAnimation<Color>(
                goalReached ? const Color(0xFF21B9A8) : _pink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            goalReached
                ? 'Harikasın! Bugünkü hedefini tamamladın! 🎉'
                : 'Biraz daha devam! ${_formatDuration(remaining)} hakkın kaldı 💪',
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${_formatDuration(_totalMinutes)} kullanıldı • Hedef ${_formatDuration(_dailyGoalMinutes)}',
            style: const TextStyle(
              color: Color(0xFF88839E),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF29234D),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF88839E),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Color paleColor;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.paleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: paleColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
              color: paleColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF88839E),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF29234D),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color paleColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.paleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: paleColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: paleColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF29234D),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF88839E),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
