import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class IpoRadarScreen extends StatefulWidget {
  const IpoRadarScreen({super.key});

  @override
  State<IpoRadarScreen> createState() => _IpoRadarScreenState();
}

class _IpoRadarScreenState extends State<IpoRadarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allIpos = [];

  final List<String> _dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/assets/data/ipo_master.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/ipo_master.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/ipo_master.json',
  ];

  @override
  void initState() {
    super.initState();
    // Strictly 2 tabs: Active & Upcoming (No Listed)
    _tabController = TabController(length: 2, vsync: this);
    _loadIpoData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadIpoData() async {
    setState(() {
      _isLoading = true;
    });

    List<Map<String, dynamic>> loaded = [];

    // 1. Try Live Network CDN endpoints
    for (final url in _dataUrls) {
      try {
        final uri = Uri.parse("$url?ts=${DateTime.now().millisecondsSinceEpoch}");
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            loaded = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            break;
          }
        }
      } catch (_) {
        // Fallback to next endpoint
      }
    }

    // 2. Fallback to Local Asset
    if (loaded.isEmpty) {
      try {
        final assetString =
            await rootBundle.loadString('assets/data/ipo_master.json');
        final decoded = json.decode(assetString);
        if (decoded is List) {
          loaded = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _allIpos = loaded;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _openIpos =>
      _allIpos.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'OPEN').toList();

  List<Map<String, dynamic>> get _upcomingIpos =>
      _allIpos.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'UPCOMING').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.radar_rounded, color: Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 6),
                Text(
                  "NSE MAINBOARD IPO RADAR",
                  style: GoogleFonts.robotoCondensed(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            Text(
              "Series EQ • Live Bidding Demand • Fresh vs OFS Split",
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF), size: 21),
            tooltip: "Refresh Live Demand",
            onPressed: _loadIpoData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: const Color(0xFF0A0E17),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00E5FF),
              indicatorWeight: 2.5,
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: Colors.white60,
              labelStyle: GoogleFonts.robotoCondensed(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
              tabs: [
                Tab(text: "🔥 ACTIVE BIDDING (${_openIpos.length})"),
                Tab(text: "⏳ UPCOMING ISSUES (${_upcomingIpos.length})"),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E5FF),
                strokeWidth: 2.5,
              ),
            )
          : Column(
              children: [
                // Regulatory Notice Shield (Play Store Safe)
                _buildRegulatoryShieldBanner(),

                // Strictly 2 Tabs View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIpoList(_openIpos, "Abhi koi Mainboard IPO open nahi hai."),
                      _buildIpoList(_upcomingIpos, "Abhi koi Upcoming Mainboard IPO announce nahi hua hai."),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRegulatoryShieldBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Official NSE Series 'EQ' issues only. Grey Market Premium (GMP) is an unofficial third-party indicator tracked purely for sentiment analysis.",
              style: TextStyle(
                color: Colors.white.withAlpha(170),
                fontSize: 9.5,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpoList(List<Map<String, dynamic>> ipos, String emptyMsg) {
    if (ipos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, color: Colors.white30, size: 40),
              const SizedBox(height: 10),
              Text(
                emptyMsg,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: ipos.length,
      itemBuilder: (context, index) {
        return _buildIpoCard(ipos[index]);
      },
    );
  }

  Widget _buildIpoCard(Map<String, dynamic> ipo) {
    final companyName = ipo['company_name'] ?? 'Mainboard Issue';
    final symbol = ipo['symbol'] ?? '';
    final sector = ipo['sector'] ?? 'General Corporate';
    final status = (ipo['status'] ?? 'UPCOMING').toString().toUpperCase();
    final priceBand = ipo['price_band'] ?? 'TBA';
    final cutOff = ipo['cut_off_price']?.toString() ?? '';
    final lotSize = ipo['lot_size']?.toString() ?? 'TBA';
    final minInvestment = ipo['min_investment']?.toString() ?? '';
    final issueSizeCr = ipo['issue_size_cr']?.toString() ?? '';
    final freshCr = ipo['fresh_issue_cr']?.toString() ?? '';
    final ofsCr = ipo['ofs_cr']?.toString() ?? '';
    final gmp = ipo['gmp']?.toString() ?? '';
    final gmpPct = ipo['gmp_percent']?.toString() ?? '';
    final estListing = ipo['est_listing_price']?.toString() ?? '';
    final about = ipo['about']?.toString() ?? '';
    final objects = (ipo['drhp_objects'] as List<dynamic>?) ?? [];
    final subscription = (ipo['subscription'] as Map<String, dynamic>?) ?? {};
    final registrar = (ipo['registrar'] as Map<String, dynamic>?) ?? {};
    final leadManagers = (ipo['lead_managers'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER ROW
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        companyName,
                        style: GoogleFonts.robotoCondensed(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (symbol.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1320),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF00E5FF).withAlpha(80)),
                        ),
                        child: Text(
                          "NSE: $symbol • Series EQ",
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF00E5FF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sector,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1E293B)),

          // 2. KEY ISSUE PARAMETERS (2x2 Grid - Overflow Proof)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildParamBox(
                        "PRICE BAND",
                        priceBand,
                        cutOff.isNotEmpty ? "Cut-off: ₹$cutOff" : "Book Built",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildParamBox(
                        "LOT SIZE & MIN BID",
                        "$lotSize Shares",
                        minInvestment.isNotEmpty ? "Min ₹$minInvestment" : "Retail 1 Lot",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildParamBox(
                        "TOTAL ISSUE SIZE",
                        issueSizeCr.isNotEmpty ? "₹$issueSizeCr Cr" : "TBA",
                        "NSE & BSE Mainboard",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildParamBox(
                        "ISSUE TYPE",
                        "100% Book Built",
                        "Series: EQ (Equity)",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. UNOFFICIAL SENTIMENT PILL (GMP Disclaimer Safe & Overflow Proof)
          if (gmp.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: _buildGmpSentimentPill(gmp, gmpPct, estListing),
            ),
          ],

          // 4. INTERACTIVE DATE FLOW STEPPER (Horizontal Scroll - Zero Overflow)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: _buildDateFlowStepper(ipo),
          ),

          // 5. VISUAL BAR 1: FRESH ISSUE VS OFS SPLIT (Promoter Cashout Reality)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: _buildFreshVsOfsBar(freshCr, ofsCr, issueSizeCr),
          ),

          // 6. VISUAL BAR 2: SMART MONEY DEMAND (QIB vs Retail Subscription with 'x')
          if (subscription.isNotEmpty || status == 'UPCOMING') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: _buildSubscriptionDemandMeter(subscription, ipo),
            ),
          ],

          // 7. CORE BUSINESS & DRHP OBJECTS
          if (about.isNotEmpty || objects.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: _buildBusinessAndObjectsCard(about, objects),
            ),
          ],

          // 8. REGISTRAR & ALLOTMENT CHECK ACTION BAR
          if (registrar.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: _buildRegistrarActionBar(registrar, leadManagers),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status;

    if (status == 'OPEN') {
      bg = const Color(0xFF064E3B);
      fg = const Color(0xFF10B981);
      label = "BIDDING OPEN";
    } else {
      bg = const Color(0xFF1E293B);
      fg = const Color(0xFF38BDF8);
      label = "UPCOMING";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.robotoCondensed(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildParamBox(String title, String val, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.robotoCondensed(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGmpSentimentPill(String gmp, String gmpPct, String estListing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB).withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: Color(0xFF38BDF8), size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "MARKET SENTIMENT (UNOFFICIAL GMP)",
                  style: GoogleFonts.robotoCondensed(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              InkWell(
                onTap: _showGmpDisclaimerDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        "Disclaimer",
                        style: GoogleFonts.robotoCondensed(
                          color: const Color(0xFF38BDF8),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "$gmp ($gmpPct%)",
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (estListing.isNotEmpty)
                Text(
                  "Est Listing: $estListing",
                  style: GoogleFonts.robotoCondensed(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            "Purely indicative forward estimate • Not published or endorsed by NSE",
            style: TextStyle(
              color: Colors.white.withAlpha(140),
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showGmpDisclaimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 18),
            const SizedBox(width: 8),
            Text(
              "Regulatory Notice",
              style: GoogleFonts.robotoCondensed(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const Text(
          "Grey Market Premium (GMP) is an unregulated, unofficial trading sentiment indicator reported by private forward contracts.\n\n"
          "• The National Stock Exchange of India (NSE) does NOT publish, endorse, or verify GMP.\n"
          "• GMP rates can be volatile and speculative.\n"
          "• Always evaluate an IPO strictly using the official Red Herring Prospectus (RHP) filed with SEBI and fundamental company financials.",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "SAMJH GAYA (OK)",
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. INTERACTIVE DATE FLOW STEPPER (Horizontal Scroll - Zero Overflow)
  Widget _buildDateFlowStepper(Map<String, dynamic> ipo) {
    final openD = _formatShortDate(ipo['open_date']?.toString());
    final closeD = _formatShortDate(ipo['close_date']?.toString());
    final allotD = _formatShortDate(ipo['allotment_date']?.toString());
    final dematD = _formatShortDate(ipo['demat_credit_date']?.toString());
    final listD = _formatShortDate(ipo['listing_date']?.toString());

    final status = (ipo['status'] ?? '').toString().toUpperCase();

    final steps = [
      {'title': 'Open', 'date': openD, 'done': true},
      {'title': 'Close', 'date': closeD, 'done': status != 'UPCOMING'},
      {'title': 'Allotment', 'date': allotD, 'done': false},
      {'title': 'Demat Credit', 'date': dematD, 'done': false},
      {'title': 'Listing Day', 'date': listD, 'done': false},
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Color(0xFF00E5FF), size: 13),
              const SizedBox(width: 5),
              Text(
                "DATE FLOW TIMELINE (OFFICIAL SCHEDULE)",
                style: GoogleFonts.robotoCondensed(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final prevDone = steps[i ~/ 2]['done'] as bool;
                  return Container(
                    width: 24,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: prevDone ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                  );
                }

                final idx = i ~/ 2;
                final item = steps[idx];
                final isDone = item['done'] as bool;
                final title = item['title'] as String;
                final date = item['date'] as String;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                        border: Border.all(
                          color: isDone ? const Color(0xFF059669) : const Color(0xFF334155),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, color: Colors.white, size: 11)
                            : Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white38,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: isDone ? Colors.white : Colors.white54,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 7.5,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 5. VISUAL BAR 1: FRESH ISSUE VS OFS SPLIT (Overflow Proof Layout)
  Widget _buildFreshVsOfsBar(String freshCr, String ofsCr, String totalCr) {
    double fresh = double.tryParse(freshCr.replaceAll(',', '')) ?? 0.0;
    double ofs = double.tryParse(ofsCr.replaceAll(',', '')) ?? 0.0;
    double total = double.tryParse(totalCr.replaceAll(',', '')) ?? (fresh + ofs);

    if (total <= 0) {
      total = 1.0;
    }

    double freshPct = (fresh / total) * 100.0;
    double ofsPct = (ofs / total) * 100.0;

    if (freshPct > 100.0) freshPct = 100.0;
    if (ofsPct > 100.0) ofsPct = 100.0;

    final isHeavyOfs = ofsPct >= 50.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF38BDF8), size: 13),
              const SizedBox(width: 5),
              Text(
                "CAPITAL ALLOCATION: FRESH ISSUE VS OFS CASHOUT",
                style: GoogleFonts.robotoCondensed(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stacked Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (freshPct > 0)
                    Expanded(
                      flex: freshPct.round().clamp(1, 100),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (ofsPct > 0)
                    Expanded(
                      flex: ofsPct.round().clamp(1, 100),
                      child: Container(color: const Color(0xFFF43F5E)),
                    ),
                  if (freshPct == 0 && ofsPct == 0)
                    Expanded(
                      child: Container(color: const Color(0xFF334155)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Multi-row breakdown (Prevents horizontal overflow)
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Fresh (Growth Capital): ${freshPct.toStringAsFixed(1)}% (₹${fresh.toInt()} Cr)",
                  style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF43F5E))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "OFS (Promoter Pocket): ${ofsPct.toStringAsFixed(1)}% (₹${ofs.toInt()} Cr)",
                  style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Takeaway Insight Chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isHeavyOfs ? const Color(0xFF4C0519).withAlpha(80) : const Color(0xFF064E3B).withAlpha(80),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isHeavyOfs
                  ? "⚠️ High Cashout Risk: Over 50% goes to promoters/PE sellers, not into company growth."
                  : "🟢 Growth Positive: Major funds enter company balance sheet for expansion.",
              style: TextStyle(
                color: isHeavyOfs ? const Color(0xFFFDA4AF) : const Color(0xFFA7F3D0),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. VISUAL BAR 2: SMART MONEY DEMAND (With 'x' Times formatting & NSE Clear Bidding Data)
  Widget _buildSubscriptionDemandMeter(Map<String, dynamic> sub, Map<String, dynamic> ipo) {
    final status = (ipo['status'] ?? 'UPCOMING').toString().toUpperCase();
    final openDate = ipo['open_date']?.toString() ?? '';
    final openDateFormatted = _formatShortDate(openDate);
    final reservation = (ipo['reservation'] as Map<String, dynamic>?) ?? {};

    // For Upcoming issues, clearly show SEBI mandated category quotas before bidding opens
    if (status == 'UPCOMING') {
      final qibPct = reservation['qib_pct']?.toString() ?? '50%';
      final niiPct = reservation['nii_pct']?.toString() ?? '15%';
      final retPct = reservation['retail_pct']?.toString() ?? '35%';

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_reg_rounded, color: Color(0xFF38BDF8), size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    "NSE ISSUE QUOTA & ALLOCATION",
                    style: GoogleFonts.robotoCondensed(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80)),
                  ),
                  child: Text(
                    "Opens $openDateFormatted",
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF38BDF8),
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "SEBI Mandated Mainboard Category Quotas (Series EQ)",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 8.5,
              ),
            ),
            const SizedBox(height: 8),

            _buildQuotaBar("QIB (Institutional Quota)", qibPct, 0.50, const Color(0xFF00E5FF)),
            const SizedBox(height: 5),
            _buildQuotaBar("NII / HNI (High Net-worth Quota)", niiPct, 0.15, const Color(0xFFF59E0B)),
            const SizedBox(height: 5),
            _buildQuotaBar("Retail (RII Individual Investors)", retPct, 0.35, const Color(0xFF10B981)),
            const SizedBox(height: 7),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "⏳ Bidding Window Yet To Open: Cumulative times subscribed will track live from official NSE order book once issue opens.",
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final qibRaw = sub['qib']?.toString() ?? '';
    final niiRaw = sub['nii']?.toString() ?? '';
    final retailRaw = sub['retail']?.toString() ?? '';
    final totalRaw = sub['total']?.toString() ?? '';

    final totalBids = sub['total_bids'];
    final sharesOffered = sub['shares_offered'];
    final qibBids = sub['qib_bids'];
    final qibOffered = sub['qib_offered'];
    final niiBids = sub['nii_bids'];
    final niiOffered = sub['nii_offered'];
    final retBids = sub['retail_bids'];
    final retOffered = sub['retail_offered'];
    final source = sub['source']?.toString() ?? 'NSE India Official Bidding Feed';
    final updatedAt = sub['updated_at']?.toString() ?? '';

    final qibFormatted = _formatSubscriptionDisplay(qibRaw);
    final niiFormatted = _formatSubscriptionDisplay(niiRaw);
    final retailFormatted = _formatSubscriptionDisplay(retailRaw);
    final totalFormatted = _formatSubscriptionDisplay(totalRaw);

    final totalBidsStr = _formatShareQuantity(totalBids);
    final totalOfferedStr = _formatShareQuantity(sharesOffered);

    double qibNum = _parseSubNumber(qibRaw);
    double niiNum = _parseSubNumber(niiRaw);
    double retNum = _parseSubNumber(retailRaw);
    double totalNum = _parseSubNumber(totalRaw);

    double maxSub = [qibNum, niiNum, retNum, totalNum, 1.0].reduce((a, b) => a > b ? a : b);
    double scaleMax = maxSub <= 1.5 ? 1.0 : (maxSub <= 5.0 ? 5.0 : (maxSub <= 10.0 ? 10.0 : maxSub));

    bool isQibLeading = qibNum > retNum && qibNum > 1.0;
    bool isRetailFomo = retNum > (qibNum * 2.5) && retNum > 2.0;

    String verdictText;
    if (isRetailFomo) {
      verdictText = "⚠️ Retail Divergence: Retail is heavily bidding while institutional big money is waiting.";
    } else if (isQibLeading) {
      verdictText = "🟢 Strong Institutional Demand: QIBs are aggressively bidding.";
    } else if (totalNum < 1.0 && totalNum > 0.0) {
      verdictText = "⏳ Bidding In Progress: Current order book at $totalFormatted across official NSE Series EQ bids.";
    } else {
      verdictText = "⚖️ Balanced Cumulative Bidding: Demand progressing per normal Mainboard cycle.";
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF00E5FF), size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "NSE LIVE CUMULATIVE DEMAND",
                  style: GoogleFonts.robotoCondensed(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF00E5FF).withAlpha(80)),
                ),
                child: Text(
                  "Total: ${totalFormatted.endsWith('x') ? '$totalFormatted Multiple' : totalFormatted}",
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF00E5FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          if (totalBidsStr.isNotEmpty && totalOfferedStr.isNotEmpty) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withAlpha(120),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stacked_line_chart_rounded, size: 12, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "NSE Bids: $totalBidsStr shares bid against $totalOfferedStr offered",
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            "Multiple (Guna) = Issue Quota ke mukable kitne guna shares ki demand aayi hai.",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 8.5,
            ),
          ),
          const SizedBox(height: 8),

          _buildCategoryBar("QIB (Institutional Smart Money)", qibFormatted, qibNum, const Color(0xFF00E5FF), scaleMax, bidsVal: qibBids, offeredVal: qibOffered),
          const SizedBox(height: 5),
          _buildCategoryBar("NII / HNI (High Net-worth)", niiFormatted, niiNum, const Color(0xFFF59E0B), scaleMax, bidsVal: niiBids, offeredVal: niiOffered),
          const SizedBox(height: 5),
          _buildCategoryBar("Retail (RII Individual Investors)", retailFormatted, retNum, const Color(0xFF10B981), scaleMax, bidsVal: retBids, offeredVal: retOffered),
          const SizedBox(height: 7),

          // Smart Money Verdict
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isRetailFomo
                  ? const Color(0xFF4C0519).withAlpha(80)
                  : const Color(0xFF064E3B).withAlpha(80),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              verdictText,
              style: TextStyle(
                color: isRetailFomo ? const Color(0xFFFDA4AF) : const Color(0xFFA7F3D0),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                source,
                style: const TextStyle(color: Colors.white38, fontSize: 8),
              ),
              if (updatedAt.isNotEmpty)
                Text(
                  updatedAt,
                  style: const TextStyle(color: Colors.white38, fontSize: 8),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(
    String label,
    String formattedVal,
    double numVal,
    Color barColor,
    double scaleMax, {
    dynamic bidsVal,
    dynamic offeredVal,
  }) {
    double progress = (numVal / scaleMax).clamp(0.02, 1.0);
    final displayMultiple = formattedVal.toLowerCase().endsWith('x') ? "$formattedVal Multiple" : formattedVal;

    final bidsFormatted = _formatShareQuantity(bidsVal);
    final offeredFormatted = _formatShareQuantity(offeredVal);
    final hasShares = bidsFormatted.isNotEmpty && offeredFormatted.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w500),
                  ),
                  if (hasShares)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        "$bidsFormatted bids / $offeredFormatted quota",
                        style: const TextStyle(color: Colors.white38, fontSize: 8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: barColor.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: barColor.withAlpha(80)),
              ),
              child: Text(
                displayMultiple,
                style: GoogleFonts.robotoMono(
                  color: barColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4.5,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildQuotaBar(String label, String pctLabel, double ratio, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: barColor.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: barColor.withAlpha(80)),
              ),
              child: Text(
                "$pctLabel Reserved",
                style: GoogleFonts.robotoMono(
                  color: barColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.05, 1.0),
            minHeight: 4.5,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  // 7. CORE BUSINESS & DRHP OBJECTS
  Widget _buildBusinessAndObjectsCard(String about, List<dynamic> objects) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_center_rounded, color: Color(0xFF38BDF8), size: 13),
              const SizedBox(width: 5),
              Text(
                "CORE BUSINESS MODEL & OBJECTS OF ISSUE",
                style: GoogleFonts.robotoCondensed(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (about.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              about,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
          if (objects.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              "Where Will Proceeds Go? (DRHP Objects):",
              style: TextStyle(
                color: Colors.white.withAlpha(160),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            ...objects.take(3).map((obj) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10)),
                    Expanded(
                      child: Text(
                        obj.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // 8. REGISTRAR & ALLOTMENT ACTION BAR
  Widget _buildRegistrarActionBar(Map<String, dynamic> reg, List<dynamic> leadManagers) {
    final name = reg['name']?.toString() ?? 'Registrar';
    final url = reg['url']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1320),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Registrar: $name",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                if (leadManagers.isNotEmpty)
                  Text(
                    "Lead: ${leadManagers.first}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 8.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              if (url.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0F172A),
                    content: Text(
                      "Allotment portal link copied: $url",
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF00E5FF).withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, color: Color(0xFF00E5FF), size: 11),
                  const SizedBox(width: 4),
                  Text(
                    "Allotment Link",
                    style: GoogleFonts.robotoCondensed(
                      color: const Color(0xFF00E5FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(String? d) {
    if (d == null || d.isEmpty) return 'TBA';
    try {
      final parts = d.split('-');
      if (parts.length == 3) {
        final day = parts[2];
        final m = int.tryParse(parts[1]) ?? 1;
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return "$day ${months[m - 1]}";
      }
    } catch (_) {}
    return d;
  }

  String _formatSubscriptionDisplay(String val) {
    if (val.isEmpty) return '0.00x';
    String s = val.trim();
    if (s.toLowerCase().endsWith('x')) return s;
    final numVal = double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (numVal != null) {
      return "${numVal.toStringAsFixed(2)}x";
    }
    return s;
  }

  double _parseSubNumber(String val) {
    final clean = val.replaceAll('x', '').replaceAll('Active', '').replaceAll('(', '').replaceAll(')', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  String _formatShareQuantity(dynamic val) {
    if (val == null) return '';
    final s = val.toString().trim().replaceAll(',', '');
    final num = double.tryParse(s);
    if (num == null || num <= 0) return '';
    if (num >= 10000000) {
      return "${(num / 10000000).toStringAsFixed(2)} Cr";
    } else if (num >= 100000) {
      return "${(num / 100000).toStringAsFixed(2)} L";
    } else if (num >= 1000) {
      return "${(num / 1000).toStringAsFixed(1)} K";
    }
    return num.toStringAsFixed(0);
  }
}
