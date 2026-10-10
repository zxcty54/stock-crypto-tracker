import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class NewsCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onTap;

  const NewsCard({
    super.key,
    required this.item,
    this.onTap,
  });

  // Automated Sentiment Detection (Headline/Body keywords based)
  Map<String, dynamic> _detectSentiment(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('surge') ||
        lower.contains('rally') ||
        lower.contains('jump') ||
        lower.contains('gain') ||
        lower.contains('high') ||
        lower.contains('profit') ||
        lower.contains('bull') ||
        lower.contains('breakout')) {
      return {
        'label': 'BULLISH',
        'color': const Color(0xFF00F5A0),
        'icon': Icons.trending_up_rounded,
      };
    } else if (lower.contains('fall') ||
        lower.contains('drop') ||
        lower.contains('loss') ||
        lower.contains('plunge') ||
        lower.contains('down') ||
        lower.contains('bear') ||
        lower.contains('crack') ||
        lower.contains('tumble')) {
      return {
        'label': 'BEARISH',
        'color': const Color(0xFFFF2A6D),
        'icon': Icons.trending_down_rounded,
      };
    }
    return {
      'label': 'NEUTRAL',
      'color': const Color(0xFF00E5FF),
      'icon': Icons.remove_rounded,
    };
  }

  void _showNewsDetailsModal(BuildContext context, String source, String title,
      String body, String time, Map<String, dynamic> sentiment) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2B3E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    source.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (sentiment['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sentiment['label'],
                    style: TextStyle(
                      color: sentiment['color'],
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Text(time, style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            const Divider(color: Color(0xFF1E2B3E), height: 24),
            Text(
              body.isNotEmpty ? body : 'No detailed summary provided for this market flash.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Color(0xFF00E5FF), size: 16),
                  label: const Text('Close Wire', style: TextStyle(color: Color(0xFF00E5FF))),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String source = (item is Map ? item['source'] : null) ?? 'Market Wire';
    final String title = (item is Map ? item['title'] : null) ?? 'Market Update Headline';
    final String body = (item is Map ? (item['body'] ?? item['summary']) : null) ?? '';
    final String time = (item is Map ? item['time'] : null) ?? 'Live';

    final sentiment = _detectSentiment('$title $body');
    final Color sentimentColor = sentiment['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2B3E), width: 1.1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () => _showNewsDetailsModal(context, source, title, body, time, sentiment),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Source Tag + Sentiment Indicator + Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162032),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF223048)),
                      ),
                      child: Text(
                        source.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Dynamic Sentiment Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sentimentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sentiment['icon'] as IconData, size: 11, color: sentimentColor),
                          const SizedBox(width: 3),
                          Text(
                            sentiment['label'],
                            style: TextStyle(
                              fontSize: 8.5,
                              color: sentimentColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: time.toLowerCase().contains('live') || time.toLowerCase().contains('just')
                                ? const Color(0xFF00F5A0)
                                : const Color(0xFF6B7A99),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Color(0xFF6B7A99),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 2. Headline
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),

                // 3. Body / Summary Snippet
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF8896AB),
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // 4. Bottom Footer Action (Tap hint)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tap to expand full flash',
                      style: TextStyle(color: Colors.white24, fontSize: 9),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
