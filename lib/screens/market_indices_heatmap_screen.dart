import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class MarketIndicesHeatmapScreen extends StatefulWidget {
  final int initialTabIndex; // 0 = Sectoral, 1 = Broad Market, 2 = All

  const MarketIndicesHeatmapScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<MarketIndicesHeatmapScreen> createState() => _MarketIndicesHeatmapScreenState();
}

class _MarketIndicesHeatmapScreenState extends State<MarketIndicesHeatmapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _sectoralList = [];
  List<Map<String, dynamic>> _broadMarketList = [];
  bool _isLoading = true;
  String _lastUpdated = "Today 03:30 PM IST";

  String _searchQuery = "";
  String _sortMode = "PERF"; // "PERF" (Performance), "NAME" (Alphabetical)
  bool _isCompactGrid = true;

  final TextEditingController _searchCtrl = TextEditingController();

  // Cloudflare Worker Proxy Endpoints & Google Apps Script Direct Feed
  final String _sheetApiUrl =
      "https://stock-models-api.nitesh-skyhigh.workers.dev/?type=sheet2";
  final String _stockApiUrl =
      "https://stock-models-api.nitesh-skyhigh.workers.dev/?type=sheet1";
  final String _constituentsApiUrl =
      "https://stock-models-api.nitesh-skyhigh.workers.dev/?type=sheet3";
  final String _directGasConstituentsUrl =
      "https://script.google.com/macros/s/AKfycbwzNPJpNK84hWl2-aziiLOoC55D6ua7NeWcFcGRZvPP-oYX9uLU1YmSZTcVPv_ZBnG3/exec";

  final NumberFormat _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
  Map<String, Map<String, dynamic>> _liveStockQuotes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadHeatmapData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHeatmapData() async {
    // 1. Instantly load bundled JSON baseline
    await _loadLocalBaseline();

    // 2. Try fetching live delta from worker
    _fetchLiveRemoteData();
  }

  Future<void> _loadLocalBaseline() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/indices_heatmap.json');
      final data = jsonDecode(jsonStr);

      if (mounted) {
        setState(() {
          _lastUpdated = data['last_updated'] ?? "Today 03:30 PM IST";
          _sectoralList = List<Map<String, dynamic>>.from(data['sectoral_indices'] ?? []);
          _broadMarketList = List<Map<String, dynamic>>.from(data['broad_market_indices'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Local baseline load error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLiveRemoteData() async {
    // 1. Fetch Sector & Broad Indices updates from Google Sheet
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse("$_sheetApiUrl&_t=$timestamp");
      final response = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic> remoteIndices = {};

        if (decoded is List) {
          for (var row in decoded) {
            if (row is Map) {
              final k = row['Index'] ?? row['name'] ?? row['Symbol'] ?? row['Sector'] ?? row['Name'] ?? '';
              if (k.toString().isNotEmpty) {
                remoteIndices[k.toString()] = row;
              }
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            remoteIndices = Map<String, dynamic>.from(decoded['data']);
          } else if (decoded.containsKey('data') && decoded['data'] is List) {
            for (var row in (decoded['data'] as List)) {
              if (row is Map) {
                final k = row['Index'] ?? row['name'] ?? row['Symbol'] ?? row['Sector'] ?? row['Name'] ?? '';
                if (k.toString().isNotEmpty) {
                  remoteIndices[k.toString()] = row;
                }
              }
            }
          } else {
            remoteIndices = decoded;
          }
        }

        if (remoteIndices.isNotEmpty && mounted) {
          _mergeLiveUpdates(remoteIndices);
        }
      }
    } catch (e) {
      debugPrint("Live Google Sheet fetch error: $e");
    }

    // 2. Fetch live stock quotes from Sheet 1 to enrich constituent stocks
    try {
      final stockRes = await http
          .get(Uri.parse(_stockApiUrl))
          .timeout(const Duration(seconds: 8));

      if (stockRes.statusCode == 200) {
        final List<dynamic> stockRows = jsonDecode(stockRes.body);
        Map<String, Map<String, dynamic>> quotes = {};
        for (var row in stockRows) {
          if (row is Map) {
            final sym = (row['Symbol'] ?? '').toString().toUpperCase().trim();
            if (sym.isNotEmpty && sym != 'SYMBOL') {
              quotes[sym] = {
                'price': _extractNum(row['CMP']),
                'change': _extractNum(row['Change']),
              };
            }
          }
        }
        if (mounted && quotes.isNotEmpty) {
          setState(() {
            _liveStockQuotes = quotes;
          });
        }
      }
    } catch (_) {
      // Silent fallback
    }

    // 3. Fetch dynamic constituents from Cloudflare Worker or direct Google Apps Script
    bool constituentsSynced = false;
    try {
      final constRes = await http
          .get(Uri.parse(_constituentsApiUrl))
          .timeout(const Duration(seconds: 8));

      if (constRes.statusCode == 200) {
        final decoded = jsonDecode(constRes.body);
        if (decoded is List && decoded.isNotEmpty) {
          _mergeRemoteConstituents(decoded);
          constituentsSynced = true;
        }
      }
    } catch (_) {}

    // Direct Google Apps Script fallback if Cloudflare Worker is pending deploy
    if (!constituentsSynced) {
      try {
        final gasRes = await http
            .get(Uri.parse(_directGasConstituentsUrl))
            .timeout(const Duration(seconds: 10));

        if (gasRes.statusCode == 200) {
          final decoded = jsonDecode(gasRes.body);
          if (decoded is List && decoded.isNotEmpty) {
            _mergeRemoteConstituents(decoded);
          }
        }
      } catch (_) {}
    }
  }

  void _mergeRemoteConstituents(List<dynamic> rows) {
    Map<String, List<Map<String, dynamic>>> sectorMap = {};
    for (var r in rows) {
      if (r is Map) {
        final sec = (r['SECTOR'] ?? r['sector'] ?? '').toString().toUpperCase().trim();
        final sym = (r['SYMBOL'] ?? r['symbol'] ?? '').toString().toUpperCase().trim();
        final name = (r['COMPANY_NAME'] ?? r['name'] ?? sym).toString();
        final weight = (r['WEIGHT'] ?? r['weight'] ?? '').toString();
        final price = _extractNum(r['CMP'] ?? r['price']);
        final change = _extractNum(r['CHANGE'] ?? r['change']);

        if (sec.isNotEmpty && sym.isNotEmpty) {
          sectorMap.putIfAbsent(sec, () => []);
          sectorMap[sec]!.add({
            'symbol': sym,
            'name': name,
            'weight': weight,
            'price': price,
            'change_pct': change,
          });
        }
      }
    }

    if (sectorMap.isNotEmpty && mounted) {
      setState(() {
        for (var item in [..._sectoralList, ..._broadMarketList]) {
          final sName = (item['name'] ?? '').toString().toUpperCase().trim();
          if (sectorMap.containsKey(sName)) {
            item['constituents'] = sectorMap[sName];
          }
        }
      });
    }
  }

  double _extractNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(
            val.toString().replaceAll(',', '').replaceAll('%', '').trim()) ??
        0.0;
  }

  void _mergeLiveUpdates(Map<String, dynamic> liveData) {
    // 1. Build a normalized map of all live entries from Google Sheet
    final Map<String, dynamic> normMap = {};
    liveData.forEach((k, v) {
      final cleanK = _normalizeKey(k.toString());
      if (cleanK.isNotEmpty) {
        normMap[cleanK] = v;
      }
    });

    // 2. Helper to find matching entry in normMap
    dynamic findMatchingLiveVal(String? name, String? symbol) {
      final nameKey = _normalizeKey(name);
      final symKey = _normalizeKey(symbol);

      if (nameKey.isNotEmpty && normMap.containsKey(nameKey)) {
        return normMap[nameKey];
      }
      if (symKey.isNotEmpty && normMap.containsKey(symKey)) {
        return normMap[symKey];
      }

      // Fuzzy contains match: e.g. "niftyit" matches "it" or "niftyitsector"
      for (var entry in normMap.entries) {
        final k = entry.key;
        if (nameKey.isNotEmpty && (k.contains(nameKey) || nameKey.contains(k))) {
          return entry.value;
        }
        if (symKey.isNotEmpty && (k.contains(symKey) || symKey.contains(k))) {
          return entry.value;
        }
      }
      return null;
    }

    double? extractPrice(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is Map) {
        final p = val['price'] ??
            val['cmp'] ??
            val['CMP'] ??
            val['ltp'] ??
            val['LTP'] ??
            val['lastPrice'] ??
            val['Price'] ??
            val['close'];
        if (p is num) return p.toDouble();
        if (p != null) return double.tryParse(p.toString().replaceAll(',', '').trim());
      }
      return null;
    }

    double? extractChange(dynamic val) {
      if (val == null) return null;
      if (val is Map) {
        final c = val['change'] ??
            val['change_pct'] ??
            val['Change'] ??
            val['pChange'] ??
            val['chg'] ??
            val['percentChange'];
        return _parseChange(c);
      }
      if (val is num) return val.toDouble();
      return _parseChange(val);
    }

    int matchedCount = 0;
    setState(() {
      for (var item in _sectoralList) {
        final val = findMatchingLiveVal(item['name'], item['symbol']);
        if (val != null) {
          final p = extractPrice(val);
          final c = extractChange(val);
          if (p != null && p > 0) item['price'] = p;
          if (c != null) item['change_pct'] = c;
          matchedCount++;
        }
      }

      for (var item in _broadMarketList) {
        final val = findMatchingLiveVal(item['name'], item['symbol']);
        if (val != null) {
          final p = extractPrice(val);
          final c = extractChange(val);
          if (p != null && p > 0) item['price'] = p;
          if (c != null) item['change_pct'] = c;
          matchedCount++;
        }
      }

      if (matchedCount > 0) {
        final now = DateTime.now();
        final timeStr = DateFormat('dd MMM, hh:mm a').format(now);
        _lastUpdated = "Google Sheet Sync • $timeStr";
      }
    });
  }

  String _normalizeKey(String? name) {
    if (name == null) return '';
    return name.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
  }

  double? _parseChange(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final str = raw.toString().replaceAll('%', '').replaceAll('+', '').trim();
    return double.tryParse(str);
  }

  List<Map<String, dynamic>> _getActiveList() {
    List<Map<String, dynamic>> source;
    if (_tabController.index == 0) {
      source = List.from(_sectoralList);
    } else if (_tabController.index == 1) {
      source = List.from(_broadMarketList);
    } else {
      source = [..._sectoralList, ..._broadMarketList];
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      source = source.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    }

    // Sort
    if (_sortMode == "PERF") {
      source.sort((a, b) {
        final ca = (a['change_pct'] as num?)?.toDouble() ?? 0.0;
        final cb = (b['change_pct'] as num?)?.toDouble() ?? 0.0;
        return cb.compareTo(ca); // Descending: top gainers first
      });
    } else if (_sortMode == "NAME") {
      source.sort((a, b) {
        final na = (a['name'] ?? '').toString();
        final nb = (b['name'] ?? '').toString();
        return na.compareTo(nb);
      });
    }

    return source;
  }

  // Institutional Color Grading System
  Color _getHeatmapColor(double changePct) {
    if (changePct >= 2.0) {
      return const Color(0xFF00FF88); // Intense Neon Green
    } else if (changePct >= 0.75) {
      return const Color(0xFF00E676); // Strong Green
    } else if (changePct > 0.0) {
      return const Color(0xFF26A69A); // Mild Green
    } else if (changePct == 0.0) {
      return const Color(0xFF607D8B); // Neutral Slate
    } else if (changePct >= -0.75) {
      return const Color(0xFFEF5350); // Mild Red
    } else if (changePct >= -1.5) {
      return const Color(0xFFFF2A6D); // Strong Crimson
    } else {
      return const Color(0xFFD50000); // Deep Blood Red
    }
  }

  Color _getTileBackground(double changePct) {
    if (changePct >= 2.0) {
      return const Color(0xFF00FF88).withOpacity(0.18);
    } else if (changePct >= 0.75) {
      return const Color(0xFF00E676).withOpacity(0.14);
    } else if (changePct > 0.0) {
      return const Color(0xFF26A69A).withOpacity(0.10);
    } else if (changePct == 0.0) {
      return const Color(0xFF1E293B).withOpacity(0.5);
    } else if (changePct >= -0.75) {
      return const Color(0xFFEF5350).withOpacity(0.12);
    } else if (changePct >= -1.5) {
      return const Color(0xFFFF2A6D).withOpacity(0.16);
    } else {
      return const Color(0xFFD50000).withOpacity(0.22);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _getActiveList();

    int advancing = 0;
    int declining = 0;
    int unchanged = 0;

    for (var it in activeList) {
      final ch = (it['change_pct'] as num?)?.toDouble() ?? 0.0;
      if (ch > 0) advancing++;
      else if (ch < 0) declining++;
      else unchanged++;
    }

    final total = activeList.length;
    final advancePct = total > 0 ? (advancing / total) : 0.5;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF00E5FF), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MARKET INDICES HEATMAP",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              "44 Broad & Sectoral Indices Matrix",
              style: TextStyle(
                color: const Color(0xFF00E5FF).withOpacity(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Switch Layout",
            icon: Icon(
              _isCompactGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isCompactGrid = !_isCompactGrid);
            },
          ),
          IconButton(
            tooltip: "Refresh Feed",
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF), size: 21),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _loadHeatmapData();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF0F1726),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E2B3E)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.6), width: 1),
                ),
                labelColor: const Color(0xFF00E5FF),
                unselectedLabelColor: Colors.white60,
                labelStyle: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w900),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: "SECTORAL (${_sectoralList.length})"),
                  Tab(text: "BROAD (${_broadMarketList.length})"),
                  Tab(text: "ALL (${_sectoralList.length + _broadMarketList.length})"),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
            )
          : RefreshIndicator(
              color: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF0F1726),
              onRefresh: _loadHeatmapData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Advance/Decline Breadth Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1726),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E2B3E)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.trending_up_rounded, color: Color(0xFF00FF88), size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      "$advancing ADVANCING",
                                      style: GoogleFonts.robotoMono(
                                        color: const Color(0xFF00FF88),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _lastUpdated,
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "$declining DECLINING",
                                      style: GoogleFonts.robotoMono(
                                        color: const Color(0xFFFF2A6D),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(Icons.trending_down_rounded, color: Color(0xFFFF2A6D), size: 16),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Ratio Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                height: 6,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: (advancePct * 100).round().clamp(1, 99),
                                      child: Container(color: const Color(0xFF00FF88)),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      flex: ((1 - advancePct) * 100).round().clamp(1, 99),
                                      child: Container(color: const Color(0xFFFF2A6D)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Search & Sort Controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1726),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF1E2B3E)),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 17),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            _searchCtrl.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          child: const Icon(Icons.cancel_rounded, color: Colors.white38, size: 16),
                                        )
                                      : null,
                                  hintText: "Search index (e.g. IT, Bank, Metal)...",
                                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 11.5),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Sort Button
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _sortMode = _sortMode == "PERF" ? "NAME" : "PERF";
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1726),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _sortMode == "PERF"
                                      ? const Color(0xFF00E5FF).withOpacity(0.4)
                                      : const Color(0xFF1E2B3E),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _sortMode == "PERF" ? Icons.bolt_rounded : Icons.sort_by_alpha_rounded,
                                    color: _sortMode == "PERF" ? const Color(0xFF00E5FF) : Colors.white60,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sortMode == "PERF" ? "GAIN" : "A-Z",
                                    style: GoogleFonts.robotoMono(
                                      color: _sortMode == "PERF" ? const Color(0xFF00E5FF) : Colors.white60,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Main Heatmap Presentation
                  if (activeList.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          "No matching indices found",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    )
                  else if (_isCompactGrid)
                    // Finviz/TradingView Style 2-Column Heatmap Grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.48,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = activeList[index];
                            return _buildHeatmapTile(item);
                          },
                          childCount: activeList.length,
                        ),
                      ),
                    )
                  else
                    // Detailed List View
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = activeList[index];
                            return _buildDetailedIndexRow(item);
                          },
                          childCount: activeList.length,
                        ),
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 60),
                  ),
                ],
              ),
            ),
    );
  }

  // -------------------------------------------------------------
  // Compact Tile Presentation (Heatmap Treemap Style)
  // -------------------------------------------------------------
  Widget _buildHeatmapTile(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final double changePct = (item['change_pct'] as num?)?.toDouble() ?? 0.0;
    final bool isUp = changePct >= 0;

    final Color heatColor = _getHeatmapColor(changePct);
    final Color tileBg = _getTileBackground(changePct);

    final String changeStr = "${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%";

    return InkWell(
      onTap: () => _showIndexDetailModal(item),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: heatColor.withOpacity(0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: heatColor.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Name & Category
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: heatColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: heatColor.withOpacity(0.5), width: 0.8),
                  ),
                  child: Text(
                    changeStr,
                    style: GoogleFonts.robotoMono(
                      color: heatColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            // Bottom: Current Level
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(price),
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Icon(
                  isUp ? Icons.arrow_outward_rounded : Icons.south_east_rounded,
                  color: heatColor,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Detailed List Row
  // -------------------------------------------------------------
  Widget _buildDetailedIndexRow(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final double changePct = (item['change_pct'] as num?)?.toDouble() ?? 0.0;
    final bool isUp = changePct >= 0;

    final Color heatColor = _getHeatmapColor(changePct);
    final String changeStr = "${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%";

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: () => _showIndexDetailModal(item),
        title: Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          category,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(price),
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  changeStr,
                  style: GoogleFonts.robotoMono(
                    color: heatColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Modal Sheet: Index Deep Dive & Trending Constituent Stocks
  // -------------------------------------------------------------
  void _showIndexDetailModal(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    final name = (item['name'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final double changePct = (item['change_pct'] as num?)?.toDouble() ?? 0.0;
    final Color heatColor = _getHeatmapColor(changePct);
    final bool isUp = changePct >= 0;

    final double? open = (item['open'] as num?)?.toDouble();
    final double? high = (item['high'] as num?)?.toDouble();
    final double? low = (item['low'] as num?)?.toDouble();

    // Extract constituents
    final rawConstituents = (item['constituents'] as List<dynamic>?) ?? [];
    List<Map<String, dynamic>> constituents = rawConstituents
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    // Enrich constituents with real-time sheet1 quotes if available
    for (var c in constituents) {
      final sym = (c['symbol'] ?? '').toString().toUpperCase();
      if (_liveStockQuotes.containsKey(sym)) {
        final live = _liveStockQuotes[sym]!;
        if (live['price'] != null && live['price'] > 0) {
          c['price'] = live['price'];
        }
        if (live['change'] != null) {
          c['change_pct'] = live['change'];
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filterMode = "ALL"; // "ALL", "GAINERS", "LOSERS"

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            List<Map<String, dynamic>> displayedConstituents = List.from(constituents);

            // Filter
            if (filterMode == "GAINERS") {
              displayedConstituents = displayedConstituents
                  .where((s) => ((s['change_pct'] as num?)?.toDouble() ?? 0.0) >= 0)
                  .toList();
            } else if (filterMode == "LOSERS") {
              displayedConstituents = displayedConstituents
                  .where((s) => ((s['change_pct'] as num?)?.toDouble() ?? 0.0) < 0)
                  .toList();
            }

            // Always sort by performance (descending: highest gainers first)
            displayedConstituents.sort((a, b) {
              final ca = (a['change_pct'] as num?)?.toDouble() ?? 0.0;
              final cb = (b['change_pct'] as num?)?.toDouble() ?? 0.0;
              return cb.compareTo(ca);
            });

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Name & Performance Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  category,
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: heatColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: heatColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              "${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%",
                              style: GoogleFonts.robotoMono(
                                color: heatColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Level Highlight
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E2B3E)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "INDEX LEVEL (CMP)",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(price),
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (open != null || high != null || low != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (open != null)
                              Expanded(child: _buildMetricMiniBox("OPEN", _currencyFormat.format(open))),
                            if (high != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetricMiniBox(
                                  "DAY HIGH",
                                  _currencyFormat.format(high),
                                  const Color(0xFF00FF88),
                                ),
                              ),
                            ],
                            if (low != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetricMiniBox(
                                  "DAY LOW",
                                  _currencyFormat.format(low),
                                  const Color(0xFFFF2A6D),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Constituent Trending Stocks Header & Filters
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.trending_up_rounded, color: Color(0xFF00E5FF), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "CONSTITUENT STOCKS",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          // Filter toggle pills
                          Row(
                            children: [
                              _buildModalFilterChip("ALL", filterMode == "ALL", () {
                                setModalState(() => filterMode = "ALL");
                              }),
                              const SizedBox(width: 4),
                              _buildModalFilterChip("GAINERS", filterMode == "GAINERS", () {
                                setModalState(() => filterMode = "GAINERS");
                              }),
                              const SizedBox(width: 4),
                              _buildModalFilterChip("LOSERS", filterMode == "LOSERS", () {
                                setModalState(() => filterMode = "LOSERS");
                              }),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Stocks List
                      Expanded(
                        child: displayedConstituents.isEmpty
                            ? Center(
                                child: Text(
                                  "No stocks match '$filterMode' filter",
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              )
                            : ListView.separated(
                                itemCount: displayedConstituents.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, idx) {
                                  final stock = displayedConstituents[idx];
                                  return _buildConstituentStockTile(stock, context);
                                },
                              ),
                      ),

                      const SizedBox(height: 10),

                      // Bottom Copy button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text(
                            "COPY INDEX VALUE",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: "$name: ${_currencyFormat.format(price)} ($changePct%)"));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$name copied to clipboard"),
                                backgroundColor: const Color(0xFF00F5A0),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF1E2B3E),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildConstituentStockTile(Map<String, dynamic> stock, BuildContext context) {
    final sym = (stock['symbol'] ?? '').toString().toUpperCase();
    final name = (stock['name'] ?? sym).toString();
    final weight = (stock['weight'] ?? '').toString();

    final double price = (stock['price'] as num?)?.toDouble() ?? 0.0;
    final double changePct = (stock['change_pct'] as num?)?.toDouble() ?? 0.0;

    final bool isUp = changePct >= 0;
    final Color trendColor = isUp ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D);

    return InkWell(
      onTap: () {
        _showStockActionSheet(context, sym, name, price, changePct);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E2B3E)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
              ),
              child: Text(
                sym,
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF00E5FF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (weight.isNotEmpty)
                    Text(
                      "Weight: $weight",
                      style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹${_currencyFormat.format(price)}",
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUp ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                        color: trendColor,
                        size: 14,
                      ),
                      Text(
                        "${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%",
                        style: GoogleFonts.robotoMono(
                          color: trendColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
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

  void _showStockActionSheet(BuildContext ctx, String sym, String name, double price, double change) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF141C2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (actionCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$sym · $name",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${_currencyFormat.format(price)} (${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%)",
                  style: GoogleFonts.robotoMono(
                    color: change >= 0 ? const Color(0xFF00FF88) : const Color(0xFFFF2A6D),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.bookmark_add_rounded, color: Color(0xFF00E5FF)),
                  title: const Text("Add to Watchlist", style: TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(actionCtx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("$sym added to Watchlist"),
                        backgroundColor: const Color(0xFF00E5FF),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                  title: const Text("Copy Stock Symbol & Quote", style: TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: "$sym: ₹$price (${change >= 0 ? '+' : ''}$change%)"));
                    Navigator.pop(actionCtx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("Copied $sym quote to clipboard"),
                        backgroundColor: const Color(0xFF00F5A0),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricMiniBox(String label, String value, [Color? valueColor]) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: valueColor ?? Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
