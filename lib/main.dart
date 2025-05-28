import 'package:flutter/material.dart';

import 'authorization/login_page.dart';

void main() {
  debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'BPM',
      theme: ThemeData(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        appBarTheme: AppBarTheme(color: Colors.white),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // Устанавливаем начальный маршрут
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
      },

      // Альтернативный вариант без именованных маршрутов:
      // home: const LoginPage(),
    );
  }
}