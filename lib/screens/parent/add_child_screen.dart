import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addChild() async {
    FocusScope.of(context).unfocus();

    final childEmail = _emailController.text.trim().toLowerCase();

    if (childEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen çocuğun e-posta adresini girin.')),
      );
      return;
    }

    final parent = FirebaseAuth.instance.currentUser;

    if (parent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ebeveyn oturumu bulunamadı.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Çocuğu e-posta adresine göre bul
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: childEmail)
          .where('role', isEqualTo: 'child')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu e-posta adresiyle kayıtlı bir çocuk hesabı bulunamadı.',
            ),
          ),
        );
        return;
      }

      final childDocument = querySnapshot.docs.first;
      final childId = childDocument.id;
      final childData = childDocument.data();

      // Kendi hesabını çocuk olarak eklemeye çalışma
      if (childId == parent.uid) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kendi hesabınızı çocuk olarak ekleyemezsiniz.'),
          ),
        );
        return;
      }

      // Çocuğun zaten başka bir ebeveyne bağlı olup olmadığını kontrol et
      final existingParentId = childData['parentId'];

      if (existingParentId != null &&
          existingParentId.toString().isNotEmpty &&
          existingParentId != parent.uid) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu çocuk hesabı zaten başka bir ebeveyne bağlı.'),
          ),
        );
        return;
      }

      // Çocuğa parentId kaydet
      await FirebaseFirestore.instance.collection('users').doc(childId).update({
        'parentId': parent.uid,
      });

      // Parent'ın childIds listesine çocuğu ekle
      await FirebaseFirestore.instance.collection('users').doc(parent.uid).set({
        'childIds': FieldValue.arrayUnion([childId]),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çocuk hesabı başarıyla bağlandı.')),
      );

      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Çocuk eklenirken hata oluştu: '
            '${e.message ?? 'Bilinmeyen hata'}',
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
        title: const Text(
          'Çocuk Ekle',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.child_care_rounded,
                      color: AppTheme.primaryColor,
                      size: 42,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Çocuğunu Bağla',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Çocuğun Mindora Family hesabını\n'
                    'ebeveyn hesabına bağla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 36),

                  const Text(
                    'Çocuğun E-posta Adresi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'cocuk@mail.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Çocuğun önce kendi hesabını oluşturmuş olması gerekir.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addChild,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.primaryColor
                            .withValues(alpha: 0.6),
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
                              'ÇOCUĞU BAĞLA',
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
          ),
        ),
      ),
    );
  }
}
