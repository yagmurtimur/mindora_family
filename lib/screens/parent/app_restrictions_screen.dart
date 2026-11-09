import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';

class AppRestrictionsScreen extends StatefulWidget {
  final String childId;

  const AppRestrictionsScreen({super.key, required this.childId});

  @override
  State<AppRestrictionsScreen> createState() => _AppRestrictionsScreenState();
}

class _AppRestrictionsScreenState extends State<AppRestrictionsScreen> {
  static const MethodChannel _channel = MethodChannel('mindora/usage');

  List<Map<String, String>> _apps = [];

  bool _isLoading = true;

  String? _error;

  final Set<String> _blockedApps = {};
  final Map<String, int> _dailyLimits = {};

  @override
  void initState() {
    super.initState();

    _loadInstalledApps();
    _loadDailyLimits();
  }

  // ============================================================

  // UYGULAMALARI GETİR

  // ============================================================

  Future<void> _loadInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );

      final apps = (result ?? [])
          .map(
            (item) =>
                Map<String, String>.from(Map<dynamic, dynamic>.from(item)),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _apps = apps;

        _isLoading = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message ?? 'Uygulamalar alınamadı.';

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Uygulamalar alınırken bir hata oluştu.';

        _isLoading = false;
      });
    }
  }

  // ============================================================

  // DEVICE ADMIN KONTROLÜ

  // ============================================================

  Future<bool> _checkDeviceAdmin() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceAdminActive');

      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ============================================================

  // DEVICE ADMIN İSTEME

  // ============================================================

  Future<void> _requestDeviceAdmin() async {
    try {
      await _channel.invokeMethod('requestDeviceAdmin');
    } on PlatformException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Cihaz yöneticisi yetkisi alınamadı.'),
        ),
      );
    }
  }

  // ============================================================

  // UYGULAMAYI GERÇEKTEN ENGELLE

  // ============================================================

  Future<void> _setAppBlocked(String packageName, bool blocked) async {
    try {
      // Önce Device Admin kontrolü

      final isAdminActive = await _checkDeviceAdmin();

      if (!isAdminActive) {
        if (!mounted) return;

        await showDialog(
          context: context,

          builder: (context) {
            return AlertDialog(
              title: const Text('Yetki Gerekli'),

              content: const Text(
                'Uygulamaları kısıtlamak için '
                'Mindora cihaz yöneticisi olarak '
                'etkinleştirilmelidir.',
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },

                  child: const Text('İptal'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    await _requestDeviceAdmin();
                  },

                  child: const Text('Yetkilendir'),
                ),
              ],
            );
          },
        );

        return;
      }

      // Android tarafındaki gerçek engelleme

      final success = await _channel.invokeMethod<bool>('setAppBlocked', {
        'packageName': packageName,

        'blocked': blocked,
      });

      if (!mounted) return;

      if (success == true) {
        setState(() {
          if (blocked) {
            _blockedApps.add(packageName);
          } else {
            _blockedApps.remove(packageName);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              blocked ? 'Uygulama engellendi.' : 'Uygulama engeli kaldırıldı.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uygulama kısıtlanamadı.')),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Uygulama kısıtlanırken hata oluştu.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Beklenmeyen hata: $e')));
    }
  }

  // ============================================================

  // ============================================================
  // GÜNLÜK UYGULAMA SÜRE SINIRLARI
  // ============================================================

  Future<void> _loadDailyLimits() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .collection('appLimits')
          .get();

      if (!mounted) return;

      setState(() {
        _dailyLimits.clear();
        for (final doc in snapshot.docs) {
          final minutes = doc.data()['dailyLimitMinutes'];
          if (minutes is num && minutes > 0) {
            _dailyLimits[doc.id] = minutes.toInt();
          }
        }
      });
    } catch (e) {
      debugPrint('Günlük limitler yüklenemedi: $e');
    }
  }

  Future<void> _chooseDailyLimit(String packageName, String appName) async {
    final selectedMinutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$appName süre sınırı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu uygulama için günlük kullanım süresini seç.'),
            const SizedBox(height: 12),
            ...[15, 30, 45, 60, 90, 120].map(
              (minutes) => ListTile(
                dense: true,
                title: Text('$minutes dakika'),
                onTap: () => Navigator.pop(dialogContext, minutes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 0),
            child: const Text('Limiti kaldır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
        ],
      ),
    );

    if (selectedMinutes == null) return;

    try {
      final limitRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .collection('appLimits')
          .doc(packageName);

      if (selectedMinutes == 0) {
        await limitRef.delete();
        if (!mounted) return;
        setState(() => _dailyLimits.remove(packageName));
      } else {
        await limitRef.set({
          'packageName': packageName,
          'appName': appName,
          'dailyLimitMinutes': selectedMinutes,
          'enabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        setState(() => _dailyLimits[packageName] = selectedMinutes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedMinutes == 0
                ? '$appName süre sınırı kaldırıldı.'
                : '$appName günlük sınırı $selectedMinutes dakika olarak kaydedildi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Limit kaydedilemedi: $e')));
    }
  }

  // SWITCH

  // ============================================================

  Future<void> _toggleBlock(String packageName) async {
    final currentlyBlocked = _blockedApps.contains(packageName);

    final newBlockedState = !currentlyBlocked;

    await _setAppBlocked(packageName, newBlockedState);
  }

  // ============================================================

  // UI

  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B1D),

      appBar: AppBar(
        backgroundColor: const Color(0xFF100B1D),

        foregroundColor: const Color(0xFFF7F2FF),

        elevation: 0,

        title: const Text(
          'Uygulama Kısıtlamaları',

          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_apps.isEmpty) {
      return const Center(
        child: Text('Çocuğun telefonunda uygulama bulunamadı.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInstalledApps,

      child: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          // ======================================================

          // ÜST BİLGİ KARTI

          // ======================================================
          Container(
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: const Color(0xFF211A38),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),

            child: Row(
              children: [
                Container(
                  width: 45,

                  height: 45,

                  decoration: BoxDecoration(
                    color: const Color(0xFFB99AFF).withOpacity(0.10),

                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: Icon(
                    Icons.security_rounded,

                    color: const Color(0xFFB99AFF),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Uygulama Kontrolü',

                        style: TextStyle(
                          fontSize: 15,

                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${_apps.length} uygulama bulundu',

                        style: TextStyle(
                          color: const Color(0xFFF1ECFF).withOpacity(0.55),

                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          ..._apps.map(_buildAppCard),
        ],
      ),
    );
  }

  // ============================================================

  // UYGULAMA KARTI

  // ============================================================

  Widget _buildAppCard(Map<String, String> app) {
    final appName = app['appName'] ?? 'Bilinmeyen uygulama';

    final packageName = app['packageName'] ?? '';

    final isBlocked = _blockedApps.contains(packageName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      decoration: BoxDecoration(
        color: const Color(0xFF211A38),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: isBlocked
              ? Colors.red.withOpacity(0.25)
              : Colors.white.withOpacity(0.10),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 45,

            height: 45,

            decoration: BoxDecoration(
              color: isBlocked
                  ? Colors.red.withOpacity(0.10)
                  : const Color(0xFFB99AFF).withOpacity(0.10),

              borderRadius: BorderRadius.circular(13),
            ),

            child: Icon(
              isBlocked ? Icons.block_rounded : Icons.apps_rounded,

              color: isBlocked ? Colors.red : const Color(0xFFB99AFF),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  appName,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 14,

                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  packageName,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: const Color(0xFFF1ECFF).withOpacity(0.45),

                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _dailyLimits[packageName] == null
                      ? 'Günlük sınır: Belirlenmedi'
                      : 'Günlük sınır: ${_dailyLimits[packageName]} dk',
                  style: TextStyle(
                    color: const Color(0xFFB99AFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Günlük süre sınırı belirle',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () => _chooseDailyLimit(packageName, appName),
          ),

          Switch(
            activeColor: const Color(0xFF69E8E0),
            inactiveThumbColor: const Color(0xFFB7AEC9),
            inactiveTrackColor: const Color(0xFF554967),
            value: isBlocked,
            onChanged: (_) {
              _toggleBlock(packageName);
            },
          ),
        ],
      ),
    );
  }
}
