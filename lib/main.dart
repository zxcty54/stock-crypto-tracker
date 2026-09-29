import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const StockPulseApp());
}

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StockPulse: Dalal Street Update',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E14), // Rich Fintech Slate
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DalalStreetScreen(),
    CryptoTrackerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_currentIndex],
          
          // Modern Floating Navigation Pill
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF151922).withOpacity(0.92),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFF262C3A), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(
                    index: 0,
                    icon: Icons.candlestick_chart_rounded,
                    label: 'Dalal Street',
                  ),
                  _navItem(
                    index: 1,
                    icon: Icons.currency_bitcoin_rounded,
                    label: 'Crypto Live',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({required int index, required IconData icon, required String label}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00D09C).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF00D09C) : const Color(0xFF758095),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF00D09C),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. DALAL STREET & MARKET NEWS SCREEN
// ==========================================
class DalalStreetScreen extends StatefulWidget {
  const DalalStreetScreen({super.key});

  @override
  State<DalalStreetScreen> createState() => _DalalStreetScreenState();
}

class _DalalStreetScreenState extends State<DalalStreetScreen> {
  List<dynamic> newsList = [];
  bool isLoading = true;

  Future<void> fetchNews() async {
    setState(() => isLoading = true);
    final url = Uri.parse('https://min-api.cryptocompare.com/data/v2/news/?lang=EN');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          newsList = data['Data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: const Color(0xFF00D09C),
        backgroundColor: const Color(0xFF151922),
        onRefresh: fetchNews,
        child: CustomScrollView(
          slivers: [
            // Custom App Bar Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'StockPulse',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dalal Street & Global Radar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF8A93A6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00D09C)),
                      onPressed: fetchNews,
                    ),
                  ],
                ),
              ),
            ),

            // Indian Market Indices Ribbon (Nifty / Sensex Overview)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    MarketIndexCard(
                      title: 'NIFTY 50',
                      points: '24,315.95',
                      change: '+0.68%',
                      isBullish: true,
                    ),
                    MarketIndexCard(
                      title: 'SENSEX',
                      points: '79,942.18',
                      change: '+0.54%',
                      isBullish: true,
                    ),
                    MarketIndexCard(
                      title: 'BANK NIFTY',
                      points: '52,180.40',
                      change: '-0.21%',
                      isBullish: false,
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Top Headlines & Wire',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // News Feed
            isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00D09C)),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = newsList[index];
                          return NewsItemCard(item: item);
                        },
                        childCount: newsList.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class MarketIndexCard extends StatelessWidget {
  final String title;
  final String points;
  final String change;
  final bool isBullish;

  const MarketIndexCard({
    super.key,
    required this.title,
    required this.points,
    required this.change,
    required this.isBullish,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBullish ? const Color(0xFF00D09C) : const Color(0xFFFF4D4F);
    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222836)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8A93A6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                points,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NewsItemCard extends StatelessWidget {
  final dynamic item;
  const NewsItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222836)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF202737),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item['source'] ?? 'Market Wire',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF00D09C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.circle, size: 6, color: Color(0xFF556075)),
              const SizedBox(width: 6),
              Text(
                'Live',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF8A93A6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item['title'] ?? 'No Title',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['body'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF8A93A6),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. CRYPTO TRACKER SCREEN
// ==========================================
class CryptoTrackerScreen extends StatefulWidget {
  const CryptoTrackerScreen({super.key});

  @override
  State<CryptoTrackerScreen> createState() => _CryptoTrackerScreenState();
}

class _CryptoTrackerScreenState extends State<CryptoTrackerScreen> {
  Map<String, dynamic> prices = {};
  bool isLoading = true;

  Future<void> fetchPrices() async {
    setState(() => isLoading = true);
    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,binancecoin,solana,ripple,cardano&vs_currencies=usd,inr&include_24hr_change=true');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          prices = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchPrices();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: const Color(0xFF00D09C),
        backgroundColor: const Color(0xFF151922),
        onRefresh: fetchPrices,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crypto Market',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'INR & USD Live Spot Ticker',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF8A93A6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00D09C)),
                      onPressed: fetchPrices,
                    ),
                  ],
                ),
              ),
            ),
            isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00D09C)),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final coinKey = prices.keys.elementAt(index);
                          final data = prices[coinKey];
                          return CryptoAssetCard(coinName: coinKey, data: data);
                        },
                        childCount: prices.keys.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class CryptoAssetCard extends StatelessWidget {
  final String coinName;
  final dynamic data;

  const CryptoAssetCard({super.key, required this.coinName, required this.data});

  @override
  Widget build(BuildContext context) {
    final double change24h = (data['usd_24h_change'] ?? 0.0).toDouble();
    final bool isUp = change24h >= 0;
    final color = isUp ? const Color(0xFF00D09C) : const Color(0xFFFF4D4F);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222836)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF202737),
            child: Text(
              coinName.substring(0, 1).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00D09C),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coinName.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹ ${(data['inr'] ?? 0).toString()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF8A93A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${(data['usd'] ?? 0).toString()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isUp ? '+' : ''}${change24h.toStringAsFixed(2)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
