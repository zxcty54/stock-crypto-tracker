import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class EconomyDemandRadarScreen extends StatefulWidget {
  const EconomyDemandRadarScreen({super.key});

  @override
  State<EconomyDemandRadarScreen> createState() => _EconomyDemandRadarScreenState();
}

class _EconomyDemandRadarScreenState extends State<EconomyDemandRadarScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/economy_demand_radar.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/economy_demand_radar.json',
    'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/economy_demand_radar.json',
  ];

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _payload;
  late TabController _tabController;

  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color borderSubtle = Color(0xFF1E2B3E);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentGreen = Color(0xFF00F5A0);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color textMuted = Color(0xFF8896AB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRadarData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRadarData({bool isRefresh = false}) async {
    if (isRefresh) HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. Try Live Network CDNs first (Zero APK rebuild required)
    for (final baseUrl in dataUrls) {
      try {
        final uri = Uri.parse('$baseUrl?ts=$timestamp');
        final response = await http.get(
          uri,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (mounted) {
            setState(() {
              _payload = decoded;
              _isLoading = false;
              _errorMessage = null;
            });
            return;
          }
        }
      } catch (_) {
        // Try next CDN
        continue;
      }
    }

    // 2. Offline / Emergency Fallback (if airplane mode or all CDNs unreachable)
    try {
      final localJson = await rootBundle.loadString('assets/data/economy_demand_radar.json');
      final decoded = jsonDecode(localJson);
      if (mounted) {
        setState(() {
          _payload = decoded;
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load telemetry radar: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C121E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "INDIAN ECONOMY DEMAND RADAR",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
            const Text(
              "FASTag Toll • Port Cargo • Diesel • 8-Core Physical Pulse",
              style: TextStyle(color: textMuted, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: accentCyan, size: 20),
            tooltip: "Live Refresh",
            onPressed: () => _fetchRadarData(isRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentCyan,
          labelColor: accentCyan,
          unselectedLabelColor: textMuted,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "🎯 SECTOR DEMAND & STOCKS"),
            Tab(text: "📊 PHYSICAL TELEMETRY GAUGES"),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: accentCyan));
    }

    if (_errorMessage != null || _payload == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: accentRed, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? "Unable to load telemetry data.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2B3E)),
                onPressed: () => _fetchRadarData(isRefresh: true),
                icon: const Icon(Icons.refresh, size: 16, color: accentCyan),
                label: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final headline = _payload!['economy_headline'] ?? {};
    final sectors = (_payload!['sector_demand_matrix'] as List?) ?? [];
    final modules = _payload!['telemetry_modules'] ?? {};

    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 1: Sector Demand Trajectories & Beneficiary Stocks
        RefreshIndicator(
          color: accentCyan,
          backgroundColor: const Color(0xFF0C121E),
          onRefresh: () => _fetchRadarData(isRefresh: true),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _buildHeadlineBanner(headline),
              const SizedBox(height: 12),
              _buildEarningsAlphaExplainer(),
              const SizedBox(height: 16),
              Text(
                "ACTIONABLE SECTOR DEMAND SIGNALS (${sectors.length})",
                style: GoogleFonts.plusJakartaSans(
                  color: accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              ...sectors.map((s) => _buildSectorDemandCard(s)),
              const SizedBox(height: 10),
              _buildSebiDisclaimerCard(),
            ],
          ),
        ),

        // Tab 2: Physical Telemetry Gauges (Toll, Ports, PPAC, 8-Core)
        RefreshIndicator(
          color: accentCyan,
          backgroundColor: const Color(0xFF0C121E),
          onRefresh: () => _fetchRadarData(isRefresh: true),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _buildEightCoreModule(modules['dpiit_eight_core']),
              const SizedBox(height: 14),
              _buildPortsModule(modules['ipa_major_ports']),
              const SizedBox(height: 14),
              _buildFuelModule(modules['ppac_fuel_freight']),
              const SizedBox(height: 14),
              _buildFastagModule(modules['netc_fastag_toll']),
              const SizedBox(height: 10),
              _buildSebiDisclaimerCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeadlineBanner(Map<String, dynamic> h) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    h['verdict'] ?? 'ECONOMIC EXPANSION',
                    style: const TextStyle(
                      color: accentGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                "Updated: ${_payload?['last_updated']?.split(' ')?.first ?? 'Latest'}",
                style: const TextStyle(color: textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricPill("8-Core Growth", "+${h['core_infra_growth_pct']}%", accentGreen),
              _metricPill("Port Cargo", "+${h['port_cargo_growth_pct']}%", accentCyan),
              _metricPill("Diesel Demand", "+${h['diesel_freight_growth_pct']}%", accentAmber),
              _metricPill("FASTag Toll", "+${h['fastag_toll_growth_pct']}%", accentGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String val, Color col) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: textMuted, fontSize: 9.5)),
      ],
    );
  }

  Widget _buildEarningsAlphaExplainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                "EDUCATIONAL MACRO INSIGHT: PHYSICAL INDICATORS",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF38BDF8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Companies ke quarterly financial results 45 din baad report hote hain, jabki Government ka physical telemetry data (DPIIT 8-Core, Fuel, Ports, FASTag) MONTHLY real-time publish hota hai. Jab physical volume dispatch expand hota hai, toh plant operating leverage se quarterly production metrics par asar padta hai. Yeh analysis purely educational macroeconomic study ke liye hai — yeh kisi bhi prakar ki stock recommendation ya investment advice nahi hai.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSebiDisclaimerCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D131F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.35)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFFFFB300), size: 15),
              SizedBox(width: 8),
              Text(
                "SEBI COMPLIANCE & STATUTORY DISCLAIMER",
                style: TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "1. NOT SEBI REGISTERED: StockPulse and its developers are NOT registered with the Securities and Exchange Board of India (SEBI) as Research Analysts (RA) or Investment Advisers (IA).\n\n"
            "2. NO BUY / SELL CALLS OR TIPS: Nothing on this app constitutes investment advice, portfolio management, stock tips, buy/sell recommendations, price targets, or financial guarantees.\n\n"
            "3. STATUTORY DATA AGGREGATION: All physical volume metrics are aggregated from official Government of India releases (DPIIT, PPAC, IPA, NPCI) solely for academic and educational macro-tracking purposes.\n\n"
            "4. INDEPENDENT ADVICE: Equity investments are subject to market risks. Users must consult a SEBI registered investment advisor before making any financial commitment.",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorDemandCard(Map<String, dynamic> s) {
    final stocks = (s['beneficiary_equities'] as List?) ?? [];
    final badge = s['momentum_badge'] ?? '🟢 EXPANDING';
    final isSoft = badge.contains('SOFTENING') || badge.contains('CONTRACTION');
    final trendOutlook = s['macro_trend_outlook'] ?? s['earnings_outlook'];
    final correlationNote = s['macro_correlation_note'] ?? s['earnings_prediction_thesis'];
    final keyMetric = s['fundamental_metric_to_track'] ?? s['key_metric_to_watch'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSoft ? accentRed.withOpacity(0.3) : borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s['sector'] ?? '',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSoft ? accentRed.withOpacity(0.15) : accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isSoft ? accentRed : accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s['primary_indicators'] ?? '',
            style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            s['economic_rationale'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
          ),
          if (trendOutlook != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSoft
                    ? accentRed.withOpacity(0.08)
                    : const Color(0xFF0A1F1C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSoft
                      ? accentRed.withOpacity(0.3)
                      : accentGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSoft
                            ? Icons.warning_amber_rounded
                            : Icons.insights_rounded,
                        size: 14,
                        color: isSoft ? accentRed : accentGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "MACRO ACTIVITY TREND: $trendOutlook",
                          style: TextStyle(
                            color: isSoft ? accentRed : accentGreen,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (correlationNote != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      correlationNote,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (keyMetric != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🎯 Fundamental Driver: ",
                          style: TextStyle(
                            color: accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            keyMetric,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF1B2433), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "SECTOR REPRESENTATIVE PEERS (EDUCATIONAL STUDY):",
                style: GoogleFonts.plusJakartaSans(
                  color: textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            "Tickers listed below are representative industry case studies for macro sensitivity tracking, NOT buy/sell recommendations.",
            style: TextStyle(color: Colors.white38, fontSize: 9, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: stocks.map((st) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1320),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1E2D44)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      st['symbol'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "• ${st['name'] ?? ''}",
                      style: const TextStyle(color: textMuted, fontSize: 10),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- TELEMETRY GAUGES WIDGETS ---

  Widget _buildEightCoreModule(Map<String, dynamic>? c) {
    if (c == null) return const SizedBox.shrink();
    final comps = (c['components'] as Map<String, dynamic>?) ?? {};

    return _telemetryCard(
      title: "1. 8-CORE INFRASTRUCTURE PRODUCTION",
      period: c['period'] ?? '',
      badgeText: "+${c['overall_yoy_growth_pct']}% YoY",
      badgeColor: accentGreen,
      child: Column(
        children: comps.entries.map((e) {
          final val = e.value as Map<String, dynamic>;
          final yoy = (val['yoy_pct'] as num?)?.toDouble() ?? 0.0;
          final isPos = yoy >= 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  "${isPos ? '+' : ''}$yoy%",
                  style: TextStyle(
                    color: isPos ? accentGreen : accentRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPortsModule(Map<String, dynamic>? p) {
    if (p == null) return const SizedBox.shrink();
    final comms = (p['major_commodities'] as Map<String, dynamic>?) ?? {};

    return _telemetryCard(
      title: "2. MAJOR PORTS EXIM TRADE (IPA)",
      period: p['period'] ?? '',
      badgeText: "${p['total_cargo_current_mmt']} MMT (+${p['cargo_yoy_growth_pct']}%)",
      badgeColor: accentCyan,
      child: Column(
        children: comms.entries.map((e) {
          final val = e.value as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  "${val['volume_mmt']} MMT (${val['share_pct']}%)",
                  style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFuelModule(Map<String, dynamic>? f) {
    if (f == null) return const SizedBox.shrink();
    final fuels = (f['fuels'] as Map<String, dynamic>?) ?? {};

    return _telemetryCard(
      title: "3. FUEL CONSUMPTION & FREIGHT PULSE (PPAC)",
      period: f['period'] ?? '',
      badgeText: "${f['total_consumption_mmt']} MMT (+${f['total_consumption_yoy_pct']}%)",
      badgeColor: accentAmber,
      child: Column(
        children: fuels.entries.map((e) {
          final val = e.value as Map<String, dynamic>;
          final yoy = (val['yoy_growth_pct'] as num?)?.toDouble() ?? 0.0;
          final isPos = yoy >= 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(val['metric_label'] ?? '', style: const TextStyle(color: textMuted, fontSize: 10)),
                  ],
                ),
                Text(
                  "${isPos ? '+' : ''}$yoy%",
                  style: TextStyle(
                    color: isPos ? accentGreen : accentRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFastagModule(Map<String, dynamic>? t) {
    if (t == null) return const SizedBox.shrink();
    final history = (t['rolling_12m_history'] as List?) ?? [];

    return _telemetryCard(
      title: "4. HIGHWAY FREIGHT & TOLL (NETC FASTAG)",
      period: t['latest_month'] ?? '',
      badgeText: "₹${t['latest_toll_cr']} Cr (+${t['yoy_growth_pct']}%)",
      badgeColor: accentGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Volume:", style: TextStyle(color: textMuted, fontSize: 11)),
              Text("${t['latest_volume_mn']} Million Vehicles", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Average Toll Ticket:", style: TextStyle(color: textMuted, fontSize: 11)),
              Text("₹${t['average_ticket_size_inr']}", style: const TextStyle(color: accentGreen, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          const Text("12-Month Toll Revenue Trend (₹ Cr):", style: TextStyle(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: history.map((h) {
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1320),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Text(h['month'] ?? '', style: const TextStyle(color: textMuted, fontSize: 9)),
                      const SizedBox(height: 2),
                      Text("₹${(h['toll_cr'] as num?)?.toInt() ?? 0}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryCard({
    required String title,
    required String period,
    required String badgeText,
    required Color badgeColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    Text(period, style: const TextStyle(color: textMuted, fontSize: 10)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF1B2433), height: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
