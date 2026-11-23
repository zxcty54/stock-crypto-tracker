import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// 🪙 Spot Ticker Import
import '../widgets/metals_ticker_card.dart';

// 📊 Single Unified Institutional Bullion Desk Import
import '../widgets/bullion_efficiency_desk_card.dart';

// 🧠 Macro Margin Research Desk Import
import '../widgets/macro_research_desk_view.dart';

// 🏢 Company Business Intelligence Screen Import
import 'company_intelligence_screen.dart';

// 🏭 Physical Economy Demand Radar Import
import 'economy_demand_radar_screen.dart';

// 📢 Corporate Announcements Screen Import
import 'corporate_announcements_screen.dart';

// 🎯 Strategy Replay Hero Card & Screen Import
import '../widgets/strategy_replay_hero_card.dart';
import 'strategy_builder_screen.dart';

// 💎 Order & Turnaround Radar Widget Import
import '../widgets/hidden_gems_radar.dart';

// ⚓ Smart Money Anchor Screen Import
import '../widgets/smart_money_anchor_screen.dart';

// 🏆 Weekly & Monthly Gainers & Delivery History Import
import 'stock_delivery_history_screen.dart';

// 🗺️ NSE Indices & Sector Heatmap Preview Card
import '../widgets/indices_heatmap_preview_card.dart';

// ⚡ Community Market Sentiment Radar
import '../widgets/community_sentiment_card.dart';

// 🕵️ Mutual Fund Smart Money Preview Card
import '../widgets/mf_smart_money_preview_card.dart';

// 🚀 NSE Mainboard IPO Radar Screen
import 'ipo_radar_screen.dart';

