import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class StrategyReplayHeroCard extends StatefulWidget {
  final VoidCallback onLaunch;

  const StrategyReplayHeroCard({
    super.key,
    required this.onLaunch,
  });

  @override
  State<StrategyReplayHeroCard> createState() => _StrategyReplayHeroCardState();
}

class _StrategyReplayHeroCardState extends State<StrategyReplayHeroCard> {
  int _revealedBars = 14;
  final int _maxTotalBars = 22;
  bool _isAutoPlaying = true;
  int _selectedSpeedMultiplier = 1; // 1x, 3x, 5x
  Timer? _tickerTimer;

  // Realistic historical sample mini candles: [O, H, L, C]
  final List<List<double>> _sampleCandles = const [
    [100, 106, 99, 105],
    [105, 109, 103, 104],
    [104, 112, 102, 110],
    [110, 113, 107, 108],
    [108, 115, 106, 114],
    [114, 118, 111, 112],
    [112, 116, 109, 115],
    [115, 122, 114, 121],
    [121, 124, 118, 119],
    [119, 126, 117, 125],
    [125, 130, 122, 128],
    [128, 131, 124, 126],
    [126, 134, 125, 133],
    [133, 137, 130, 135],
    // Hidden futuristic forward-bars
    [135, 142, 133, 140],
    [140, 144, 137, 138],
    [138, 145, 136, 143],
    [143, 150, 141, 148],
    [148, 152, 144, 146],
    [146, 155, 145, 153],
    [153, 158, 150, 156],
    [156, 162, 154, 160],
  ];

