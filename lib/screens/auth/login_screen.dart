import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../parent/parent_dashboard.dart';
import '../child/child_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta ve şifrenizi girin.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Firebase Authentication ile giriş yap
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Kullanıcı bulunamadı.');
      }

      // 2. Firestore'dan kullanıcının profilini getir
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDocument.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kullanıcı profili bulunamadı. Lütfen tekrar kayıt olun.',
            ),
          ),
        );

        return;
      }

      // 3. Role bilgisini al
      final data = userDocument.data();
      final String? role = data?['role'] as String?;

      if (!mounted) return;

      // 4. Role göre dashboard'a yönlendir
      if (role == 'parent') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ParentDashboard()),
        );
      } else if (role == 'child') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChildDashboard()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı rolü bulunamadı. Lütfen rolünüzü seçin.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          message = 'E-posta veya şifre hatalı.';
          break;

        case 'user-not-found':
          message = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
          break;

        case 'invalid-email':
          message = 'Geçerli bir e-posta adresi girin.';
          break;

        case 'user-disabled':
          message = 'Bu hesap devre dışı bırakılmış.';
          break;

        case 'network-request-failed':
          message = 'İnternet bağlantınızı kontrol edin.';
          break;

        default:
          message = 'Giriş sırasında bir hata oluştu.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kullanıcı bilgileri alınırken hata oluştu: '
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Şifrenizi yenilemek için önce e-posta adresinizi girin.',
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Şifre yenileme bağlantısı e-posta adresinize gönderildi.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Geçerli bir e-posta adresi girin.';
          break;

        case 'user-not-found':
          message = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
          break;

        default:
          message = 'Şifre yenileme sırasında bir hata oluştu.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Başlık
                  const Text(
                    'Hoş Geldin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Mindora Family ile dijital yaşamı\n'
                    'birlikte daha dengeli hale getirin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 38),

                  // E-posta
                  const Text(
                    'E-posta',
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
                    decoration: InputDecoration(
                      hintText: 'ornek@mail.com',
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

                  const SizedBox(height: 20),

                  // Şifre
                  const Text(
                    'Şifre',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Şifrenizi girin',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
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

                  const SizedBox(height: 12),

                  // Şifremi unuttum
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text(
                        'Şifremi Unuttum?',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Giriş butonu
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
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
                              'GİRİŞ YAP',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Ayırıcı
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'veya',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Google
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Google girişi daha sonra eklenecek.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: const Text(
                        'Google ile devam et',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textColor,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Kayıt ol
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hesabın yok mu?',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Kayıt Ol',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
