import 'dart:convert';
import 'dart:math';
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
  final String _cdnUrl =
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

  Future<void> _fetchCompaniesData({bool isManual = false}) async {
    if (isManual) setState(() => _isRefreshing = true);

    final cacheBuster = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final requestUri = Uri.parse('$_cdnUrl?v=$cacheBuster');

    try {
      final res = await http.get(
        requestUri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 14));

      if (res.statusCode == 200) {
        _parseAndSetData(res.body);
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Synced Latest Live Data (${_companiesData.length} Companies)'),
              backgroundColor: const Color(0xFF00F5A0),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      throw Exception("HTTP ${res.statusCode}");
    } catch (e) {
      debugPrint("Remote fetch notice: $e");
      try {
        final localData = await rootBundle.loadString('assets/data/company_business_models.json');
        _parseAndSetData(localData);
      } catch (_) {
        setState(() {
          _errorMessage = 'Data sync failed';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
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

  void _openStockPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
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
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 36,
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
                        "SELECT COMPANY (${_companiesData.length})",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Text(
                        "Search & Filter",
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF162032),
                      hintText: "Search ticker (e.g. ASIANPAINT, RELIANCE)",
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF25334A)),
                      ),
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredSymbols.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E2B3E), height: 1),
                      itemBuilder: (context, idx) {
                        final sym = filteredSymbols[idx];
                        final comp = (_companiesData[sym] as Map<String, dynamic>?) ?? {};
                        final isSel = sym == _selectedSymbol;
                        final opm = comp['audited_statement_snapshot']?['profit_and_loss']?['OPM %'] ?? 'N/A';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSymbol = sym);
                            Navigator.pop(context);
                          },
                          leading: CircleAvatar(
                            backgroundColor: isSel ? const Color(0xFF00E5FF) : const Color(0xFF1A263D),
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
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            comp['company_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141F33),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "OPM $opm%",
                              style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 10, fontWeight: FontWeight.bold),
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
        backgroundColor: Color(0xFF090D16),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }

    if (_errorMessage != null || _companiesData.isEmpty || _selectedSymbol == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text(_errorMessage ?? 'Data unavailable', style: const TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () => _fetchCompaniesData(),
                child: const Text('Retry', style: TextStyle(color: Color(0xFF00E5FF))),
              ),
            ],
          ),
        ),
      );
    }

    final company = (_companiesData[_selectedSymbol] as Map<String, dynamic>?) ?? {};
    final bModel = (company['business_model_architecture'] as Map<String, dynamic>?) ?? {};
    final pricing = (company['pricing_and_macro_sensitivity'] as Map<String, dynamic>?) ?? {};
    final cashFlowReality = (company['cash_flow_reality'] as Map<String, dynamic>?) ?? {};
    final statement = (company['audited_statement_snapshot'] as Map<String, dynamic>?) ?? {};
    final pnl = (statement['profit_and_loss'] as Map<String, dynamic>?) ?? {};
    final balanceSheet = (statement['balance_sheet'] as Map<String, dynamic>?) ?? {};
    final cf = (statement['cash_flow'] as Map<String, dynamic>?) ?? {};
    final eff = (statement['efficiency_ratios'] as Map<String, dynamic>?) ?? {};
    final catalysts = (company['strategic_catalysts'] as List?) ?? [];
    final metrics = (company['must_watch_metrics'] as List?) ?? [];
    final invalidation = (company['thesis_invalidation_trigger'] as Map<String, dynamic>?) ?? {};
    final risks = (company['core_risks'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        titleSpacing: 16,
        title: InkWell(
          onTap: _openStockPicker,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF162032),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF25334A)),
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
          backgroundColor: const Color(0xFF0F1726),
          onRefresh: () => _fetchCompaniesData(isManual: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
            children: [
              // 1. Executive Status Header
              _buildExecutiveHeader(company, pricing),
              const SizedBox(height: 14),

              // 2. Business Model Architecture Deep Dive
              _buildSectionTitle("BUSINESS MODEL ARCHITECTURE", Icons.architecture_rounded),
              const SizedBox(height: 8),
              _buildArchitectureCard(bModel),
              const SizedBox(height: 14),

              // 3. Efficiency & Financial Health Bento Strip
              _buildSectionTitle("KEY OPERATIONAL EFFICIENCIES", Icons.speed_rounded),
              const SizedBox(height: 8),
              _buildEfficiencyStrip(eff, pnl, cf),
              const SizedBox(height: 14),

              // 4. Complete Audited Statements (P&L, Balance Sheet, Cash Flow)
              _buildSectionTitle("AUDITED STATUTORY STATEMENTS (MAR 2026)", Icons.account_balance_rounded),
              const SizedBox(height: 8),
              _buildStatementsTabContainer(pnl, balanceSheet, cf, cashFlowReality),
              const SizedBox(height: 14),

              // 5. Strategic Catalysts & Must-Watch Metric
              _buildSectionTitle("GROWTH CATALYSTS & MONITORABLES", Icons.track_changes_rounded),
              const SizedBox(height: 8),
              _buildCatalystsAndMetrics(catalysts, metrics),
              const SizedBox(height: 14),

              // 6. Thesis Invalidation & Core Risks
              _buildSectionTitle("CRITICAL EXIT TRIGGERS & RISKS", Icons.warning_amber_rounded, color: const Color(0xFFFF2A6D)),
              const SizedBox(height: 8),
              _buildThesisAndRisks(invalidation, risks),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION WIDGETS ---

  Widget _buildExecutiveHeader(Map<String, dynamic> comp, Map<String, dynamic> pricing) {
    final capability = (pricing['margin_defense_capability'] ?? 'COMPRESSED').toString().toUpperCase();
    final isCompressed = capability.contains('COMPRESSED');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2B3E)),
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
                    Text(
                      comp['company_name'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      comp['data_period'] ?? 'Audited Statutory',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
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
                  isCompressed ? "MARGINS COMPRESSED" : "MARGINS RESILIENT",
                  style: TextStyle(
                    color: isCompressed ? const Color(0xFFFF2A6D) : const Color(0xFF00F5A0),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF141F33),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_rounded, size: 14, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Primary Driver: ${pricing['primary_macro_driver'] ?? 'N/A'}",
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  pricing['strategic_rationale'] ?? '',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureCard(Map<String, dynamic> b) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        children: [
          _archItem("Operational Engine", b['operational_engine_analysis'], Icons.precision_manufacturing_outlined, const Color(0xFF00E5FF)),
          const Divider(color: Color(0xFF1E2B3E), height: 18),
          _archItem("Sourcing & Cost Defense", b['sourcing_and_cost_defense'], Icons.shield_outlined, const Color(0xFFFF9800)),
          const Divider(color: Color(0xFF1E2B3E), height: 18),
          _archItem("Channel Moat & Vulnerability", b['channel_moat_vulnerability'], Icons.storefront_outlined, const Color(0xFF38BDF8)),
          const Divider(color: Color(0xFF1E2B3E), height: 18),
          _archItem("Working Capital Physics", b['working_capital_physics'], Icons.sync_alt_rounded, const Color(0xFF00F5A0)),
        ],
      ),
    );
  }

  Widget _archItem(String title, dynamic text, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                text?.toString() ?? 'N/A',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEfficiencyStrip(Map<String, dynamic> eff, Map<String, dynamic> pnl, Map<String, dynamic> cf) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("ROCE", "${eff['ROCE %'] ?? 0}%", const Color(0xFF00F5A0)),
          _divider(),
          _statItem("CCC", "${eff['Cash Conversion Cycle']?.toInt() ?? 0} d", const Color(0xFF00E5FF)),
          _divider(),
          _statItem("INVENTORY", "${eff['Inventory Days']?.toInt() ?? 0} d", const Color(0xFFFF9800)),
          _divider(),
          _statItem("DEBTOR", "${eff['Debtor Days']?.toInt() ?? 0} d", Colors.white),
          _divider(),
          _statItem("PAYABLE", "${eff['Days Payable']?.toInt() ?? 0} d", const Color(0xFF38BDF8)),
        ],
      ),
    );
  }

  Widget _buildStatementsTabContainer(
      Map<String, dynamic> pnl,
      Map<String, dynamic> bs,
      Map<String, dynamic> cf,
      Map<String, dynamic> cfReality,
      ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Profit & Loss Summary
          const Text("PROFIT & LOSS STATEMENT", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _statementRow("Sales Turnover", "₹${_formatCr(pnl['Sales'])}"),
          _statementRow("Operating Expenses", "₹${_formatCr(pnl['Expenses'])}"),
          _statementRow("Operating Profit (EBITDA)", "₹${_formatCr(pnl['Operating Profit'])}"),
          _statementRow("Operating Profit Margin (OPM)", "${pnl['OPM %']}%", isHighlight: true, highlightColor: const Color(0xFF00E5FF)),
          _statementRow("Interest Expenses", "₹${_formatCr(pnl['Interest'])}"),
          _statementRow("Depreciation", "₹${_formatCr(pnl['Depreciation'])}"),
          _statementRow("Net Profit After Tax (PAT)", "₹${_formatCr(pnl['Net Profit'])}", isHighlight: true, highlightColor: const Color(0xFF00F5A0)),
          _statementRow("Earnings Per Share (EPS)", "₹${pnl['EPS in Rs'] ?? 0}"),
          _statementRow("Dividend Payout %", "${pnl['Dividend Payout %'] ?? 0}%"),

          const Divider(color: Color(0xFF1E2B3E), height: 20),

          // 2. Cash Flow Health
          const Text("CASH FLOW REALITY & CAPITAL EXPENDITURE", style: TextStyle(color: Color(0xFF00F5A0), fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _statementRow("Cash from Operations (CFO)", "₹${_formatCr(cf['Cash from Operating Activity'])}"),
          _statementRow("Cash from Investing (Capex)", "₹${_formatCr(cf['Cash from Investing Activity'])}"),
          _statementRow("Cash from Financing", "₹${_formatCr(cf['Cash from Financing Activity'])}"),
          _statementRow("Free Cash Flow (FCF)", "₹${_formatCr(cf['Free Cash Flow'])}", isHighlight: true, highlightColor: const Color(0xFF00F5A0)),
          _statementRow("CFO to Operating Profit Conversion", "${cf['CFO/OP'] ?? 97}%", isHighlight: true, highlightColor: const Color(0xFFFF9800)),
          const SizedBox(height: 4),
          Text("FCF Profile: ${cfReality['free_cash_flow_profile'] ?? ''}", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontStyle: FontStyle.italic)),

          const Divider(color: Color(0xFF1E2B3E), height: 20),

          // 3. Balance Sheet Health
          const Text("BALANCE SHEET INTEGRITY", style: TextStyle(color: Color(0xFFFF9800), fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _statementRow("Equity Capital + Reserves", "₹${_formatCr((bs['Equity Capital'] ?? 0) + (bs['Reserves'] ?? 0))}"),
          _statementRow("Total Borrowings (Debt)", "₹${_formatCr(bs['Borrowings'])}", isHighlight: true, highlightColor: const Color(0xFFFF9800)),
          _statementRow("Fixed Assets + CWIP", "₹${_formatCr((bs['Fixed Assets'] ?? 0) + (bs['CWIP'] ?? 0))}"),
          _statementRow("Investments", "₹${_formatCr(bs['Investments'])}"),
          _statementRow("Total Balance Sheet Size", "₹${_formatCr(bs['Total Assets'])}"),
        ],
      ),
    );
  }

  Widget _statementRow(String label, String value, {bool isHighlight = false, Color highlightColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: isHighlight ? highlightColor : Colors.white,
              fontSize: 11.5,
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalystsAndMetrics(List catalysts, List metrics) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("STRATEGIC GROWTH CATALYSTS", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...catalysts.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("⚡ ", style: TextStyle(fontSize: 10)),
                Expanded(child: Text(c.toString(), style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.35))),
              ],
            ),
          )),
          const Divider(color: Color(0xFF1E2B3E), height: 18),
          const Text("MUST-WATCH QUARTERLY MONITORABLE", style: TextStyle(color: Color(0xFFFF9800), fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...metrics.map((m) {
            final mMap = m as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF141F33),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(mMap['metric'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text(mMap['reported_value'] ?? '', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(mMap['analytical_significance'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildThesisAndRisks(Map<String, dynamic> inv, List risks) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0E18),
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
                "THESIS INVALIDATION (EXIT / AVOID BENCHMARK)",
                style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inv['structural_red_flag']?.toString() ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold, height: 1.35),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2A6D).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Breach Benchmark: ", style: TextStyle(color: Colors.white70, fontSize: 10)),
                Flexible(
                  child: Text(
                    inv['numerical_breach_benchmark']?.toString() ?? 'N/A',
                    style: const TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          if (inv['strategic_implication'] != null) ...[
            const SizedBox(height: 6),
            Text(
              "Implication: ${inv['strategic_implication']}",
              style: const TextStyle(color: Color(0xFFFECACA), fontSize: 10.5, height: 1.3),
            ),
          ],
          if (risks.isNotEmpty) ...[
            const Divider(color: Color(0xFF3B1D24), height: 18),
            const Text("CORE MACRO & BUSINESS RISKS", style: TextStyle(color: Color(0xFFF87171), fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...risks.map((r) {
              final rMap = r as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ${rMap['risk_type'] ?? ''}", style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    Text(rMap['analysis'] ?? '', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10, height: 1.3)),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {Color color = const Color(0xFF64748B)}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(val, style: GoogleFonts.robotoMono(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _divider() => Container(height: 24, width: 1, color: const Color(0xFF1E2B3E));

  String _formatCr(dynamic val) {
    if (val == null) return "0";
    if (val is! num) {
      double? parsed = double.tryParse(val.toString().replaceAll(',', ''));
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