  @override
  void initState() {
    super.initState();
    _startPreviewLoop();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _startPreviewLoop() {
    _tickerTimer?.cancel();
    final delay = (900 / _selectedSpeedMultiplier).round();
    _tickerTimer = Timer.periodic(Duration(milliseconds: delay), (_) {
      if (!_isAutoPlaying) return;
      setState(() {
        if (_revealedBars < _maxTotalBars) {
          _revealedBars++;
        } else {
          _revealedBars = 8; // Reset back to simulate blind restart
        }
      });
    });
  }

  void _stepOneBar() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAutoPlaying = false;
      if (_revealedBars < _maxTotalBars) {
        _revealedBars++;
      } else {
        _revealedBars = 8;
      }
    });
  }

  void _togglePlayPause() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
    });
    if (_isAutoPlaying) _startPreviewLoop();
  }

  void _cycleSpeed() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedSpeedMultiplier == 1) {
        _selectedSpeedMultiplier = 3;
      } else if (_selectedSpeedMultiplier == 3) {
        _selectedSpeedMultiplier = 5;
      } else {
        _selectedSpeedMultiplier = 1;
      }
    });
    if (_isAutoPlaying) _startPreviewLoop();
  }

  void _resetScrubber() {
    HapticFeedback.lightImpact();
    setState(() {
      _revealedBars = 8;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        // Deep Obsidian gradient with glowing Cyber-Cyan accent border
        gradient: const RadialGradient(
          center: Alignment(-0.6, -0.8),
          radius: 1.4,
          colors: [
            Color(0xFF162544), // Highlighted deep teal-blue glow
            Color(0xFF0C1424),
            Color(0xFF070B13),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.55),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.20),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.70),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF00E5FF),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00F5A0),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00F5A0),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          "HERO RADAR • 10-YR NSE ARCHIVE",
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF00E5FF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reset scrubber button
                  InkWell(
                    onTap: _resetScrubber,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF233550)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white70, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            "RESET",
                            style: GoogleFonts.robotoMono(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title and Subtitle
              Text(
                "Bar-by-Bar Strategy Replay",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Future bars remain completely hidden. Step forward candle-by-candle and prove your risk-reward with zero foresight bias.",
                style: TextStyle(
                  color: Color(0xFFA5B4CB),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 14),

              // Interactive Candle Scrubber Stage With 0% Bias Barrier
              Container(
                height: 105,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF070C15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1F2F47), width: 1.1),
                ),
                child: CustomPaint(
                  painter: _ScrubberPreviewPainter(
                    candles: _sampleCandles,
                    revealedCount: _revealedBars,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // In-Card Mini Playback Control Deck
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Play/Pause Toggle
                      InkWell(
                        onTap: _togglePlayPause,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isAutoPlaying
                                ? const Color(0xFF00E5FF).withOpacity(0.2)
                                : const Color(0xFF142136),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isAutoPlaying ? const Color(0xFF00E5FF) : const Color(0xFF253956),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isAutoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: _isAutoPlaying ? const Color(0xFF00E5FF) : Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isAutoPlaying ? "AUTOPLAY" : "PAUSED",
                                style: GoogleFonts.robotoMono(
                                  color: _isAutoPlaying ? const Color(0xFF00E5FF) : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Step Forward Bar
                      InkWell(
                        onTap: _stepOneBar,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF142136),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF253956)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.skip_next_rounded, color: Color(0xFF00F5A0), size: 15),
                              const SizedBox(width: 3),
                              Text(
                                "STEP +1",
                                style: GoogleFonts.robotoMono(
                                  color: const Color(0xFF00F5A0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Speed Switcher
                      InkWell(
                        onTap: _cycleSpeed,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF142136),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.5)),
                          ),
                          child: Text(
                            "${_selectedSpeedMultiplier}X",
                            style: GoogleFonts.robotoMono(
                              color: const Color(0xFFFFB703),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Candle Counter
                  Text(
                    "BAR $_revealedBars / $_maxTotalBars",
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF6B7F9E),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // High-Energy Primary Launch Button
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF00F5A0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    widget.onLaunch();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.candlestick_chart_rounded, color: Color(0xFF070B13), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "LAUNCH FULL REPLAY TERMINAL",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF070B13),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: Color(0xFF070B13), size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for Visual Scrubber and Blind Forward Barrier
class _ScrubberPreviewPainter extends CustomPainter {
  final List<List<double>> candles;
  final int revealedCount;

  _ScrubberPreviewPainter({
    required this.candles,
    required this.revealedCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double candleWidth = size.width / candles.length;
    final bullColor = const Color(0xFF00F5A0);
    final bearColor = const Color(0xFFFF2A6D);

    double minVal = 99999;
    double maxVal = -99999;
    for (var c in candles) {
      minVal = min(minVal, c[2]);
      maxVal = max(maxVal, c[1]);
    }
    final range = maxVal - minVal;

    // 1. Draw Revealed Candles
    for (int i = 0; i < revealedCount && i < candles.length; i++) {
      final c = candles[i];
      final isBull = c[3] >= c[0];
      final color = isBull ? bullColor : bearColor;

      final x = (i * candleWidth) + (candleWidth / 2);
      final highY = size.height - ((c[1] - minVal) / range) * (size.height - 18) - 6;
      final lowY = size.height - ((c[2] - minVal) / range) * (size.height - 18) - 6;
      final openY = size.height - ((c[0] - minVal) / range) * (size.height - 18) - 6;
      final closeY = size.height - ((c[3] - minVal) / range) * (size.height - 18) - 6;

      // Wick
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        Paint()
          ..color = color
          ..strokeWidth = 1.2,
      );

      // Body
      final top = min(openY, closeY);
      final height = max((openY - closeY).abs(), 2.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - (candleWidth * 0.32), top, candleWidth * 0.64, height),
          const Radius.circular(1.5),
        ),
        Paint()..color = color,
      );
    }

    // 2. Cut-Off Vertical Wall (The Blind Threshold)
    final double barrierX = (revealedCount * candleWidth).clamp(0.0, size.width);

    final barrierPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.6;

    // Dotted barrier line
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(barrierX, startY),
        Offset(barrierX, min(startY + 5, size.height)),
        barrierPaint,
      );
      startY += 8;
    }

    // 3. Shaded "Hidden Future" Area (Right of barrier)
    if (barrierX < size.width) {
      final hiddenRect = Rect.fromLTRB(barrierX, 0, size.width, size.height);
      canvas.drawRect(
        hiddenRect,
        Paint()..color = const Color(0xFF050912).withOpacity(0.85),
      );

      // "0% BIAS" Watermark Badge over hidden area
      final textPainter = TextPainter(
        text: TextSpan(
          text: "FUTURE HIDDEN\n[ 0% BIAS ]",
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF4C617F),
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            height: 1.3,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final textX = barrierX + ((size.width - barrierX - textPainter.width) / 2);
      final textY = (size.height - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(max(textX, barrierX + 6), textY));
    }
  }

  @override
  bool shouldRepaint(covariant _ScrubberPreviewPainter oldDelegate) {
    return oldDelegate.revealedCount != revealedCount;
  }
}