// 🌍 Global Economy Radar Preview Card
import '../widgets/global_economy_preview_card.dart';
import 'global_economy_radar_screen.dart';
import 'institutional_internals_radar_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final String _sheetApiUrl =
      "https://stock-models-api.nitesh-skyhigh.workers.dev/?type=sheet2";

  double _niftyPrice = 25548.20;
  String _niftyChangeStr = "+0.13%";
  String _marketStatus = "POST_MARKET";
  bool _isVotingAllowed = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveIndices();
  }

  Future<void> _fetchLiveIndices() async {
    try {
      final response = await http
          .get(Uri.parse(_sheetApiUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        Map<String, dynamic> parsedData = {};
        String status = "POST_MARKET";
        bool allowed = true;

        if (decoded is Map<String, dynamic>) {
          status = decoded['market_status']?.toString() ?? "POST_MARKET";
          allowed = decoded['voting_allowed'] == true;

          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            parsedData = Map<String, dynamic>.from(decoded['data']);
          } else {
            parsedData = decoded;
          }
        }

        double extractedNifty = _niftyPrice;
        String extractedChange = _niftyChangeStr;
        parsedData.forEach((key, val) {
          final cleanKey = key.toString().toLowerCase().replaceAll(" ", "").replaceAll("_", "");
          if (cleanKey.contains("nifty50") || cleanKey == "nifty") {
            if (val is Map) {
              if (val.containsKey('price')) {
                extractedNifty = (val['price'] as num).toDouble();
              }
              if (val.containsKey('change')) {
                final c = val['change'];
                final d = (c is num)
                    ? c.toDouble()
                    : double.tryParse(c.toString().replaceAll('%', '').trim()) ?? 0.0;
                extractedChange = "${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)}%";
              }
            } else if (val is num) {
              extractedNifty = val.toDouble();
            }
          }
        });

        if (mounted) {
          setState(() {
            _niftyPrice = extractedNifty;
            _niftyChangeStr = extractedChange;
            _marketStatus = status;
            _isVotingAllowed = allowed;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF0F1726),
          onRefresh: () async {
            await _fetchLiveIndices();
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 🎯 1. 10-YEAR HISTORICAL STRATEGY REPLAY HERO CARD (Top Highlight)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: StrategyReplayHeroCard(
                    onLaunch: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StrategyBuilderScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 🗺️ 2. NSE INDICES & SECTOR HEATMAP (Broad 21 & Sectoral 23 Matrix)
              const SliverToBoxAdapter(
                child: IndicesHeatmapPreviewCard(),
              ),

              // ⚡ 2B. MARKET SENTIMENT & TRADER CONSENSUS RADAR (Daily Mood & Target Strikes)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                  child: CommunitySentimentCard(
                    niftyLivePrice: _niftyPrice,
                    niftyChangeStr: _niftyChangeStr,
                    marketStatus: _marketStatus,
                    isVotingAllowed: _isVotingAllowed,
                  ),
                ),
              ),

              // 🕵️ 2C. MUTUAL FUND SMART MONEY RADAR (Top 20 DII Infiltrations & Overlap Audit)
              const SliverToBoxAdapter(
                child: MfSmartMoneyPreviewCard(),
              ),

              // 🚀 2D. NSE MAINBOARD IPO RADAR (Series EQ • Fresh vs OFS • Live Demand)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IpoRadarScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withAlpha(100),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.rocket_launch_rounded,
                                color: Color(0xFF00E5FF),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "NSE MAINBOARD IPO RADAR",
                                        style: GoogleFonts.robotoCondensed(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF).withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "SERIES EQ",
                                          style: GoogleFonts.robotoMono(
                                            color: const Color(0xFF00E5FF),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    "Live NSE Demand • Fresh vs OFS Split • Date Timeline Stepper",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF00E5FF),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 💎 3. HIDDEN GEMS RADAR (Order Book & Sales Turnaround Desk)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrderRadarDashboardWidget(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withAlpha(90),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.radar_rounded,
                                color: Color(0xFF38BDF8),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "HIDDEN GEMS RADAR",
                                        style: TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "ORDER & TURNAROUND",
                                        style: TextStyle(
                                          color: Color(0xFFFFB703),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Unexecuted Order Book & Low P/S Turnaround Gems",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF8896AB),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ⚓ 3. SMART MONEY ANCHOR DESK (QIP & Floor Radar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SmartMoneyAnchorScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00E676).withAlpha(90),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.anchor_rounded,
                                color: Color(0xFF00E676),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "SMART MONEY ANCHOR",
                                        style: TextStyle(
                                          color: Color(0xFF00E676),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "QIP & FLOOR RADAR",
                                        style: TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Institutional Allotment Floor & Prime Discounts",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF8896AB),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🪙 4. LIVE SPOT METALS, COPPER & FOREX TICKER
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: MetalsTickerCard(),
                ),
              ),

              // 📢 5. CORPORATE ANNOUNCEMENTS & FILINGS BANNER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CorporateAnnouncementsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFB703).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB703).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Color(0xFFFFB703),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "CORPORATE FILINGS & ORDERS",
                                        style: TextStyle(
                                          color: Color(0xFFFFB703),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "BSE / NSE",
                                        style: TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Disclosures, Order Wins, Board Meets & Buybacks",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF8896AB),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 📊 5B. STOCK OHLC & DELIVERY DATA RADAR BANNER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StockDeliveryHistoryScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF131B2A), Color(0xFF0F1726)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00F0FF).withOpacity(0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F0FF).withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00F0FF).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.candlestick_chart_rounded,
                                    color: Color(0xFF00F0FF),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "STOCK OHLC & DELIVERY RADAR",
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF00F0FF),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00F5A0).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "20D NSE DATA",
                                              style: TextStyle(
                                                color: Color(0xFF00F5A0),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        "20-Day Open, High, Low, Close & Demat Delivery % (1,589 Stocks)",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFF00F0FF),
                                  size: 14,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _buildBannerFeatureChip("📊 20-Day OHLC History", const Color(0xFF00F0FF))),
                                const SizedBox(width: 8),
                                Expanded(child: _buildBannerFeatureChip("🎯 Stealth Accumulation", const Color(0xFF00F5A0))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: _buildBannerFeatureChip("📦 High Demat Delivery %", const Color(0xFFFFB703))),
                                const SizedBox(width: 8),
                                Expanded(child: _buildBannerFeatureChip("🏆 1W & 1M Top Movers", const Color(0xFFFF2A6D))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🧠 6. AI MACRO MARGIN RADAR ENTRY BANNER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MacroResearchDeskView(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.psychology_alt_rounded,
                                color: Color(0xFF00E5FF),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "MACRO MARGIN RADAR",
                                        style: TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "LIVE AI",
                                        style: TextStyle(
                                          color: Color(0xFF00E676),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Crude & Commodity impact on Stock Margins",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF8896AB),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🏭 7. PHYSICAL ECONOMY DEMAND RADAR ENTRY BANNER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EconomyDemandRadarScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF9100).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9100).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.factory_rounded,
                                color: Color(0xFFFF9100),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "PHYSICAL ECONOMY RADAR",
                                        style: TextStyle(
                                          color: Color(0xFFFF9100),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "8-CORE · PORTS · FUEL",
                                        style: TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Physical Ground Telemetry & Sector Demand Signals",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF8896AB),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🌍 7B. GLOBAL ECONOMY RADAR ENTRY BANNER (Pressure vs Expansion across Superpowers)
              const SliverToBoxAdapter(
                child: GlobalEconomyPreviewCard(),
              ),

              // 🏛️ 7C. INSTITUTIONAL FLOWS & MARKET RISK RADAR ENTRY BANNER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InstitutionalInternalsRadarScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF131B2A), Color(0xFF0F1726)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00FF88).withOpacity(0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF88).withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF88).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_rounded,
                                    color: Color(0xFF00FF88),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "INSTITUTIONAL & RISK RADAR",
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF00FF88),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E5FF).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "FII / DII / VIX",
                                              style: TextStyle(
                                                color: Color(0xFF00E5FF),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        "Participant Derivatives Squeeze • India VIX • Breadth • Promoter Pledge",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFF00FF88),
                                  size: 14,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _buildBannerFeatureChip("🏛️ FII/DII Cash Flow", const Color(0xFF00FF88))),
                                const SizedBox(width: 8),
                                Expanded(child: _buildBannerFeatureChip("🌡️ India VIX Risk Meter", const Color(0xFFFFB703))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: _buildBannerFeatureChip("⚡ Promoter Pledge Stress", const Color(0xFFFF2A6D))),
                                const SizedBox(width: 8),
                                Expanded(child: _buildBannerFeatureChip("📦 Bulk & Block Deals", const Color(0xFF00E5FF))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🏢 8. COMPANY BUSINESS INTELLIGENCE ENTRY BANNER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompanyIntelligenceScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF10B981).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.domain_verification_rounded,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "COMPANY FUNDAMENTAL RADAR",
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "MOAT & RISKS",
                                        style: TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Pricing Power, Cash Flow Quality & Anti-Thesis",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF8896AB),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 📊 8. INSTITUTIONAL BULLION EFFICIENCY DESK
              const SliverToBoxAdapter(
                child: BullionEfficiencyDeskCard(),
              ),

              // Bottom Spacer
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
