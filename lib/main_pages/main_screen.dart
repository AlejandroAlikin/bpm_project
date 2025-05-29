import 'package:bpm/main_pages/results_page.dart';
import 'package:bpm/main_pages/scanning_page.dart';
import 'package:flutter/material.dart';

import '../design/colors.dart';
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

  final List<Widget> _pages = [
    const ScanningPage(),
    const ResultsPage(),
    const AccountPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (!_isAnimating) {
            setState(() => _currentIndex = index);
          }
        },
        physics: const ClampingScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) async {
        if (_currentIndex == index || _isAnimating) return;

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
          icon: Icon(Icons.home_outlined, color: inactiveColor, size: 28),
          activeIcon: Icon(Icons.home, color: primaryBlue, size: 36),
          label: 'Главная',
          tooltip: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined, color: inactiveColor, size: 28),
          activeIcon: Icon(Icons.analytics, color: primaryBlue, size: 36),
          label: 'Результаты',
          tooltip: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline, color: inactiveColor, size: 28),
          activeIcon: Icon(Icons.person, color: primaryBlue, size: 36),
          label: 'Профиль',
          tooltip: '',
        ),
      ],
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 0,
      backgroundColor: Colors.white,
      selectedItemColor: primaryBlue,
      unselectedItemColor: inactiveColor,
    );
  }
}