import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../widgets/market_index_card.dart';
import '../widgets/news_card.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
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
        color: const Color(0xFF00E5FF),
        backgroundColor: const Color(0xFF131B2A),
        onRefresh: fetchNews,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('StockPulse',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Dalal Street & Global Wire',
                            style: TextStyle(fontSize: 12, color: Color(0xFF8896AB))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
                      onPressed: fetchNews,
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    MarketIndexCard(title: 'NIFTY 50', points: '24,315.95', change: '+0.68%', isBullish: true),
                    MarketIndexCard(title: 'SENSEX', points: '79,942.18', change: '+0.54%', isBullish: true),
                    MarketIndexCard(title: 'BANK NIFTY', points: '52,180.40', change: '-0.21%', isBullish: false),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Text('Top Headlines',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => NewsCard(item: newsList[index]),
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
