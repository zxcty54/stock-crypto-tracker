import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TraderFeedCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onPostDeleted;

  const TraderFeedCard({
    super.key,
    required this.post,
    required this.onPostDeleted,
  });

  @override
  State<TraderFeedCard> createState() => _TraderFeedCardState();
}

class _TraderFeedCardState extends State<TraderFeedCard> {
  final supabase = Supabase.instance.client;
  late int _agreeCount;
  late int _disagreeCount;
  String? _myVote;

  @override
  void initState() {
    super.initState();
    _agreeCount = widget.post['agree_count'] ?? 0;
    _disagreeCount = widget.post['disagree_count'] ?? 0;
    _checkMyVote();
  }

  Future<void> _checkMyVote() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final vote = await supabase
        .from('post_votes')
        .select('vote_type')
        .eq('post_id', widget.post['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    if (vote != null && mounted) {
      setState(() => _myVote = vote['vote_type']);
    }
  }

  Future<void> _castVote(String type) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    HapticFeedback.selectionClick();

    try {
      if (_myVote == type) {
        // Withdraw vote
        await supabase
            .from('post_votes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_id', user.id);
        setState(() {
          if (type == 'AGREE') _agreeCount = (_agreeCount - 1).clamp(0, 999999);
          if (type == 'DISAGREE') _disagreeCount = (_disagreeCount - 1).clamp(0, 999999);
          _myVote = null;
        });
      } else {
        // Insert or Upsert Vote
        await supabase.from('post_votes').upsert({
          'post_id': widget.post['id'],
          'user_id': user.id,
          'vote_type': type,
        });

        setState(() {
          if (_myVote == 'AGREE') _agreeCount = (_agreeCount - 1).clamp(0, 999999);
          if (_myVote == 'DISAGREE') _disagreeCount = (_disagreeCount - 1).clamp(0, 999999);

          if (type == 'AGREE') _agreeCount++;
          if (type == 'DISAGREE') _disagreeCount++;
          _myVote = type;
        });
      }
    } catch (_) {}
  }

  Future<void> _deletePost() async {
    try {
      await supabase.from('trader_posts').delete().eq('id', widget.post['id']);
      widget.onPostDeleted();
    } catch (_) {}
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) return 'Live';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    final bool isMyPost = currentUserId != null && currentUserId == widget.post['user_id'];
    final profile = widget.post['profiles'] as Map<String, dynamic>?;
    final String authorName = profile?['full_name'] ?? 'Anonymous Trader';

    final String bias = widget.post['bias'] ?? 'NEUTRAL';
    Color biasColor = const Color(0xFFFFD700);
    if (bias == 'BULLISH') biasColor = const Color(0xFF00F5A0);
    if (bias == 'BEARISH') biasColor = const Color(0xFFFF2A6D);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Post Header (User + Tags)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF1F2B3E),
                      child: Text(
                        authorName.isNotEmpty ? authorName[0].toUpperCase() : 'T',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatTimestamp(widget.post['created_at']),
                          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: biasColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: biasColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        bias,
                        style: TextStyle(color: biasColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (isMyPost) ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                        color: const Color(0xFF141C2B),
                        onSelected: (val) {
                          if (val == 'delete') _deletePost();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Setup', style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 2. Asset & Timeframe Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Text(
                  widget.post['asset_symbol'] ?? 'ASSET',
                  style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162032),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.post['timeframe'] ?? '5m',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 3. Analysis Reasoning
          if (widget.post['analysis_note'] != null && (widget.post['analysis_note'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(
                widget.post['analysis_note'],
                style: const TextStyle(color: Color(0xFFB0BDD0), fontSize: 11.5, height: 1.3),
              ),
            ),

          // 4. Chart Image
          ClipRRect(
            child: CachedNetworkImage(
              imageUrl: widget.post['chart_url'],
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(
                height: 220,
                color: const Color(0xFF141C2B),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))),
              ),
              errorWidget: (c, u, e) => Container(
                height: 220,
                color: const Color(0xFF141C2B),
                child: const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
              ),
            ),
          ),

          // 5. Action Meter (Agree vs Trap Alert)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _voteButton(
                      label: 'AGREE',
                      count: _agreeCount,
                      icon: Icons.thumb_up_alt_outlined,
                      isActive: _myVote == 'AGREE',
                      color: const Color(0xFF00F5A0),
                      onTap: () => _castVote('AGREE'),
                    ),
                    const SizedBox(width: 8),
                    _voteButton(
                      label: 'TRAP ALERT',
                      count: _disagreeCount,
                      icon: Icons.warning_amber_rounded,
                      isActive: _myVote == 'DISAGREE',
                      color: const Color(0xFFFF2A6D),
                      onTap: () => _castVote('DISAGREE'),
                    ),
                  ],
                ),
                Text(
                  'Sentiment: ${(_agreeCount + _disagreeCount) == 0 ? 50 : ((_agreeCount / (_agreeCount + _disagreeCount)) * 100).toInt()}% Bullish',
                  style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voteButton({
    required String label,
    required int count,
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.18) : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? color : const Color(0xFF25334A)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: isActive ? color : Colors.white54),
            const SizedBox(width: 5),
            Text(
              '$label ($count)',
              style: TextStyle(
                color: isActive ? color : Colors.white60,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
