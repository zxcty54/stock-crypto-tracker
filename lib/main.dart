import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/news_screen.dart';
import 'screens/corporate_announcements_screen.dart';
import 'screens/strategy_builder_screen.dart';
import 'screens/community_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/stock_delivery_history_screen.dart';
import 'widgets/legal_disclaimer_dialog.dart';
import 'widgets/create_chart_post_sheet.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌐 GitHub Secrets se inject hone wale variables
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const StockPulseApp());
}

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StockPulse: Institutional Terminal',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription? _intentSub;

  final List<Widget> _pages = const [
    NewsScreen(),
    CorporateAnnouncementsScreen(),
    StrategyBuilderScreen(),
    CommunityScreen(),
  ];

  final List<String> _titles = const [
    'MARKET NEWS WIRE',
    'CORPORATE FILINGS',
    'STRATEGY BUILDER',
    'TRADER COMMUNITY WIRE',
  ];

  @override
  void initState() {
    super.initState();
    _listenToSharedMedia();
  }

  /// 📸 Phone Gallery se share ki hui image ko listen aur handle karein
  void _listenToSharedMedia() {
    // Scenario 1: App background / memory mein chal rahi ho
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleSharedImage(File(value.first.path));
        }
      },
      onError: (err) {
        debugPrint("getMediaStream error: $err");
      },
    );

    // Scenario 2: App completely closed ho aur user ne gallery se khola ho
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedImage(File(value.first.path));
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _handleSharedImage(File imageFile) {
    if (!AuthService.isLoggedIn()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFFF2A6D),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Access Denied: Pehle app ke Community tab me jakar Trader Handle create karein tabhi chart share hoga.',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _currentIndex = 3);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => CreateChartPostSheet(
          initialImage: imageFile,
          onPostCreated: () {},
        ),
      );
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF090D16),
      drawer: _buildInstitutionalDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTerminalHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 20,
              child: _buildFloatingNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1726),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2B3E))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF00E5FF), size: 24),
                tooltip: 'Open Terminal Menu',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STOCKPULSE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    _titles[_currentIndex],
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF25334A)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00F5A0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE FEED',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0A0F1A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1726),
                border: Border(bottom: BorderSide(color: Color(0xFF1E2B3E))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.terminal_rounded, color: Color(0xFF00E5FF), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'StockPulse Pro',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'Institutional Terminal v1.0',
                            style: TextStyle(color: Color(0xFF6B7A99), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                'ANALYTICS & ENGINES',
                style: TextStyle(color: Color(0xFF5A6882), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ),
            _drawerTile(
              icon: Icons.pie_chart_rounded,
              title: 'Delivery & OHLC History',
              subtitle: '20-Day Qty, Del %, High/Low filters',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StockDeliveryHistoryScreen(),
                  ),
                );
              },
            ),
            _drawerTile(
              icon: Icons.candlestick_chart_rounded,
              title: 'Strategy Replay Builder',
              subtitle: 'Bar-by-bar backtest & SL/TP tools',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            _drawerTile(
              icon: Icons.radar_rounded,
              title: 'Market Radar & Scanner',
              subtitle: 'Consolidation squeeze & breakouts',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: ScannerScreen()),
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF1E2B3E), height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                'FEEDS & ARCHIVES',
                style: TextStyle(color: Color(0xFF5A6882), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ),
            _drawerTile(
              icon: Icons.hub_rounded,
              title: 'Trader Wire Community',
              subtitle: 'Share chart setups & market bias',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            _drawerTile(
              icon: Icons.campaign_rounded,
              title: 'Corporate Filings & Orders',
              subtitle: 'BSE/NSE exchange disclosures',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            _drawerTile(
              icon: Icons.newspaper_rounded,
              title: 'Financial News Wire',
              subtitle: 'Real-time market press updates',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            const Divider(color: Color(0xFF1E2B3E), height: 20),
            _drawerTile(
              icon: Icons.shield_outlined,
              title: 'Regulatory & Risk Disclaimer',
              subtitle: 'Paper trading & SEBI advisory notice',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const LegalDisclaimerDialog(),
                );
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F1726),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fastly CDN Synced', style: TextStyle(color: Color(0xFF6B7A99), fontSize: 10)),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00F5A0),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFF00E5FF).withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isHighlight ? Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)) : null,
      ),
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        leading: Icon(
          icon,
          color: isHighlight ? const Color(0xFF00E5FF) : const Color(0xFF8896AB),
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: isHighlight ? const Color(0xFF00E5FF) : Colors.white,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 10),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A).withOpacity(0.96),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF202C42), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.newspaper_rounded, 'News'),
          _navItem(1, Icons.campaign_rounded, 'Filings'),
          _navItem(2, Icons.candlestick_chart_rounded, 'Strategy'),
          _navItem(3, Icons.hub_rounded, 'Community'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF8896AB),
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF00E5FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
