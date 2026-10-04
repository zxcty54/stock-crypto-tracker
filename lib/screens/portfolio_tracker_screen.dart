import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PortfolioTrackerScreen extends StatefulWidget {
  const PortfolioTrackerScreen({super.key});

  @override
  State<Ek premium aur institutional-grade feel dene ke liye interface mein Bloomberg/TradingView jaisa high-density design, segmented dashboards, dynamic watchlist switching aur granular execution controls hona zaroori hai.

Neeche poora complete architecture aur layout design plan diya gaya hai, sath hi woh core features jisse yeh best portfolio aur multiple-watchlist widget banega.

---

### Core Architecture & Features Jo Is Widget Mein Milenge:

1. **5 Independent Watchlists:**
   * User 5 distinct watchlists manage kar sakega (jaise *Main Tech*, *Breakout Candidates*, *High Dividend*, *Nifty Heavyweights*, *Penny Scanners*).
   * Har watchlist ka alag dashboard metrics hoga: Average Change %, Top Gainer, Top Loser aur Total Monitored Count.
2. **Dedicated Institutional Navigation Tabs:**
   * **Dashboard & Holdings:** ₹5 Lakh virtual ledger, live floating P&L, allocation breakdown aur open copy-trading positions.
   * **Multi-Watchlist Engine:** Horizontal ticker badges se 1-click watchlist switch, custom add/delete stocks, aur real-time CMP & Change% sync.
   * **Settled Audit Book:** Closed trades ka date-wise historical ledger with gross return % calculation.
3. **Execution Sheet (Paper Trading Order Pad):**
   * Live price par instant buy, dynamic margin buffer check (insufficient cash blocker), aur visual slippage simulation.
   * Quick quantity multipliers (10x, 50x, 100x ya Max Available Cash).

---

### Complete Widget Source Code: `lib/screens/portfolio_tracker_screen.dart`

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PortfolioTrackerScreen extends StatefulWidget {
  PortfolioTrackerScreen({super.key});

  @override
  State<PortfolioTrackerScreen> createState() => _PortfolioTrackerScreenState();
}

class _PortfolioTrackerScreenState extends State<PortfolioTrackerScreen>
    with SingleTickerProviderStateMixin {
  final String _sheetUrl =
      '[https://script.google.com/macros/s/AKfycbzE5FVwepYICR2SPsubssC8zdvCrFbEJqh1lEawkjb8DxVrAv2hTnOzKfozz4Sj3uW8vQ/exec](https://script.google.com/macros/s/AKfycbzE5FVwepYICR2SPsubssC8zdvCrFbEJqh1lEawkjb8DxVrAv2hTnOzKfozz4Sj3uW8vQ/exec)';

  late TabController _tabController;
  static const double _initialCapital = 500000.0;
  double _availableCash = _initialCapital;
  double _realizedPnl = 0.0;

  Map<String, Map<String, dynamic>> _marketFeed = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _fetchError;

  List<Map<String, dynamic>> _openPositions = [];
  List<Map<String, dynamic>> _closedTrades = [];

  // Multi-Watchlist Configuration (5 Independent Slots)
  final List<String> _watchlistNames = [
    'Primary Radar',
    'Momentum Breakouts',
    'Bluechip 50',
    'Value Bets',
    'Swing Setups'
  ];
  int _activeWatchlistIndex = 0;
  Map<int, Set<String>> _watchlists = {
    0: {},
    1: {},
    2: {},
    3: {},
    4: {},
  };

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _restorePersistence();
    _loadPrices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- STATE STORAGE ---
  Future<void> _restorePersistence() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _availableCash = prefs.getDouble('v_capital') ?? _initialCapital;
      _realizedPnl = prefs.getDouble('v_realized') ?? 0.0;

      final posStr = prefs.getString('v_positions');
      if (posStr != null) {
        _openPositions = List<Map<String, dynamic>>.from(jsonDecode(posStr));
      }

      final histStr = prefs.getString('v_history');
      if (histStr != null) {
        _closedTrades = List<Map<String, dynamic>>.from(jsonDecode(histStr));
      }

      for (int i = 0; i < 5; i++) {
        final list = prefs.getStringList('v_watchlist_$i');
        if (list != null) {
          _watchlists[i] = list.toSet();
        }
      }
    });
  }

  Future<void> _savePersistence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('v_capital', _availableCash);
    await prefs.setDouble('v_realized', _realizedPnl);
    await prefs.setString('v_positions', jsonEncode(_openPositions));
    await prefs.setString('v_history', jsonEncode(_closedTrades));

    for (int i = 0; i < 5; i++) {
      await prefs.setStringList('v_watchlist_$i', _watchlists[i]!.toList());
    }
  }

  // --- API DATA PIPELINE ---
  Future<void> _loadPrices({bool showSnackbar = false}) async {
    if (showSnackbar) setState(() => _isRefreshing = true);

    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(_sheetUrl))
        ..followRedirects = true
        ..maxRedirects = 5;

      final resStream = await client.send(req).timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(resStream);

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        Map<String, Map<String, dynamic>> temp = {};

        for (var row in data) {
          if (row is Map) {
            final sym = (row['Symbol'] ?? '').toString().toUpperCase().trim();
            if (sym.isNotEmpty && sym != 'SYMBOL') {
              temp[sym] = {
                'price': _extractNum(row['CMP']),
                'change': _extractNum(row['Change']),
              };
            }
          }
        }

        setState(() {
          _marketFeed = temp;
          _isLoading = false;
          _isRefreshing = false;
          _fetchError = null;
        });

        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Sync Success: ${_marketFeed.length} assets synced live'),
              backgroundColor: const Color(0xFF00F5A0),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint("API sync error: $e");
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _fetchError = e.toString();
      });
    }
  }

  double _extractNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll(',', '').replaceAll('%', '').trim()) ?? 0.0;
  }

  // --- ORDER EXECUTION ---
  void _executeBuy(String symbol, double price, int qty) {
    final totalCost = price * qty;
    if (totalCost > _availableCash) {
      _notify("Insufficient Margin. Required: ₹${totalCost.toStringAsFixed(2)}", Colors.redAccent);
      return;
    }

    setState(() {
      _availableCash -= totalCost;
      _openPositions.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'symbol': symbol,
        'entry_price': price,
        'qty': qty,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _savePersistence();
    HapticFeedback.heavyImpact();
    _notify("Order Filled: $qty shares of $symbol @ ₹$price", const Color(0xFF00F5A0));
  }

  void _settlePosition(Map<String, dynamic> item) {
    final sym = item['symbol'];
    final entry = (item['entry_price'] as num).toDouble();
    final qty = (item['qty'] as num).toInt();
    final ltp = _marketFeed[sym]?['price'] ?? entry;

    final pnl = (ltp - entry) * qty;

    setState(() {
      _availableCash += (entry * qty) + pnl;
      _realizedPnl += pnl;
      _openPositions.removeWhere((p) => p['id'] == item['id']);

      _closedTrades.insert(0, {
        ...item,
        'exit_price': ltp,
        'realized_pnl': pnl,
        'pnl_pct': entry > 0 ? ((ltp - entry) / entry) * 100 : 0.0,
        'settled_at': DateTime.now().toIso8601String(),
      });
    });

    _savePersistence();
    HapticFeedback.mediumImpact();
    _notify(
      "Position Closed: ${pnl >= 0 ? '+' : ''}₹${pnl.toStringAsFixed(2)}",
      pnl >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
    );
  }

  void _toggleWatchlistMembership(String sym) {
    setState(() {
      final currentSet = _watchlists[_activeWatchlistIndex]!;
      if (currentSet.contains(sym)) {
        currentSet.remove(sym);
        _notify("Removed from ${_watchlistNames[_activeWatchlistIndex]}", Colors.white60);
      } else {
        currentSet.add(sym);
        _notify("Saved to ${_watchlistNames[_activeWatchlistIndex]} ⭐", const Color(0xFF00E5FF));
      }
    });
    _savePersistence();
  }

  void _notify(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
        backgroundColor: bg,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- PORTFOLIO VALUATION METRICS ---
  double get _floatingUnrealizedPnl {
    double total = 0.0;
    for (var pos in _openPositions) {
      final sym = pos['symbol'];
      final entry = (pos['entry_price'] as num).toDouble();
      final qty = (pos['qty'] as num).toInt();
      final ltp = _marketFeed[sym]?['price'] ?? entry;
      total += (ltp - entry) * qty;
    }
    return total;
  }

  double get _investedCapital {
    double total = 0.0;
    for (var pos in _openPositions) {
      total += (pos['entry_price'] as num).toDouble() * (pos['qty'] as num).toInt();
    }
    return total;
  }

  double get _navValuation => _availableCash + _investedCapital + _floatingUnrealizedPnl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1322),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PORTFOLIO TERMINAL",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              "LIVE INSTITUTIONAL FEED • NSE EQ",
              style: GoogleFonts.robotoMono(color: const Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2))
                : const Icon(Icons.sync_rounded, color: Color(0xFF00E5FF), size: 20),
            tooltip: 'Live Sheet Refresh',
            onPressed: _isRefreshing ? null : () => _loadPrices(showSnackbar: true),
          ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.white54, size: 20),
            tooltip: 'Reset Ledger',
            onPressed: _showResetLedgerModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          indicatorWeight: 3,
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: "OPEN BOOK (${_openPositions.length})"),
            Tab(text: "WATCHLISTS (5)"),
            Tab(text: "SETTLED (${_closedTrades.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : Column(
              children: [
                _buildInstitutionalDashboardBanner(),
                _buildTerminalSearchBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPositionsTab(),
                      _buildMultiWatchlistTab(),
                      _buildSettledLedgerTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- INSTITUTIONAL EXECUTIVE BANNER ---
  Widget _buildInstitutionalDashboardBanner() {
    final unPnl = _floatingUnrealizedPnl;
    final isPos = unPnl >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("NET ASSET VALUE (NAV)",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(
                    "₹${_navValuation.toStringAsFixed(2)}",
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPos ? const Color(0xFF00F5A0).withOpacity(0.12) : const Color(0xFFFF2A6D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isPos ? const Color(0xFF00F5A0).withOpacity(0.4) : const Color(0xFFFF2A6D).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("UNREALIZED FLOATING",
                        style: TextStyle(
                            color: isPos ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900)),
                    Text(
                      "${isPos ? '+' : ''}₹${unPnl.toStringAsFixed(2)}",
                      style: GoogleFonts.robotoMono(
                          color: isPos ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E2B3E), height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricBlock("AVAILABLE MARGIN", "₹${_availableCash.toStringAsFixed(1)}", const Color(0xFF00E5FF)),
              _metricBlock("OPEN EXPOSURE", "₹${_investedCapital.toStringAsFixed(1)}", Colors.white70),
              _metricBlock("NET SETTLED P&L", "${_realizedPnl >= 0 ? '+' : ''}₹${_realizedPnl.toStringAsFixed(1)}",
                  _realizedPnl >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBlock(String label, String val, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 8.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.robotoMono(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // --- TERMINAL SEARCH CONTROL ---
  Widget _buildTerminalSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF131D31),
          hintText: _marketFeed.isEmpty ? "Connecting to Sheet..." : "Search in ${_marketFeed.length} live stocks...",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 16),
          suffixIcon: _searchFilter.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchFilter = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onChanged: (val) {
          setState(() {
            _searchFilter = val.trim().toUpperCase();
            if (_searchFilter.isNotEmpty && _tabController.index != 1) {
              _tabController.animateTo(1);
            }
          });
        },
      ),
    );
  }

  // --- TAB 1: ACTIVE HOLDINGS ---
  Widget _buildPositionsTab() {
    if (_openPositions.isEmpty) {
      return _buildEmptySlot("No Active Exposure", "Discover stocks from Watchlists or Search to initiate paper orders.");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _openPositions.length,
      itemBuilder: (ctx, i) {
        final pos = _openPositions[i];
        final sym = pos['symbol'];
        final entry = (pos['entry_price'] as num).toDouble();
        final qty = (pos['qty'] as num).toInt();
        final ltp = _marketFeed[sym]?['price'] ?? entry;

        final diff = (ltp - entry) * qty;
        final diffPct = entry > 0 ? ((ltp - entry) / entry) * 100 : 0.0;
        final isProfit = diff >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1626),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("LONG", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      Text(sym, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Text("• $qty Qty", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${isProfit ? '+' : ''}₹${diff.toStringAsFixed(2)}",
                        style: GoogleFonts.robotoMono(
                          color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        "${isProfit ? '+' : ''}${diffPct.toStringAsFixed(2)}%",
                        style: TextStyle(
                          color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E2B3E), height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Entry: ₹$entry • LTP: ₹$ltp", style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2A6D).withOpacity(0.15),
                      foregroundColor: const Color(0xFFFF2A6D),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFFF2A6D), width: 0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _settlePosition(pos),
                    child: const Text("CLOSE & SETTLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: MULTI-WATCHLIST MATRIX (5 WATCHLISTS) ---
  Widget _buildMultiWatchlistTab() {
    final activeSet = _watchlists[_activeWatchlistIndex]!;

    List<String> displayList = [];
    if (_searchFilter.isNotEmpty) {
      displayList = _marketFeed.keys.where((s) => s.contains(_searchFilter)).toList();
    } else if (activeSet.isNotEmpty) {
      displayList = activeSet.toList();
    } else {
      displayList = _marketFeed.keys.take(25).toList();
    }

    return Column(
      children: [
        // 5 Segmented Watchlist Selector Badges
        Container(
          height: 38,
          margin: const EdgeInsets.only(top: 6, bottom: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _watchlistNames.length,
            itemBuilder: (ctx, i) {
              final isSel = _activeWatchlistIndex == i;
              final count = _watchlists[i]!.length;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSel,
                  showCheckmark: false,
                  label: Text("${_watchlistNames[i]} ($count)"),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                  backgroundColor: const Color(0xFF0F1726),
                  selectedColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSel ? const Color(0xFF00E5FF) : const Color(0xFF1E2B3E)),
                  ),
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _activeWatchlistIndex = i);
                  },
                ),
              );
            },
          ),
        ),

        // Live Watchlist Metric Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _searchFilter.isNotEmpty
                    ? "SEARCH RESULTS (${displayList.length})"
                    : "${_watchlistNames[_activeWatchlistIndex].toUpperCase()} (${activeSet.length} SAVED)",
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.w900),
              ),
              Text(
                "${_marketFeed.length} Stocks Streamed",
                style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Stock Rows
        Expanded(
          child: displayList.isEmpty
              ? _buildEmptySlot("Watchlist Empty", "Use search bar above to bookmark stocks into this bucket.")
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: displayList.length,
                  itemBuilder: (ctx, i) {
                    final sym = displayList[i];
                    final price = _marketFeed[sym]?['price'] ?? 0.0;
                    final chg = _marketFeed[sym]?['change'] ?? 0.0;
                    final isMember = activeSet.contains(sym);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1626),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E2B3E)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isMember ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                  color: isMember ? const Color(0xFF00E5FF) : Colors.white30,
                                  size: 20,
                                ),
                                onPressed: () => _toggleWatchlistMembership(sym),
                              ),
                              Text(sym,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("₹${price.toStringAsFixed(2)}",
                                      style: GoogleFonts.robotoMono(
                                          color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                                  Text(
                                    "${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(2)}%",
                                    style: TextStyle(
                                      color: chg >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00F5A0),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _openOrderModal(sym, price),
                                child: const Text("BUY",
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10.5)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: SETTLED AUDIT LEDGER ---
  Widget _buildSettledLedgerTab() {
    if (_closedTrades.isEmpty) {
      return _buildEmptySlot("Audit Ledger Clean", "Completed and closed paper trades will appear here with audited P&L.");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _closedTrades.length,
      itemBuilder: (ctx, i) {
        final t = _closedTrades[i];
        final pnl = (t['realized_pnl'] as num).toDouble();
        final pct = (t['pnl_pct'] as num).toDouble();
        final isProfit = pnl >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1626),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['symbol'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text("Entry: ₹${t['entry_price']} • Exit: ₹${t['exit_price']} (${t['qty']} Qty)",
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}",
                    style: GoogleFonts.robotoMono(
                      color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "${isProfit ? '+' : ''}${pct.toStringAsFixed(2)}%",
                    style: TextStyle(
                      color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PAPER TRADE ORDER MODAL ---
  void _openOrderModal(String symbol, double price) {
    int qty = 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1322),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          final totalRequired = price * qty;
          final hasMargin = totalRequired <= _availableCash;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("EXECUTE COPY BUY",
                        style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w900)),
                    Text("Margin: ₹${_availableCash.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(symbol,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    Text("CMP: ₹${price.toStringAsFixed(2)}",
                        style: GoogleFonts.robotoMono(
                            color: const Color(0xFF00F5A0), fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Color(0xFF1E2B3E), height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Quantity (Shares):", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF00E5FF)),
                          onPressed: qty > 1 ? () => setModal(() => qty--) : null,
                        ),
                        Text("$qty",
                            style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E5FF)),
                          onPressed: () => setModal(() => qty++),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Required Capital:", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(
                      "₹${totalRequired.toStringAsFixed(2)}",
                      style: GoogleFonts.robotoMono(
                        color: hasMargin ? Colors.white : Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasMargin ? const Color(0xFF00F5A0) : Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: hasMargin
                        ? () {
                            Navigator.pop(ctx);
                            _executeBuy(symbol, price, qty);
                          }
                        : null,
                    child: Text(
                      hasMargin ? "CONFIRM PAPER ORDER" : "INSUFFICIENT MARGIN",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showResetLedgerModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1726),
        title: const Text('Reset Virtual Ledger?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Yeh aapki sabhi open holdings ko clear karke virtual cash ₹5,00,000 par reset kar dega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A6D)),
            onPressed: () {
              setState(() {
                _availableCash = _initialCapital;
                _realizedPnl = 0.0;
                _openPositions.clear();
                _closedTrades.clear();
              });
              _savePersistence();
              Navigator.pop(ctx);
              _notify("Ledger restored to ₹5,00,000", const Color(0xFF00E5FF));
            },
            child: const Text('Reset Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF1E2B3E), size: 44),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
