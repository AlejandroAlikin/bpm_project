import 'package:bpm/main_pages/results_page.dart';
import 'package:bpm/main_pages/scanning_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../design/colors.dart';
import '../design/elderly_styles.dart';
import '../services/theme_service.dart';
import '../services/tts_service.dart';
import 'account_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  final Color inactiveColor = Colors.grey;
  bool _isAnimating = false;
  final TTSService _tts = TTSService();

  final List<Widget> _pages = [
    const ScanningPage(),
    const ResultsPage(),
    const AccountPage(),
  ];

  final List<String> _pageNames = ['Главная', 'Результаты', 'Профиль'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _tts.init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isElderly = themeService.isElderlyMode;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (!_isAnimating) {
            setState(() => _currentIndex = index);
            if (isElderly) {
              _tts.speak(_pageNames[index]);
            }
          }
        },
        physics: const ClampingScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (_currentIndex == index || _isAnimating) return;

          if (isElderly) {
            await _tts.speak(_pageNames[index]);
          }

          setState(() {
            _isAnimating = true;
            _currentIndex = index;
          });

          await _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          setState(() => _isAnimating = false);
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, color: inactiveColor, size: isElderly ? 32 : 28),
            activeIcon: Icon(Icons.home, color: primaryBlue, size: isElderly ? 40 : 36),
            label: 'Главная',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined, color: inactiveColor, size: isElderly ? 32 : 28),
            activeIcon: Icon(Icons.analytics, color: primaryBlue, size: isElderly ? 40 : 36),
            label: 'Результаты',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, color: inactiveColor, size: isElderly ? 32 : 28),
            activeIcon: Icon(Icons.person, color: primaryBlue, size: isElderly ? 40 : 36),
            label: 'Профиль',
            tooltip: '',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
        backgroundColor: isElderly ? ElderlyStyles.backgroundColor : Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: inactiveColor,
        selectedLabelStyle: GoogleFonts.manrope(
          fontSize: isElderly ? 14 : 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: isElderly ? 14 : 12,
        ),
      ),
    );
  }
}