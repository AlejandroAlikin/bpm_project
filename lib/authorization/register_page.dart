// register_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bpm/design/colors.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bpm/authorization/login_page.dart';
import 'package:bpm/main_pages/main_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  AnimationController? _shakeController;
  Animation<Offset>? _shakeAnimation;
  AnimationController? _errorController;
  Animation<double>? _errorAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _focusName = FocusNode();
  final _focusEmail = FocusNode();
  final _focusPassword = FocusNode();
  final _focusConfirmPassword = FocusNode();

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0.03, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0.03, 0), end: const Offset(-0.03, 0)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(-0.03, 0), end: const Offset(0.03, 0)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(
      parent: _shakeController!,
      curve: Curves.easeInOut,
    ));

    _errorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _errorAnimation = CurvedAnimation(
      parent: _errorController!,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shakeController?.dispose();
    _errorController?.dispose();
    _focusName.dispose();
    _focusEmail.dispose();
    _focusPassword.dispose();
    _focusConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> _playShakeAnimation() async {
    await _shakeController?.forward();
    await _shakeController?.reverse();
  }

  Future<void> _showErrorAnimation() async {
    await _errorController?.forward();
    await Future.delayed(const Duration(seconds: 3));
    await _errorController?.reverse().then((_) {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Validate passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Пароли не совпадают';
      });
      await _playShakeAnimation();
      await _showErrorAnimation();
      setState(() => _isLoading = false);
      return;
    }

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // Update display name
        await userCredential.user?.updateDisplayName(_nameController.text.trim());

        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
      await _playShakeAnimation();
      await _showErrorAnimation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла неизвестная ошибка';
      });
      await _playShakeAnimation();
      await _showErrorAnimation();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'Этот email уже используется';
      case 'invalid-email':
        return 'Некорректный адрес электронной почты';
      case 'operation-not-allowed':
        return 'Регистрация отключена';
      case 'weak-password':
        return 'Пароль слишком слабый (минимум 6 символов)';
      default:
        return 'Ошибка регистрации';
    }
  }

  bool get _isNameError => _errorMessage != null &&
      _errorMessage!.contains('имя пользователя');

  bool get _isEmailError => _errorMessage != null &&
      _errorMessage!.contains('email');

  bool get _isPasswordError => _errorMessage != null &&
      (_errorMessage!.contains('пароль') || _errorMessage!.contains('Пароль'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Lottie.asset(
                    'assets/animations/heart_pulse.json',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Создать аккаунт',
                    style: GoogleFonts.manrope(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заполните данные для регистрации',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name Field
                  SlideTransition(
                    position: _shakeAnimation!,
                    child: _buildInputField(
                      controller: _nameController,
                      focusNode: _focusName,
                      label: 'Имя',
                      icon: Icons.person_rounded,
                      isError: _isNameError,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  SlideTransition(
                    position: _shakeAnimation!,
                    child: _buildInputField(
                      controller: _emailController,
                      focusNode: _focusEmail,
                      label: 'Email',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      isError: _isEmailError,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SlideTransition(
                    position: _shakeAnimation!,
                    child: _buildInputField(
                      controller: _passwordController,
                      focusNode: _focusPassword,
                      label: 'Пароль',
                      icon: Icons.lock_rounded,
                      obscureText: _obscurePassword,
                      isError: _isPasswordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: _isPasswordError ? const Color(0xFFE53935) : Colors.grey.shade500,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SlideTransition(
                    position: _shakeAnimation!,
                    child: _buildInputField(
                      controller: _confirmPasswordController,
                      focusNode: _focusConfirmPassword,
                      label: 'Подтвердите пароль',
                      icon: Icons.lock_reset_rounded,
                      obscureText: _obscurePassword,
                      isError: _isPasswordError,
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        'Зарегистрироваться',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      ),
                      child: RichText(
                        text: TextSpan(
                          text: 'Уже есть аккаунт? ',
                          style: GoogleFonts.manrope(
                            color: Colors.grey.shade600,
                          ),
                          children: [
                            TextSpan(
                              text: 'Войти',
                              style: GoogleFonts.manrope(
                                color: primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Error Message
          if (_errorMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(_errorAnimation!),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0x15B00020),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x30B00020), width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 20, color: Color(0xFFE53935)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFFE53935),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Color(0xFFE53935)),
                              onPressed: () {
                                _errorController?.reverse().then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _errorMessage = null;
                                      _isLoading = false;
                                    });
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool isError = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isError ? const Color(0xFFE53935) : Colors.grey.shade600),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isError ? const Color(0xFFE53935) : primaryBlue,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE53935),
            width: 2,
          ),
        ),
        labelStyle: GoogleFonts.manrope(
          color: isError ? const Color(0xFFE53935) : Colors.grey.shade600,
        ),
      ),
      style: GoogleFonts.manrope(
        color: Colors.black,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}