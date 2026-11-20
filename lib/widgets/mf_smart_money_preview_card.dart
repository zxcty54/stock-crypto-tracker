import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/mf_smart_money_screen.dart';

class MfSmartMoneyPreviewCard extends StatefulWidget {
  const MfSmartMoneyPreviewCard({super.key});

  @override
  State<MfSmartMoneyPreviewCard> createState() => _MfSmartMoneyPreviewCardState();
}

class _MfSmartMoneyPreviewCardState extends State<MfSmartMoneyPreviewCard> {
  String _freshBuyText = "KAYNES / CDSL";
  String _accText = "TRENT (+36%)";
  String _rotationText = "Large Cap (+1.8%)";
  String _regimeBadge = "QUALITY ROTATION";

  @override
  void initState() {
    super.initState();
    _loadPreviewStats();
  }

  Future<void> _loadPreviewStats() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/mf_smart_money_radar.json');
      final data = jsonDecode(jsonStr);
      final rotation = data['market_cap_rotation'] as Map<String, dynamic>?;
      final infiltrations =
          data['smart_money_infiltrations'] as List<dynamic>?;

      if (mounted) {
        setState(() {
          if (infiltrations != null && infiltrations.isNotEmpty) {
            final freshBuys = infiltrations
                .where((i) => i['action_type'] == 'FRESH_ENTRY')
                .toList();
            if (freshBuys.isNotEmpty) {
              final symbols = freshBuys
                  .take(2)
                  .map((i) => i['symbol'].toString())
                  .join(' / ');
              _freshBuyText = symbols;
            }

            final accum = infiltrations
                .where((i) => i['action_type'] == 'AGGRESSIVE_ACCUMULATION')
                .toList();
            if (accum.isNotEmpty) {
              final topAcc = accum.first;
              final pct =
                  (topAcc['avg_holding_increase_pct'] as num?)?.toInt() ?? 0;
              _accText = "${topAcc['symbol']} (+$pct%)";
            }
          }

          if (rotation != null) {
            final tiers = rotation['tiers'] as List<dynamic>?;
            if (tiers != null && tiers.isNotEmpty) {
              final large = tiers.first;
              final mom = (large['mom_change_pct'] as num?)?.toDouble() ?? 0.0;
              _rotationText = "Large Cap (${mom >= 0 ? '+' : ''}${mom.toStringAsFixed(1)}%)";
            }
            if (rotation['regime'] == 'FLIGHT_TO_QUALITY') {
              _regimeBadge = "QUALITY ROTATION";
            }
          }
        });
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
                builder: (_) => const MfSmartMoneyScreen(),
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
                            Icons.radar_rounded,
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
                                  "MF SMART MONEY RADAR",
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
                                    "TOP 20 DIIs",
                                    style: TextStyle(
                                      color: Color(0xFF00FF88),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _regimeBadge,
                                    style: const TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              "Money Flow, Infiltrations, Exits & Overlap Audit",
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
                        "FRESH BUY",
                        _freshBuyText,
                        const Color(0xFF00FF88),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMiniStatChip(
                        "ACCUMULATION",
                        _accText,
                        const Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMiniStatChip(
                        "ROTATION",
                        _rotationText,
                        const Color(0xFFFFB703),
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
