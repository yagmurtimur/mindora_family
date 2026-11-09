import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import 'role_selection_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ageController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String _selectedGender = 'Other';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final ageText = _ageController.text.trim();

    // Alan kontrolü
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        ageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    // Yaş kontrolü
    final age = double.tryParse(ageText);

    if (age == null || age < 5 || age > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen 5-100 arasında geçerli bir yaş girin.'),
        ),
      );
      return;
    }

    // Şifre uzunluğu kontrolü
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre en az 6 karakter olmalıdır.')),
      );
      return;
    }

    // Şifre eşleşme kontrolü
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şifreler eşleşmiyor.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase Authentication ile kullanıcı oluştur
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Kullanıcı oluşturulamadı.');
      }

      // Ad Soyad bilgisini Firebase Authentication'a kaydet
      await user.updateDisplayName(name);

      // Firestore users/{uid} dokümanını oluştur
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'age': age,
        'gender': _selectedGender,
        'role': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Kullanıcı bilgilerini yenile
      await user.reload();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesabınız başarıyla oluşturuldu.')),
      );

      // Rol seçim ekranına gönder
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'Bu e-posta adresi zaten kayıtlı.';
          break;

        case 'invalid-email':
          message = 'Geçerli bir e-posta adresi girin.';
          break;

        case 'weak-password':
          message = 'Şifre çok zayıf. Daha güçlü bir şifre seçin.';
          break;

        case 'network-request-failed':
          message = 'İnternet bağlantınızı kontrol edin.';
          break;

        case 'operation-not-allowed':
          message = 'E-posta ve şifre ile kayıt şu anda etkin değil.';
          break;

        default:
          message = 'Kayıt sırasında bir hata oluştu.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt sırasında hata oluştu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
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
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Hesap Oluştur',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Mindora Family ile daha dengeli\n'
                    'bir dijital yaşam için ilk adımı at.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Ad Soyad',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      hintText: 'Adınız Soyadınız',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                  ),

                  const SizedBox(height: 18),

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
                    decoration: _inputDecoration(
                      hintText: 'ornek@mail.com',
                      prefixIcon: Icons.email_outlined,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Yaş',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      hintText: 'Yaşınız',
                      prefixIcon: Icons.cake_outlined,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Cinsiyet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: const [
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Kadın'),
                          ),
                          DropdownMenuItem(value: 'Male', child: Text('Erkek')),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Belirtmek istemiyorum'),
                          ),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                if (value == null) return;

                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

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
                    decoration: _inputDecoration(
                      hintText: 'En az 6 karakter',
                      prefixIcon: Icons.lock_outline_rounded,
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
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Şifre Tekrar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: _inputDecoration(
                      hintText: 'Şifrenizi tekrar girin',
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
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
                              'KAYIT OL',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Zaten hesabın var mı?',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text(
                          'Giriş Yap',
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
