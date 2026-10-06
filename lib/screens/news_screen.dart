import 'package:flutter/material.dart';

// 🪙 Spot Ticker Import
import '../widgets/metals_ticker_card.dart';

// 📊 Single Unified Institutional Bullion Desk Import
import '../widgets/bullion_efficiency_desk_card.dart';

// 🧠 Macro Margin Research Desk Import
import '../widgets/macro_research_desk_view.dart';

// 🏢 Company Business Intelligence Screen Import
import 'company_intelligence_screen.dart';

// 📢 Corporate Announcements Screen Import
import 'corporate_announcements_screen.dart';

// 🎯 Strategy Replay Hero Card & Screen Import
import '../widgets/strategy_replay_hero_card.dart';
import 'strategy_builder_screen.dart';

// 💎 Order & Turnaround Radar Widget Import
import '../widgets/hidden_gems_radar.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 600));
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

              // 💎 2. HIDDEN GEMS RADAR (Order Book & Sales Turnaround Desk)
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

              // 🪙 3. LIVE SPOT METALS, COPPER & FOREX TICKER
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: MetalsTickerCard(),
                ),
              ),

              // 📢 4. CORPORATE ANNOUNCEMENTS & FILINGS BANNER
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

              // 🧠 5. AI MACRO MARGIN RADAR ENTRY BANNER
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

              // 🏢 6. COMPANY BUSINESS INTELLIGENCE ENTRY BANNER
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

              // 📊 7. INSTITUTIONAL BULLION EFFICIENCY DESK
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
}
