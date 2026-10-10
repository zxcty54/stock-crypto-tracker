import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OrderRadarDashboardWidget extends StatefulWidget {
  final String workerBaseUrl;

  const OrderRadarDashboardWidget({
    Key? key,
    this.workerBaseUrl = "https://stock-models-api.nitesh-skyhigh.workers.dev",
  }) : super(key: key);

  @override
  State<OrderRadarDashboardWidget> createState() => _OrderRadarDashboardWidgetState();
}

class _OrderRadarDashboardWidgetState extends State<OrderRadarDashboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRadarData();
  }

  Future<void> _loadRadarData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final endpoint = "${widget.workerBaseUrl}/?type=radar";
      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _reportData = decoded;
          _isLoading = false;
        });
      } else {
        throw Exception("Server returned HTTP ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load live radar data: $e";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 44),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadRadarData,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Retry Live Fetch"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    // FIXED: prime_hidden_gems aur hidden_gems dono keys ko check karega
    final hiddenGems = (_reportData?['prime_hidden_gems'] as List?) ??
        (_reportData?['hidden_gems'] as List?) ??
        [];
    final allOrders = _reportData?['all_tracked_orders'] as List? ?? [];
    final turnaroundGems = _reportData?['turnaround_sales_gems'] as List? ?? [];
    final lastUpdated = _reportData?['last_updated'] ?? "N/A";

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🎯 Order & Turnaround Radar",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              "Updated: $lastUpdated | Live Server",
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: "Live Refresh",
            onPressed: _loadRadarData,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: "🔥 Gems (${hiddenGems.length})"),
            Tab(text: "📋 Orders (${allOrders.length})"),
            Tab(text: "🚀 Turnaround (${turnaroundGems.length})"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderListView(hiddenGems, isHiddenGemTab: true),
          _buildOrderListView(allOrders, isHiddenGemTab: false),
          _buildTurnaroundListView(turnaroundGems),
        ],
      ),
    );
  }

  Widget _buildOrderListView(List items, {required bool isHiddenGemTab}) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isHiddenGemTab
              ? "No prime hidden gems matching runway & debt guards currently."
              : "No tracked order records available.",
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: items.length + 1, // +1 for SEBI Disclaimer at bottom
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _buildSebiDisclaimer();
        }

        final item = items[index];
        final symbol = item['symbol'] ?? "";
        final companyName = item['company_name'] ?? symbol;
        final mcap = (item['market_cap_cr'] ?? 0).toDouble();
        final orderBook = (item['pending_order_book_cr'] ?? 0).toDouble();
        final multiple = (item['order_to_mcap_multiple'] ?? 0).toDouble();
        final debtToMcap = (item['debt_to_mcap'] ?? 0).toDouble();
        final runwayYears = item['revenue_runway_years'] ?? item['execution_runway_years'] ?? "";
        final classification = item['classification'] ?? "";
        final isPaperTrap = classification == "PAPER_BACKLOG_TRAP";
        final thesis = item['thesis'] ?? "";
        final docUrl = item['source_doc'] ?? "";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPaperTrap
                  ? Colors.redAccent.withOpacity(0.5)
                  : (isHiddenGemTab ? const Color(0xFFF59E0B) : const Color(0xFF334155)),
              width: (isHiddenGemTab || isPaperTrap) ? 1.4 : 1.0,
            ),
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
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (runwayYears.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPaperTrap
                                      ? Colors.redAccent.withOpacity(0.15)
                                      : const Color(0xFF0284C7).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isPaperTrap ? "⚠️ $runwayYears" : "⏳ $runwayYears Runway",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isPaperTrap ? Colors.redAccent : const Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaperTrap
                          ? Colors.redAccent.withOpacity(0.2)
                          : (multiple >= 1.0
                              ? const Color(0xFF16A34A).withOpacity(0.2)
                              : const Color(0xFF38BDF8).withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPaperTrap
                            ? Colors.redAccent
                            : (multiple >= 1.0 ? const Color(0xFF22C55E) : const Color(0xFF38BDF8)),
                      ),
                    ),
                    child: Text(
                      "${multiple}x MCap",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPaperTrap
                            ? Colors.redAccent
                            : (multiple >= 1.0 ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricTile("Order Book", "₹${orderBook.toStringAsFixed(0)} Cr", Colors.amberAccent),
                  _metricTile("Market Cap", "₹${mcap.toStringAsFixed(0)} Cr", Colors.white70),
                  _metricTile(
                    "Debt/MCap",
                    "${debtToMcap}x",
                    debtToMcap <= 0.8 ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ],
              ),
              if (thesis.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  thesis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (docUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.parse(docUrl);
                      if (await canLaunchUrl(uri)) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text(
                      "📄 Rating Rationale ↗",
                      style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                    ),
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildTurnaroundListView(List items) {
    if (items.isEmpty) {
      return const Center(
        child: Text("No turnaround records available.", style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _buildSebiDisclaimer();
        }

        final item = items[index];
        final symbol = item['symbol'] ?? "";
        final companyName = item['company_name'] ?? symbol;
        final mcap = (item['market_cap_cr'] ?? 0).toDouble();
        final sales = (item['annual_sales_cr'] ?? 0).toDouble();
        final salesMultiple = (item['sales_to_mcap_multiple'] ?? 0).toDouble();
        final psRatio = (item['ps_ratio'] ?? 0).toDouble();
        final debtToMcap = (item['debt_to_mcap'] ?? 0).toDouble();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
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
                          symbol,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                    ),
                    child: Text(
                      "P/S: ${psRatio}x",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricTile("Annual Sales", "₹${sales.toStringAsFixed(0)} Cr", const Color(0xFF38BDF8)),
                  _metricTile("Market Cap", "₹${mcap.toStringAsFixed(0)} Cr", Colors.white70),
                  _metricTile("Sales/MCap", "${salesMultiple}x", Colors.greenAccent),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "🛡️ Debt/MCap: ${debtToMcap}x | Safe Balance Sheet",
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _metricTile(String title, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSebiDisclaimer() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: Colors.amberAccent, size: 14),
              SizedBox(width: 6),
              Text(
                "SEBI Statutory Disclaimer",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            "This tracker computes quantitative order-to-sales ratios from publicly available statutory disclosures for research purposes only. "
            "We are not a SEBI-registered Investment Advisor or Research Analyst. Backlog execution is subject to project and client delays. "
            "Please consult a certified financial advisor before investing.",
            style: TextStyle(fontSize: 10, color: Colors.white54, height: 1.3),
          ),
        ],
      ),
    );
  }
}
