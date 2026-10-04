ScreenState();
}

class _PortfolioTrackerScreenState extends State<PortfolioTrackerScreen>
    with SingleTickerProviderStateMixin {
  final String _sheetApiUrl =
      'https://script.google.com/macros/s/AKfycbzE5FVwepYICR2SPsubssC8zdvCrFbEJqh1lEawkjb8DxVrAv2hTnOzKfozz4Sj3uW8vQ/exec';

  late TabController _tabController;

  // Virtual Account Balance
  static const double _initialCapital = 500000.0; // ₹5,00,000 Virtual Capital
  double _availableCash = _initialCapital;
  double _realizedPnl = 0.0;

  // Market Feed Data
  Map<String, Map<String, dynamic>> _marketFeed = {};
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Portfolio & Watchlist Stores
  List<Map<String, dynamic>> _openPositions = [];
  List<Map<String, dynamic>> _closedTrades = [];
  Set<String> _watchlist = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPortfolioState();
    _fetchLiveSheetPrices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LOCAL PERSISTENCE ---
  Future<void> _loadPortfolioState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _availableCash = prefs.getDouble('virtual_cash') ?? _initialCapital;
      _realizedPnl = prefs.getDouble('realized_pnl') ?? 0.0;

      final positionsJson = prefs.getString('open_positions');
      if (positionsJson != null) {
        _openPositions = List<Map<String, dynamic>>.from(jsonDecode(positionsJson));
      }

      final closedJson = prefs.getString('closed_trades');
      if (closedJson != null) {
        _closedTrades = List<Map<String, dynamic>>.from(jsonDecode(closedJson));
      }

      final watchlistList = prefs.getStringList('user_watchlist');
      if (watchlistList != null) {
        _watchlist = watchlistList.toSet();
      }
    });
  }

  Future<void> _savePortfolioState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('virtual_cash', _availableCash);
    await prefs.setDouble('realized_pnl', _realizedPnl);
    await prefs.setString('open_positions', jsonEncode(_openPositions));
    await prefs.setString('closed_trades', jsonEncode(_closedTrades));
    await prefs.setStringList('user_watchlist', _watchlist.toList());
  }

  // --- LIVE DATA FETCH FROM GOOGLE SCRIPT ---
  Future<void> _fetchLiveSheetPrices({bool isManual = false}) async {
    if (isManual) setState(() => _isRefreshing = true);

    try {
      final res = await http.get(Uri.parse(_sheetApiUrl)).timeout(const Duration(seconds: 14));
      if (res.statusCode == 200 || res.statusCode == 302) {
        final dynamic raw = jsonDecode(res.body);
        Map<String, Map<String, dynamic>> parsedFeed = {};

        // Handles List of maps or Object formats returned by Google Script
        if (raw is List) {
          for (var item in raw) {
            final sym = (item['symbol'] ?? item['name'] ?? item['ticker'] ?? item['Stock'] ?? '').toString().toUpperCase().trim();
            if (sym.isNotEmpty) {
              final price = _parseDouble(item['price'] ?? item['ltp'] ?? item['current_price'] ?? item['LTP'] ?? item['Price']);
              final change = _parseDouble(item['change'] ?? item['pChange'] ?? item['Change%'] ?? item['chg']);
              parsedFeed[sym] = {'price': price, 'change': change};
            }
          }
        } else if (raw is Map) {
          raw.forEach((k, v) {
            final sym = k.toString().toUpperCase().trim();
            if (v is Map) {
              parsedFeed[sym] = {
                'price': _parseDouble(v['price'] ?? v['ltp'] ?? v['current_price']),
                'change': _parseDouble(v['change'] ?? v['pChange']),
              };
            }
          });
        }

        setState(() {
          _marketFeed = parsedFeed;
          _isLoading = false;
          _isRefreshing = false;
        });

        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Live Prices Synced (${_marketFeed.length} Stocks)'),
              backgroundColor: const Color(0xFF00F5A0),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint("Google Sheet API Fetch Error: $e");
    }

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').replaceAll('%', '').trim()) ?? 0.0;
  }

  // --- TRADING EXECUTION ENGINE ---
  void _executeOrder(String symbol, double entryPrice, int qty, String side) {
    final orderValue = entryPrice * qty;

    if (side == 'BUY' && orderValue > _availableCash) {
      _showToast('❌ Insufficient Virtual Cash! Required: ₹${orderValue.toStringAsFixed(2)}', Colors.redAccent);
      return;
    }

    setState(() {
      if (side == 'BUY') {
        _availableCash -= orderValue;
      }

      _openPositions.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'symbol': symbol,
        'entry_price': entryPrice,
        'qty': qty,
        'side': side,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _savePortfolioState();
    HapticFeedback.heavyImpact();
    _showToast('✅ Order Executed: $side $qty Qty of $symbol @ ₹$entryPrice', const Color(0xFF00F5A0));
  }

  void _exitPosition(Map<String, dynamic> pos) {
    final symbol = pos['symbol'];
    final entryPrice = (pos['entry_price'] as num).toDouble();
    final qty = (pos['qty'] as num).toInt();
    final side = pos['side'];

    final currentLtp = _marketFeed[symbol]?['price'] ?? entryPrice;
    double tradePnl = 0.0;

    if (side == 'BUY') {
      tradePnl = (currentLtp - entryPrice) * qty;
      _availableCash += (entryPrice * qty) + tradePnl; // Principal + Settled P&L
    } else {
      tradePnl = (entryPrice - currentLtp) * qty;
      _availableCash += tradePnl;
    }

    setState(() {
      _realizedPnl += tradePnl;
      _openPositions.removeWhere((p) => p['id'] == pos['id']);

      _closedTrades.insert(0, {
        ...pos,
        'exit_price': currentLtp,
        'pnl': tradePnl,
        'exit_time': DateTime.now().toIso8601String(),
      });
    });

    _savePortfolioState();
    HapticFeedback.mediumImpact();
    _showToast('🎯 Position Settled! P&L: ${tradePnl >= 0 ? "+" : ""}₹${tradePnl.toStringAsFixed(2)}',
        tradePnl >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D));
  }

  void _toggleWatchlist(String symbol) {
    setState(() {
      if (_watchlist.contains(symbol)) {
        _watchlist.remove(symbol);
        _showToast('Removed from Watchlist', Colors.white60);
      } else {
        _watchlist.add(symbol);
        _showToast('Added to Watchlist ⭐', const Color(0xFF00E5FF));
      }
    });
    _savePortfolioState();
  }

  void _resetVirtualAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1726),
        title: const Text('Reset Virtual Capital?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Yeh aapki saari open positions delete kar dega aur virtual balance ko ₹5,00,000 par reset kar dega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A6D)),
            onPressed: () {
              setState(() {
                _availableCash = _initialCapital;
                _realizedPnl = 0.0;
                _openPositions.clear();
                _closedTrades.clear();
              });
              _savePortfolioState();
              Navigator.pop(ctx);
              _showToast('Virtual Balance Reset to ₹5,00,000', const Color(0xFF00E5FF));
            },
            child: const Text('Reset Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- CALCULATIONS ---
  double get _totalUnrealizedPnl {
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

  double get _investedAmount {
    double total = 0.0;
    for (var pos in _openPositions) {
      total += (pos['entry_price'] as num).toDouble() * (pos['qty'] as num).toInt();
    }
    return total;
  }

  double get _totalPortfolioValue => _availableCash + _investedAmount + _totalUnrealizedPnl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        title: Text(
          "PORTFOLIO TERMINAL",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.0,
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
            tooltip: 'Sync Live Sheet LTP',
            onPressed: _isRefreshing ? null : () => _fetchLiveSheetPrices(isManual: true),
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white60, size: 20),
            tooltip: 'Reset ₹5L Virtual Account',
            onPressed: _resetVirtualAccount,
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
            Tab(text: "POSITIONS (${_openPositions.length})"),
            Tab(text: "WATCHLIST (${_watchlist.length})"),
            Tab(text: "HISTORY (${_closedTrades.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : Column(
              children: [
                _buildRealtimeBalanceBanner(),
                _buildSearchBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPositionsTab(),
                      _buildWatchlistTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- PORTFOLIO EXECUTIVE METRICS BANNER ---
  Widget _buildRealtimeBalanceBanner() {
    final unPnl = _totalUnrealizedPnl;
    final isProfit = unPnl >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                  const Text("TOTAL PORTFOLIO VALUE",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    "₹${_formatCurrency(_totalPortfolioValue)}",
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isProfit ? const Color(0xFF00F5A0).withOpacity(0.12) : const Color(0xFFFF2A6D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isProfit ? const Color(0xFF00F5A0).withOpacity(0.3) : const Color(0xFFFF2A6D).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "LIVE UNREALIZED P&L",
                      style: TextStyle(
                          color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900),
                    ),
                    Text(
                      "${isProfit ? '+' : ''}₹${unPnl.toStringAsFixed(2)}",
                      style: GoogleFonts.robotoMono(
                          color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
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
              _metricCol("AVAILABLE CASH", "₹${_formatCurrency(_availableCash)}", const Color(0xFF00E5FF)),
              _metricCol("INVESTED", "₹${_formatCurrency(_investedAmount)}", Colors.white70),
              _metricCol("SETTLED P&L", "${_realizedPnl >= 0 ? '+' : ''}₹${_realizedPnl.toStringAsFixed(1)}",
                  _realizedPnl >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.robotoMono(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // --- SEARCH BAR WIDGET ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF141F33),
          hintText: "Search stock from Google Sheet (e.g. RELIANCE, TCS)...",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E2B3E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E2B3E)),
          ),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim().toUpperCase()),
      ),
    );
  }

  // --- TAB 1: LIVE POSITIONS ---
  Widget _buildPositionsTab() {
    if (_openPositions.isEmpty) {
      return _buildEmptyPlaceholder("No Open Positions", "Search stocks and hit BUY to start paper copy-trading.");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _openPositions.length,
      itemBuilder: (ctx, i) {
        final pos = _openPositions[i];
        final sym = pos['symbol'];
        final entry = (pos['entry_price'] as num).toDouble();
        final qty = (pos['qty'] as num).toInt();
        final ltp = _marketFeed[sym]?['price'] ?? entry;

        final pnl = (ltp - entry) * qty;
        final pnlPct = entry > 0 ? ((ltp - entry) / entry) * 100 : 0.0;
        final isProfit = pnl >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(pos['side'],
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      Text(sym,
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Text("• ${qty} Qty", style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}",
                        style: GoogleFonts.robotoMono(
                          color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        "${isProfit ? '+' : ''}${pnlPct.toStringAsFixed(2)}%",
                        style: TextStyle(
                          color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                          fontSize: 10,
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
                  Text("Entry: ₹${entry.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  Text("LTP: ₹${ltp.toStringAsFixed(2)}",
                      style: GoogleFonts.robotoMono(color: const Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2A6D).withOpacity(0.15),
                      foregroundColor: const Color(0xFFFF2A6D),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFFF2A6D), width: 0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _exitPosition(pos),
                    child: const Text("EXIT / SETTLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: WATCHLIST & SEARCH DISCOVERY ---
  Widget _buildWatchlistTab() {
    List<String> displaySymbols = [];

    if (_searchQuery.isNotEmpty) {
      displaySymbols = _marketFeed.keys.where((s) => s.contains(_searchQuery)).toList();
    } else {
      displaySymbols = _watchlist.toList();
    }

    if (displaySymbols.isEmpty) {
      return _buildEmptyPlaceholder(
        _searchQuery.isNotEmpty ? "Stock Not Found in Sheet" : "Watchlist is Empty",
        "Type any stock name in the search bar above to monitor live Google Sheet prices.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: displaySymbols.length,
      itemBuilder: (ctx, i) {
        final sym = displaySymbols[i];
        final item = _marketFeed[sym] ?? {'price': 0.0, 'change': 0.0};
        final price = item['price'] as double;
        final chg = item['change'] as double;
        final isUp = chg >= 0;
        final isWatched = _watchlist.contains(sym);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
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
                      isWatched ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isWatched ? const Color(0xFF00E5FF) : Colors.white38,
                      size: 22,
                    ),
                    onPressed: () => _toggleWatchlist(sym),
                  ),
                  Text(
                    sym,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹${price.toStringAsFixed(2)}",
                          style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(
                        "${isUp ? '+' : ''}${chg.toStringAsFixed(2)}%",
                        style: TextStyle(
                          color: isUp ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F5A0).withOpacity(0.15),
                      foregroundColor: const Color(0xFF00F5A0),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF00F5A0), width: 0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openOrderSheet(sym, price),
                    child: const Text("BUY", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: SETTLED TRADE HISTORY ---
  Widget _buildHistoryTab() {
    if (_closedTrades.isEmpty) {
      return _buildEmptyPlaceholder("No Settled Trades", "When you close positions, settled P&L will show here.");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _closedTrades.length,
      itemBuilder: (ctx, i) {
        final tr = _closedTrades[i];
        final pnl = (tr['pnl'] as num).toDouble();
        final isProfit = pnl >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E2B3E)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr['symbol'],
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    "Bought @ ₹${tr['entry_price']} • Exited @ ₹${tr['exit_price']} (${tr['qty']} Qty)",
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                ],
              ),
              Text(
                "${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}",
                style: GoogleFonts.robotoMono(
                  color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ORDER SHEET (BUY DIALOG) ---
  void _openOrderSheet(String symbol, double price) {
    int qty = 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final orderTotal = price * qty;
            final canAfford = orderTotal <= _availableCash;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("COPY TRADE ORDER",
                          style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w900)),
                      Text("Cash: ₹${_formatCurrency(_availableCash)}",
                          style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(symbol,
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text("LTP: ₹${price.toStringAsFixed(2)}",
                          style: GoogleFonts.robotoMono(color: const Color(0xFF00F5A0), fontSize: 14, fontWeight: FontWeight.w900)),
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
                            onPressed: qty > 1 ? () => setSheetState(() => qty--) : null,
                          ),
                          Text("$qty",
                              style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E5FF)),
                            onPressed: () => setSheetState(() => qty++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Estimated Total Value:", style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text("₹${orderTotal.toStringAsFixed(2)}",
                          style: GoogleFonts.robotoMono(
                              color: canAfford ? Colors.white : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAfford ? const Color(0xFF00F5A0) : Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: canAfford
                          ? () {
                              Navigator.pop(ctx);
                              _executeOrder(symbol, price, qty, 'BUY');
                            }
                          : null,
                      child: Text(
                        canAfford ? "EXECUTE COPY BUY" : "INSUFFICIENT BALANCE",
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
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

  Widget _buildEmptyPlaceholder(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF1E2B3E), size: 48),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double val) {
    if (val >= 100000) {
      return "${(val / 100000).toStringAsFixed(2)}L";
    }
    return val.toStringAsFixed(2);
  }
}
