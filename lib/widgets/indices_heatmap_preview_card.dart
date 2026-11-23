import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../screens/market_indices_heatmap_screen.dart';

class IndicesHeatmapPreviewCard extends StatefulWidget {
  const IndicesHeatmapPreviewCard({super.key});

  @override
  State<IndicesHeatmapPreviewCard> createState() => _IndicesHeatmapPreviewCardState();
}

class _IndicesHeatmapPreviewCardState extends State<IndicesHeatmapPreviewCard> {
  List<Map<String, dynamic>> _topGainers = [];
  List<Map<String, dynamic>> _topLosers = [];
  bool _isLoaded = false;

  final String _sheetApiUrl =
      "https://stock-models-api.nitesh-skyhigh.workers.dev/?type=sheet2";

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  Future<void> _loadSample() async {
    List<Map<String, dynamic>> sectors = [];
    try {
      final jsonStr = await rootBundle.loadString('assets/data/indices_heatmap.json');
      final data = jsonDecode(jsonStr);

      sectors = List<Map<String, dynamic>>.from(data['sectoral_indices'] ?? []);

      _updateGainersLosers(sectors);
    } catch (_) {}

    // Immediately fetch live delta from Google Sheet
    _fetchLiveSheet(sectors);
  }

  void _updateGainersLosers(List<Map<String, dynamic>> sectors) {
    sectors.sort((a, b) {
      final ca = (a['change_pct'] as num?)?.toDouble() ?? 0.0;
      final cb = (b['change_pct'] as num?)?.toDouble() ?? 0.0;
      return cb.compareTo(ca);
    });

    if (mounted) {
      setState(() {
        _topGainers = sectors.take(3).toList();
        _topLosers = sectors.reversed.take(3).toList();
        _isLoaded = true;
      });
    }
  }

  Future<void> _fetchLiveSheet(List<Map<String, dynamic>> sectors) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await http.get(
        Uri.parse("$_sheetApiUrl&_t=$timestamp"),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        Map<String, dynamic> remote = {};

        if (decoded is List) {
          for (var r in decoded) {
            if (r is Map) {
              final k = r['Index'] ?? r['name'] ?? r['Symbol'] ?? r['Sector'] ?? '';
              if (k.toString().isNotEmpty) remote[k.toString()] = r;
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            remote = Map<String, dynamic>.from(decoded['data']);
          } else if (decoded.containsKey('data') && decoded['data'] is List) {
            for (var r in (decoded['data'] as List)) {
              if (r is Map) {
                final k = r['Index'] ?? r['name'] ?? r['Symbol'] ?? r['Sector'] ?? '';
                if (k.toString().isNotEmpty) remote[k.toString()] = r;
              }
            }
          } else {
            remote = decoded;
          }
        }

        if (remote.isNotEmpty) {
          final normMap = <String, dynamic>{};
          remote.forEach((k, v) {
            final ck = k.toString().toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
            if (ck.isNotEmpty) normMap[ck] = v;
          });

          for (var s in sectors) {
            final nk = (s['name'] ?? '').toString().toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
            final sk = (s['symbol'] ?? '').toString().toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');

            dynamic match = normMap[nk] ?? normMap[sk];
            if (match == null) {
              for (var entry in normMap.entries) {
                if (nk.contains(entry.key) || entry.key.contains(nk)) {
                  match = entry.value;
                  break;
                }
              }
            }

            if (match != null) {
              if (match is Map) {
                final c = match['change'] ?? match['change_pct'] ?? match['Change'] ?? match['pChange'] ?? match['chg'];
                if (c != null) {
                  final str = c.toString().replaceAll('%', '').replaceAll('+', '').trim();
                  final d = double.tryParse(str);
                  if (d != null) s['change_pct'] = d;
                }
              } else if (match is num) {
                s['change_pct'] = match.toDouble();
              }
            }
          }

          _updateGainersLosers(sectors);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MarketIndicesHeatmapScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: Color(0xFF00E5FF),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "NSE INDICES HEATMAP",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                              "23 Sectoral + 21 Broad Market Matrix",
                              style: TextStyle(
                                color: Color(0xFF6B7A99),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFF00FF88), size: 12),
                          SizedBox(width: 2),
                          Text(
                            "LIVE",
                            style: TextStyle(
                              color: Color(0xFF00FF88),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Top movers mini treemap ribbon
                if (_isLoaded) ...[
                  Row(
                    children: [
                      // Top Gainer chip
                      if (_topGainers.isNotEmpty)
                        Expanded(
                          child: _buildMiniHeatChip(_topGainers.first, isUp: true),
                        ),
                      const SizedBox(width: 6),
                      // Runner-up gainer
                      if (_topGainers.length > 1)
                        Expanded(
                          child: _buildMiniHeatChip(_topGainers[1], isUp: true),
                        ),
                      const SizedBox(width: 6),
                      // Top Loser chip
                      if (_topLosers.isNotEmpty)
                        Expanded(
                          child: _buildMiniHeatChip(_topLosers.first, isUp: false),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Action Footer Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Color-graded treemap with CMP & ranges",
                      style: GoogleFonts.robotoMono(
                        color: Colors.white38,
                        fontSize: 9.5,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "EXPLORE 44 INDICES",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF00E5FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF00E5FF),
                          size: 13,
                        ),
                      ],
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

  Widget _buildMiniHeatChip(Map<String, dynamic> item, {required bool isUp}) {
    final name = (item['name'] ?? '').toString().replaceAll('NIFTY ', '');
    final double changePct = (item['change_pct'] as num?)?.toDouble() ?? 0.0;
    final Color color = isUp ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%",
            style: GoogleFonts.robotoMono(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
