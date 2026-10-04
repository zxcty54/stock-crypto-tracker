import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StrategyReplayHeroCard extends StatelessWidget {
  final VoidCallback onLaunch;

  const StrategyReplayHeroCard({
    super.key,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1B2E),
            Color(0xFF080D17),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Aesthetic Grid & Mini Candlestick Graphic
          Positioned(
            right: -10,
            bottom: -5,
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                size: const Size(160, 110),
                painter: _DecorativeCandlePainter(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00F5A0),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "HISTORICAL SIMULATOR",
                            style: GoogleFonts.robotoMono(
                              color: const Color(0xFF00E5FF),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "NSE 10-YR ARCHIVE",
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Main Headline
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bar-by-Bar Replay Engine",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Real market 10-Year historical data par apni trading edge test karein. Drag-and-drop SL & Target ke sath realistic forward backtesting.",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Feature Highlights Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pill("🎯 Visual SL/TP"),
                    _pill("📊 20-EMA Volume"),
                    _pill("⚡ Up to 3x Speed"),
                    _pill("📝 Audit Journal"),
                  ],
                ),

                const SizedBox(height: 16),

                // Primary Eye-Catching CTA
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF070B13),
                      elevation: 4,
                      shadowColor: const Color(0xFF00E5FF).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onLaunch,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_fill_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "START REPLAY BACKTEST",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF131F33),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF223554), width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Background Candlestick Shape Painter for Institutional Aesthetics
class _DecorativeCandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;

    final List<Map<String, double>> candles = [
      {'x': 15, 'top': 40, 'bot': 80, 'high': 20, 'low': 95},
      {'x': 45, 'top': 30, 'bot': 65, 'high': 15, 'low': 80},
      {'x': 75, 'top': 55, 'bot': 90, 'high': 40, 'low': 105},
      {'x': 105, 'top': 20, 'bot': 55, 'high': 10, 'low': 70},
      {'x': 135, 'top': 15, 'bot': 40, 'high': 5, 'low': 60},
    ];

    for (var c in candles) {
      canvas.drawLine(Offset(c['x']!, c['high']!), Offset(c['x']!, c['low']!), paint);
      canvas.drawRect(
        Rect.fromLTRB(c['x']! - 8, c['top']!, c['x']! + 8, c['bot']!),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
