import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Этот файл будет сгенерирован автоматически
import 'authorization/login_page.dart';

void main() async {
  // Отключаем debugPrint
  debugPrint = (String? message, {int? wrapWidth}) {};

  // Обязательная инициализация Flutter биндингов
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Проверка подключения (опционально)
  await _testFirebaseConnection();

  runApp(const MyApp());
}

// Тестовый метод для проверки подключения к Firebase
Future<void> _testFirebaseConnection() async {
  try {
    await FirebaseFirestore.instance.collection('test').doc('connection').set({
      'timestamp': FieldValue.serverTimestamp(),
    });
    print('Firebase подключен успешно!');
  } catch (e) {
    print('Ошибка подключения к Firebase: $e');
  }
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
        iconTheme: const IconThemeData(color: Colors.white),
        appBarTheme: const AppBarTheme(color: Colors.white),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}