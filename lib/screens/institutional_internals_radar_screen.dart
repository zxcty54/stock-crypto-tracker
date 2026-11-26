import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'company_intelligence_screen.dart';
import 'stock_delivery_history_screen.dart';
import 'global_economy_radar_screen.dart';
import 'sector_sources_directory_screen.dart';

class InstitutionalInternalsRadarScreen extends StatefulWidget {
  const InstitutionalInternalsRadarScreen({super.key});

  @override
  State<InstitutionalInternalsRadarScreen> createState() =>
      _InstitutionalInternalsRadarScreenState();
}

class _InstitutionalInternalsRadarScreenState
    extends State<InstitutionalInternalsRadarScreen> {
  static const Color kBgDark = Color(0xFF090D16);
  static const Color kCardDark = Color(0xFF131B2A);
  static const Color kBorderSubtle = Color(0xFF1E2B3E);
  static const Color kAccentCyan = Color(0xFF00E5FF);
  static const Color kAccentGreen = Color(0xFF00FF88);
  static const Color kAccentAmber = Color(0xFFFFB703);
  static const Color kAccentRed = Color(0xFFFF2A6D);
  static const Color kTextMuted = Color(0xFF8896AB);

  static const List<String> dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/arena/4bcd1358-stock-crypto-tracker/assets/data/global_economy_radar.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/arena/4bcd1358-stock-crypto-tracker/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@arena/4bcd1358-stock-crypto-tracker/assets/data/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@arena/4bcd1358-stock-crypto-tracker/global_economy_radar.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/assets/data/global_economy_radar.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/global_economy_radar.json',
    'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/global_economy_radar.json',
  ];

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isGuideExpanded = false;
  Map<String, dynamic> _fiiDiiFlows = {};
  Map<String, dynamic> _fiiDiiDerivatives = {};
  Map<String, dynamic> _marketInternals = {};
  Map<String, dynamic> _promoterRadar = {};
  Map<String, dynamic> _bulkBlockDeals = {};

  DateTime? _parseFlexibleDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final clean = dateStr.trim().replaceAll('-', ' ');
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final day = int.tryParse(parts[0]);
      final year = int.tryParse(parts[2]);
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      final mKey = parts[1].toLowerCase();
      final month = months[mKey.length >= 3 ? mKey.substring(0, 3) : mKey];
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(dateStr);
  }

  bool _isStaleDowngrade(String? incomingDateStr, String? currentDateStr) {
    if (incomingDateStr == null || currentDateStr == null) return false;
    final inDate = _parseFlexibleDate(incomingDateStr);
    final curDate = _parseFlexibleDate(currentDateStr);
    if (inDate != null && curDate != null) {
      return inDate.isBefore(curDate);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadDataset();
  }

  void _populateData(Map<String, dynamic> data) {
    _fiiDiiFlows = Map<String, dynamic>.from(data['fii_dii_flows'] ?? {});
    _fiiDiiDerivatives =
        Map<String, dynamic>.from(data['fii_dii_derivatives'] ?? {});
    _marketInternals =
        Map<String, dynamic>.from(data['market_internals'] ?? {});
    _promoterRadar =
        Map<String, dynamic>.from(data['promoter_insider_radar'] ?? {});
    _bulkBlockDeals =
        Map<String, dynamic>.from(data['smart_bulk_block_deals'] ?? {});
  }

  Future<void> _loadDataset({bool isRefresh = false}) async {
    if (isRefresh) {
      HapticFeedback.lightImpact();
      setState(() => _isSyncing = true);
    }

    // Only load bundled asset on cold boot if memory state is empty
    if (!isRefresh && _fiiDiiFlows.isEmpty) {
      try {
        final localJson = await rootBundle
            .loadString('assets/data/global_economy_radar.json');
        final dynamic parsed = jsonDecode(localJson);
        if (parsed is Map<String, dynamic> &&
            (parsed['fii_dii_flows'] != null || parsed['market_internals'] != null)) {
          if (mounted) {
            setState(() {
              _populateData(parsed);
              _isLoading = false;
            });
          }
        }
      } catch (_) {}
    }

    for (final url in dataUrls) {
      try {
        final uri = Uri.parse("$url?t=${DateTime.now().millisecondsSinceEpoch}");
        final response = await http.get(
          uri,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final dynamic parsed = jsonDecode(utf8.decode(response.bodyBytes));
          if (parsed is Map<String, dynamic>) {
            final incomingDeriv = parsed['fii_dii_derivatives'] as Map<String, dynamic>? ?? {};
            final incomingFlows = parsed['fii_dii_flows'] as Map<String, dynamic>? ?? {};
            final String? incomingDateStr = incomingDeriv['trade_date'] ?? incomingFlows['trade_date'];
            final String? currentDateStr = _fiiDiiDerivatives['trade_date'] ?? _fiiDiiFlows['trade_date'];

            // Prevent stale cache or older remote branch from downgrading newer data
            if (_isStaleDowngrade(incomingDateStr, currentDateStr)) {
              continue;
            }

            if (mounted) {
              setState(() {
                _populateData(parsed);
                _isSyncing = false;
                _isLoading = false;
              });

              if (isRefresh) {
                final date = _fiiDiiDerivatives['trade_date'] ??
                    _fiiDiiFlows['trade_date'] ??
                    'Latest';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Institutional Telemetry Synced ($date)'),
                    backgroundColor: const Color(0xFF00C853),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
            return;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "INSTITUTIONAL & RISK RADAR",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: kAccentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                  ),
                  child: const Text(
                    "DII / FII / VIX",
                    style: TextStyle(
                      color: kAccentGreen,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Flexible(
                  child: Text(
                    "Participant OI • India VIX • Breadth",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kTextMuted, fontSize: 8.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_rounded,
                color: kAccentAmber, size: 20),
            tooltip: "47 Sector Sources & Telemetry Hub",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SectorSourcesDirectoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.public_rounded,
                color: kAccentCyan, size: 20),
            tooltip: "Switch to Global Economy Radar",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalEconomyRadarScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded,
                color: Colors.white70, size: 20),
            tooltip: "Kaise Use Karein? (Smart Money User Guide)",
            onPressed: () => _showInstitutionalHelpModal(context),
          ),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kAccentCyan,
                    ),
                  )
                : const Icon(Icons.sync_rounded,
                    color: kAccentCyan, size: 20),
            tooltip: "Live Sync from Exchange Feed",
            onPressed: () => _loadDataset(isRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: kAccentCyan,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              color: kAccentCyan,
              backgroundColor: kCardDark,
              onRefresh: () => _loadDataset(isRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  _buildExecutiveHeader(),
                  const SizedBox(height: 12),
                  if (_fiiDiiFlows.isNotEmpty) ...[
                    _buildFiiDiiDivergenceCard(),
                    const SizedBox(height: 12),
                  ],
                  if (_marketInternals.isNotEmpty) ...[
                    _buildMarketInternalsCard(),
                    const SizedBox(height: 12),
                  ],
                  if (_promoterRadar.isNotEmpty || _bulkBlockDeals.isNotEmpty) ...[
                    _buildPromoterAndBulkDealsCard(),
                    const SizedBox(height: 12),
                  ],
                  _buildStatutoryNotice(),
                ],
              ),
            ),
    );
  }

  Widget _buildExecutiveHeader() {
    final double fiiNet =
        (_fiiDiiFlows['fii_net_crores'] as num?)?.toDouble() ?? -2450.0;
    final double diiNet =
        (_fiiDiiFlows['dii_net_crores'] as num?)?.toDouble() ?? 3180.0;
    final double netPulse = diiNet + fiiNet;
    final double vix =
        (_marketInternals['india_vix'] as num?)?.toDouble() ?? 12.8;
    final String regime =
        _marketInternals['vix_regime'] ?? 'LOW VOLATILITY';
    final double breadthPct =
        (_marketInternals['advance_decline_ratio_pct'] as num?)?.toDouble() ??
            62.4;

    final bool isDiiAbsorbing = diiNet >= fiiNet.abs();
    final bool isNetPositive = netPulse >= 0;
    final Color verdictColor = isDiiAbsorbing ? kAccentGreen : (isNetPositive ? kAccentCyan : kAccentRed);

    final String verdictHeadline = isDiiAbsorbing
        ? "🟢 NET DOMESTIC ABSORPTION (BULLISH ACCUMULATION)"
        : (isNetPositive
            ? "🟢 NET INSTITUTIONAL INFLOW (POSITIVE BIAS)"
            : "🔴 NET INSTITUTIONAL OUTFLOW (DEFENSIVE RISK)");

    final String plainConclusion;
    if (fiiNet > 0 && diiNet > 0) {
      plainConclusion = "FIIs (+₹${fiiNet.toStringAsFixed(0)} Cr) aur DIIs (+₹${diiNet.toStringAsFixed(0)} Cr) dono taraf se dual buying active hai. Broad liquidity trend strong bullish bana hua hai. 🎯 Action: Market leaders ke saath rally ride karein.";
    } else if (fiiNet > 0 && diiNet <= 0) {
      plainConclusion = "Foreign institutions ne ₹${fiiNet.toStringAsFixed(0)} Cr ki aggressive net buying ki hai, jo DII profit booking (-₹${diiNet.abs().toStringAsFixed(0)} Cr) se zyada hai. Institutional pulse net positive (+₹${netPulse.toStringAsFixed(0)} Cr) hai. 🎯 Action: Quality breakout stocks me buy on dips.";
    } else if (fiiNet <= 0 && diiNet > 0) {
      plainConclusion = isDiiAbsorbing
          ? "Domestic Institutions (DIIs ₹${diiNet.toStringAsFixed(0)} Cr) ne Foreign selling (₹${fiiNet.abs().toStringAsFixed(0)} Cr) ko poori tarah absorb kiya hai. Market internals strong hain. 🎯 Action: SIP cushion safe hai; dip par panic sell na karein, quality portfolio hold rakhein."
          : "Foreign selling (₹${fiiNet.abs().toStringAsFixed(0)} Cr) domestic buying se zyada hai. Cautious risk regime active hai. 🎯 Action: Fresh aggressive long trades hold karein.";
    } else {
      plainConclusion = "FIIs aur DIIs dono taraf se net selling chal rahi hai. Defensive risk regime active hai. 🎯 Action: Defensive bane rahein aur cash reserve badhayein.";
    }

    // Visual chart factor calculations
    final double totalAbsoluteFlow = (diiNet.abs() + fiiNet.abs()).clamp(1.0, 50000.0);
    final double diiSharePct = ((diiNet.abs() / totalAbsoluteFlow) * 100).clamp(10.0, 90.0);
    final double fiiSharePct = 100.0 - diiSharePct;

    // VIX position (scale 10 to 30)
    final double vixPosition = ((vix - 10.0) / 20.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131B2A), Color(0xFF0F1726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: verdictColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: verdictColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded, color: kAccentCyan, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "EXECUTIVE VERDICT & CORE TAKEAWAY",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: verdictColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: verdictColor.withOpacity(0.35)),
                ),
                child: Text(
                  "LIVE VERDICT",
                  style: GoogleFonts.robotoMono(
                    color: verdictColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big Verdict Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: verdictColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdictHeadline,
                  style: GoogleFonts.plusJakartaSans(
                    color: verdictColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "Combined Net Flow: ",
                      style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                    ),
                    Text(
                      "${netPulse >= 0 ? '+' : ''}₹${netPulse.toStringAsFixed(0)} Cr",
                      style: GoogleFonts.robotoMono(
                        color: netPulse >= 0 ? kAccentGreen : kAccentRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plainConclusion,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 📊 VISUAL CHARTS SECTION
          Text(
            "VISUAL FLOWS & RISK METERS",
            style: GoogleFonts.plusJakartaSans(
              color: kAccentCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          // Chart 1: FII vs DII Battle Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A101D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "DII Absorption: ₹${diiNet.toStringAsFixed(0)} Cr (${diiSharePct.toStringAsFixed(0)}%)",
                      style: const TextStyle(color: kAccentGreen, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "FII Selling: ₹${fiiNet.abs().toStringAsFixed(0)} Cr (${fiiSharePct.toStringAsFixed(0)}%)",
                      style: const TextStyle(color: kAccentRed, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: diiSharePct.toInt(),
                        child: Container(
                          height: 8,
                          color: kAccentGreen,
                        ),
                      ),
                      Container(width: 2, height: 8, color: Colors.white70),
                      Expanded(
                        flex: fiiSharePct.toInt(),
                        child: Container(
                          height: 8,
                          color: kAccentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Chart 2: India VIX Volatility Spectrum Meter
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A101D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2B3E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "India VIX Risk Gauge",
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (vix <= 15 ? kAccentGreen : (vix <= 22 ? kAccentAmber : kAccentRed)).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "VIX: ${vix.toStringAsFixed(1)} ($regime)",
                        style: TextStyle(
                          color: vix <= 15 ? kAccentGreen : (vix <= 22 ? kAccentAmber : kAccentRed),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 35,
                        child: Container(
                          height: 8,
                          color: kAccentGreen,
                          alignment: Alignment.center,
                        ),
                      ),
                      Container(width: 1, height: 8, color: Colors.black),
                      Expanded(
                        flex: 35,
                        child: Container(
                          height: 8,
                          color: kAccentAmber,
                        ),
                      ),
                      Container(width: 1, height: 8, color: Colors.black),
                      Expanded(
                        flex: 30,
                        child: Container(
                          height: 8,
                          color: kAccentRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("🟢 Calm (<14)", style: TextStyle(color: kAccentGreen, fontSize: 8.5)),
                    Text("🟡 Normal (14-19)", style: TextStyle(color: kAccentAmber, fontSize: 8.5)),
                    Text("🔴 High Risk (>19)", style: TextStyle(color: kAccentRed, fontSize: 8.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2x2 Metric Grid (Clean and spacious, no overflow)
          Row(
            children: [
              Expanded(
                child: _buildMetricGridCard(
                  "FII Net Cash",
                  "${fiiNet >= 0 ? '+' : ''}₹${fiiNet.toStringAsFixed(0)} Cr",
                  fiiNet >= 0 ? "Net Buying" : "Distribution",
                  fiiNet >= 0 ? kAccentGreen : kAccentRed,
                  Icons.public_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricGridCard(
                  "DII Net Cash",
                  "${diiNet >= 0 ? '+' : ''}₹${diiNet.toStringAsFixed(0)} Cr",
                  diiNet >= 0 ? "Absorption" : "Selling",
                  diiNet >= 0 ? kAccentGreen : kAccentRed,
                  Icons.account_balance_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricGridCard(
                  "India VIX Meter",
                  vix.toStringAsFixed(1),
                  regime,
                  vix <= 15 ? kAccentGreen : (vix <= 22 ? kAccentAmber : kAccentRed),
                  Icons.speed_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricGridCard(
                  "Market Breadth",
                  "${breadthPct.toStringAsFixed(0)}% Adv",
                  breadthPct >= 50 ? "Broad Participation" : "Selective Churn",
                  breadthPct >= 50 ? kAccentGreen : kAccentAmber,
                  Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGridCard(
      String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.robotoMono(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatutoryNotice() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, color: kAccentCyan, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "SEBI Statutory Notice: Institutional participant-wise derivatives, advance-decline breadth, promoter pledging, and bulk deals synthesized directly from official NSE/BSE exchange disclosures. Strictly educational market telemetry; does not constitute investment advice or buy/sell recommendations.",
              style: TextStyle(color: Colors.white60, fontSize: 8.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiiDiiDivergenceCard() {
    final double fiiNet = (_fiiDiiFlows['fii_net_crores'] as num?)?.toDouble() ?? -2450.0;
    final double diiNet = (_fiiDiiFlows['dii_net_crores'] as num?)?.toDouble() ?? 3180.0;
    final double netPulse = (_fiiDiiFlows['net_pulse_crores'] as num?)?.toDouble() ?? 730.0;
    final double absorption = (_fiiDiiFlows['absorption_ratio'] as num?)?.toDouble() ?? 1.3;
    final String verdict = _fiiDiiFlows['regime_verdict'] ?? 'DII Absorption Moat';
    final String tradeDate = _fiiDiiDerivatives['trade_date'] ??
        _fiiDiiFlows['trade_date'] ??
        'Market Close';

    final bool isNetPositive = netPulse >= 0;
    final Color netColor = isNetPositive ? kAccentGreen : kAccentRed;

    final String shortVerdict;
    if (fiiNet > 0 && diiNet > 0) {
      shortVerdict = "Dual Inflow";
    } else if (fiiNet > 0 && diiNet <= 0) {
      shortVerdict = "FII Buying";
    } else if (fiiNet <= 0 && diiNet > 0) {
      shortVerdict = "DII Absorption";
    } else {
      shortVerdict = "Dual Outflow";
    }

    final double fiiFactor = (fiiNet.abs() / 5000.0).clamp(0.12, 1.0);
    final double diiFactor = (diiNet.abs() / 5000.0).clamp(0.12, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: kAccentCyan, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        "INSTITUTIONAL CASH (FII vs DII)",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        tradeDate,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: netColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: netColor.withOpacity(0.35)),
                ),
                child: Text(
                  shortVerdict,
                  style: TextStyle(
                    color: netColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: () => _showInstitutionalHelpModal(context),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAccentCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kAccentCyan.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.help_outline_rounded, color: kAccentCyan, size: 9),
                      SizedBox(width: 3),
                      Text(
                        "Kaise Samjhein?",
                        style: TextStyle(
                          color: kAccentCyan,
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Numbers Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("FOREIGN (FII)",
                      style: TextStyle(color: kAccentRed, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  Text(
                    "${fiiNet > 0 ? '+' : ''}₹${fiiNet.toStringAsFixed(0)} Cr",
                    style: GoogleFonts.robotoMono(
                      color: fiiNet >= 0 ? kAccentGreen : kAccentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: netColor.withOpacity(0.35)),
                ),
                child: Column(
                  children: [
                    const Text("NET PULSE",
                        style: TextStyle(color: Colors.white38, fontSize: 7.5, fontWeight: FontWeight.bold)),
                    Text(
                      "${netPulse > 0 ? '+' : ''}₹${netPulse.toStringAsFixed(0)} Cr",
                      style: GoogleFonts.robotoMono(
                        color: netColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("DOMESTIC (DII)",
                      style: TextStyle(color: kAccentGreen, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  Text(
                    "${diiNet > 0 ? '+' : ''}₹${diiNet.toStringAsFixed(0)} Cr",
                    style: GoogleFonts.robotoMono(
                      color: diiNet >= 0 ? kAccentGreen : kAccentRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visual Divergence Gauge Bar
          Row(
            children: [
              // FII Bar (Left, Red)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: ((1.0 - fiiFactor) * 100).toInt(),
                      child: Container(height: 5, color: const Color(0xFF131B2A)),
                    ),
                    Expanded(
                      flex: (fiiFactor * 100).toInt(),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: kAccentRed,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 10,
                color: Colors.white54,
              ),
              // DII Bar (Right, Green)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: (diiFactor * 100).toInt(),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: kAccentGreen,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: ((1.0 - diiFactor) * 100).toInt(),
                      child: Container(height: 5, color: const Color(0xFF131B2A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("OUTFLOW DABAO", style: TextStyle(color: Colors.white38, fontSize: 7.5)),
              Text("0 BASE", style: TextStyle(color: Colors.white38, fontSize: 7.5)),
              Text("SIP ABSORPTION", style: TextStyle(color: Colors.white38, fontSize: 7.5)),
            ],
          ),

          if (_fiiDiiDerivatives.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFF1E2B3E)),
            const SizedBox(height: 10),
            _buildDerivativesSentimentSection(),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFF1E2B3E)),
          const SizedBox(height: 10),
          _buildActionableTakeawayBox(
            fiiNet: fiiNet,
            diiNet: diiNet,
            netPulse: netPulse,
            fiiLongRatio: (_fiiDiiDerivatives['fii_long_ratio'] as num?)?.toDouble() ?? 21.4,
            fiiShortRatio: (_fiiDiiDerivatives['fii_short_ratio'] as num?)?.toDouble() ?? 78.6,
            clientLongRatio: (_fiiDiiDerivatives['client_long_ratio'] as num?)?.toDouble() ?? 67.2,
          ),
          const SizedBox(height: 10),
          _buildExpandableWidgetGuideSection(),
        ],
      ),
    );
  }

  Widget _buildDerivativesSentimentSection() {
    final double fiiLongRatio = (_fiiDiiDerivatives['fii_long_ratio'] as num?)?.toDouble() ?? 19.4;
    final double fiiShortRatio = (_fiiDiiDerivatives['fii_short_ratio'] as num?)?.toDouble() ?? 80.6;
    final int fiiLong = (_fiiDiiDerivatives['fii_index_long_contracts'] as num?)?.toInt() ?? 28500;
    final int fiiShort = (_fiiDiiDerivatives['fii_index_short_contracts'] as num?)?.toInt() ?? 118500;
    final int fiiNet = (_fiiDiiDerivatives['fii_net_contracts'] as num?)?.toInt() ?? -90000;
    final double clientLongRatio = (_fiiDiiDerivatives['client_long_ratio'] as num?)?.toDouble() ?? 66.2;
    final double diiLongRatio = (_fiiDiiDerivatives['dii_long_ratio'] as num?)?.toDouble() ?? 40.0;
    final String zoneLabel = _fiiDiiDerivatives['zone_label'] ?? 'Extreme Short Squeeze (< 20% Long)';

    final bool isExtremeSqueeze = fiiLongRatio < 20.0;
    final Color badgeColor = isExtremeSqueeze ? kAccentRed : (fiiLongRatio < 40.0 ? kAccentAmber : kAccentGreen);

    final String shortZoneLabel;
    if (fiiLongRatio < 20.0) {
      shortZoneLabel = "Short Squeeze (<20% L)";
    } else if (fiiLongRatio < 40.0) {
      shortZoneLabel = "Bearish Hedge (${fiiLongRatio.toStringAsFixed(0)}% L)";
    } else if (fiiLongRatio > 60.0) {
      shortZoneLabel = "Bullish (${fiiLongRatio.toStringAsFixed(0)}% L)";
    } else {
      shortZoneLabel = "Neutral (${fiiLongRatio.toStringAsFixed(0)}% L)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_rounded, color: kAccentCyan, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                "NSE INDEX FUTURES OI (NIFTY & BANKNIFTY)",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Text(
                shortZoneLabel,
                maxLines: 1,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Long vs Short Ratio Numbers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "LONG: ${(fiiLong / 1000).toStringAsFixed(1)}k (${fiiLongRatio.toStringAsFixed(1)}%)",
              style: GoogleFonts.robotoMono(
                color: kAccentGreen,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${fiiNet > 0 ? '+' : ''}${(fiiNet / 1000).toStringAsFixed(1)}k NET",
                style: GoogleFonts.robotoMono(
                  color: fiiNet >= 0 ? kAccentGreen : kAccentRed,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              "SHORT: ${(fiiShort / 1000).toStringAsFixed(1)}k (${fiiShortRatio.toStringAsFixed(1)}%)",
              style: GoogleFonts.robotoMono(
                color: kAccentRed,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Multi-segment Long vs Short Meter Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              Expanded(
                flex: (fiiLongRatio * 10).toInt().clamp(5, 950),
                child: Container(
                  height: 6,
                  color: kAccentGreen,
                ),
              ),
              Expanded(
                flex: (fiiShortRatio * 10).toInt().clamp(5, 950),
                child: Container(
                  height: 6,
                  color: kAccentRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Scale marker row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("0% LONG", style: TextStyle(color: Colors.white38, fontSize: 7)),
            Text("20% SQUEEZE LINE", style: TextStyle(color: kAccentAmber, fontSize: 7, fontWeight: FontWeight.bold)),
            Text("50% NEUTRAL", style: TextStyle(color: Colors.white38, fontSize: 7)),
            Text("100% SHORT", style: TextStyle(color: Colors.white38, fontSize: 7)),
          ],
        ),
        const SizedBox(height: 8),

        // Counterparty Contrast Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF090D16),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("RETAIL COUNTERPART: ", style: TextStyle(color: Colors.white54, fontSize: 8)),
                  Text(
                    "${clientLongRatio.toStringAsFixed(1)}% LONG",
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text("DII FUTURES: ", style: TextStyle(color: Colors.white54, fontSize: 8)),
                  Text(
                    "${diiLongRatio.toStringAsFixed(1)}% LONG",
                    style: GoogleFonts.robotoMono(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionableTakeawayBox({
    required double fiiNet,
    required double diiNet,
    required double netPulse,
    required double fiiLongRatio,
    required double fiiShortRatio,
    required double clientLongRatio,
  }) {
    final bool isSqueezeZone = fiiLongRatio < 22.0;
    final bool isHedgeZone = fiiLongRatio >= 22.0 && fiiLongRatio < 40.0;
    final bool isNeutralZone = fiiLongRatio >= 40.0 && fiiLongRatio <= 65.0;

    final String futuresTitle;
    final Color futuresColor;
    final String futuresTrapWarning;
    final String futuresActionAdvise;

    if (isSqueezeZone) {
      futuresTitle = "EXTREME SHORT SQUEEZE ZONE (${fiiLongRatio.toStringAsFixed(1)}% LONG / ${fiiShortRatio.toStringAsFixed(1)}% SHORT)";
      futuresColor = kAccentAmber;
      futuresTrapWarning = "Galti se bhi Put (PE) buy mat karo ya aggressive short mat karo. FIIs ke paas 78%+ short contracts hain, unki shorting limit exhaust ho chuki hai.";
      futuresActionAdvise = "Reversal / Short-Covering pump ke liye taiyar rahein. Positive news aate hi FIIs shorts kaatenge jisse index 300-500 pt tezi se bounce ho sakti hai. Dips par buying ke mauke dhundein.";
    } else if (isHedgeZone) {
      futuresTitle = "BEARISH HEDGING / CAUTIOUS ZONE (${fiiLongRatio.toStringAsFixed(1)}% LONG)";
      futuresColor = kAccentAmber;
      futuresTrapWarning = "Breakouts chase mat karo, breakouts aksar fail honge.";
      futuresActionAdvise = "Market choppy aur range-bound rahegi. Major support par buy aur resistance par profit book karein.";
    } else if (isNeutralZone) {
      futuresTitle = "BALANCED NEUTRAL ZONE (${fiiLongRatio.toStringAsFixed(1)}% LONG)";
      futuresColor = kAccentCyan;
      futuresTrapWarning = "Index sideways chop karega, blind index trading avoid karein.";
      futuresActionAdvise = "Stock-specific momentum chalega. Top sectors aur breakout stocks me swing trades ride karein.";
    } else {
      futuresTitle = "OVERBOUGHT / TOP CAUTION ZONE (${fiiLongRatio.toStringAsFixed(1)}% LONG)";
      futuresColor = kAccentRed;
      futuresTrapWarning = "Greed mein aakar top par naye breakouts buy na karein.";
      futuresActionAdvise = "FIIs heavily long hain, fresh buying room kam hai. Trailing stop-loss tight karein aur profits lock karna shuru karein.";
    }

    final bool isDiiAbsorbing = fiiNet < 0 && diiNet >= fiiNet.abs();
    final bool isDualInflow = fiiNet > 0 && diiNet > 0;
    final bool isDualOutflow = fiiNet < 0 && diiNet < 0;

    final String cashTitle;
    final Color cashColor;
    final String cashAdvice;

    if (isDiiAbsorbing) {
      cashTitle = "DII SIP ABSORPTION MOAT (NET +₹${(diiNet + fiiNet).toStringAsFixed(0)} CR)";
      cashColor = kAccentGreen;
      cashAdvice = "FIIs ne ₹${fiiNet.abs().toStringAsFixed(0)} Cr becha, par Bharat ke DIIs ne ₹${diiNet.toStringAsFixed(0)} Cr buy karke absorb kar liya. Market crash ka koi darr nahi hai, panic selling na karein.";
    } else if (isDualInflow) {
      cashTitle = "DUAL INSTITUTIONAL RALLY (FII + DII BUYING)";
      cashColor = kAccentGreen;
      cashAdvice = "FIIs aur DIIs dono heavy buyers hain! Market me strong tailwind hai, dips par market leaders ride karein.";
    } else if (isDualOutflow) {
      cashTitle = "DUAL OUTFLOW RISK ALERT (DEFENSIVE STANCE)";
      cashColor = kAccentRed;
      cashAdvice = "Dono institutions ne cash withdraw kiya hai. Fresh buying hold karein aur defensive cash reserve badhayein.";
    } else {
      cashTitle = "FII OUTFLOW DABAAV (NET -₹${(fiiNet.abs() - diiNet).toStringAsFixed(0)} CR)";
      cashColor = kAccentAmber;
      cashAdvice = "Foreign selling domestic buying se zyada hai. Index par temporary pressure reh sakta hai, stop-loss strict rakhein.";
    }

    final bool isRetailTrap = clientLongRatio >= 60.0 && fiiLongRatio < 35.0;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: futuresColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: futuresColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(Icons.tips_and_updates_rounded, color: futuresColor, size: 13),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🎯 IS DATA SE KYA SAMJHEIN? (AAPKA ASLI FAYDA)",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      "Smart Money positioning se trade & investment ka live decision",
                      style: TextStyle(color: kTextMuted, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTakeawayItem(
            badge: "1. FII FUTURES SIGNAL",
            title: futuresTitle,
            color: futuresColor,
            trapWarning: futuresTrapWarning,
            actionAdvice: futuresActionAdvise,
          ),
          const SizedBox(height: 8),
          _buildTakeawayItem(
            badge: "2. CASH MARKET BATTLE",
            title: cashTitle,
            color: cashColor,
            actionAdvice: cashAdvice,
          ),
          if (isRetailTrap) ...[
            const SizedBox(height: 8),
            _buildTakeawayItem(
              badge: "3. RETAIL TRAP ALERT",
              title: "CLIENTS ${clientLongRatio.toStringAsFixed(0)}% LONG vs FII ${fiiShortRatio.toStringAsFixed(0)}% SHORT",
              color: kAccentAmber,
              trapWarning: "Retail traders bullish (FOMO) hain jabki FIIs short baithe hain.",
              actionAdvice: "Smart money pehle retail stop-losses hunt karti hai, uske baad market reverse hoti hai. Bhedchaal me Call chase na karein.",
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTakeawayItem({
    required String badge,
    required String title,
    required Color color,
    String? trapWarning,
    required String actionAdvice,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (trapWarning != null) ...[
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🛑 ", style: TextStyle(fontSize: 9.5)),
                Expanded(
                  child: Text(
                    trapWarning,
                    style: const TextStyle(
                      color: Color(0xFFFFB4AB),
                      fontSize: 8.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🎯 ", style: TextStyle(fontSize: 9.5)),
              Expanded(
                child: Text(
                  actionAdvice,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableWidgetGuideSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccentCyan.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isGuideExpanded = !_isGuideExpanded;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: kAccentCyan, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "📘 WIDGET GUIDE: DATA SAMAJHNE KE 3 NIYAM",
                          style: GoogleFonts.plusJakartaSans(
                            color: kAccentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          "Roz subah 9:00 AM par 30 seconds me market tone pakadein",
                          style: TextStyle(color: kTextMuted, fontSize: 7.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isGuideExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kAccentCyan,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_isGuideExpanded) ...[
            Container(height: 1, color: const Color(0xFF1E2B3E)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRuleCard(
                    number: "NIYAM 1",
                    title: "FII Index Futures Long Ratio Formula",
                    description: "FIIs Dalal Street ke smart whales hain. Unka Long % market top aur bottom batata hai:",
                    bullets: [
                      "🟢 < 20% Long: Extreme Short Squeeze -> FIIs 80%+ short hain. Galti se bhi PE buy mat karo, achanak 300-500 pt rocket bounce aayega.",
                      "🟡 20% - 40% Long: Bearish Hedging -> Market choppy aur range-bound rahegi. Support par buy, resistance par sell.",
                      "⚪ 40% - 60% Long: Neutral Zone -> Balanced market. Index chop karega, stock-specific momentum chalega.",
                      "🔴 > 70% Long: Top Warning -> FIIs overbought hain. Breakout chase mat karo, trailing SL tight karo aur profits book karo.",
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRuleCard(
                    number: "NIYAM 2",
                    title: "Cash Flow Battle (FII vs DII SIP Moat)",
                    description: "Cash market batata hai ki system me asli paisa aa raha hai ya nikal raha hai:",
                    bullets: [
                      "🛡️ DII Inflow > FII Outflow: Bharat ke retail SIPs (₹25k Cr/mo) selling ko absorb kar rahe hain. Market crash ka darr nahi hai, dip par panic selling mat karo.",
                      "🚀 Dual Inflow (FII + DII Green): Heavy Bull Run. Bina dare high-beta index leaders ride karo.",
                      "🚨 Dual Outflow (FII + DII Red): Systemic Risk Alert. Cash badhao aur naye trades se bachein.",
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRuleCard(
                    number: "NIYAM 3",
                    title: "Roz Subah 9:00 AM ka 30-Second Routine",
                    description: "Market khulne se pehle bas ye 3 kadam dekhein:",
                    bullets: [
                      "Kadam 1: FII Futures Long % dekho (<20% hai toh Put mat lo, >70% hai toh Call mat chase karo).",
                      "Kadam 2: DII Net Cash dekho (DII buying positive hai toh dips me support milega).",
                      "Kadam 3: India VIX dekho (<14 market safe hai, >18 positions aadhi kar lo).",
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kAccentCyan.withOpacity(0.4)),
                        backgroundColor: kAccentCyan.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.school_rounded, color: kAccentCyan, size: 14),
                      label: const Text(
                        "Pura Masterclass Guide Padhein (Examples Ke Saath)",
                        style: TextStyle(
                          color: kAccentCyan,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _showInstitutionalHelpModal(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleCard({
    required String number,
    required String title,
    required String description,
    required List<String> bullets,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: kAccentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: kAccentCyan,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: kTextMuted, fontSize: 8),
          ),
          const SizedBox(height: 5),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  b,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    height: 1.3,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _showInstitutionalHelpModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kAccentCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: kAccentCyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "INSTITUTIONAL RADAR GUIDE",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          "FII/DII Futures & Cash Data se Trading Fayda Kaise Uthayein",
                          style: TextStyle(color: kTextMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildModalSection(
                title: "1. FIIs Kaun Hain aur Unka Data Kyun Dekhein?",
                content: "FIIs (Foreign Institutional Investors) Dalal Street ke sabse bade Smart Money / Whales hote hain jo hazaron karod se market ka direction tai karte hain. Jab FIIs index futures me heavy positions banate hain, toh market unke opposite nahi chal sakti.",
              ),
              const SizedBox(height: 12),
              _buildModalSection(
                title: "2. FII Index Futures Long Ratio: Master Cheat Sheet",
                content: "Ye indicator batata hai ki FIIs Nifty aur BankNifty futures me kitne % Bullish (Long) hain aur kitne % Bearish (Short) hain:\n\n• < 20% Long (Extreme Squeeze):\nFIIs ne 80%+ short contracts khol rakhe hain. Unki shorting limit khatam hai. Galti se bhi Put (PE) buy mat karo. Thodi si positive khabar aate hi market 300-500 point rocket ki tarah bounce karegi.\n\n• 20% - 40% Long (Bearish Hedging):\nFIIs cautious hain. Market choppy aur sideways rahegi. Breakouts aksar fail hote hain. Support par buy aur resistance par book karo.\n\n• 40% - 60% Long (Neutral):\nBalanced market. Index range me rahega, par quality stocks me strong run milega.\n\n• > 70% Long (Top Warning):\nFIIs overbought hain. Top par breakout chase na karein, stop-loss tight karein aur profit book karna shuru karein.",
              ),
              const SizedBox(height: 12),
              _buildModalSection(
                title: "3. Cash Market (FII vs DII Battle)",
                content: "Cash market liquidity ka balance dikhata hai:\n\n• Case 1: FII Selling vs DII Buying (Absorption):\nBharat ke retail SIPs (₹25,000+ Cr har mahine) DIIs ke zariye FIIs ki foreign selling ko absorb kar rahe hain. Iska matlab market crash nahi hogi, dip par panic selling na karein.\n\n• Case 2: Dual Buying (FII + DII Green):\nAggressive bull run. Market leaders (Reliance, HDFC Bank, ICICI Bank, TCS) ko bina dare ride karein.\n\n• Case 3: Dual Selling (FII + DII Red):\nSystem se liquidity nikal rahi hai. High alert! Cash hold karein aur naye trades se bachein.",
              ),
              const SizedBox(height: 12),
              _buildModalSection(
                title: "4. Retailers (Clients) vs FII Trap",
                content: "Jab retail traders (Clients) 65-70%+ Long hote hain aur FIIs 75-80% Short hote hain, toh ye sabse bada Retail Trap hota hai. Retailers ko lagta hai market upar jayegi, par FIIs pehle retail ke stop loss trigger karte hain. Isliye jab retail heavy long ho, tab FOMO se bachein.",
              ),
              const SizedBox(height: 12),
              _buildModalSection(
                title: "5. Roz Subah 9:00 AM ka 3-Step Routine",
                content: "1. FII Futures Long % check karo (<20% hai toh Put lene ki galti mat karo; >70% hai toh top pe Call buy mat karo).\n2. DII Net Absorption check karo (DII FII se zyada buy kar rahe hain toh portfolio safe hai).\n3. India VIX dekho (<14 calm, >18 positions half).",
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentCyan,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Samajh Gaya (Close)",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalSection({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: kAccentCyan,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketInternalsCard() {
    final int tot = (_marketInternals['total_stocks_screened'] as num?)?.toInt() ?? 1589;
    final int adv = (_marketInternals['advances_count'] as num?)?.toInt() ?? 545;
    final int dec = (_marketInternals['declines_count'] as num?)?.toInt() ?? 1040;
    final double breadthPct = (_marketInternals['breadth_thrust_pct'] as num?)?.toDouble() ?? 34.4;
    final double decPct = (100.0 - breadthPct).clamp(0.0, 100.0);

    final String regime = _marketInternals['market_regime'] ?? 'INDEX_CAMOUFLAGE';
    final String regimeTruth = _marketInternals['regime_truth'] ??
        'Heavyweights holding headline index while 65%+ broader stocks are in net decline.';

    final double vix = (_marketInternals['india_vix'] as num?)?.toDouble() ?? 13.4;
    final String vixLabel = _marketInternals['vix_label'] ?? 'Healthy Structural Trend (12.0 - 15.5)';

    final bool isCamouflage = regime == 'INDEX_CAMOUFLAGE';
    final bool isAccumulation = regime == 'BROAD_ACCUMULATION';
    final Color regimeColor = isCamouflage ? kAccentRed : (isAccumulation ? kAccentGreen : kAccentAmber);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: kAccentCyan, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "MARKET INTERNALS & CAMOUFLAGE RADAR",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: regimeColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: regimeColor.withOpacity(0.4)),
                ),
                child: Text(
                  isCamouflage ? "🚨 INDEX CAMOUFLAGE" : (isAccumulation ? "🟢 BROAD ACCUMULATION" : "BIFURCATED"),
                  style: TextStyle(
                    color: regimeColor,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Advance vs Decline Numbers Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ADV: $adv (${breadthPct.toStringAsFixed(1)}%)",
                style: GoogleFonts.robotoMono(
                  color: kAccentGreen,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  "$tot Audited",
                  style: const TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "DEC: $dec (${decPct.toStringAsFixed(1)}%)",
                style: GoogleFonts.robotoMono(
                  color: kAccentRed,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Visual Breadth Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Expanded(
                  flex: (breadthPct * 10).toInt().clamp(5, 950),
                  child: Container(height: 6, color: kAccentGreen),
                ),
                Expanded(
                  flex: (decPct * 10).toInt().clamp(5, 950),
                  child: Container(height: 6, color: kAccentRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("0% ADVANCES", style: TextStyle(color: Colors.white38, fontSize: 7)),
              Text("50% BREADTH PIVOT", style: TextStyle(color: Colors.white38, fontSize: 7)),
              Text("100% ADVANCES", style: TextStyle(color: Colors.white38, fontSize: 7)),
            ],
          ),
          const SizedBox(height: 6),

          // 1-line Camouflage Truth Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: regimeColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isCamouflage ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  color: regimeColor,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    regimeTruth,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 8.5, height: 1.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Divider
          Container(height: 1, color: const Color(0xFF1E2B3E)),
          const SizedBox(height: 8),

          // India VIX Barometer Section
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: kAccentAmber, size: 13),
              const SizedBox(width: 4),
              Text(
                "INDIA VIX: ${vix.toStringAsFixed(2)}",
                style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  vixLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kAccentCyan, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Multi-zone VIX meter
          Row(
            children: [
              Expanded(child: Container(height: 4, decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.6), borderRadius: const BorderRadius.horizontal(left: Radius.circular(2))))),
              const SizedBox(width: 2),
              Expanded(child: Container(height: 4, color: kAccentCyan.withOpacity(0.6))),
              const SizedBox(width: 2),
              Expanded(child: Container(height: 4, color: kAccentAmber.withOpacity(0.6))),
              const SizedBox(width: 2),
              Expanded(child: Container(height: 4, decoration: BoxDecoration(color: kAccentRed.withOpacity(0.6), borderRadius: const BorderRadius.horizontal(right: Radius.circular(2))))),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("< 12 COMPLACENCY", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
              Text("12-15.5 STEADY", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
              Text("15.5-21 EVENT", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
              Text("> 21 PANIC BOTTOM", style: TextStyle(color: Colors.white38, fontSize: 6.5)),
            ],
          ),
          const SizedBox(height: 8),

          // Bottom Action: Inspect Delivery vs Churn Traps
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showDeliveryVsChurnSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentCyan.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Inspect Top 6 Real Delivery Buys vs Operator Churn Traps",
                    style: TextStyle(
                      color: kAccentCyan,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kAccentCyan, size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeliveryVsChurnSheet(BuildContext context) {
    final List<dynamic> realBuys = (_marketInternals['top_delivery_accumulations'] as List<dynamic>? ?? []);
    final List<dynamic> churnTraps = (_marketInternals['top_churn_distribution_traps'] as List<dynamic>? ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: kAccentCyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "INSTITUTIONAL TRUTH: DELIVERY vs CHURN",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  "Separating genuine demat share lock-in from operator day-trading volume traps.",
                  style: TextStyle(color: kTextMuted, fontSize: 9),
                ),
                const SizedBox(height: 14),

                // SECTION 1: REAL DELIVERY ACCUMULATION
                Row(
                  children: const [
                    Icon(Icons.lock_rounded, color: kAccentGreen, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🟢 REAL INSTITUTIONAL DEMAT ACCUMULATION (> 95% DELIVERY)",
                      style: TextStyle(
                        color: kAccentGreen,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...realBuys.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final double chg = (st['change_pct'] as num?)?.toDouble() ?? 0.0;
                  final double deliv = (st['delivery_pct'] as num?)?.toDouble() ?? 0.0;
                  final int vol = (st['volume'] as num?)?.toInt() ?? 0;
                  final String volStr = vol > 1000000 ? "${(vol / 1000000).toStringAsFixed(1)}M" : "${(vol / 1000).toStringAsFixed(0)}k";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          sym,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${chg >= 0 ? '+' : ''}$chg%",
                          style: GoogleFonts.robotoMono(
                            color: chg >= 0 ? kAccentGreen : kAccentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${deliv.toStringAsFixed(1)}% Delivery ($volStr)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // SECTION 2: OPERATOR CHURN TRAPS
                Row(
                  children: const [
                    Icon(Icons.shuffle_rounded, color: kAccentRed, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🔴 OPERATOR CHURN TRAPS (< 15% DELIVERY, DAY-TRADING CHURN)",
                      style: TextStyle(
                        color: kAccentRed,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...churnTraps.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final double chg = (st['change_pct'] as num?)?.toDouble() ?? 0.0;
                  final double deliv = (st['delivery_pct'] as num?)?.toDouble() ?? 0.0;
                  final int vol = (st['volume'] as num?)?.toInt() ?? 0;
                  final String volStr = vol > 10000000 ? "${(vol / 10000000).toStringAsFixed(1)} Cr" : (vol > 100000 ? "${(vol / 100000).toStringAsFixed(1)}L" : "${(vol / 1000).toStringAsFixed(0)}k");

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          sym,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${chg >= 0 ? '+' : ''}$chg%",
                          style: GoogleFonts.robotoMono(
                            color: chg >= 0 ? kAccentGreen : kAccentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${deliv.toStringAsFixed(1)}% Delivery ($volStr Vol)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentRed,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kAccentCyan, size: 12),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SEBI Statutory Notice: Algorithmic delivery percentage scan from official NSE Bhavcopy. Strictly educational analysis; does not constitute investment advice or stock recommendations.",
                          style: TextStyle(color: Colors.white54, fontSize: 8, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPromoterAndBulkDealsCard() {
    final highPledgeList = (_promoterRadar['high_pledge_danger_zone'] as List<dynamic>? ?? []);
    final insiderBuys = (_promoterRadar['insider_promoter_accumulations'] as List<dynamic>? ?? []);
    final netAbsorptions = (_bulkBlockDeals['net_institutional_absorptions'] as List<dynamic>? ?? []);
    final churnTraps = (_bulkBlockDeals['filtered_operator_churn_traps'] as List<dynamic>? ?? []);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: kAccentCyan, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "PROMOTER PLEDGE & MARQUEE BULK DEALS",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: kAccentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kAccentCyan.withOpacity(0.4)),
                ),
                child: const Text(
                  "INSTITUTIONAL RADAR",
                  style: TextStyle(
                    color: kAccentCyan,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // PART 1: Promoter Pledge & Insider SAST Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PLEDGE RISK (> 25%): ${highPledgeList.length} STOCKS",
                style: GoogleFonts.robotoMono(
                  color: kAccentRed,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "SAST INSIDER BUYS: ${insiderBuys.length}",
                style: GoogleFonts.robotoMono(
                  color: kAccentGreen,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showPledgeAndInsiderSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentRed.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "⚡ Inspect Margin Call Danger Zone & Insider SAST Purchases",
                    style: TextStyle(
                      color: kAccentRed,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kAccentRed, size: 13),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Divider
          Container(height: 1, color: const Color(0xFF1E2B3E)),
          const SizedBox(height: 8),

          // PART 2: Smart Bulk & Block Deals (Operator Churn Filtered)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MARQUEE NET DEMAT (> ₹10 Cr): ${netAbsorptions.length}",
                style: GoogleFonts.robotoMono(
                  color: kAccentGreen,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "OPERATOR CHURN: ${churnTraps.length} TRAPS",
                style: GoogleFonts.robotoMono(
                  color: kAccentAmber,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showSmartBulkDealsSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccentGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "🏛️ Inspect Marquee Net Absorption vs Filtered Churn Traps",
                    style: TextStyle(
                      color: kAccentGreen,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: kAccentGreen, size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPledgeAndInsiderSheet(BuildContext context) {
    final highPledge = (_promoterRadar['high_pledge_danger_zone'] as List<dynamic>? ?? []);
    final insiderBuys = (_promoterRadar['insider_promoter_accumulations'] as List<dynamic>? ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: kAccentCyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "PROMOTER PLEDGING & INSIDER SAST RADAR",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  "Tracking high lender pledge risk and personal promoter open-market share accumulation.",
                  style: TextStyle(color: kTextMuted, fontSize: 9),
                ),
                const SizedBox(height: 14),

                // SECTION 1: MARGIN CALL DANGER ZONE
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: kAccentRed, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "⚠️ MARGIN CALL DANGER ZONE (> 25% PROMOTER PLEDGE)",
                      style: TextStyle(
                        color: kAccentRed,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...highPledge.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final comp = st['company'] ?? sym;
                  final double pledge = (st['pledged_pct'] as num?)?.toDouble() ?? 0.0;
                  final double promoter = (st['promoter_holding'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              comp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${pledge.toStringAsFixed(1)}% Pledged (${promoter.toStringAsFixed(1)}% Holding)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentRed,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompanyIntelligenceScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Model →",
                              style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // SECTION 2: INSIDER PROMOTER BUYS
                Row(
                  children: const [
                    Icon(Icons.trending_up_rounded, color: kAccentGreen, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🟢 INSIDER PROMOTER ACCUMULATION (SEBI SAST REG 29 OPEN MARKET)",
                      style: TextStyle(
                        color: kAccentGreen,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...insiderBuys.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final comp = st['company'] ?? sym;
                  final double stakeCr = (st['stake_acquired_cr'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              comp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "+₹${stakeCr.toStringAsFixed(1)} Cr Open-Market Buy",
                            style: GoogleFonts.robotoMono(
                              color: kAccentGreen,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompanyIntelligenceScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Model →",
                              style: TextStyle(color: kAccentGreen, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kAccentCyan, size: 12),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SEBI Statutory Notice: Pledged shareholding and SAST insider disclosures from official stock exchange filings. Strictly educational analysis; does not constitute investment advice.",
                          style: TextStyle(color: Colors.white54, fontSize: 8, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSmartBulkDealsSheet(BuildContext context) {
    final netAbsorptions = (_bulkBlockDeals['net_institutional_absorptions'] as List<dynamic>? ?? []);
    final churnTraps = (_bulkBlockDeals['filtered_operator_churn_traps'] as List<dynamic>? ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: kAccentCyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "SMART BULK/BLOCK ABSORPTION vs OPERATOR CHURN",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  "Isolating Marquee Institutional Net Demat Delivery from fake operator intraday churn.",
                  style: TextStyle(color: kTextMuted, fontSize: 9),
                ),
                const SizedBox(height: 14),

                // SECTION 1: MARQUEE NET ABSORPTION
                Row(
                  children: const [
                    Icon(Icons.verified_rounded, color: kAccentGreen, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🟢 MARQUEE NET INSTITUTIONAL ABSORPTION (> ₹10 Cr NET DEMAT)",
                      style: TextStyle(
                        color: kAccentGreen,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...netAbsorptions.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final client = st['client_name'] ?? '';
                  final double netCr = (st['net_value_cr'] as num?)?.toDouble() ?? 0.0;
                  final double price = (st['avg_price'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              client,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "+₹${netCr.toStringAsFixed(1)} Cr @ ₹${price.toStringAsFixed(0)}",
                            style: GoogleFonts.robotoMono(
                              color: kAccentGreen,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // SECTION 2: FILTERED OPERATOR CHURN TRAPS
                Row(
                  children: const [
                    Icon(Icons.block_rounded, color: kAccentAmber, size: 12),
                    SizedBox(width: 5),
                    Text(
                      "🔴 FILTERED OPERATOR INTRADAY CHURN (DAY-TRADING VOLUME BAIT)",
                      style: TextStyle(
                        color: kAccentAmber,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...churnTraps.map((st) {
                  final sym = st['symbol']?.toString().toUpperCase() ?? '';
                  final client = st['client_name'] ?? '';
                  final double grossCr = (st['gross_traded_cr'] as num?)?.toDouble() ?? 0.0;
                  final double netCr = (st['net_absorbed_cr'] as num?)?.toDouble() ?? 0.0;
                  final double churn = (st['churn_ratio_pct'] as num?)?.toDouble() ?? 99.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: kAccentAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sym,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              client,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 8),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kAccentAmber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${churn.toStringAsFixed(1)}% Churn (₹${grossCr.toStringAsFixed(0)} Cr Traded / Net ₹${netCr.toStringAsFixed(2)} Cr)",
                            style: GoogleFonts.robotoMono(
                              color: kAccentAmber,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDeliveryHistoryScreen(initialSymbol: sym),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F293D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Delivery →",
                              style: TextStyle(color: kAccentCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: kAccentCyan, size: 12),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SEBI Statutory Notice: Bulk and Block deal data processed via algorithmic netting from official exchange disclosures. Strictly educational analysis; does not constitute investment advice.",
                          style: TextStyle(color: Colors.white54, fontSize: 8, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }



}
