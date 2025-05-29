import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bpm/design/colors.dart';
import 'package:bpm/main_pages/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bpm/authorization/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<StatefulWidget> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  late TextEditingController _loginTextEditingController;
  late TextEditingController _emailTextEditingController;
  late TextEditingController _passwordTextEditingController;
  late TextEditingController _passwordRepeatTextEditingController;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  AnimationController? _shakeController;
  Animation<Offset>? _shakeAnimation;
  AnimationController? _errorController;
  Animation<double>? _errorAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _focusLogin = FocusNode();
  final _focusEmail = FocusNode();
  final _focusPassword = FocusNode();
  final _focusPasswordRepeat = FocusNode();

  @override
  void initState() {
    super.initState();
    _loginTextEditingController = TextEditingController();
    _emailTextEditingController = TextEditingController();
    _passwordTextEditingController = TextEditingController();
    _passwordRepeatTextEditingController = TextEditingController();

    // Инициализация анимации дрожания
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

    // Анимация появления ошибки
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
    _loginTextEditingController.dispose();
    _emailTextEditingController.dispose();
    _passwordTextEditingController.dispose();
    _passwordRepeatTextEditingController.dispose();
    _shakeController?.dispose();
    _errorController?.dispose();
    _focusLogin.dispose();
    _focusEmail.dispose();
    _focusPassword.dispose();
    _focusPasswordRepeat.dispose();
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

  Future<void> _registerWithEmailAndPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Валидация паролей
    if (_passwordTextEditingController.text != _passwordRepeatTextEditingController.text) {
      setState(() {
        _errorMessage = 'Пароли не совпадают';
      });
      await _playShakeAnimation();
      await _showErrorAnimation();
      setState(() => _isLoading = false);
      return;
    }

    try {
      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: _emailTextEditingController.text.trim(),
        password: _passwordTextEditingController.text.trim(),
      );

      if (userCredential.user != null) {
        // Обновляем displayName с именем пользователя
        await userCredential.user?.updateDisplayName(
          _loginTextEditingController.text.trim(),
        );

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

  bool get _isLoginError => _errorMessage != null &&
      _errorMessage!.contains('имя пользователя');

  bool get _isEmailError => _errorMessage != null &&
      _errorMessage!.contains('email');

  bool get _isPasswordError => _errorMessage != null &&
      (_errorMessage!.contains('пароль') || _errorMessage!.contains('Пароль'));

  @override
  Widget build(BuildContext context) {
    // Цвета для ошибок
    const errorColor = Color(0xFFB00020);
    const errorBorderColor = Color(0xFFD32F2F);
    const errorBackgroundColor = Color(0x15B00020);

    final _errorInputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelStyle: GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: errorColor,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.5, color: errorBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.5, color: errorBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.5, color: errorBorderColor),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      errorStyle: const TextStyle(height: 0),
    );

    final _normalInputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelStyle: GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1D1B20),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.5, color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.5, color: primaryBlue),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      errorStyle: const TextStyle(height: 0),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 7,
                child: Center(
                  child: Image.asset(
                    'assets/images/heart_logo.jpg',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Expanded(
                flex: 7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Добро пожаловать!',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Поле имени пользователя
                        SlideTransition(
                          position: _shakeAnimation!,
                          child: SizedBox(
                            width: double.infinity,
                            child: TextField(
                              controller: _loginTextEditingController,
                              focusNode: _focusLogin,
                              decoration: _isLoginError && _errorMessage != null
                                  ? _errorInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.account_box_outlined,
                                  size: 24,
                                  color: errorColor,
                                ),
                                labelText: 'Имя пользователя',
                              )
                                  : _normalInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.account_box_outlined,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                labelText: 'Имя пользователя',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Поле email
                        SlideTransition(
                          position: _shakeAnimation!,
                          child: SizedBox(
                            width: double.infinity,
                            child: TextField(
                              controller: _emailTextEditingController,
                              focusNode: _focusEmail,
                              decoration: _isEmailError && _errorMessage != null
                                  ? _errorInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  size: 24,
                                  color: errorColor,
                                ),
                                labelText: 'Адрес эл. почты',
                              )
                                  : _normalInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                labelText: 'Адрес эл. почты',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Поле пароля
                        SlideTransition(
                          position: _shakeAnimation!,
                          child: SizedBox(
                            width: double.infinity,
                            child: TextField(
                              controller: _passwordTextEditingController,
                              focusNode: _focusPassword,
                              obscureText: _obscurePassword,
                              decoration: _isPasswordError && _errorMessage != null
                                  ? _errorInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.password_outlined,
                                  size: 24,
                                  color: errorColor,
                                ),
                                labelText: 'Пароль',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: errorColor,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              )
                                  : _normalInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.password_outlined,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                labelText: 'Пароль',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Поле повторения пароля
                        SlideTransition(
                          position: _shakeAnimation!,
                          child: SizedBox(
                            width: double.infinity,
                            child: TextField(
                              controller: _passwordRepeatTextEditingController,
                              focusNode: _focusPasswordRepeat,
                              obscureText: _obscurePassword,
                              decoration: _isPasswordError && _errorMessage != null
                                  ? _errorInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.password_outlined,
                                  size: 24,
                                  color: errorColor,
                                ),
                                labelText: 'Повторите пароль',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: errorColor,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              )
                                  : _normalInputDecoration.copyWith(
                                prefixIcon: const Icon(
                                  Icons.password_outlined,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                labelText: 'Повторите пароль',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: FractionallySizedBox(
                            widthFactor: 3 / 4,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _registerWithEmailAndPassword,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                backgroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Text(
                                'Зарегистрироваться',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: FractionallySizedBox(
                            widthFactor: 3 / 4,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: Colors.transparent,
                                splashFactory: NoSplash.splashFactory,
                              ),
                              child: Text(
                                'Уже есть аккаунт?',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Анимированное окошко ошибки
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
                          color: errorBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x30B00020), width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 20, color: errorColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.manrope(
                                  color: errorColor,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: errorColor),
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
}