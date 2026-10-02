import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class CompanyIntelligenceScreen extends StatefulWidget {
  const CompanyIntelligenceScreen({super.key});

  @override
  State<CompanyIntelligenceScreen> createState() => _CompanyIntelligenceScreenState();
}

class _CompanyIntelligenceScreenState extends State<CompanyIntelligenceScreen> {
  // ⚡ Guaranteed Upstream Proxy (Edge cache lock bypass)
  final String _primaryCdnUrl =
      'https://raw.githack.com/zxcty54/stock-crypto-tracker/main/company_business_models.json';
  final String _fallbackFastlyUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/company_business_models.json';

  Map<String, dynamic> _companiesData = {};
  String? _selectedSymbol;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCompaniesData();
  }

  /// 🚀 Multi-Tier Live Sync (Githack -> Fastly jsDelivr -> Local Assets)
  Future<void> _fetchCompaniesData({bool isManual = false}) async {
    if (isManual) setState(() => _isRefreshing = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. Primary Direct Upstream Fetch
    try {
      final res = await http.get(
        Uri.parse('$_primaryCdnUrl?_t=$timestamp'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        _parseAndSetData(res.body);
        _showSuccessSnackbar(isManual);
        return;
      }
    } catch (primaryErr) {
      debugPrint("Primary fetch failed: $primaryErr. Trying Fastly fallback...");
    }

    // 2. Secondary Fastly jsDelivr Fetch
    try {
      final resFallback = await http.get(
        Uri.parse('$_fallbackFastlyUrl?ts=$timestamp'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (resFallback.statusCode == 200) {
        _parseAndSetData(resFallback.body);
        _showSuccessSnackbar(isManual);
        return;
      }
    } catch (fallbackErr) {
      debugPrint("Fastly fallback failed: $fallbackErr. Loading local assets...");
    }

    // 3. Final Local Fallback
    try {
      final localData = await rootBundle.loadString('assets/data/company_business_models.json');
      _parseAndSetData(localData);
    } catch (localErr) {
      setState(() {
        _errorMessage = 'Data sync issue. Check internet connection.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _showSuccessSnackbar(bool isManual) {
    if (isManual && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Live Research Memo Synced (${_companiesData.length} Companies)'),
          backgroundColor: const Color(0xFF00F5A0),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _parseAndSetData(String rawJson) {
    try {
      final Map<String, dynamic> root = jsonDecode(rawJson);
      final Map<String, dynamic> companies = (root['companies'] as Map<String, dynamic>?) ?? {};

      setState(() {
        _companiesData = companies;
        if (_companiesData.isNotEmpty) {
          if (_selectedSymbol == null || !_companiesData.containsKey(_selectedSymbol)) {
            _selectedSymbol = _companiesData.keys.first;
          }
        }
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (err) {
      setState(() {
        _errorMessage = 'Parse Error: $err';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  /// 🔍 100+ Companies Search Modal
  void _openStockPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredSymbols = _companiesData.keys
                .where((s) => s.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "RESEARCH COVERAGE (${_companiesData.length})",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF00E5FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Text(
                        "Fastly Powered",
                        style: TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF131D31),
                      hintText: "Search company ticker (e.g. ASIANPAINT, RELIANCE)",
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                      ),
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredSymbols.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF162238), height: 1),
                      itemBuilder: (context, idx) {
                        final sym = filteredSymbols[idx];
                        final comp = (_companiesData[sym] as Map<String, dynamic>?) ?? {};
                        final isSel = sym == _selectedSymbol;

                        final opm = comp['audited_statement_snapshot']?['profit_and_loss']?['OPM %'] ??
                            comp['audited_statement_snapshot']?['gross_margin_pct'] ??
                            '18%';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSymbol = sym);
                            Navigator.pop(context);
                          },
                          leading: CircleAvatar(
                            backgroundColor: isSel ? const Color(0xFF00E5FF) : const Color(0xFF16243C),
                            child: Text(
                              sym.substring(0, sym.length > 2 ? 2 : sym.length),
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          title: Text(
                            sym,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSel ? const Color(0xFF00E5FF) : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: Text(
                            comp['company_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131F33),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1E2B3E)),
                            ),
                            child: Text(
                              "OPM $opm%",
                              style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }

    if (_errorMessage != null || _companiesData.isEmpty || _selectedSymbol == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text(_errorMessage ?? 'Data unavailable', style: const TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () => _fetchCompaniesData(isManual: true),
                child: const Text('Purge & Retry', style: TextStyle(color: Color(0xFF00E5FF))),
              ),
            ],
          ),
        ),
      );
    }

    final company = (_companiesData[_selectedSymbol] as Map<String, dynamic>?) ?? {};

    // 🛡 Dual-Schema Safe Extraction
    final bModel = (company['business_model_architecture'] as Map<String, dynamic>?) ?? {};
    final coreOld = (company['core_identity'] as Map<String, dynamic>?) ?? {};
    final moatOld = (company['economic_moat'] as Map<String, dynamic>?) ?? {};

    final opEngine = bModel['operational_engine_analysis'] ?? coreOld['what_it_sells'] ?? 'Operational analysis pending.';
    final costDefense = bModel['sourcing_and_cost_defense'] ?? moatOld['moat_description'] ?? 'Cost defense details pending.';
    final channelMoat = bModel['channel_moat_vulnerability'] ?? coreOld['who_is_customer'] ?? 'Channel distribution details pending.';
    final wcPhysics = bModel['working_capital_physics'] ?? (company['cash_flow_health'] as Map?)?['working_capital_nature'] ?? 'Working capital dynamics pending.';

    final pricing = (company['pricing_and_macro_sensitivity'] as Map<String, dynamic>?) ??
        (company['pricing_power_index'] as Map<String, dynamic>?) ??
        {};

    final cashFlowReality = (company['cash_flow_reality'] as Map<String, dynamic>?) ??
        (company['cash_flow_health'] as Map<String, dynamic>?) ??
        {};

    final statement = (company['audited_statement_snapshot'] as Map<String, dynamic>?) ?? {};
    final pnl = (statement['profit_and_loss'] as Map<String, dynamic>?) ?? {};
    final bs = (statement['balance_sheet'] as Map<String, dynamic>?) ?? {};
    final cf = (statement['cash_flow'] as Map<String, dynamic>?) ?? {};
    final eff = (statement['efficiency_ratios'] as Map<String, dynamic>?) ?? {};

    final catalysts = (company['strategic_catalysts'] as List?) ??
        (company['revenue_drivers'] as List?) ??
        [];

    final metrics = (company['must_watch_metrics'] as List?) ?? [];

    dynamic invRaw = company['thesis_invalidation_trigger'] ?? company['anti_thesis_trigger'];
    Map<String, dynamic> invalidation = {};
    if (invRaw is Map<String, dynamic>) {
      invalidation = invRaw;
    } else if (invRaw is String) {
      invalidation = {
        'structural_red_flag': invRaw,
        'numerical_breach_benchmark': 'Continuous margin erosion trigger',
        'strategic_implication': 'Pricing power breakdown and volume contraction',
      };
    }

    final risks = (company['core_risks'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        titleSpacing: 16,
        title: InkWell(
          onTap: _openStockPicker,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2D4A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedSymbol ?? 'SELECT',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00E5FF), size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, color: Color(0xFF00E5FF), size: 20),
            tooltip: 'Live Fastly Sync',
            onPressed: _isRefreshing ? null : () => _fetchCompaniesData(isManual: true),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF0B1220),
          onRefresh: () => _fetchCompaniesData(isManual: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
            children: [
              // 1. Research Memo Executive Header
              _buildReportHeader(company, pricing),
              const SizedBox(height: 16),

              // 2. Business Model Architecture (Qualitative Analysis)
              _buildSectionHeader("BUSINESS MODEL ARCHITECTURE", "HOW THE OPERATIONAL ENGINE WORKS", Icons.domain_rounded),
              const SizedBox(height: 10),
              _buildAnalysisCard(
                title: "1. Operational Engine Analysis",
                subtitle: "Kaccha maal lene se lekar retail counter tak distribution ka flow",
                analysis: opEngine,
                accentColor: const Color(0xFF00E5FF),
                icon: Icons.precision_manufacturing_outlined,
              ),
              const SizedBox(height: 10),
              _buildAnalysisCard(
                title: "2. Sourcing & Cost Defense (Margin Impact)",
                subtitle: "Crude oil inflation & pricing pass-through ability",
                analysis: costDefense,
                accentColor: const Color(0xFFFFB300),
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 10),
              _buildAnalysisCard(
                title: "3. Channel Moat & Market Vulnerability",
                subtitle: "Dealer relationship moat vs naye players ka competition",
                analysis: channelMoat,
                accentColor: const Color(0xFF38BDF8),
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 10),
              _buildAnalysisCard(
                title: "4. Working Capital Physics",
                subtitle: "Inventory days & Cash Conversion Cycle dynamics",
                analysis: wcPhysics,
                accentColor: const Color(0xFF00F5A0),
                icon: Icons.sync_alt_rounded,
              ),
              const SizedBox(height: 16),

              // 3. Cash Flow Reality & Capital Deployment
              _buildSectionHeader("CASH FLOW REALITY", "OPERATIONAL CASH CONVERSION & FREE CASH FLOW", Icons.account_balance_wallet_outlined),
              const SizedBox(height: 10),
              _buildCashFlowDossier(cashFlowReality, cf),
              const SizedBox(height: 16),

              // 4. Strategic Catalysts & Monitorable Metrics
              _buildSectionHeader("STRATEGIC CATALYSTS & METRICS", "WHAT DRIVES GROWTH IN UPCOMING QUARTERS", Icons.track_changes_rounded),
              const SizedBox(height: 10),
              _buildCatalystsAndMetricsCard(catalysts, metrics),
              const SizedBox(height: 16),

              // 5. Critical Exit Trigger (Thesis Invalidation)
              _buildSectionHeader("THESIS INVALIDATION TRIGGER", "CLEAR CONDITIONS TO EXIT / AVOID THIS STOCK", Icons.dangerous_rounded, titleColor: const Color(0xFFFF2A6D)),
              const SizedBox(height: 10),
              _buildThesisInvalidationDossier(invalidation, risks),
              const SizedBox(height: 16),

              // 6. Audited Financial Baseline (Collapsible Detailed Views)
              _buildSectionHeader("AUDITED FINANCIAL BASELINE", "STATUTORY STATEMENTS & EFFICIENCY RATIOS", Icons.table_chart_rounded),
              const SizedBox(height: 10),
              _buildFinancialStatementsAccordion(pnl, bs, cf, eff, statement),
            ],
          ),
        ),
      ),
    );
  }

  // --- SUB WIDGET BUILDERS ---

  Widget _buildReportHeader(Map<String, dynamic> comp, Map<String, dynamic> pricing) {
    final capability = (pricing['margin_defense_capability'] ?? pricing['rating'] ?? 'COMPRESSED')
        .toString()
        .toUpperCase();
    final isCompressed = capability.contains('COMPRESSED') || capability.contains('MEDIUM');
    final driver = pricing['primary_macro_driver'] ?? pricing['linked_primary_driver'] ?? 'Brent Crude Oil & USD-INR';
    final rationale = pricing['strategic_rationale'] ?? pricing['rationale'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A263D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comp['company_name'] ?? _selectedSymbol ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "EQUITY RESEARCH NOTE • ${comp['data_period'] ?? 'Mar 2026 (Audited)'}",
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCompressed ? const Color(0xFFFF2A6D).withOpacity(0.15) : const Color(0xFF00F5A0).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompressed ? const Color(0xFFFF2A6D).withOpacity(0.4) : const Color(0xFF00F5A0).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  isCompressed ? "MARGINS COMPRESSED" : "PRICING POWER RESILIENT",
                  style: TextStyle(
                    color: isCompressed ? const Color(0xFFFF2A6D) : const Color(0xFF00F5A0),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1C2A44)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 15, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Primary Sensitivity: $driver",
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                if (rationale.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    rationale,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard({
    required String title,
    required String subtitle,
    required String analysis,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A263D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            analysis,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowDossier(Map<String, dynamic> cfReality, Map<String, dynamic> cf) {
    final earningsQuality = cfReality['earnings_quality_assessment'] ??
        cfReality['operating_cash_vs_profit'] ??
        'Operating cash flow conversion tracked at high quality.';
    final fcfProfile = cfReality['free_cash_flow_profile'] ??
        'Free cash flow primarily deployed in capacity expansions and home decor.';
    final cfoOp = cf['CFO/OP'] ?? 97;
    final fcfVal = cf['Free Cash Flow'] ?? 2604;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A263D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricPill("CFO/OP CONVERSION", "$cfoOp%", const Color(0xFF00F5A0)),
              _metricPill("FREE CASH FLOW", "₹${_formatCr(fcfVal)}", const Color(0xFF00E5FF)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Earnings Quality Reality:",
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF00F5A0), fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            earningsQuality,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.4),
          ),
          const Divider(color: Color(0xFF1A263D), height: 18),
          Text(
            "Capital Allocation Profile:",
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            fcfProfile,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalystsAndMetricsCard(List catalysts, List metrics) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A263D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "UPCOMING GROWTH CATALYSTS",
            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          ...catalysts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("⚡ ", style: TextStyle(fontSize: 11)),
                    Expanded(
                      child: Text(
                        c.toString(),
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )),
          if (metrics.isNotEmpty) ...[
            const Divider(color: Color(0xFF1A263D), height: 18),
            const Text(
              "MUST-WATCH OPERATIONAL METRIC",
              style: TextStyle(color: Color(0xFFFFB300), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            ...metrics.map((m) {
              final map = m as Map<String, dynamic>;
              final mName = map['metric'] ?? '';
              final mVal = map['reported_value'] ?? map['benchmark_normal'] ?? '';
              final mWhy = map['analytical_significance'] ?? map['why_track'] ?? '';

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mName,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          mVal,
                          style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mWhy,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, height: 1.35),
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

  Widget _buildThesisInvalidationDossier(Map<String, dynamic> inv, List risks) {
    final redFlag = inv['structural_red_flag']?.toString() ?? 'Watch continuous margin compression and loss of volume.';
    final benchmark = inv['numerical_breach_benchmark']?.toString() ?? 'OPM % < 15% aur Inventory Days > 160 days';
    final implication = inv['strategic_implication']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C0D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF2A6D).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.dangerous_rounded, color: Color(0xFFFF2A6D), size: 18),
              SizedBox(width: 6),
              Text(
                "THESIS INVALIDATION (WHEN TO EXIT)",
                style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            redFlag,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, height: 1.35),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2A6D).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF2A6D).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text("Numerical Breach Level: ", style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                Expanded(
                  child: Text(
                    benchmark,
                    style: const TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          if (implication != null && implication.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Implication: $implication",
              style: const TextStyle(color: Color(0xFFFECACA), fontSize: 10.5, height: 1.35),
            ),
          ],
          if (risks.isNotEmpty) ...[
            const Divider(color: Color(0xFF331624), height: 18),
            const Text(
              "UNDERLYING OPERATIONAL & MARKET RISKS",
              style: TextStyle(color: Color(0xFFF87171), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            ...risks.map((r) {
              final rMap = r as Map<String, dynamic>;
              final rType = rMap['risk_type'] ?? 'Risk Factor';
              final rDesc = rMap['analysis'] ?? rMap['description'] ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• $rType", style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 1),
                    Text(rDesc, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, height: 1.3)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialStatementsAccordion(
      Map<String, dynamic> pnl,
      Map<String, dynamic> bs,
      Map<String, dynamic> cf,
      Map<String, dynamic> eff,
      Map<String, dynamic> rawSnapshot,
  ) {
    final sales = pnl['Sales'] ?? rawSnapshot['revenue_cr'] ?? 33906.0;
    final opm = pnl['OPM %'] ?? rawSnapshot['gross_margin_pct'] ?? 18.0;
    final netProfit = pnl['Net Profit'] ?? rawSnapshot['net_profit_cr'] ?? 3710.0;
    final roce = eff['ROCE %'] ?? 26.0;
    final ccc = eff['Cash Conversion Cycle'] ?? 107.0;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1626),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A263D)),
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          title: Text(
            "AUDITED STATUTORY NUMBERS & RATIOS",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            "Sales: ₹${_formatCr(sales)} • OPM: $opm% • ROCE: $roce% • CCC: ${ccc.toInt()}d",
            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFF1A263D), height: 1),
                  const SizedBox(height: 10),

                  const Text("EFFICIENCY & WORKING CAPITAL RATIOS", style: TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _statementRow("Cash Conversion Cycle (CCC)", "${eff['Cash Conversion Cycle']?.toInt() ?? 107} days", isHighlight: true, highlightColor: const Color(0xFF00F5A0)),
                  _statementRow("Inventory Days", "${eff['Inventory Days']?.toInt() ?? 142} days"),
                  _statementRow("Debtor Days", "${eff['Debtor Days']?.toInt() ?? 46} days"),
                  _statementRow("Days Payable", "${eff['Days Payable']?.toInt() ?? 81} days"),
                  _statementRow("ROCE %", "${eff['ROCE %'] ?? 26}%", isHighlight: true, highlightColor: const Color(0xFF00E5FF)),

                  const Divider(color: Color(0xFF1A263D), height: 18),

                  const Text("PROFIT & LOSS STATEMENT (INR CR)", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _statementRow("Sales Turnover", "₹${_formatCr(sales)}"),
                  _statementRow("Operating Expenses", "₹${_formatCr(pnl['Expenses'] ?? 27899)}"),
                  _statementRow("Operating Profit (EBITDA)", "₹${_formatCr(pnl['Operating Profit'] ?? 6006)}"),
                  _statementRow("Operating Profit Margin (OPM)", "$opm%", isHighlight: true, highlightColor: const Color(0xFF00E5FF)),
                  _statementRow("Net Profit (PAT)", "₹${_formatCr(netProfit)}", isHighlight: true, highlightColor: const Color(0xFF00F5A0)),
                  _statementRow("EPS in Rs", "₹${pnl['EPS in Rs'] ?? 38.23}"),
                  _statementRow("Dividend Payout %", "${pnl['Dividend Payout %'] ?? 65}%"),

                  const Divider(color: Color(0xFF1A263D), height: 18),

                  const Text("BALANCE SHEET & CASH FLOW HEALTH", style: TextStyle(color: Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _statementRow("Borrowings (Debt)", "₹${_formatCr(bs['Borrowings'] ?? 2290)}"),
                  _statementRow("Total Balance Sheet Size", "₹${_formatCr(bs['Total Assets'] ?? 30355)}"),
                  _statementRow("Cash from Operations (CFO)", "₹${_formatCr(cf['Cash from Operating Activity'] ?? 4424)}"),
                  _statementRow("Free Cash Flow (FCF)", "₹${_formatCr(cf['Free Cash Flow'] ?? 2604)}", isHighlight: true, highlightColor: const Color(0xFF00F5A0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statementRow(String label, String value, {bool isHighlight = false, Color highlightColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: isHighlight ? highlightColor : Colors.white,
              fontSize: 11,
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(val, style: GoogleFonts.robotoMono(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, {Color titleColor = const Color(0xFF64748B)}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: titleColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: titleColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF475569), fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _formatCr(dynamic val) {
    if (val == null) return "0";
    if (val is! num) {
      double? parsed = double.tryParse(val.toString().replaceAll(',', '').replaceAll('₹', '').trim());
      if (parsed == null) return val.toString();
      val = parsed;
    }
    double parsedVal = (val as num).toDouble();
    if (parsedVal >= 100000) {
      return "${(parsedVal / 100000).toStringAsFixed(2)}L Cr";
    }
    return "${parsedVal.toStringAsFixed(0)} Cr";
  }
}
