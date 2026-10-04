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

  List<Map<String, dynamic>> _openPositions = [];
  List<Map<String, dynamic>> _closedTrades = [];
  Set<String> _watchlist = {};

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _restoreData();
    _loadPrices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _availableCash = prefs.getDouble('virtual_funds') ?? _initialCapital;
      _realizedPnl = prefs.getDouble('settled_pnl') ?? 0.0;

      final posStr = prefs.getString('positions_cache');
      if (posStr != null) {
        _openPositions = List<Map<String, dynamic>>.from(jsonDecode(posStr));
      }

      final histStr = prefs.getString('history_cache');
      if (histStr != null) {
        _closedTrades = List<Map<String, dynamic>>.from(jsonDecode(histStr));
      }

      final watchList = prefs.getStringList('watchlist_cache');
      if (watchList != null) {
        _watchlist = watchList.toSet();
      }
    });
  }

  Future<void> _persistData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('virtual_funds', _availableCash);
    await prefs.setDouble('settled_pnl', _realizedPnl);
    await prefs.setString('positions_cache', jsonEncode(_openPositions));
    await prefs.setString('history_cache', jsonEncode(_closedTrades));
    await prefs.setStringList('watchlist_cache', _watchlist.toList());
  }

  Future<void> _loadPrices({bool showSnackbar = false}) async {
    if (showSnackbar) setState(() => _isRefreshing = true);

    try {
      final res = await http.get(Uri.parse(_sheetUrl)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 || res.statusCode == 302) {
        final parsed = jsonDecode(res.body);
        Map<String, Map<String, dynamic>> tempFeed = {};

        if (parsed is List) {
          for (var entry in parsed) {
            final name = (entry['symbol'] ?? entry['name'] ?? entry['ticker'] ?? '').toString().toUpperCase().trim();
            if (name.isNotEmpty) {
              tempFeed[name] = {
                'price': _extractNum(entry['price'] ?? entry['ltp'] ?? entry['current_price']),
                'change': _extractNum(entry['change'] ?? entry['pChange'] ?? entry['chg']),
              };
            }
          }
        } else if (parsed is Map) {
          parsed.forEach((k, v) {
            final key = k.toString().toUpperCase().trim();
            if (v is Map) {
              tempFeed[key] = {
                'price': _extractNum(v['price'] ?? v['ltp']),
                'change': _extractNum(v['change'] ?? v['pChange']),
              };
            }
          });
        }

        setState(() {
          _marketFeed = tempFeed;
          _isLoading = false;
          _isRefreshing = false;
        });

        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Market sync complete: ${_marketFeed.length} assets updated'),
              backgroundColor: const Color(0xFF00F5A0),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint("Price sync error: $e");
    }

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  double _extractNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll(',', '').replaceAll('%', '').trim()) ?? 0.0;
  }

  void _buyPosition(String symbol, double price, int qty) {
    final cost = price * qty;
    if (cost > _availableCash) {
      _notify("Insufficient funds. Need ₹${cost.toStringAsFixed(2)}", Colors.redAccent);
      return;
    }

    setState(() {
      _availableCash -= cost;
      _openPositions.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'symbol': symbol,
        'entry_price': price,
        'qty': qty,
        'side': 'BUY',
        'time': DateTime.now().toIso8601String(),
      });
    });

    _persistData();
    HapticFeedback.lightImpact();
    _notify("Bought $qty shares of $symbol at ₹$price", const Color(0xFF00F5A0));
  }

  void _closePosition(Map<String, dynamic> item) {
    final symbol = item['symbol'];
    final entry = (item['entry_price'] as num).toDouble();
    final qty = (item['qty'] as num).toInt();
    final ltp = _marketFeed[symbol]?['price'] ?? entry;

    final diff = (ltp - entry) * qty;

    setState(() {
      _availableCash += (entry * qty) + diff;
      _realizedPnl += diff;
      _openPositions.removeWhere((p) => p['id'] == item['id']);

      _closedTrades.insert(0, {
        ...item,
        'exit_price': ltp,
        'settled_amount': diff,
        'closed_at': DateTime.now().toIso8601String(),
      });
    });

    _persistData();
    HapticFeedback.mediumImpact();
    _notify(
      "Position closed. P&L: ${diff >= 0 ? '+' : ''}₹${diff.toStringAsFixed(2)}",
      diff >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
    );
  }

  void _toggleFavorite(String sym) {
    setState(() {
      if (_watchlist.contains(sym)) {
        _watchlist.remove(sym);
        _notify("Removed $sym from watchlist", Colors.white60);
      } else {
        _watchlist.add(sym);
        _notify("Added $sym to watchlist", const Color(0xFF00E5FF));
      }
    });
    _persistData();
  }

  void _notify(String text, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: bg,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double get _floatingPnl {
    double total = 0.0;
    for (var pos in _openPositions) {
      final sym = pos['symbol'];
      final entry = (pos['entry_price'] as num).toDouble();
      final qty = (pos['qty'] as num).toInt();
      final current = _marketFeed[sym]?['price'] ?? entry;
      total += (current - entry) * qty;
    }
    return total;
  }

  double get _totalAllocated {
    double sum = 0.0;
    for (var pos in _openPositions) {
      sum += (pos['entry_price'] as num).toDouble() * (pos['qty'] as num).toInt();
    }
    return sum;
  }

  double get _netWorth => _availableCash + _totalAllocated + _floatingPnl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        title: Text(
          "PORTFOLIO TRACKER",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
            onPressed: _isRefreshing ? null : () => _loadPrices(showSnackbar: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: "HOLDINGS (${_openPositions.length})"),
            Tab(text: "WATCHLIST (${_watchlist.length})"),
            Tab(text: "SETTLED (${_closedTrades.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : Column(
              children: [
                _buildHeaderStats(),
                _buildSearchInput(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHoldingsTab(),
                      _buildWatchlistTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderStats() {
    final livePnl = _floatingPnl;
    final isPos = livePnl >= 0;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PORTFOLIO VALUATION", style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(
                    "₹${_netWorth.toStringAsFixed(2)}",
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isPos ? const Color(0xFF00F5A0).withOpacity(0.15) : const Color(0xFFFF2A6D).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${isPos ? '+' : ''}₹${livePnl.toStringAsFixed(2)}",
                  style: GoogleFonts.robotoMono(
                    color: isPos ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E2B3E), height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statTile("VIRTUAL CASH", "₹${_availableCash.toStringAsFixed(1)}", const Color(0xFF00E5FF)),
              _statTile("INVESTED", "₹${_totalAllocated.toStringAsFixed(1)}", Colors.white70),
              _statTile("SETTLED P&L", "${_realizedPnl >= 0 ? '+' : ''}₹${_realizedPnl.toStringAsFixed(1)}",
                  _realizedPnl >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String val, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.robotoMono(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF141F33),
          hintText: "Search stock symbol from sheet...",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF), size: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onChanged: (val) => setState(() => _searchFilter = val.trim().toUpperCase()),
      ),
    );
  }

  Widget _buildHoldingsTab() {
    if (_openPositions.isEmpty) {
      return const Center(child: Text("No active positions", style: TextStyle(color: Colors.white38, fontSize: 12)));
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
        final isProfit = diff >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sym, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(
                    "${isProfit ? '+' : ''}₹${diff.toStringAsFixed(2)}",
                    style: GoogleFonts.robotoMono(
                      color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Qty: $qty • Avg: ₹$entry • LTP: ₹$ltp", style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      backgroundColor: const Color(0xFFFF2A6D).withOpacity(0.15),
                    ),
                    onPressed: () => _closePosition(pos),
                    child: const Text("EXIT", style: TextStyle(color: Color(0xFFFF2A6D), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWatchlistTab() {
    List<String> list = [];
    if (_searchFilter.isNotEmpty) {
      list = _marketFeed.keys.where((s) => s.contains(_searchFilter)).toList();
    } else {
      list = _watchlist.toList();
    }

    if (list.isEmpty) {
      return const Center(child: Text("Search stocks to monitor prices", style: TextStyle(color: Colors.white38, fontSize: 12)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final sym = list[i];
        final price = _marketFeed[sym]?['price'] ?? 0.0;
        final chg = _marketFeed[sym]?['change'] ?? 0.0;
        final isFav = _watchlist.contains(sym);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? const Color(0xFF00E5FF) : Colors.white38, size: 20),
                    onPressed: () => _toggleFavorite(sym),
                  ),
                  Text(sym, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                ],
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹$price", style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("${chg >= 0 ? '+' : ''}$chg%", style: TextStyle(color: chg >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D), fontSize: 9.5)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5A0), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () => _showOrderModal(sym, price),
                    child: const Text("BUY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_closedTrades.isEmpty) {
      return const Center(child: Text("No closed trades recorded", style: TextStyle(color: Colors.white38, fontSize: 12)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _closedTrades.length,
      itemBuilder: (ctx, i) {
        final t = _closedTrades[i];
        final amount = (t['settled_amount'] as num).toDouble();
        final isGain = amount >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['symbol'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  Text("Bought: ₹${t['entry_price']} • Sold: ₹${t['exit_price']} (${t['qty']} Qty)", style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                ],
              ),
              Text(
                "${isGain ? '+' : ''}₹${amount.toStringAsFixed(2)}",
                style: GoogleFonts.robotoMono(color: isGain ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOrderModal(String symbol, double price) {
    int count = 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("BUY $symbol", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Text("Price per share: ₹$price", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.remove, color: Colors.white), onPressed: count > 1 ? () => setModal(() => count--) : null),
                  Text("$count", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => setModal(() => count++)),
                ],
              ),
              Text("Total: ₹${(price * count).toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5A0), minimumSize: const Size.fromHeight(38)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _buyPosition(symbol, price, count);
                },
                child: const Text("CONFIRM BUY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
