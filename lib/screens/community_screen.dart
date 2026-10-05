import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/trader_feed_card.dart';
import '../widgets/create_chart_post_sheet.dart';
import '../widgets/create_confession_sheet.dart'; // 👈 Text-Only Confession Sheet Import
import '../widgets/community_sentiment_card.dart';
import '../services/auth_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _communityPosts = [];
  bool _isLoadingPosts = true;
  String? _postsError;

  // Google Sheet Web App State
  Map<String, dynamic> _liveIndices = {};
  double _niftyPrice = 22459.80;
  String _marketStatus = "POST_MARKET";
  bool _isVotingAllowed = true;

  final String _sheetApiUrl =
      "https://script.google.com/macros/s/AKfycbyPkUC7yn0aj8zhpLYfHAKXFCiW6oZ6tp42nHU4PUnxuDoc7pAZ3eUStmC4NQXZxu47/exec";

  @override
  void initState() {
    super.initState();
    _fetchLiveIndices();
    _fetchCommunityPosts();
  }

  Future<void> _fetchLiveIndices() async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_sheetApiUrl))
        ..followRedirects = true
        ..maxRedirects = 5;

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        Map<String, dynamic> parsedData = {};
        String status = "POST_MARKET";
        bool allowed = true;

        if (decoded is Map<String, dynamic>) {
          status = decoded['market_status']?.toString() ?? "POST_MARKET";
          allowed = decoded['voting_allowed'] == true;

          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            parsedData = Map<String, dynamic>.from(decoded['data']);
          } else {
            parsedData = decoded;
          }
        }

        double extractedNifty = _niftyPrice;
        parsedData.forEach((key, val) {
          final cleanKey = key.toString().toLowerCase().replaceAll(" ", "").replaceAll("_", "");
          if (cleanKey.contains("nifty50") || cleanKey == "nifty") {
            if (val is Map && val.containsKey('price')) {
              extractedNifty = (val['price'] as num).toDouble();
            } else if (val is num) {
              extractedNifty = val.toDouble();
            }
          }
        });

        if (mounted) {
          setState(() {
            _liveIndices = parsedData;
            _niftyPrice = extractedNifty;
            _marketStatus = status;
            _isVotingAllowed = allowed;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchCommunityPosts() async {
    try {
      final res = await _supabase
          .from('trader_posts')
          .select('*, profiles(username, full_name, avatar_url)')
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _communityPosts = List<Map<String, dynamic>>.from(res);
          _isLoadingPosts = false;
          _postsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _postsError = e.toString();
        });
      }
    }
  }

  void _openCreatePostFlow() {
    HapticFeedback.mediumImpact();
    if (AuthService.isLoggedIn()) {
      _openCreatePostBottomSheet();
    } else {
      _showHandlePromptDialog(context, () {
        _openCreatePostBottomSheet();
      });
    }
  }

  void _openCreatePostBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateChartPostSheet(
        onPostCreated: () => _fetchCommunityPosts(),
      ),
    );
  }

  void _openConfessionFlow() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateConfessionSheet(
        onConfessionPosted: () => _fetchCommunityPosts(),
      ),
    );
  }

  void _showHandlePromptDialog(BuildContext context, VoidCallback onSuccess) {
    final nameCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F1726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E2B3E)),
            ),
            title: Text(
              'CREATE TRADER HANDLE',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your name to share chart setups and participate in community votes.',
                  style: TextStyle(color: Color(0xFF8896AB), fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'e.g. Rahul Trader',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF141C2B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2B3E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;

                        setDialogState(() => isSubmitting = true);
                        final ok = await AuthService.startAnonymousSession(name);

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        if (ok) {
                          onSuccess();
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFFFF2A6D),
                                content: Text('Auth Failed: Enable anonymous provider in Supabase.'),
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF090D16),
      endDrawer: _buildIndicesDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        elevation: 0,
        toolbarHeight: 0,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          onPressed: _openCreatePostFlow,
          backgroundColor: const Color(0xFF00E5FF),
          elevation: 4,
          icon: const Icon(Icons.add_chart_rounded, color: Colors.black, size: 20),
          label: Text(
            'POST SETUP',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF0F1726),
          onRefresh: () async {
            await Future.wait([
              _fetchLiveIndices(),
              _fetchCommunityPosts(),
            ]);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 120),
            // 3 static header items: Indices (0), Sentiment (1), Confession Bar (2)
            itemCount: 3 + (_communityPosts.isEmpty ? 1 : _communityPosts.length),
            itemBuilder: (context, index) {
              // 1. TOP INDICES TICKER
              if (index == 0) {
                return _buildTopIndicesTickerStrip();
              }

              // 2. HERO SENTIMENT CARD
              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: CommunitySentimentCard(
                    niftyLivePrice: _niftyPrice,
                    marketStatus: _marketStatus,
                    isVotingAllowed: _isVotingAllowed,
                  ),
                );
              }

              // 3. 🎯 TRADER CONFESSION DESK ENTRY STRIP (Max 700 words, No attachment)
              if (index == 2) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openConfessionFlow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF2A6D).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2A6D).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFFFF2A6D), size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "TRADER CONFESSION DESK",
                                  style: GoogleFonts.robotoMono(
                                    color: const Color(0xFFFF2A6D),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "FOMO ya Revenge trade? Confess anonymously (Max 700 words)...",
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_note_rounded, color: Color(0xFFFF2A6D), size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Empty placeholder
              if (_communityPosts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.query_stats_rounded, color: Colors.white24, size: 40),
                      SizedBox(height: 10),
                      Text('No Setups Posted Yet', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              // Feed Cards (Offset index - 3)
              final post = _communityPosts[index - 3];
              return TraderFeedCard(
                key: ValueKey(post['id']),
                post: post,
                onPostDeleted: _fetchCommunityPosts,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopIndicesTickerStrip() {
    final entries = _liveIndices.isNotEmpty
        ? _liveIndices.entries.toList()
        : [
            MapEntry("Nifty 50", {"price": 22459.80, "change": "+0.17%"}),
            MapEntry("Bank Nifty", {"price": 54522.70, "change": "+0.13%"}),
            MapEntry("Sensex", {"price": 72042.98, "change": "+0.19%"}),
          ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Container(
              margin: const EdgeInsets.only(left: 14, right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1726),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2B3E)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.candlestick_chart_rounded, color: Color(0xFF00E5FF), size: 14),
                  SizedBox(width: 4),
                  Text("MARKETS", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 14),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = entries[i];
                final name = item.key;
                double price = 0.0;
                String change = "0.0%";

                if (item.value is Map) {
                  price = (item.value['price'] as num?)?.toDouble() ?? 0.0;
                  change = item.value['change']?.toString() ?? "0.0%";
                }

                final bool isUp = !change.startsWith("-");

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1726),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E2B3E)),
                  ),
                  child: Row(
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Text(price.toStringAsFixed(price > 1000 ? 1 : 2), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 5),
                      Text(
                        change.startsWith("+") || change.startsWith("-") ? change : "+$change",
                        style: TextStyle(
                          color: isUp ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicesDrawer() {
    final entries = _liveIndices.entries.toList();

    return Drawer(
      backgroundColor: const Color(0xFF0F1726),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public_rounded, color: Color(0xFF00E5FF), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "GLOBAL INDICES",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E2B3E), height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = entries[i];
                    final name = item.key;
                    double price = 0.0;
                    String change = "0.0%";

                    if (item.value is Map) {
                      price = (item.value['price'] as num?)?.toDouble() ?? 0.0;
                      change = item.value['change']?.toString() ?? "0.0%";
                    }

                    final bool isUp = !change.startsWith("-");

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141C2B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E2B3E)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(
                            "$price (${change.startsWith("+") || change.startsWith("-") ? change : "+$change"})",
                            style: TextStyle(color: isUp ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
