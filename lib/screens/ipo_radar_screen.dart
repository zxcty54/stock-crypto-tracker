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
  String? _errorMessage;
  List<Map<String, dynamic>> _allIpos = [];

  final List<String> _dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/assets/data/ipo_master.json',
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/ipo_master.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/assets/data/ipo_master.json',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      _errorMessage = null;
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
      } catch (e) {
        _errorMessage = "Could not load IPO data. Please check connection.";
      }
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

  List<Map<String, dynamic>> get _listedIpos =>
      _allIpos.where((e) => (e['status'] ?? '').toString().toUpperCase() == 'LISTED').toList();

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
              "Series EQ • Official Exchange Demand • Behind-the-Scenes Split",
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
                fontSize: 12.5,
                letterSpacing: 0.4,
              ),
              tabs: [
                Tab(text: "🔥 ACTIVE (${_openIpos.length})"),
                Tab(text: "⏳ UPCOMING (${_upcomingIpos.length})"),
                Tab(text: "📋 LISTED (${_listedIpos.length})"),
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

                // Tabs Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIpoList(_openIpos, "Koi Mainboard IPO abhi open nahi hai."),
                      _buildIpoList(_upcomingIpos, "Koi Upcoming Mainboard issue announce nahi hua hai."),
                      _buildIpoList(_listedIpos, "Koi recently listed Mainboard data available nahi hai."),
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
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Official NSE Series 'EQ' issues only. Grey Market Premium (GMP) is an unofficial third-party sentiment indicator for educational awareness only.",
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

    final isListed = status == 'LISTED';
    final listingPrice = ipo['listing_price']?.toString() ?? '';
    final listingGain = ipo['listing_gain']?.toString() ?? '';

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName,
                            style: GoogleFonts.robotoCondensed(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (symbol.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                    _buildStatusBadge(status),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1E293B)),

          // 2. KEY ISSUE PARAMETERS GRID (Price, Lot, Size)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
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
                    "LOT / MIN BID",
                    "$lotSize Shares",
                    minInvestment.isNotEmpty ? "₹$minInvestment" : "Retail 1 Lot",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildParamBox(
                    "TOTAL ISSUE",
                    issueSizeCr.isNotEmpty ? "₹$issueSizeCr Cr" : "TBA",
                    isListed ? "Mainboard" : "NSE & BSE",
                  ),
                ),
              ],
            ),
          ),

          // 3. UNOFFICIAL SENTIMENT PILL (GMP Disclaimer Safe)
          if (!isListed && gmp.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: _buildGmpSentimentPill(gmp, gmpPct, estListing),
            ),
          ],

          // 3B. IF LISTED: LISTING PERFORMANCE BANNER
          if (isListed && listingPrice.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: _buildListedPerformanceBanner(listingPrice, listingGain),
            ),
          ],

          // 4. INTERACTIVE DATE FLOW STEPPER
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: _buildDateFlowStepper(ipo),
          ),

          // 5. VISUAL BAR 1: FRESH ISSUE VS OFS SPLIT (Promoter Cashout Reality)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: _buildFreshVsOfsBar(freshCr, ofsCr, issueSizeCr),
          ),

          // 6. VISUAL BAR 2: SMART MONEY DEMAND (QIB vs Retail)
          if (!isListed && subscription.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: _buildSubscriptionDemandMeter(subscription),
            ),
          ],

          // 7. CORE BUSINESS & DRHP OBJECTS
          if (about.isNotEmpty || objects.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: _buildBusinessAndObjectsCard(about, objects),
            ),
          ],

          // 8. REGISTRAR & ALLOTMENT CHECK ACTION BAR
          if (registrar.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
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

    switch (status) {
      case 'OPEN':
        bg = const Color(0xFF064E3B);
        fg = const Color(0xFF10B981);
        label = "BIDDING OPEN";
        break;
      case 'UPCOMING':
        bg = const Color(0xFF1E293B);
        fg = const Color(0xFF38BDF8);
        label = "UPCOMING";
        break;
      case 'LISTED':
        bg = const Color(0xFF312E81);
        fg = const Color(0xFF818CF8);
        label = "LISTED";
        break;
      default:
        bg = const Color(0xFF1E293B);
        fg = Colors.white70;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB).withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.show_chart_rounded, color: Color(0xFF38BDF8), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Market Sentiment (Unofficial): ",
                      style: GoogleFonts.robotoCondensed(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "$gmp ($gmpPct%)",
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (estListing.isNotEmpty)
                  Text(
                    "Est Listing Price: $estListing • Purely indicative third-party estimate",
                    style: TextStyle(
                      color: Colors.white.withAlpha(140),
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: _showGmpDisclaimerDialog,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListedPerformanceBanner(String listingPrice, String listingGain) {
    final isPos = !listingGain.startsWith('-');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isPos ? const Color(0xFF064E3B).withAlpha(80) : const Color(0xFF4C0519).withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPos ? const Color(0xFF10B981).withAlpha(100) : const Color(0xFFF43F5E).withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: isPos ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "NSE Listing Day Result: Listed at $listingPrice",
              style: GoogleFonts.robotoCondensed(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isPos ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              listingGain,
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
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
          "• GMP rates can be manipulated and volatile.\n"
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

  // 4. INTERACTIVE DATE FLOW STEPPER
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
      {'title': 'Allotment', 'date': allotD, 'done': status == 'LISTED'},
      {'title': 'Demat', 'date': dematD, 'done': status == 'LISTED'},
      {'title': 'Listing', 'date': listD, 'done': status == 'LISTED'},
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
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final prevDone = steps[i ~/ 2]['done'] as bool;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: prevDone ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                  ),
                );
              }

              final idx = i ~/ 2;
              final item = steps[idx];
              final isDone = item['done'] as bool;
              final title = item['title'] as String;
              final date = item['date'] as String;

              return Column(
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
        ],
      ),
    );
  }

  // 5. VISUAL BAR 1: FRESH ISSUE VS OFS SPLIT
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
              height: 12,
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
          const SizedBox(height: 6),

          // Breakdown labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
                  const SizedBox(width: 5),
                  Text(
                    "Fresh (Company Growth): ${freshPct.toStringAsFixed(1)}% (₹${fresh.toInt()} Cr)",
                    style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF43F5E))),
                  const SizedBox(width: 5),
                  Text(
                    "OFS (Promoter Pocket): ${ofsPct.toStringAsFixed(1)}% (₹${ofs.toInt()} Cr)",
                    style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                  ),
                ],
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
                  ? "⚠️ High Cashout Risk: Over 50% of proceeds go to promoters/PE sellers, not into company operations."
                  : "🟢 Growth Positive: Major funds enter company balance sheet for capex & debt repayment.",
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

  // 6. VISUAL BAR 2: SMART MONEY DEMAND (QIB vs Retail)
  Widget _buildSubscriptionDemandMeter(Map<String, dynamic> sub) {
    final qib = sub['qib']?.toString() ?? 'TBA';
    final nii = sub['nii']?.toString() ?? 'TBA';
    final retail = sub['retail']?.toString() ?? 'TBA';
    final total = sub['total']?.toString() ?? 'TBA';

    double qibNum = _parseSubNumber(qib);
    double niiNum = _parseSubNumber(nii);
    double retNum = _parseSubNumber(retail);

    bool isQibLeading = qibNum > retNum && qibNum > 1.0;
    bool isRetailFomo = retNum > (qibNum * 2.5) && retNum > 2.0;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: Color(0xFF00E5FF), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    "NSE LIVE CUMULATIVE DEMAND (SUBSCRIPTION)",
                    style: GoogleFonts.robotoCondensed(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Total: $total",
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF00E5FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _buildCategoryBar("QIB (Institutional Smart Money)", qib, qibNum, const Color(0xFF00E5FF)),
          const SizedBox(height: 5),
          _buildCategoryBar("NII / HNI (High Net-worth)", nii, niiNum, const Color(0xFFF59E0B)),
          const SizedBox(height: 5),
          _buildCategoryBar("Retail (RII Individual Investors)", retail, retNum, const Color(0xFF10B981)),
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
              isRetailFomo
                  ? "⚠️ Retail Divergence: Retail is heavily bidding while institutional big money is waiting or cautious."
                  : (isQibLeading
                      ? "🟢 Strong Institutional Conviction: QIBs are aggressively absorbing shares."
                      : "⚖️ Balanced Cumulative Bidding: Demand is tracking standard mainboard progression."),
              style: TextStyle(
                color: isRetailFomo ? const Color(0xFFFDA4AF) : const Color(0xFFA7F3D0),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String label, String rawVal, double numVal, Color barColor) {
    double progress = (numVal / 10.0).clamp(0.02, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
            Text(
              rawVal,
              style: GoogleFonts.robotoMono(
                color: barColor,
                fontWeight: FontWeight.w700,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
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
          InkWell(
            onTap: () {
              if (url.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0F172A),
                    content: Text(
                      "Allotment portal copied: $url",
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

  double _parseSubNumber(String val) {
    final clean = val.replaceAll('x', '').replaceAll('Active', '').replaceAll('(', '').replaceAll(')', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
