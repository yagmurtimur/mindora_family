import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../parent/parent_dashboard.dart';
import '../child/child_dashboard.dart';
import '../../theme/app_theme.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  Future<void> _continue() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen bir rol seçin.')));
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
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? '',
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      if (_selectedRole == 'parent') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ParentDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChildDashboard()),
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bilgiler kaydedilirken hata oluştu: ${e.message ?? 'Bilinmeyen hata'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beklenmeyen bir hata oluştu.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Sen kimsin?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Mindora Family deneyimini sana\n'
                'uygun şekilde kişiselleştirelim.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              _RoleCard(
                icon: Icons.family_restroom_rounded,
                title: 'Ebeveyn',
                description:
                    'Çocuğunun dijital yaşamını takip et, '
                    'analizleri görüntüle ve sağlıklı kullanım '
                    'hedefleri oluştur.',
                isSelected: _selectedRole == 'parent',
                onTap: _isLoading
                    ? () {}
                    : () {
                        setState(() {
                          _selectedRole = 'parent';
                        });
                      },
              ),

              const SizedBox(height: 18),

              _RoleCard(
                icon: Icons.child_care_rounded,
                title: 'Çocuk',
                description:
                    'Dijital alışkanlıklarını takip et, '
                    'hedeflerini gör ve sana özel öneriler al.',
                isSelected: _selectedRole == 'child',
                onTap: _isLoading
                    ? () {}
                    : () {
                        setState(() {
                          _selectedRole = 'child';
                        });
                      },
              ),

              const Spacer(),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.6,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'DEVAM ET',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
                size: 30,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
