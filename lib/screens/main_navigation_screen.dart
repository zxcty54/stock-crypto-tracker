import 'package:flutter/material.dart';
import '../widgets/floating_nav_bar.dart';
import 'news_screen.dart';
import 'corporate_announcements_screen.dart';
import 'crypto_screen.dart';
import 'community_screen.dart'; // 👥 Scanner ki jagah Community screen import ki gayi

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    NewsScreen(),
    CorporateAnnouncementsScreen(),
    CryptoScreen(),
    CommunityScreen(), // 👥 4th slot par Community screen set ho gayi
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 20,
            child: FloatingNavBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}
