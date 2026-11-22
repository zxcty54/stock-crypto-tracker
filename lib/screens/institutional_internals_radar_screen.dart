import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'company_intelligence_screen.dart';
import 'stock_delivery_history_screen.dart';
import 'global_economy_radar_screen.dart';

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
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/assets/data/global_economy_radar.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/global_economy_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/global_economy_radar.json',
    'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/global_economy_radar.json',
  ];

  bool _isLoading = true;
  bool _isSyncing = false;
  Map<String, dynamic> _fiiDiiFlows = {};
  Map<String, dynamic> _fiiDiiDerivatives = {};
  Map<String, dynamic> _marketInternals = {};
  Map<String, dynamic> _promoterRadar = {};
  Map<String, dynamic> _bulkBlockDeals = {};

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

    for (final url in dataUrls) {
      try {
        final uri = Uri.parse("$url?t=${DateTime.now().millisecondsSinceEpoch}");
        final response = await http.get(
          uri,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final dynamic parsed = jsonDecode(utf8.decode(response.bodyBytes));
          if (parsed is Map<String, dynamic>) {
            if (mounted) {
              setState(() {
                _populateData(parsed);
                _isSyncing = false;
                _isLoading = false;
              });
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
          children: [
            Row(
              children: [
                Text(
                  "INSTITUTIONAL & RISK RADAR",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: kAccentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kAccentGreen.withOpacity(0.3)),
                  ),
                  child: const Text(
                    "DII / FII / VIX",
                    style: TextStyle(
                      color: kAccentGreen,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              "Participant OI • India VIX • Breadth • Pledge Risk • Bulk Deals",
              style: TextStyle(color: kTextMuted, fontSize: 9.5),
            ),
          ],
        ),
        actions: [
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

    final String plainConclusion = isDiiAbsorbing
        ? "Domestic Institutions (DIIs ₹${diiNet.toStringAsFixed(0)} Cr) ne Foreign selling (₹${fiiNet.abs().toStringAsFixed(0)} Cr) ko poori tarah absorb kiya hai. Market internals strong hain."
        : (isNetPositive
            ? "FIIs aur DIIs dono taraf se net buying active hai. Broad liquidity trend positive bana hua hai."
            : "Foreign selling domestic buying se zyada hai. Cautious risk regime active hai.");

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded,
                        color: kAccentCyan, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      "INSTITUTIONAL CASH (FII vs DII)",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        tradeDate,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: netColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  verdict,
                  style: TextStyle(
                    color: netColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_rounded, color: kAccentCyan, size: 14),
                const SizedBox(width: 5),
                Text(
                  "NSE INDEX FUTURES OI (NIFTY & BANKNIFTY)",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Text(
                zoneLabel,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded, color: kAccentCyan, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    "MARKET INTERNALS & CAMOUFLAGE RADAR",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
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
                "ADVANCES: $adv (${breadthPct.toStringAsFixed(1)}%)",
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
                  "$tot NSE STOCKS AUDITED",
                  style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "DECLINES: $dec (${decPct.toStringAsFixed(1)}%)",
                style: GoogleFonts.robotoMono(
                  color: kAccentRed,
                  fontSize: 10,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                ],
              ),
              Text(
                vixLabel,
                style: const TextStyle(color: kAccentCyan, fontSize: 8, fontWeight: FontWeight.bold),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: kAccentCyan, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    "PROMOTER PLEDGE & MARQUEE BULK DEALS",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
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
