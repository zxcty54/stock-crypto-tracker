import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SmartMoneyAnchorScreen extends StatefulWidget {
  const SmartMoneyAnchorScreen({super.key});

  @override
  State<SmartMoneyAnchorScreen> createState() => _SmartMoneyAnchorScreenState();
}

class _SmartMoneyAnchorScreenState extends State<SmartMoneyAnchorScreen> {
  static const String apiUrl =
      'https://stock-models-api.nitesh-skyhigh.workers.dev/?type=anchor';

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;
  String _selectedFilter = 'ALL'; // ALL, PRIME, BUFFER, EXTENDED

  @override
  void initState() {
    super.initState();
    _fetchAnchorReport();
  }

  Future<void> _fetchAnchorReport({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(forceRefresh ? '$apiUrl&nocache=true' : apiUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _reportData = decoded;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Server error: HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Data load error: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getFilteredSetups() {
    if (_reportData == null) return [];
    final all = _reportData!['all_setups'] as List<dynamic>? ?? [];

    if (_selectedFilter == 'PRIME') {
      return all.where((e) => e['zone'] == 'PRIME_DISCOUNT').toList();
    } else if (_selectedFilter == 'BUFFER') {
      return all.where((e) => e['zone'] == 'ACCUMULATION_BUFFER').toList();
    } else if (_selectedFilter == 'EXTENDED') {
      return all.where((e) => e['zone'] == 'EXTENDED' || e['zone'] == 'OVERBOUGHT').toList();
    }
    return all;
  }

  Future<void> _openPdf(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Institutional Anchor Radar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'QIP & Preferential Allotments',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF58A6FF)),
            onPressed: () => _fetchAnchorReport(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF238636)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
                onPressed: () => _fetchAnchorReport(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final setups = _getFilteredSetups();
    final primeCount = _reportData?['prime_discount_opportunities'] ?? 0;
    final totalCount = _reportData?['total_anchors_discovered'] ?? 0;

    return RefreshIndicator(
      color: const Color(0xFF238636),
      backgroundColor: const Color(0xFF161B22),
      onRefresh: () => _fetchAnchorReport(forceRefresh: true),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSummaryBanner(primeCount, totalCount),
                  const SizedBox(height: 14),
                  _buildFilterChips(),
                ],
              ),
            ),
          ),
          if (setups.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No setups found under this category.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildAnchorCard(setups[index]),
                childCount: setups.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(dynamic primeCount, dynamic totalCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('Discovered', '$totalCount', const Color(0xFF58A6FF)),
          Container(height: 35, width: 1, color: Colors.white10),
          _buildStatColumn('Prime Discounts', '$primeCount', const Color(0xFF2EA043)),
          Container(height: 35, width: 1, color: Colors.white10),
          _buildStatColumn('Window', '60 Days', Colors.amberAccent),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChipItem('ALL', 'All Tracked'),
          const SizedBox(width: 8),
          _filterChipItem('PRIME', '🔥 Prime Discount'),
          const SizedBox(width: 8),
          _filterChipItem('BUFFER', '🛡️ Near Floor'),
          const SizedBox(width: 8),
          _filterChipItem('EXTENDED', '🚀 Extended'),
        ],
      ),
    );
  }

  Widget _filterChipItem(String key, String label) {
    final bool isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey)),
      selected: isSelected,
      selectedColor: const Color(0xFF238636),
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF238636) : Colors.white12),
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildAnchorCard(dynamic item) {
    final bool isPrime = item['zone'] == 'PRIME_DISCOUNT';
    final double delta = (item['delta_to_floor_pct'] as num?)?.toDouble() ?? 0.0;
    final List allottees = item['allottees'] as List? ?? [];
    final String? pdfUrl = item['filing_pdf'];

    final Color badgeColor = isPrime
        ? const Color(0xFF2EA043)
        : (item['zone'] == 'OVERBOUGHT' ? Colors.redAccent : const Color(0xFF58A6FF));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPrime ? const Color(0xFF2EA043).withOpacity(0.6) : Colors.white10,
          width: isPrime ? 1.5 : 1,
        ),
      ),
      color: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Symbol, Deal Type, and Zone Badge
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
                            item['symbol'] ?? '',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item['tier1_backed'] == true)
                            const Icon(Icons.verified, color: Color(0xFF58A6FF), size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['company_name'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: BorderSide(color: badgeColor, width: 0.8),
                  ),
                  child: Text(
                    item['zone_label'] ?? '',
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.white10, height: 24),

            // Middle Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn('Live CMP', '₹${item['cmp']}', Colors.white),
                _buildMetricColumn('Anchor Floor', '₹${item['institutional_floor_price']}', const Color(0xFF7EE787)),
                _buildMetricColumn(
                  'Delta',
                  '${delta > 0 ? '+' : ''}$delta%',
                  delta < 0 ? const Color(0xFF2EA043) : Colors.amberAccent,
                ),
                _buildMetricColumn(
                  'Raised',
                  item['capital_raised_cr'] > 0 ? '₹${item['capital_raised_cr']} Cr' : '--',
                  Colors.white70,
                ),
              ],
            ),

            // Allottees Section
            if (allottees.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: allottees.map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(6),
                      border: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance, size: 11, color: Color(0xFF58A6FF)),
                        const SizedBox(width: 4),
                        Text(
                          '${a['name']}',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Bottom Actions: PDF & Deal Details
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['deal_type'] ?? 'Institutional Allotment',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (pdfUrl != null && pdfUrl.isNotEmpty)
                  InkWell(
                    onTap: () => _openPdf(pdfUrl),
                    child: const Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 14, color: Color(0xFF58A6FF)),
                        SizedBox(width: 4),
                        Text(
                          'NSE Circular',
                          style: TextStyle(fontSize: 11, color: Color(0xFF58A6FF), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String title, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
