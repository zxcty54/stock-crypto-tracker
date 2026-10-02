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

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final headers = {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };

    try {
      final res = await http
          .get(Uri.parse('$_cdnUrl?ts=$timestamp'), headers: headers)
          .timeout(const Duration(seconds: 14));

      if (res.statusCode == 200) {
        _parseAndSetData(res.body);
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Loaded ${_companiesData.length} Companies'),
              backgroundColor: const Color(0xFF00F5A0),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      throw Exception("HTTP ${res.statusCode}");
    } catch (e) {
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
                      Text(
                        "100+ Scale Ready",
                        style: TextStyle(color: const Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Input
                  TextField(
                    autofocus: false,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF162032),
                      hintText: "Search by ticker (e.g. ASIANPAINT, RELIANCE)",
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
                        final comp = _companiesData[sym] as Map<String, dynamic>;
                        final isSel = sym == _selectedSymbol;
                        final opm = comp['audited_statement_snapshot']?['profit_and_loss']?['OPM %'];

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

    if (_errorMessage != null || _companiesData.isEmpty) {
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

    final company = _companiesData[_selectedSymbol] as Map<String, dynamic>;
    final bModel = company['business_model_architecture'] ?? {};
    final pricing = company['pricing_and_macro_sensitivity'] ?? {};
    final cashFlow = company['cash_flow_reality'] ?? {};
    final statement = company['audited_statement_snapshot'] ?? {};
    final pnl = (statement['profit_and_loss'] as Map<String, dynamic>?) ?? {};
    final eff = (statement['efficiency_ratios'] as Map<String, dynamic>?) ?? {};
    final invalidation = company['thesis_invalidation_trigger'] ?? {};

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
              // 🌟 HERO LEVEL 1: High-Contrast Executive Status
              _buildExecutiveSummaryBanner(company, pricing),
              const SizedBox(height: 12),

              // 🌟 HERO LEVEL 2: Financial Efficiency Bento Grid (4 Core Numbers)
              _buildFinancialBentoStrip(pnl, eff),
              const SizedBox(height: 14),

              // 🌟 TIER 2: 4-Pillar Business Reality (Bento 2x2 Grid)
              _buildSectionTitle("BUSINESS MODEL MECHANICS", Icons.account_tree_outlined),
              const SizedBox(height: 8),
              _buildPillarsBento(bModel, cashFlow),
              const SizedBox(height: 14),

              // 🌟 TIER 3: Anti-Thesis / Sell Trigger (Most Important Warning)
              _buildSectionTitle("CRITICAL EXIT CONDITION", Icons.warning_amber_rounded, color: const Color(0xFFFF2A6D)),
              const SizedBox(height: 8),
              _buildThesisInvalidationBox(invalidation),
            ],
          ),
        ),
      ),
    );
  }

  // --- COMPONENT LEVEL BUILDERS ---

  Widget _buildExecutiveSummaryBanner(Map<String, dynamic> company, Map<String, dynamic> pricing) {
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
                      company['company_name'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      company['data_period'] ?? 'Audited Statutory',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Status Badge
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
                  isCompressed ? "MARGINS COMPRESSED" : "MARGINS HEALTHY",
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pricing['strategic_rationale'] ?? '',
                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialBentoStrip(Map<String, dynamic> pnl, Map<String, dynamic> eff) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("SALES", "₹${_formatCr(pnl['Sales'])}", Colors.white),
          _divider(),
          _statItem("OPM", "${pnl['OPM %'] ?? 0}%", const Color(0xFF00E5FF)),
          _divider(),
          _statItem("ROCE", "${eff['ROCE %'] ?? 0}%", const Color(0xFF00F5A0)),
          _divider(),
          _statItem("CCC", "${eff['Cash Conversion Cycle']?.toInt() ?? 0}d", const Color(0xFFFF9800)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(val, style: GoogleFonts.robotoMono(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _divider() => Container(height: 24, width: 1, color: const Color(0xFF1E2B3E));

  Widget _buildPillarsBento(Map<String, dynamic> b, Map<String, dynamic> cf) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _bentoCard("Factory Engine", b['operational_engine_analysis'], Icons.precision_manufacturing_outlined, const Color(0xFF00E5FF))),
            const SizedBox(width: 8),
            Expanded(child: _bentoCard("Cost Defense", b['sourcing_and_cost_defense'], Icons.shield_outlined, const Color(0xFFFF9800))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _bentoCard("Channel Moat", b['channel_moat_vulnerability'], Icons.storefront_outlined, const Color(0xFF38BDF8))),
            const SizedBox(width: 8),
            Expanded(child: _bentoCard("Cash Conversion", cf['earnings_quality_assessment'], Icons.account_balance_wallet_outlined, const Color(0xFF00F5A0))),
          ],
        ),
      ],
    );
  }

  Widget _bentoCard(String title, dynamic text, IconData icon, Color accent) {
    return Container(
      height: 145,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 5),
              Text(title, style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                text?.toString() ?? 'N/A',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThesisInvalidationBox(Map<String, dynamic> inv) {
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
                "SELL TRIGGER (ANTI-THESIS)",
                style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inv['structural_red_flag'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.35),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2A6D).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Breach Level: ", style: TextStyle(color: Colors.white70, fontSize: 10)),
                Text(
                  inv['numerical_breach_benchmark'] ?? 'N/A',
                  style: const TextStyle(color: Color(0xFFFF2A6D), fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (inv['strategic_implication'] != null) ...[
            const SizedBox(height: 8),
            Text(
              "Implication: ${inv['strategic_implication']}",
              style: const TextStyle(color: Color(0xFFFECACA), fontSize: 10.5, height: 1.3),
            ),
          ],
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

  String _formatCr(dynamic val) {
    if (val == null) return "0";
    double parsedVal = (val as num).toDouble();
    if (parsedVal >= 100000) {
      return "${(parsedVal / 100000).toStringAsFixed(2)}L Cr";
    }
    return "${parsedVal.toStringAsFixed(0)} Cr";
  }
}
