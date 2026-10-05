import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/trader_feed_card.dart';
import '../widgets/create_chart_post_sheet.dart';
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

  // Google Sheet Live Indices State
  Map<String, dynamic> _liveIndices = {};
  double _niftyPrice = 22459.80; // Baseline fallback
  bool _isLoadingIndices = false;

  final String _sheetApiUrl =
      "https://script.google.com/macros/s/AKfycbyPkUC7yn0aj8zhpLYfHAKXFCiW6oZ6tp42nHU4PUnxuDoc7pAZ3eUStmC4NQXZxu47/exec";

  @override
  void initState() {
    super.initState();
    _fetchLiveIndices();
    _fetchCommunityPosts();
  }

  // ---------------------------------------------------------------------------
  // 1. Live Indices Fetch with Google 302 Redirect & Safe Fallback
  // ---------------------------------------------------------------------------
  Future<void> _fetchLiveIndices() async {
    if (mounted) setState(() => _isLoadingIndices = true);

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
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            parsedData = Map<String, dynamic>.from(decoded['data']);
          } else {
            parsedData = decoded;
          }
        }

        // Extract Nifty 50 CMP to feed Sentiment Dynamic Strikes
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
            _isLoadingIndices = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingIndices = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingIndices = false);
    }
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
        onPostCreated: () {
          _fetchCommunityPosts();
        },
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
                                content: Text(
                                  'Auth Failed: Supabase Dashboard > Authentication > Providers > Anonymous ko Enable karein.',
                                  style: TextStyle(fontSize: 12),
                                ),
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
        toolbarHeight: 0, // Clean completely blank top bar
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
            itemCount: 2 + (_communityPosts.isEmpty ? 1 : _communityPosts.length),
            itemBuilder: (context, index) {
              // -------------------------------------------------------------
              // 1. TOP LIVE INDICES HORIZONTAL STRIP
              // -------------------------------------------------------------
              if (index == 0) {
                return _buildTopIndicesTickerStrip();
              }

              // -------------------------------------------------------------
              // 2. REALTIME SENTIMENT CARD (In Front with Dynamic Nifty Strikes)
              // -------------------------------------------------------------
              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: CommunitySentimentCard(niftyLivePrice: _niftyPrice),
                );
              }

              // Empty Feed Message
              if (_communityPosts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.query_stats_rounded, color: Colors.white24, size: 40),
                      const SizedBox(height: 10),
                      const Text(
                        'No Setups Posted Yet',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Be the first to share your chart setup.',
                        style: TextStyle(color: Color(0xFF6B7A99), fontSize: 11),
                      ),
                    ],
                  ),
                );
              }

              // Community Trader Feed Posts
              final post = _communityPosts[index - 2];
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

  // ---------------------------------------------------------------------------
  // Top Subtle Indices Bar (Horizontal Scroll)
  // ---------------------------------------------------------------------------
  Widget _buildTopIndicesTickerStrip() {
    final entries = _liveIndices.isNotEmpty
        ? _liveIndices.entries.toList()
        : [
            MapEntry("Nifty 50", {"price": 22459.80, "change": "+0.17%"}),
            MapEntry("Bank Nifty", {"price": 54522.70, "change": "+0.13%"}),
            MapEntry("Sensex", {"price": 72042.98, "change": "+0.19%"}),
            MapEntry("Dow Jones", {"price": 46592.53, "change": "+0.31%"}),
            MapEntry("Nasdaq", {"price": 22764.46, "change": "-0.47%"}),
          ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Drawer trigger button
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
          // Horizontal ticker items
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
                } else if (item.value is num) {
                  price = (item.value as num).toDouble();
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
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        price.toStringAsFixed(price > 1000 ? 1 : 2),
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        change.startsWith("+") || change.startsWith("-") ? change : "+$change",
                        style: TextStyle(
                          color: isUp ? const Color(0xFF00C076) : const Color(0xFFFF2A6D),
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

  // ---------------------------------------------------------------------------
  // Clean Indices Drawer (Displays all fetched items in one panel)
  // ---------------------------------------------------------------------------
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
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text("Realtime feeds from Google Finance", style: TextStyle(color: Color(0xFF8896AB), fontSize: 11)),
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
                    } else if (item.value is num) {
                      price = (item.value as num).toDouble();
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(price.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                              Text(
                                change.startsWith("+") || change.startsWith("-") ? change : "+$change",
                                style: TextStyle(
                                  color: isUp ? const Color(0xFF00C076) : const Color(0xFFFF2A6D),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ],
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

// ============================================================================
// 🎯 REALTIME 2-IN-1 COMMUNITY SENTIMENT CARD WITH DYNAMIC STRIKE RANGES
// ============================================================================
class CommunitySentimentCard extends StatefulWidget {
  final double niftyLivePrice;

  const CommunitySentimentCard({super.key, required this.niftyLivePrice});

  @override
  State<CommunitySentimentCard> createState() => _CommunitySentimentCardState();
}

class _CommunitySentimentCardState extends State<CommunitySentimentCard> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _activeTab = 0; // 0 = Daily, 1 = Monthly Outlook
  String? _myVote;
  String? _myTargetLevel;
  bool _isSubmitting = false;

  String get _dailyPeriodKey {
    final now = DateTime.now();
    return "DAILY-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  final String _monthlyPeriodKey = "EXPIRY-NOV-2026";
  String get _currentPeriod => _activeTab == 0 ? _dailyPeriodKey : _monthlyPeriodKey;

  // Auto-calculated strike ranges from Live Nifty CMP
  List<String> get _dynamicRanges {
    final p = widget.niftyLivePrice > 0 ? widget.niftyLivePrice : 22459.80;
    final base = ((p / 500).round() * 500).toInt();
    final upper = base + 500;
    final lower = base - 500;

    return [
      "> $upper",
      "$lower - $upper",
      "< $lower",
    ];
  }

  bool get _isDailyVotingWindowOpen {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final marketCloseMinutes = 15 * 60 + 30; // 3:30 PM
    final marketOpenMinutes = 9 * 60 + 15;   // 9:15 AM
    return currentMinutes >= marketCloseMinutes || currentMinutes < marketOpenMinutes;
  }

  @override
  void initState() {
    super.initState();
    _loadUserExistingVote();
  }

  Future<void> _loadUserExistingVote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('user_predictions')
          .select('prediction, target_level')
          .eq('user_id', user.id)
          .eq('target_month', _currentPeriod)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _myVote = res?['prediction'] as String?;
          _myTargetLevel = res?['target_level'] as String?;
        });
      }
    } catch (_) {}
  }

  void _switchTab(int index) {
    if (_activeTab == index) return;
    setState(() {
      _activeTab = index;
      _myVote = null;
      _myTargetLevel = null;
    });
    _loadUserExistingVote();
  }

  Future<void> _castVote(String type, {String? targetLevel}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0F1726),
          content: Text('Please create trader handle to vote!', style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      );
      return;
    }

    if (_activeTab == 0 && !_isDailyVotingWindowOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF141C2B),
          content: Text('Voting locked! Market is live (9:15 AM - 3:30 PM). Opens at 3:30 PM.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      final payload = {
        'user_id': user.id,
        'target_month': _currentPeriod,
        'prediction': type,
        if (targetLevel != null) 'target_level': targetLevel,
      };

      await _supabase.from('user_predictions').upsert(
        payload,
        onConflict: 'user_id,target_month',
      );

      if (mounted) {
        setState(() {
          _myVote = type;
          if (targetLevel != null) _myTargetLevel = targetLevel;
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF141C2B),
            duration: const Duration(seconds: 1),
            content: Text(
              'Prediction recorded: $type ${targetLevel ?? ""}',
              style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2B3E)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('sentiment_stats')
            .stream(primaryKey: ['target_month'])
            .eq('target_month', _currentPeriod),
        builder: (context, snapshot) {
          final data = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;

          final totalVotes = data?['total_votes'] ?? 0;
          final bullPct = (data?['bullish_pct'] ?? 50.0).toDouble();
          final bearPct = (data?['bearish_pct'] ?? 50.0).toDouble();
          final sidePct = (data?['sideways_pct'] ?? 0.0).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Section Title + Dual Timeframe Switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.show_chart_rounded, color: Color(0xFF00E5FF), size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _activeTab == 0 ? "TOMORROW'S MOOD" : "MONTHLY OUTLOOK",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141C2B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E2B3E)),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton("Daily", 0),
                        _buildTabButton("Nov Expiry", 1),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Question Prompt + Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _activeTab == 0
                          ? "Kal Nifty Bullish rahega ya Bearish?"
                          : "November Expiry tak Nifty ka trend kaisa rahega?",
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_activeTab == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isDailyVotingWindowOpen
                            ? const Color(0xFF00C076).withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _isDailyVotingWindowOpen ? const Color(0xFF00C076) : Colors.orange,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _isDailyVotingWindowOpen ? "VOTING OPEN" : "MARKET LIVE",
                        style: TextStyle(
                          color: _isDailyVotingWindowOpen ? const Color(0xFF00C076) : Colors.orange,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Multi-Segment Ratio Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 9,
                  child: Row(
                    children: [
                      Expanded(
                        flex: totalVotes == 0 ? 50 : bullPct.round().clamp(1, 98),
                        child: Container(color: const Color(0xFF00C076)),
                      ),
                      if (_activeTab == 1 && sidePct > 0) ...[
                        const SizedBox(width: 2),
                        Expanded(
                          flex: sidePct.round().clamp(1, 98),
                          child: Container(color: const Color(0xFFFFB300)),
                        ),
                      ],
                      const SizedBox(width: 2),
                      Expanded(
                        flex: totalVotes == 0 ? 50 : bearPct.round().clamp(1, 98),
                        child: Container(color: const Color(0xFFFF2A6D)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Live Percentages Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Bullish: ${totalVotes == 0 ? "50%" : "${bullPct.toStringAsFixed(1)}%"}",
                    style: const TextStyle(color: Color(0xFF00C076), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                  if (_activeTab == 1)
                    Text(
                      "Sideways: ${totalVotes == 0 ? "0%" : "${sidePct.toStringAsFixed(1)}%"}",
                      style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  Text(
                    "Bearish: ${totalVotes == 0 ? "50%" : "${bearPct.toStringAsFixed(1)}%"}",
                    style: const TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action Buttons
              if (_activeTab == 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildVoteBtn(
                        label: "BULLISH",
                        type: "BULLISH",
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF00C076),
                        isSelected: _myVote == "BULLISH",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildVoteBtn(
                        label: "BEARISH",
                        type: "BEARISH",
                        icon: Icons.trending_down_rounded,
                        color: const Color(0xFFFF2A6D),
                        isSelected: _myVote == "BEARISH",
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildVoteBtn(
                        label: "BULLISH",
                        type: "BULLISH",
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF00C076),
                        isSelected: _myVote == "BULLISH",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildVoteBtn(
                        label: "RANGE",
                        type: "SIDEWAYS",
                        icon: Icons.swap_horiz_rounded,
                        color: const Color(0xFFFFB300),
                        isSelected: _myVote == "SIDEWAYS",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildVoteBtn(
                        label: "BEARISH",
                        type: "BEARISH",
                        icon: Icons.trending_down_rounded,
                        color: const Color(0xFFFF2A6D),
                        isSelected: _myVote == "BEARISH",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dynamic Expiry Range Chips (From Sheet CMP)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Expected Expiry Range:",
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Nifty: ${widget.niftyLivePrice.toStringAsFixed(1)}",
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: _dynamicRanges.map((range) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildTargetChip(range),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTargetChip(String range) {
    final isSelected = _myTargetLevel == range;
    return InkWell(
      onTap: () {
        if (_myVote != null) {
          _castVote(_myVote!, targetLevel: range);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pehle Bullish/Bearish/Range chun lijiye!")),
          );
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.15) : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF1E2B3E),
          ),
        ),
        child: Text(
          range,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white60,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int idx) {
    final active = _activeTab == idx;
    return GestureDetector(
      onTap: () => _switchTab(idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E5FF).withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? const Color(0xFF00E5FF) : Colors.white54,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildVoteBtn({
    required String label,
    required String type,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: _isSubmitting ? null : () => _castVote(type, targetLevel: _myTargetLevel),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF1E2B3E),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : Colors.white60),
            const SizedBox(width: 5),
            Text(
              isSelected ? "$label ✓" : label,
              style: TextStyle(
                color: isSelected ? color : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
