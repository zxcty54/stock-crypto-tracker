import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class CompanyIntelligenceScreen extends StatefulWidget {
  const CompanyIntelligenceScreen({super.key});

  @override
  State<CompanyIntelligenceScreen> createState() => _CompanyIntelligenceScreenState();
}

class _CompanyIntelligenceScreenState extends State<CompanyIntelligenceScreen> {
  // 🌐 Aapka Target Fastly CDN Endpoint
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
    if (isManual) {
      setState(() => _isRefreshing = true);
    }

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
              content: Text('⚡ Sync Complete! ${_companiesData.length} Companies Loaded.'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      throw Exception("Fastly returned HTTP ${res.statusCode}");
    } catch (e) {
      debugPrint("Remote fetch error: $e. Falling back to local offline assets...");
      try {
        final localData = await rootBundle.loadString('assets/data/company_business_models.json');
        _parseAndSetData(localData);
      } catch (localErr) {
        setState(() {
          _errorMessage = 'Data sync failed (Network unavailable & offline file missing)';
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
        _errorMessage = 'JSON Parse Error: $err';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B12),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }

    if (_errorMessage != null || _companiesData.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B12),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text(_errorMessage ?? 'No company data available',
                  style: const TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchCompaniesData();
                },
                child: const Text('Retry Connection', style: TextStyle(color: Color(0xFF00E5FF))),
              ),
            ],
          ),
        ),
      );
    }

    final company = (_selectedSymbol != null && _companiesData.containsKey(_selectedSymbol))
        ? (_companiesData[_selectedSymbol] as Map<String, dynamic>)
        : (_companiesData.values.first as Map<String, dynamic>);

    final core = company['core_identity'] ?? {};
    final moat = company['economic_moat'] ?? {};
    final pricingPower = company['pricing_power_index'] ?? {};
    final cashFlow = company['cash_flow_health'] ?? {};
    final financials = company['audited_statement_snapshot'] ?? {};
    final drivers = (company['revenue_drivers'] as List?) ?? [];
    final metrics = (company['must_watch_metrics'] as List?) ?? [];
    final antiThesis = company['anti_thesis_trigger'] ?? '';
    final risks = (company['core_risks'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        title: const Text(
          'COMPANY BUSINESS INTELLIGENCE',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
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
            tooltip: 'Live Refresh Data',
            onPressed: _isRefreshing ? null : () => _fetchCompaniesData(isManual: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStockSelector(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF00E5FF),
                backgroundColor: const Color(0xFF0F1726),
                onRefresh: () => _fetchCompaniesData(isManual: true),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
                  children: [
                    _buildIdentityCard(company, moat, core),
                    const SizedBox(height: 12),
                    _buildFinancialGrid(financials, cashFlow),
                    const SizedBox(height: 12),
                    _buildPricingPowerCard(pricingPower),
                    const SizedBox(height: 12),
                    _buildDriversAndMetricsCard(drivers, metrics),
                    const SizedBox(height: 12),
                    _buildRiskAndAntiThesisCard(risks, antiThesis),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1726),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2B3E))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _companiesData.keys.map((sym) {
          final isSel = _selectedSymbol == sym;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(sym),
              selected: isSel,
              selectedColor: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF162032),
              labelStyle: TextStyle(
                color: isSel ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSel ? const Color(0xFF00E5FF) : const Color(0xFF25334A),
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedSymbol = sym);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIdentityCard(Map<String, dynamic> company, Map<String, dynamic> moat, Map<String, dynamic> core) {
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
                      company['company_name'] ?? _selectedSymbol ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      company['data_period'] ?? 'Audited Financials',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 4),
                    Text(
                      moat['moat_type'] ?? 'Economic Moat',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            moat['moat_description'] ?? '',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.35),
          ),
          const Divider(color: Color(0xFF1E2B3E), height: 18),
          _detailRow(Icons.inventory_2_outlined, "What it Sells", core['what_it_sells'] ?? ''),
          const SizedBox(height: 8),
          _detailRow(Icons.group_outlined, "Customer Base", core['who_is_customer'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildFinancialGrid(Map<String, dynamic> f, Map<String, dynamic> cf) {
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
              const Text(
                'AUDITED STATEMENT SNAPSHOT',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Cash Flow: ${cf['free_cash_flow_quality'] ?? 'High'}',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricTile("Revenue", "₹${_formatCr(f['revenue_cr'])}", Colors.white),
              _metricTile("Gross Margin", "${f['gross_margin_pct'] ?? 'N/A'}", const Color(0xFF00E5FF)),
              _metricTile("Net Margin", "${f['net_margin_pct'] ?? 'N/A'}", const Color(0xFF10B981)),
              _metricTile("D/E Ratio", "${f['debt_to_equity'] ?? 'N/A'}", const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF162032),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cf['operating_cash_vs_profit'] ?? '',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingPowerCard(Map<String, dynamic> pp) {
    final rating = pp['rating'] ?? 'MEDIUM';
    final isHigh = rating == 'HIGH';

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
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 15, color: Color(0xFF00E5FF)),
                  SizedBox(width: 6),
                  Text(
                    'PRICING POWER & PASS-THROUGH',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isHigh ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rating (${pp['pass_through_speed'] ?? 'N/A'})',
                  style: TextStyle(
                    color: isHigh ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pp['rationale'] ?? '',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversAndMetricsCard(List drivers, List metrics) {
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
          const Text(
            'KEY GROWTH DRIVERS',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          ...drivers.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 14)),
                    Expanded(
                      child: Text(
                        d.toString(),
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )),
          if (metrics.isNotEmpty) ...[
            const Divider(color: Color(0xFF1E2B3E), height: 18),
            const Text(
              'MUST-WATCH OPERATIONAL METRICS',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            ...metrics.map((m) {
              final map = m as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          map['metric'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          map['benchmark_normal'] ?? '',
                          style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      map['why_track'] ?? '',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
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

  Widget _buildRiskAndAntiThesisCard(List risks, String antiThesis) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1116),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 6),
              Text(
                'ANTI-THESIS TRIGGER (WHEN TO EXIT / AVOID)',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            antiThesis,
            style: const TextStyle(color: Color(0xFFFECACA), fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600),
          ),
          if (risks.isNotEmpty) ...[
            const Divider(color: Color(0xFF3B1D24), height: 18),
            ...risks.map((r) {
              final rMap = r as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rMap['risk_type'] ?? 'Risk',
                      style: const TextStyle(color: Color(0xFFF87171), fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rMap['description'] ?? '',
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 10.5, height: 1.3),
                    ),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$title: ',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: body,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ✅ Fixed naming conflict: 'parsedVal' used instead of 'num'
  String _formatCr(dynamic val) {
    if (val == null) return "0";
    double parsedVal = (val as num).toDouble();
    if (parsedVal >= 100000) {
      return "${(parsedVal / 100000).toStringAsFixed(2)}L Cr";
    }
    return "${parsedVal.toStringAsFixed(0)} Cr";
  }
}
