import 'package:bpm/services/tts_settings_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'authorization/login_page.dart';
import 'main_pages/main_screen.dart';
import 'design/colors.dart';
import 'services/theme_service.dart';
import 'design/elderly_styles.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _initializeNotifications();
  await TTSSettingsService().init();

  runApp(const MyApp());
}

Future<void> _initializeNotifications() async {
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'pressure_reminder_channel',
    'Напоминания об измерениях',
    description: 'Напоминания о необходимости измерить давление',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {},
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'BPM',
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ru', 'RU'),
            ],
            locale: const Locale('ru', 'RU'),
            theme: themeService.isElderlyMode ? _elderlyTheme : _youngTheme,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

final ThemeData _youngTheme = ThemeData(
  fontFamily: GoogleFonts.manrope().fontFamily,
  primaryColor: Colors.white,
  scaffoldBackgroundColor: Colors.white,
  iconTheme: const IconThemeData(color: Colors.black),
  appBarTheme: const AppBarTheme(
    color: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  visualDensity: VisualDensity.adaptivePlatformDensity,
  colorScheme: ColorScheme.light(
    primary: primaryBlue,
    secondary: primaryBlue.withOpacity(0.8),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryBlue,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryBlue, width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);

final ThemeData _elderlyTheme = ThemeData(
  fontFamily: GoogleFonts.manrope().fontFamily,
  primaryColor: ElderlyStyles.backgroundColor,
  scaffoldBackgroundColor: ElderlyStyles.backgroundColor,
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: ElderlyStyles.primaryColor,
    secondary: ElderlyStyles.primaryColor.withOpacity(0.8),
  ),
  iconTheme: const IconThemeData(color: ElderlyStyles.textColor),
  appBarTheme: AppBarTheme(
    color: ElderlyStyles.backgroundColor,
    elevation: 1,
    iconTheme: const IconThemeData(color: ElderlyStyles.textColor),
    titleTextStyle: ElderlyStyles.headlineMedium,
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ElderlyStyles.primaryColor,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElderlyStyles.elevatedButtonStyle,
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ElderlyStyles.outlinedButtonStyle,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: ElderlyStyles.primaryColor, width: 2),
    ),
    filled: true,
    fillColor: ElderlyStyles.surfaceColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    labelStyle: ElderlyStyles.bodyMedium,
  ),
  cardTheme: const CardThemeData(
    elevation: 2,
    margin: EdgeInsets.all(8),
  ),
);

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;

          if (user == null) {
            return const LoginPage();
          } else {
            return const MainScreen();
          }
        }

        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(color: primaryBlue),
          ),
        );
      },
    );
  }
}