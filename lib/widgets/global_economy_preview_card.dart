import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/global_economy_radar_screen.dart';

class GlobalEconomyPreviewCard extends StatefulWidget {
  const GlobalEconomyPreviewCard({super.key});

  @override
  State<GlobalEconomyPreviewCard> createState() =>
      _GlobalEconomyPreviewCardState();
}

class _GlobalEconomyPreviewCardState extends State<GlobalEconomyPreviewCard> {
  String _usText = "US: +2.8% Tech";
  String _euText = "EU: 46.0 Slump";
  String _emText = "EM: +7.2% Peak";

  @override
  void initState() {
    super.initState();
    _loadPreviewStats();
  }

  Future<void> _loadPreviewStats() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/data/global_economy_radar.json');
      final data = jsonDecode(jsonStr);
      final hud = data['executive_hud'] as Map<String, dynamic>?;
      if (hud != null) {
        final pillars = (hud['core_pillars'] as List<dynamic>? ?? []);
        if (mounted && pillars.length >= 5) {
          setState(() {
            _usText = "US: 54.9 PMI";
            _euText = "EU: 46.0 Slump";
            _emText = "Asia: 58.6 Peak";
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GlobalEconomyRadarScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF131B2A), Color(0xFF0F1726)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.35),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.public_rounded,
                            color: Color(0xFF00E5FF),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "GLOBAL ECONOMY RADAR",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF88)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "WORLD MACRO",
                                    style: TextStyle(
                                      color: Color(0xFF00FF88),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              "Where Pressure is Building vs Where Growth is Expanding",
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF00E5FF),
                      size: 13,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3 Highlights Chips Row (Dynamic)
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatChip(
                        "US EXPANSION",
                        _usText,
                        const Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMiniStatChip(
                        "EUROPE SLUMP",
                        _euText,
                        const Color(0xFFFF2A6D),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMiniStatChip(
                        "ASIA CHINA+1",
                        _emText,
                        const Color(0xFF00FF88),
                      ),
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

  Widget _buildMiniStatChip(String tag, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
