import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  List<Map<String, dynamic>> _communityPosts = [];
  bool _isLoadingPosts = true;
  String? _postsError;

  @override
  void initState() {
    super.initState();
    _fetchCommunityPosts();
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
      backgroundColor: const Color(0xFF090D16),
      // Clean blank status area with no title text
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
          onRefresh: () async => await _fetchCommunityPosts(),
          child: _isLoadingPosts
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2))
              : _postsError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Unable to connect: $_postsError',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFF2A6D), fontSize: 11),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 120),
                      itemCount: 1 + (_communityPosts.isEmpty ? 1 : _communityPosts.length),
                      itemBuilder: (context, index) {
                        // 🎯 Top Sentiment Widget
                        if (index == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: CommunitySentimentCard(),
                          );
                        }

                        // Feed is empty
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

                        // Trader Posts List
                        final post = _communityPosts[index - 1];
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
}

// ============================================================================
// 🎯 REALTIME 2-IN-1 COMMUNITY SENTIMENT CARD COMPONENT
// ============================================================================
class CommunitySentimentCard extends StatefulWidget {
  const CommunitySentimentCard({super.key});

  @override
  State<CommunitySentimentCard> createState() => _CommunitySentimentCardState();
}

class _CommunitySentimentCardState extends State<CommunitySentimentCard> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 0 = Daily Mood, 1 = Monthly Outlook
  int _activeTab = 0;

  String? _myVote;
  String? _myTargetLevel;
  bool _isSubmitting = false;

  // Dynamic daily period key based on date
  String get _dailyPeriodKey {
    final now = DateTime.now();
    return "DAILY-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  final String _monthlyPeriodKey = "EXPIRY-NOV-2026";

  String get _currentPeriod => _activeTab == 0 ? _dailyPeriodKey : _monthlyPeriodKey;

  // Daily Voting Window: 3:30 PM to 9:15 AM
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
          content: Text('Voting locked! Market is currently live (9:15 AM - 3:30 PM).'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote error: $e')),
        );
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
              // Top Bar: Section Title + Segmented Switcher
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

              // Prompt Question + Window Badge
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

              // Ratio Progress Bar
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

              // Live Percentages
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
                Text(
                  "Expected Expiry Range:",
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildTargetChip("> 25,500"),
                    const SizedBox(width: 6),
                    _buildTargetChip("24,500 - 25,500"),
                    const SizedBox(width: 6),
                    _buildTargetChip("< 24,500"),
                  ],
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
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_myVote != null) {
            _castVote(_myVote!, targetLevel: range);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Pehle Bullish/Bearish/Range vote select karein!")),
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
