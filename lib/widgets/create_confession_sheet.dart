import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateConfessionSheet extends StatefulWidget {
  final VoidCallback onConfessionPosted;

  const CreateConfessionSheet({
    super.key,
    required this.onConfessionPosted,
  });

  @override
  State<CreateConfessionSheet> createState() => _CreateConfessionSheetState();
}

class _CreateConfessionSheetState extends State<CreateConfessionSheet> {
  final _confessionController = TextEditingController();
  final _assetController = TextEditingController(text: 'NIFTY');
  
  String _selectedTag = 'REVENGE TRADE';
  bool _isAnonymous = true;
  bool _isPosting = false;
  int _wordCount = 0;
  static const int _maxWords = 700;

  final List<Map<String, dynamic>> _tags = [
    {'label': 'REVENGE TRADE', 'color': Color(0xFFFF2A6D)},
    {'label': 'MISSED ENTRY', 'color': Color(0xFFFFB703)},
    {'label': 'EARLY EXIT', 'color': Color(0xFF00E5FF)},
    {'label': 'OVERTRADING', 'color': Color(0xFFB388FF)},
  ];

  @override
  void initState() {
    super.initState();
    _confessionController.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _confessionController.removeListener(_updateWordCount);
    _confessionController.dispose();
    _assetController.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _confessionController.text.trim();
    final count = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    if (_wordCount != count) {
      setState(() => _wordCount = count);
    }
  }

  Future<void> _submitConfession() async {
    final text = _confessionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya apna confession likhein.')),
      );
      return;
    }

    if (_wordCount > _maxWords) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Limit exceeded! Max $_maxWords words allow hain. (Abhi: $_wordCount words)'),
          backgroundColor: const Color(0xFFFF2A6D),
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle log in karein.')),
      );
      return;
    }

    setState(() => _isPosting = true);
    HapticFeedback.mediumImpact();

    try {
      await supabase.from('trader_posts').insert({
        'user_id': user.id,
        'chart_url': null,
        'asset_symbol': _assetController.text.trim().toUpperCase(),
        'timeframe': '1D',
        'bias': 'NEUTRAL',
        'analysis_note': text,
        'regret_tag': _selectedTag,
        'is_anonymous': _isAnonymous,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onConfessionPosted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confession posted anonymously to the wire.'),
            backgroundColor: Color(0xFF131B2A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOverLimit = _wordCount > _maxWords;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: Color(0xFF1E2B3E), width: 1.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRADER CONFESSION DESK',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFF2A6D),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Text-only confession • Max 700 words',
                    style: TextStyle(color: Colors.white38, fontSize: 10.5),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tag Selection Ribbon
          const Text(
            'SELECT MISTAKE CATEGORY',
            style: TextStyle(color: Color(0xFF6B7A99), fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final tag = _tags[i];
                final isSelected = _selectedTag == tag['label'];
                final Color col = tag['color'];

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTag = tag['label']);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? col.withOpacity(0.2) : const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? col : const Color(0xFF1E2B3E),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text(
                      tag['label'],
                      style: GoogleFonts.robotoMono(
                        color: isSelected ? col : Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Ticker Symbol Field
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag_rounded, color: Color(0xFF00E5FF), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _assetController,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'SYMBOL (e.g. NIFTY, BANKNIFTY)',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Text Confession Field with Red Alert on Overlimit
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131B2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOverLimit ? const Color(0xFFFF2A6D) : const Color(0xFF1E2B3E),
                width: isOverLimit ? 1.4 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _confessionController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  decoration: const InputDecoration(
                    hintText: 'Kya hua tha aaj? (e.g. Subah 8k profit tha, lalach me 3 trade aur liye aur 14k loss me book kiya...)',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 11.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 10, 8),
                  child: Text(
                    '$_wordCount / $_maxWords words',
                    style: GoogleFonts.robotoMono(
                      color: isOverLimit ? const Color(0xFFFF2A6D) : const Color(0xFF6B7A99),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Anonymous Post Toggle Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security_rounded, color: Color(0xFF00E5FF), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'POST AS ANONYMOUS TRADER',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Switch(
                  value: _isAnonymous,
                  activeColor: const Color(0xFF00E5FF),
                  onChanged: (val) => setState(() => _isAnonymous = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Submit CTA Button (Disabled if empty or over limit)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: (_isPosting || isOverLimit || _wordCount == 0) ? null : _submitConfession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2A6D),
                disabledBackgroundColor: const Color(0xFFFF2A6D).withOpacity(0.25),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isPosting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isOverLimit ? 'WORD LIMIT EXCEEDED' : 'CONFESS TO WIRE',
                      style: GoogleFonts.plusJakartaSans(
                        color: isOverLimit ? Colors.white38 : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
