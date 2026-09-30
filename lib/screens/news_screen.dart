import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// 🪙 Metals & Forex Ticker Card Import
import '../widgets/metals_ticker_card.dart';

class NewsItem {
  final String title;
  final String source;
  final String time;
  final String? url;
  final String? summary;

  NewsItem({
    required this.title,
    required this.source,
    required this.time,
    this.url,
    this.summary,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? 'Market Headline',
      source: json['source'] ?? 'Financial Wire',
      time: json['time'] ?? 'Just now',
      url: json['url'],
      summary: json['summary'],
    );
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final String _newsUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/market_news.json';

  List<NewsItem> _newsList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final res = await http.get(
        Uri.parse('$_newsUrl?ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      );

      if (res.statusCode == 200) {
        final dynamic raw = jsonDecode(res.body);
        List<NewsItem> parsed = [];

        if (raw is List) {
          parsed = raw.map((e) => NewsItem.fromJson(e)).toList();
        } else if (raw is Map && raw.containsKey('news')) {
          parsed = (raw['news'] as List).map((e) => NewsItem.fromJson(e)).toList();
        }

        if (mounted) {
          setState(() {
            _newsList = parsed;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'HTTP ${res.statusCode}: Failed to sync wire';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Live feed connection error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: RefreshIndicator(
        color: const Color(0xFF00E5FF),
        backgroundColor: const Color(0xFF0F1726),
        onRefresh: _fetchNews,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 🪙 1. LIVE BULLION, COPPER & FOREX TICKER CARD (Top Position)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: MetalsTickerCard(),
              ),
            ),

            // 📰 2. Section Header: Wire News
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MARKET NEWS WIRE',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF00E5FF)),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isLoading = true);
                        _fetchNews();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 📑 3. News Feed Content
            if (_isLoading && _newsList.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
                ),
              )
            else if (_error != null && _newsList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.white30, size: 36),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      TextButton(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchNews();
                        },
                        child: const Text('Retry Feed', style: TextStyle(color: Color(0xFF00E5FF))),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 100), // Bottom padding for navbar dock
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _newsList[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1726),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E2B3E)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A2436),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.source.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.time,
                                  style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            if (item.summary != null && item.summary!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.summary!,
                                style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    childCount: _newsList.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
