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
  int _commentCount = 0;

  late String _analysisNote;
  late String _assetSymbol;
  late String _bias;

  @override
  void initState() {
    super.initState();
    _agreeCount = widget.post['agree_count'] ?? 0;
    _disagreeCount = widget.post['disagree_count'] ?? 0;
    _analysisNote = widget.post['analysis_note'] ?? '';
    _assetSymbol = widget.post['asset_symbol'] ?? 'ASSET';
    _bias = widget.post['bias'] ?? 'NEUTRAL';
    _checkMyVote();
    _fetchCommentCount();
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

  Future<void> _fetchCommentCount() async {
    try {
      final res = await supabase
          .from('post_comments')
          .select('id')
          .eq('post_id', widget.post['id']);
      if (mounted) {
        setState(() => _commentCount = (res as List).length);
      }
    } catch (_) {}
  }

  Future<void> _castVote(String type) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    HapticFeedback.selectionClick();

    try {
      if (_myVote == type) {
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

  // ✏️ Edit Post Note & Bias
  Future<void> _editPost() async {
    final noteCtrl = TextEditingController(text: _analysisNote);
    String editBias = _bias;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F1726),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E2B3E)),
          ),
          title: Text(
            'EDIT SETUP',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Update analysis...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF141C2B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Market Bias', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 6),
              Row(
                children: ['BULLISH', 'BEARISH', 'NEUTRAL'].map((b) {
                  final isSel = editBias == b;
                  Color col = b == 'BULLISH'
                      ? const Color(0xFF00F5A0)
                      : (b == 'BEARISH' ? const Color(0xFFFF2A6D) : const Color(0xFFFFD700));
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => setDlgState(() => editBias = b),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? col.withOpacity(0.2) : const Color(0xFF141C2B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSel ? col : const Color(0xFF1E2B3E)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            b,
                            style: TextStyle(
                              color: isSel ? col : Colors.white54,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      try {
        await supabase.from('trader_posts').update({
          'analysis_note': noteCtrl.text.trim(),
          'bias': editBias,
        }).eq('id', widget.post['id']);

        setState(() {
          _analysisNote = noteCtrl.text.trim();
          _bias = editBias;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setup updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePost() async {
    try {
      await supabase.from('trader_posts').delete().eq('id', widget.post['id']);
      widget.onPostDeleted();
    } catch (_) {}
  }

  Future<void> _reportPost() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle trader handle banayein.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1726),
        title: const Text('REPORT SETUP?', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        content: const Text(
          '10 alag traders dwara report karne par yeh post automatically delete ho jayegi.',
          style: TextStyle(color: Color(0xFF8896AB), fontSize: 11),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A6D)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('post_reports').insert({
        'post_id': widget.post['id'],
        'reporter_id': user.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted.')),
        );
      }
      widget.onPostDeleted();
    } on PostgrestException catch (e) {
      if (mounted) {
        final msg = e.code == '23505' ? 'Aap pehle hi report kar chuke hain.' : 'Error: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  // 💬 Comments & Replies Modal Sheet
  void _openCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF1E2B3E)),
      ),
      builder: (ctx) => _CommentSectionSheet(
        postId: widget.post['id'],
        onCommentCountChanged: (count) {
          setState(() => _commentCount = count);
        },
      ),
    );
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) return 'now';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    final bool isMyPost = currentUserId != null && currentUserId == widget.post['user_id'];
    final profile = widget.post['profiles'] as Map<String, dynamic>?;
    final String authorName = profile?['full_name'] ?? 'Trader';
    final String username = profile?['username'] ?? 'trader';

    Color biasColor = const Color(0xFFFFD700);
    if (_bias == 'BULLISH') biasColor = const Color(0xFF00F5A0);
    if (_bias == 'BEARISH') biasColor = const Color(0xFFFF2A6D);

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1A2333), width: 0.8), // 👈 Patla Twitter divider
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Left: Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1E2B3E),
            child: Text(
              authorName.isNotEmpty ? authorName[0].toUpperCase() : 'T',
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Right: Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Name + Handle + Time + Bias + 3-Dot)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '@$username · ${_formatTimestamp(widget.post['created_at'])}',
                      style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 11),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: biasColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _bias,
                        style: TextStyle(color: biasColor, fontSize: 8.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // 3-Dots Menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
                      padding: EdgeInsets.zero,
                      color: const Color(0xFF141C2B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF1E2B3E)),
                      ),
                      onSelected: (val) {
                        if (val == 'edit') _editPost();
                        if (val == 'delete') _deletePost();
                        if (val == 'report') _reportPost();
                      },
                      itemBuilder: (ctx) => [
                        if (isMyPost) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            height: 34,
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: Color(0xFF00E5FF), size: 15),
                                SizedBox(width: 8),
                                Text('Edit Setup', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            height: 34,
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Color(0xFFFF2A6D), size: 15),
                                SizedBox(width: 8),
                                Text('Delete Setup', style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 12)),
                              ],
                            ),
                          ),
                        ] else
                          const PopupMenuItem(
                            value: 'report',
                            height: 34,
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, color: Color(0xFFFF2A6D), size: 15),
                                SizedBox(width: 8),
                                Text('Report Setup', style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Asset Symbol & Timeframe badge
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '#$_assetSymbol',
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF00E5FF),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141C2B),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          widget.post['timeframe'] ?? '5m',
                          style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Analysis Note
                if (_analysisNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _analysisNote,
                      style: const TextStyle(color: Color(0xFFD6E0EE), fontSize: 12.5, height: 1.35),
                    ),
                  ),

                // Chart Image
                if (widget.post['chart_url'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1E2B3E)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: widget.post['chart_url'],
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(
                            height: 180,
                            color: const Color(0xFF141C2B),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))),
                          ),
                          errorWidget: (c, u, e) => Container(
                            height: 140,
                            color: const Color(0xFF141C2B),
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Twitter Style Bottom Actions (Comments, Agree, Trap Alert)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Comment button
                    InkWell(
                      onTap: _openCommentsSheet,
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF8896AB)),
                          const SizedBox(width: 4),
                          Text(
                            '$_commentCount',
                            style: const TextStyle(color: Color(0xFF8896AB), fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // Agree (Upvote)
                    InkWell(
                      onTap: () => _castVote('AGREE'),
                      child: Row(
                        children: [
                          Icon(
                            _myVote == 'AGREE' ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                            size: 15,
                            color: _myVote == 'AGREE' ? const Color(0xFF00F5A0) : const Color(0xFF8896AB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_agreeCount',
                            style: TextStyle(
                              color: _myVote == 'AGREE' ? const Color(0xFF00F5A0) : const Color(0xFF8896AB),
                              fontSize: 11,
                              fontWeight: _myVote == 'AGREE' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Trap Alert (Disagree)
                    InkWell(
                      onTap: () => _castVote('DISAGREE'),
                      child: Row(
                        children: [
                          Icon(
                            _myVote == 'DISAGREE' ? Icons.warning_rounded : Icons.warning_amber_rounded,
                            size: 16,
                            color: _myVote == 'DISAGREE' ? const Color(0xFFFF2A6D) : const Color(0xFF8896AB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_disagreeCount',
                            style: TextStyle(
                              color: _myVote == 'DISAGREE' ? const Color(0xFFFF2A6D) : const Color(0xFF8896AB),
                              fontSize: 11,
                              fontWeight: _myVote == 'DISAGREE' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sentiment %
                    Text(
                      '${(_agreeCount + _disagreeCount) == 0 ? 50 : ((_agreeCount / (_agreeCount + _disagreeCount)) * 100).toInt()}% Bull',
                      style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 9.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 💬 Comment & Threaded Reply Bottom Sheet
// =========================================================
class _CommentSectionSheet extends StatefulWidget {
  final String postId;
  final ValueChanged<int> onCommentCountChanged;

  const _CommentSectionSheet({
    required this.postId,
    required this.onCommentCountChanged,
  });

  @override
  State<_CommentSectionSheet> createState() => _CommentSectionSheetState();
}

class _CommentSectionSheetState extends State<_CommentSectionSheet> {
  final supabase = Supabase.instance.client;
  final TextEditingController _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final res = await supabase
          .from('post_comments')
          .select('*, profiles(username, full_name)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
        widget.onCommentCountChanged(_comments.length);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle trader profile setup karein.')),
      );
      return;
    }

    try {
      await supabase.from('post_comments').insert({
        'post_id': widget.postId,
        'user_id': user.id,
        'content': text,
        'parent_id': _replyingTo?['id'], // If reply, pass parent ID
      });

      _commentCtrl.clear();
      setState(() => _replyingTo = null);
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate parent comments and replies
    final parentComments = _comments.where((c) => c['parent_id'] == null).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Sheet Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E2B3E))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REPLIES (${_comments.length})',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Comments List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2))
                  : parentComments.isEmpty
                      ? const Center(
                          child: Text('No replies yet. Be the first to comment.',
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: parentComments.length,
                          itemBuilder: (ctx, idx) {
                            final comment = parentComments[idx];
                            final replies = _comments.where((c) => c['parent_id'] == comment['id']).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCommentRow(comment),
                                // Nested replies indented
                                if (replies.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: Column(
                                      children: replies.map((r) => _buildCommentRow(r, isReply: true)).toList(),
                                    ),
                                  ),
                                const Divider(color: Color(0xFF162032), height: 16),
                              ],
                            );
                          },
                        ),
            ),

            // Reply Banner (if replying to someone)
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: const Color(0xFF141C2B),
                child: Row(
                  children: [
                    Text(
                      'Replying to @${_replyingTo?['profiles']?['username'] ?? 'trader'}',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() => _replyingTo = null),
                      child: const Icon(Icons.close, size: 14, color: Colors.white54),
                    ),
                  ],
                ),
              ),

            // Bottom Input Field
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1726),
                border: Border(top: BorderSide(color: Color(0xFF1E2B3E))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null ? 'Tweet your reply...' : 'Add a comment...',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF141C2B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF00E5FF)),
                    onPressed: _sendComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentRow(Map<String, dynamic> c, {bool isReply = false}) {
    final prof = c['profiles'] as Map<String, dynamic>?;
    final name = prof?['full_name'] ?? 'Trader';
    final user = prof?['username'] ?? 'trader';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 11 : 14,
            backgroundColor: const Color(0xFF1E2B3E),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'T',
              style: TextStyle(color: const Color(0xFF00E5FF), fontSize: isReply ? 9 : 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text('@$user', style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(c['content'] ?? '', style: const TextStyle(color: Color(0xFFD6E0EE), fontSize: 12, height: 1.25)),
                const SizedBox(height: 4),
                if (!isReply)
                  InkWell(
                    onTap: () => setState(() => _replyingTo = c),
                    child: const Text('Reply', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
