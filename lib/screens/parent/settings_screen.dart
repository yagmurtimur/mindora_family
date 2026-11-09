import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Ayarlar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('Hesap'),

          _buildSettingTile(
            icon: Icons.person_outline,
            title: 'Profil',
            subtitle: 'Profil bilgilerini görüntüle ve düzenle',
            onTap: () {
              _openProfile(context);
            },
          ),

          const SizedBox(height: 20),

          _buildSectionTitle('Aile'),

          _buildSettingTile(
            icon: Icons.people_outline,
            title: 'Çocuk Yönetimi',
            subtitle: 'Çocuk hesaplarını yönet',
            onTap: () {
              _openChildManagement(context);
            },
          ),

          const SizedBox(height: 20),

          _buildSectionTitle('Bildirimler'),

          _buildSettingTile(
            icon: Icons.notifications_none,
            title: 'Bildirim Ayarları',
            subtitle: 'Bildirim tercihlerini yönet',
            onTap: () {
              _openNotificationSettings(context);
            },
          ),

          const SizedBox(height: 20),

          _buildSectionTitle('Uygulama'),

          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'Hakkında',
            subtitle: 'Mindora hakkında bilgi',
            onTap: () {
              _showAboutDialog(context);
            },
          ),

          const SizedBox(height: 12),

          _buildSettingTile(
            icon: Icons.logout,
            title: 'Çıkış Yap',
            subtitle: 'Mindora hesabından çıkış yap',
            iconColor: Colors.redAccent,
            titleColor: Colors.redAccent,
            onTap: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ============================================================
  // SETTING TILE
  // ============================================================

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.white70,
    Color titleColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white30),
        onTap: onTap,
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ProfileScreen()),
    );
  }

  // ============================================================
  // CHILD MANAGEMENT
  // ============================================================

  void _openChildManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ChildManagementScreen()),
    );
  }

  // ============================================================
  // NOTIFICATION SETTINGS
  // ============================================================

  void _openNotificationSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _NotificationSettingsScreen()),
    );
  }

  // ============================================================
  // ABOUT
  // ============================================================

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF15151C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Mindora',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Yapay zeka destekli dijital davranış ve sağlık analiz sistemi.\n\n'
            'Mindora; ekran süresi, dijital kullanım alışkanlıkları, '
            'uyku, fiziksel aktivite ve benzeri verileri analiz ederek '
            'kullanıcıya anlamlı geri bildirimler sunmayı amaçlar.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF15151C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Çıkış Yap',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Hesabından çıkış yapmak istediğine emin misin?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  await FirebaseAuth.instance.signOut();

                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Çıkış yapılırken bir hata oluştu.'),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Çıkış Yap',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// PROFILE SCREEN
// ================================================================

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  final _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String _email = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      _email = user.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null) {
        _nameController.text =
            data['name']?.toString() ?? data['displayName']?.toString() ?? '';

        _role = data['role']?.toString() ?? '';
      }
    } catch (_) {
      // Profil yükleme hatası
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil bilgileri güncellendi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil güncellenirken hata oluştu.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 45,
                      color: Colors.white70,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Ad Soyad',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF15151C),
                    hintText: 'Adınızı girin',
                    hintStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.white54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'E-posta',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15151C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _email.isEmpty ? 'E-posta bulunamadı' : _email,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Rol',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15151C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: Colors.white54),
                      const SizedBox(width: 12),
                      Text(
                        _role == 'parent'
                            ? 'Ebeveyn'
                            : _role == 'child'
                            ? 'Çocuk'
                            : 'Belirtilmemiş',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Değişiklikleri Kaydet',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ================================================================
// CHILD MANAGEMENT SCREEN
// ================================================================

class _ChildManagementScreen extends StatelessWidget {
  const _ChildManagementScreen();

  @override
  Widget build(BuildContext context) {
    final parent = FirebaseAuth.instance.currentUser;

    if (parent == null) {
      return _emptyScreen(context, 'Oturum bulunamadı.');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Çocuk Yönetimi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('parentId', isEqualTo: parent.uid)
            .where('role', isEqualTo: 'child')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _emptyScreen(context, 'Çocuk hesapları yüklenemedi.');
          }

          final children = snapshot.data?.docs ?? [];

          if (children.isEmpty) {
            return _emptyScreen(
              context,
              'Henüz bağlı bir çocuk hesabı bulunmuyor.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final data = children[index].data() as Map<String, dynamic>;

              final name =
                  data['name']?.toString() ??
                  data['displayName']?.toString() ??
                  'İsimsiz';

              final email = data['email']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151C),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white70),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: email.isEmpty
                      ? null
                      : Text(
                          email,
                          style: const TextStyle(color: Colors.white38),
                        ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white30,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ================================================================
// NOTIFICATION SETTINGS
// ================================================================

class _NotificationSettingsScreen extends StatefulWidget {
  const _NotificationSettingsScreen();

  @override
  State<_NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<_NotificationSettingsScreen> {
  bool goalNotifications = true;
  bool riskNotifications = true;
  bool dailySummaryNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text(
          'Bildirim Ayarları',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildNotificationTile(
            icon: Icons.flag_outlined,
            title: 'Hedef Bildirimleri',
            subtitle: 'Çocuğun hedefi aştığında bildirim al',
            value: goalNotifications,
            onChanged: (value) {
              setState(() {
                goalNotifications = value;
              });
            },
          ),

          const SizedBox(height: 12),

          _buildNotificationTile(
            icon: Icons.warning_amber_outlined,
            title: 'Risk Değişikliği',
            subtitle: 'AI risk seviyesinde değişiklik olduğunda bildir',
            value: riskNotifications,
            onChanged: (value) {
              setState(() {
                riskNotifications = value;
              });
            },
          ),

          const SizedBox(height: 12),

          _buildNotificationTile(
            icon: Icons.today_outlined,
            title: 'Günlük Özet',
            subtitle: 'Günlük kullanım özetini bildir',
            value: dailySummaryNotifications,
            onChanged: (value) {
              setState(() {
                dailySummaryNotifications = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15151C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        secondary: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// ================================================================
// EMPTY SCREEN
// ================================================================

Widget _emptyScreen(BuildContext context, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 50),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}
