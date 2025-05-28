import 'package:bpm/authorization/register_page.dart';
import 'package:bpm/design/colors.dart';
import 'package:bpm/main_pages/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<StatefulWidget> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late TextEditingController _emailTextEditingController;
  late TextEditingController _passwordTextEditingController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailTextEditingController = TextEditingController();
    _passwordTextEditingController = TextEditingController();
  }

  @override
  void dispose() {
    _emailTextEditingController.dispose();
    _passwordTextEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelStyle: GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1D1B20),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );

    return Scaffold(
      body: Column(
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
                      'С возвращением!',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: TextField(
                        controller: _emailTextEditingController,
                        decoration: _inputDecoration.copyWith(
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 24,
                            color: Colors.black,
                          ),
                          labelText: 'Адрес эл. почты',
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: TextField(
                        controller: _passwordTextEditingController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration.copyWith(
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
                          onPressed: () {
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => MainScreen())
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            backgroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Войти',
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegisterPage(),
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
                            'Зарегистрироваться',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue, // розовый цвет текста
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
