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

  // Active target period (Next month or custom label)
  final String _currentPeriod = "NOV-2026";

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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.hub_outlined, color: Color(0xFF00E5FF), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'TRADER WIRE',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
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
      body: RefreshIndicator(
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
                    // Item count: 1 (Sentiment Widget) + Posts (ya 1 empty message)
                    itemCount: 1 + (_communityPosts.isEmpty ? 1 : _communityPosts.length),
                    itemBuilder: (context, index) {
                      // ------------------------------------------------------
                      // 🎯 INDEX 0: TOP SENTIMENT POLL WIDGET
                      // ------------------------------------------------------
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: CommunitySentimentCard(targetPeriod: _currentPeriod),
                        );
                      }

                      // Agar posts empty hain toh Empty Placeholder Card dikhao
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

                      // ------------------------------------------------------
                      // 📊 INDEX 1+: COMMUNITY TRADER POSTS
                      // ------------------------------------------------------
                      final post = _communityPosts[index - 1];
                      return TraderFeedCard(
                        key: ValueKey(post['id']),
                        post: post,
                        onPostDeleted: _fetchCommunityPosts,
                      );
                    },
                  ),
      ),
    );
  }
}

// ============================================================================
// 🎯 REALTIME COMMUNITY SENTIMENT CARD COMPONENT
// ============================================================================
class CommunitySentimentCard extends StatefulWidget {
  final String targetPeriod;

  const CommunitySentimentCard({super.key, required this.targetPeriod});

  @override
  State<CommunitySentimentCard> createState() => _CommunitySentimentCardState();
}

class _CommunitySentimentCardState extends State<CommunitySentimentCard> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _myVote;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMyVote();
  }

  Future<void> _loadMyVote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('user_predictions')
          .select('prediction')
          .eq('user_id', user.id)
          .eq('target_month', widget.targetPeriod)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _myVote = res['prediction'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _castVote(String type) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0F1726),
          content: Text('Please login or create handle to vote!', style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      await _supabase.from('user_predictions').upsert({
        'user_id': user.id,
        'target_month': widget.targetPeriod,
        'prediction': type,
      });

      if (mounted) {
        setState(() {
          _myVote = type;
          _isSubmitting = false;
        });
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('sentiment_stats')
            .stream(primaryKey: ['target_month'])
            .eq('target_month', widget.targetPeriod),
        builder: (context, snapshot) {
          final data = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;

          final totalVotes = data?['total_votes'] ?? 0;
          final bullPct = (data?['bullish_pct'] ?? 50.0).toDouble();
          final bearPct = (data?['bearish_pct'] ?? 50.0).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'MARKET SENTIMENT (${widget.targetPeriod})',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$totalVotes votes',
                    style: const TextStyle(color: Color(0xFF8896AB), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ratio Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: totalVotes == 0 ? 50 : bullPct.round().clamp(1, 99),
                        child: Container(color: const Color(0xFF00C076)),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: totalVotes == 0 ? 50 : bearPct.round().clamp(1, 99),
                        child: Container(color: const Color(0xFFFF2A6D)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Percentage Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bullish: ${totalVotes == 0 ? "50%" : "${bullPct.toStringAsFixed(1)}%"}',
                    style: const TextStyle(color: Color(0xFF00C076), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                  Text(
                    'Bearish: ${totalVotes == 0 ? "50%" : "${bearPct.toStringAsFixed(1)}%"}',
                    style: const TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Voting Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildVoteBtn(
                      label: 'BULLISH',
                      type: 'BULLISH',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF00C076),
                      isSelected: _myVote == 'BULLISH',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildVoteBtn(
                      label: 'BEARISH',
                      type: 'BEARISH',
                      icon: Icons.trending_down_rounded,
                      color: const Color(0xFFFF2A6D),
                      isSelected: _myVote == 'BEARISH',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
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
      onTap: _isSubmitting ? null : () => _castVote(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF1E2B3E),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isSelected ? color : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white70,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
