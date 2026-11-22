import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ---------------- DATA MODEL ----------------
class StockDayRecord {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int tradedQty;
  final double deliveryPercent;

  StockDayRecord({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.tradedQty,
    required this.deliveryPercent,
  });

  factory StockDayRecord.fromList(List<dynamic> list) {
    return StockDayRecord(
      date: list[0].toString(),
      open: (list[1] as num).toDouble(),
      high: (list[2] as num).toDouble(),
      low: (list[3] as num).toDouble(),
      close: (list[4] as num).toDouble(),
      tradedQty: list[5] is num
          ? (list[5] as num).toInt()
          : int.tryParse(list[5].toString()) ?? 0,
      deliveryPercent: list.length > 6 ? (list[6] as num).toDouble() : 0.0,
    );
  }

  int get deliveryQty => ((tradedQty * deliveryPercent) / 100).round();
  bool get isBull => close >= open;
}

class MarketMoverItem {
  final String symbol;
  final double cmp;
  final double refPrice;
  final double changePct;
  final int volume;
  final double deliveryPct;
  final String period;

  MarketMoverItem({
    required this.symbol,
    required this.cmp,
    required this.refPrice,
    required this.changePct,
    required this.volume,
    required this.deliveryPct,
    required this.period,
  });
}

class StealthAccumulationItem {
  final String symbol;
  final double cmp;
  final double dayChangePct;
  final double deliveryPct;
  final int volume;
  final int deliveryQty;
  final String date;
  final bool isStealthAccumulation;
  final bool isSpeculativeChurn;
  final String verdict;

  StealthAccumulationItem({
    required this.symbol,
    required this.cmp,
    required this.dayChangePct,
    required this.deliveryPct,
    required this.volume,
    required this.deliveryQty,
    required this.date,
    required this.isStealthAccumulation,
    required this.isSpeculativeChurn,
    required this.verdict,
  });
}

enum DeliveryFilterMode {
  latestDate,
  highestDelivery,
  lowestDelivery,
  highestVolume,
}

// ---------------- SCREEN WIDGET ----------------
class StockDeliveryHistoryScreen extends StatefulWidget {
  final String initialSymbol;
  final int initialTabIndex;

  const StockDeliveryHistoryScreen({
    super.key,
    this.initialSymbol = '360ONE',
    this.initialTabIndex = 0,
  });

  @override
  State<StockDeliveryHistoryScreen> createState() =>
      _StockDeliveryHistoryScreenState();
}

class _StockDeliveryHistoryScreenState
    extends State<StockDeliveryHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _dataUrls = [
    'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/main/stock_history_20d.json',
    'https://cdn.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/stock_history_20d.json',
    'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/stock_history_20d.json',
  ];

  late TabController _mainTabController;
  Map<String, List<StockDayRecord>> _stockDatabase = {};
  late String _selectedSymbol;
  bool _isLoading = true;
  String? _errorMessage;
  DeliveryFilterMode _currentFilter = DeliveryFilterMode.latestDate;

  // Market Movers Collections
  int _selectedMoverSubTab = 0; // 0: 🟢 1-Week, 1: 🚀 1-Month, 2: 🔴 Top Losers, 3: 📦 High Deliv
  List<MarketMoverItem> _weeklyGainers = [];
  List<MarketMoverItem> _monthlyGainers = [];
  List<MarketMoverItem> _weeklyLosers = [];
  List<MarketMoverItem> _highDeliveryGainers = [];

  // 🎯 Stealth Accumulation Collections
  int _selectedStealthSubTab = 0; // 0: Pure Accumulation, 1: High Deliv Uptick, 2: Speculative Pump
  List<StealthAccumulationItem> _pureAccumulationList = [];
  List<StealthAccumulationItem> _highDelUptickList = [];
  List<StealthAccumulationItem> _speculativeChurnList = [];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _selectedSymbol = widget.initialSymbol;
    _fetchHistoryData();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  void _computeMarketMovers() {
    final List<MarketMoverItem> weekly = [];
    final List<MarketMoverItem> monthly = [];

    _stockDatabase.forEach((sym, records) {
      if (records.length < 2) return;
      final latest = records.last;
      final cmp = latest.close;

      // 1-Week (5 trading sessions ago)
      if (records.length >= 5) {
        final p5 = records[records.length - 5].close;
        if (p5 > 0) {
          final chg = ((cmp - p5) / p5) * 100;
          weekly.add(MarketMoverItem(
            symbol: sym,
            cmp: cmp,
            refPrice: p5,
            changePct: double.parse(chg.toStringAsFixed(2)),
            volume: latest.tradedQty,
            deliveryPct: latest.deliveryPercent,
            period: '5-Day (1W)',
          ));
        }
      }

      // 1-Month / Multi-session (earliest recorded session in window)
      final pMonth = records.first.close;
      if (pMonth > 0) {
        final chg = ((cmp - pMonth) / pMonth) * 100;
        monthly.add(MarketMoverItem(
          symbol: sym,
          cmp: cmp,
          refPrice: pMonth,
          changePct: double.parse(chg.toStringAsFixed(2)),
          volume: latest.tradedQty,
          deliveryPct: latest.deliveryPercent,
          period: '${records.length}-Session Window',
        ));
      }
    });

    weekly.sort((a, b) => b.changePct.compareTo(a.changePct));
    monthly.sort((a, b) => b.changePct.compareTo(a.changePct));

    _weeklyGainers = weekly.where((x) => x.changePct > 0).take(35).toList();
    _weeklyLosers = weekly.where((x) => x.changePct < 0).toList().reversed.take(35).toList();
    _monthlyGainers = monthly.where((x) => x.changePct > 0).take(35).toList();
    _highDeliveryGainers = weekly.where((x) => x.deliveryPct >= 50.0 && x.changePct > 2.0).take(30).toList();

    // 🎯 Stealth Accumulation Scanner Computation
    final List<StealthAccumulationItem> pureAcc = [];
    final List<StealthAccumulationItem> delUptick = [];
    final List<StealthAccumulationItem> specChurn = [];

    _stockDatabase.forEach((sym, records) {
      if (records.isEmpty) return;
      final latest = records.last;
      final cmp = latest.close;
      final open = latest.open;
      final double dayChg = open > 0 ? ((cmp - open) / open) * 100 : 0.0;
      final delPct = latest.deliveryPercent;
      final vol = latest.tradedQty;
      final delQty = latest.deliveryQty;

      // Pure Stealth Accumulation: High Delivery >= 70%, tight price movement |DayChg| <= 1.8%
      if (delPct >= 70.0 && dayChg.abs() <= 1.8 && vol >= 1000) {
        pureAcc.add(StealthAccumulationItem(
          symbol: sym,
          cmp: cmp,
          dayChangePct: double.parse(dayChg.toStringAsFixed(2)),
          deliveryPct: delPct,
          volume: vol,
          deliveryQty: delQty,
          date: latest.date,
          isStealthAccumulation: true,
          isSpeculativeChurn: false,
          verdict: 'STEALTH DEMAT ACCUMULATION',
        ));
      } else if (delPct >= 65.0 && dayChg > 1.2 && dayChg <= 4.0 && vol >= 1000) {
        delUptick.add(StealthAccumulationItem(
          symbol: sym,
          cmp: cmp,
          dayChangePct: double.parse(dayChg.toStringAsFixed(2)),
          deliveryPct: delPct,
          volume: vol,
          deliveryQty: delQty,
          date: latest.date,
          isStealthAccumulation: true,
          isSpeculativeChurn: false,
          verdict: 'HIGH DELIVERY WITH UPTICK',
        ));
      } else if (dayChg >= 4.0 && delPct < 25.0 && vol >= 5000) {
        specChurn.add(StealthAccumulationItem(
          symbol: sym,
          cmp: cmp,
          dayChangePct: double.parse(dayChg.toStringAsFixed(2)),
          deliveryPct: delPct,
          volume: vol,
          deliveryQty: delQty,
          date: latest.date,
          isStealthAccumulation: false,
          isSpeculativeChurn: true,
          verdict: 'OPERATOR PUMP (LOW DELIV)',
        ));
      }
    });

    pureAcc.sort((a, b) => b.deliveryPct.compareTo(a.deliveryPct));
    delUptick.sort((a, b) => b.deliveryPct.compareTo(a.deliveryPct));
    specChurn.sort((a, b) => b.dayChangePct.compareTo(a.dayChangePct));

    _pureAccumulationList = pureAcc.take(50).toList();
    _highDelUptickList = delUptick.take(50).toList();
    _speculativeChurnList = specChurn.take(50).toList();
  }

  Future<void> _fetchHistoryData() async {
    for (final url in _dataUrls) {
      try {
        final res = await http.get(
          Uri.parse('$url?ts=${DateTime.now().millisecondsSinceEpoch}'),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200 && res.body.isNotEmpty) {
          final Map<String, dynamic> rawJson = jsonDecode(utf8.decode(res.bodyBytes));
          final Map<String, List<StockDayRecord>> parsed = {};

          rawJson.forEach((sym, records) {
            final list = records as List;
            parsed[sym] = list.map((item) => StockDayRecord.fromList(item)).toList();
          });

          if (mounted) {
            setState(() {
              _stockDatabase = parsed;
              _computeMarketMovers();
              if (!_stockDatabase.containsKey(_selectedSymbol) &&
                  _stockDatabase.isNotEmpty) {
                _selectedSymbol = _stockDatabase.keys.first;
              }
              _errorMessage = null;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("Endpoint failed ($url): $e");
      }
    }

    if (mounted && _stockDatabase.isEmpty) {
      setState(() {
        _errorMessage = 'Network connection issue: Unable to load 20D OHLC and delivery data.';
        _isLoading = false;
      });
    }
  }

  List<StockDayRecord> _getProcessedRecords() {
    final original = _stockDatabase[_selectedSymbol] ?? [];
    final records = List<StockDayRecord>.from(original);

    switch (_currentFilter) {
      case DeliveryFilterMode.highestDelivery:
        records.sort((a, b) => b.deliveryPercent.compareTo(a.deliveryPercent));
        break;
      case DeliveryFilterMode.lowestDelivery:
        records.sort((a, b) => a.deliveryPercent.compareTo(b.deliveryPercent));
        break;
      case DeliveryFilterMode.highestVolume:
        records.sort((a, b) => b.tradedQty.compareTo(a.tradedQty));
        break;
      case DeliveryFilterMode.latestDate:
        records.sort((a, b) => b.date.compareTo(a.date));
        break;
    }
    return records;
  }

  String _formatCompact(num val) {
    if (val >= 10000000) return '${(val / 10000000).toStringAsFixed(2)} Cr';
    if (val >= 100000) return '${(val / 100000).toStringAsFixed(2)} L';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)} K';
    return val.toStringAsFixed(0);
  }

  String _formatExact(int val) {
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // 🔍 Interactive Stock Search Modal Bottom Sheet
  void _openStockSearchModal() {
    HapticFeedback.selectionClick();
    final allSymbols = _stockDatabase.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredSymbols = allSymbols.where((s) {
              return s.toLowerCase().contains(searchQuery.toLowerCase().trim());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search Bar Input
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF162032),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF25334A)),
                    ),
                    child: TextField(
                      autofocus: true,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: const Color(0xFF00F0FF),
                      decoration: InputDecoration(
                        hintText: 'Search stock name (e.g. TCS, 360ONE, INFY)...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF6B7A99),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF00F0FF),
                          size: 20,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                onPressed: () {
                                  setModalState(() => searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Results Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STOCKS (${filteredSymbols.length})',
                        style: const TextStyle(
                          color: Color(0xFF5A6882),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Text(
                        'Tap to analyze history',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Filtered List
                  Expanded(
                    child: filteredSymbols.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, color: Colors.white30, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'No stock matching "$searchQuery"',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredSymbols.length,
                            itemBuilder: (context, idx) {
                              final sym = filteredSymbols[idx];
                              final isCurrent = sym == _selectedSymbol;
                              final records = _stockDatabase[sym] ?? [];
                              final latestRecord = records.isNotEmpty ? records.last : null;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? const Color(0xFF00F0FF).withOpacity(0.12)
                                      : const Color(0xFF131B2A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCurrent
                                        ? const Color(0xFF00F0FF).withOpacity(0.4)
                                        : const Color(0xFF1E2B3E),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(ctx);
                                    setState(() => _selectedSymbol = sym);
                                  },
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C273C),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${records.length}D',
                                      style: const TextStyle(
                                        color: Color(0xFF00F0FF),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    sym,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isCurrent ? const Color(0xFF00F0FF) : Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: latestRecord != null
                                      ? Text(
                                          'Last: ₹${latestRecord.close.toStringAsFixed(1)} • Vol: ${_formatCompact(latestRecord.tradedQty)}',
                                          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 10),
                                        )
                                      : null,
                                  trailing: latestRecord != null
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: latestRecord.deliveryPercent >= 50
                                                ? const Color(0xFF00F5A0).withOpacity(0.15)
                                                : const Color(0xFFFF9800).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${latestRecord.deliveryPercent.toStringAsFixed(1)}% Del',
                                            style: TextStyle(
                                              color: latestRecord.deliveryPercent >= 50
                                                  ? const Color(0xFF00F5A0)
                                                  : const Color(0xFFFF9800),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        )
                                      : null,
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
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1726),
        elevation: 0,
        title: Text(
          'DELIVERY & OHLC ANALYTICS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF00F0FF),
            letterSpacing: 0.8,
          ),
        ),
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: const Color(0xFF00F0FF),
          indicatorWeight: 3,
          labelColor: const Color(0xFF00F0FF),
          unselectedLabelColor: const Color(0xFF8896AB),
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.candlestick_chart_rounded, size: 16), text: "📊 OHLC & Delivery"),
            Tab(icon: Icon(Icons.radar_rounded, size: 16), text: "🎯 Stealth Accumulation"),
            Tab(icon: Icon(Icons.leaderboard_rounded, size: 16), text: "🏆 1W & 1M Movers"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF00F0FF)),
            tooltip: 'Search Stock',
            onPressed: _openStockSearchModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchHistoryData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00F0FF),
                strokeWidth: 2,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.redAccent, size: 36),
                      const SizedBox(height: 10),
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchHistoryData();
                        },
                        child: const Text('Try Again',
                            style: TextStyle(color: Color(0xFF00F0FF))),
                      )
                    ],
                  ),
                )
              : TabBarView(
                  controller: _mainTabController,
                  children: [
                    Column(
                      children: [
                        _buildSelectorAndFilterBar(),
                        _buildSummaryBar(),
                        Expanded(child: _buildHistoryListView()),
                      ],
                    ),
                    _buildStealthAccumulationTab(),
                    _buildMarketMoversTab(),
                  ],
                ),
    );
  }

  Widget _buildStealthAccumulationTab() {
    List<StealthAccumulationItem> activeList;
    switch (_selectedStealthSubTab) {
      case 0:
        activeList = _pureAccumulationList;
        break;
      case 1:
        activeList = _highDelUptickList;
        break;
      case 2:
      default:
        activeList = _speculativeChurnList;
        break;
    }

    return Column(
      children: [
        // Educational Concept Card
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF131B2A), Color(0xFF0F1726)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF00FF88), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "SMART MONEY STEALTH ACCUMULATION",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF00FF88),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Jab Delivery % bohot high ho (70% - 90%+) lekin Price Change tight range me ho (±1.5%) — iska matlab Institutional Buyers चुपचाप shares Demat account me le ja rahe hain bina price ko pump kiye (Real Accumulation). Agar price +8% bhaage par delivery sirf 15% ho, wo retail trap / speculative pump hota hai.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        // Sub-filter selector chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F1726),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStealthSubTabChip(0, "🎯 Pure Stealth (${_pureAccumulationList.length})", const Color(0xFF00FF88)),
                const SizedBox(width: 8),
                _buildStealthSubTabChip(1, "⚡ High Deliv Uptick (${_highDelUptickList.length})", const Color(0xFF00F0FF)),
                const SizedBox(width: 8),
                _buildStealthSubTabChip(2, "⚠️ Speculative Pump (${_speculativeChurnList.length})", const Color(0xFFFFB703)),
              ],
            ),
          ),
        ),

        // List of scanned stocks
        Expanded(
          child: activeList.isEmpty
              ? const Center(
                  child: Text(
                    "No stocks matching this criteria in latest session",
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                  itemCount: activeList.length,
                  itemBuilder: (context, idx) {
                    final item = activeList[idx];
                    final badgeColor = item.isSpeculativeChurn
                        ? const Color(0xFFFFB703)
                        : (item.deliveryPct >= 75.0 ? const Color(0xFF00FF88) : const Color(0xFF00F0FF));

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _selectedSymbol = item.symbol;
                        });
                        _mainTabController.animateTo(0);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: badgeColor.withOpacity(0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.symbol,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: badgeColor.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        item.verdict,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "₹${item.cmp.toStringAsFixed(2)}",
                                  style: GoogleFonts.robotoMono(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Delivery Progress Bar
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: (item.deliveryPct / 100.0).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFF1E2B3E),
                                      valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${item.deliveryPct.toStringAsFixed(1)}% Delivery",
                                  style: GoogleFonts.robotoMono(
                                    color: badgeColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Traded: ${_formatCompact(item.volume)} • Demat: ${_formatCompact(item.deliveryQty)}",
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (item.dayChangePct >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D)).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "${item.dayChangePct >= 0 ? '+' : ''}${item.dayChangePct.toStringAsFixed(2)}% Move",
                                    style: TextStyle(
                                      color: item.dayChangePct >= 0 ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStealthSubTabChip(int index, String label, Color color) {
    final isSelected = _selectedStealthSubTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStealthSubTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF131B2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF1E2B3E),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : const Color(0xFF8896AB),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMarketMoversTab() {
    List<MarketMoverItem> activeList;
    switch (_selectedMoverSubTab) {
      case 0:
        activeList = _weeklyGainers;
        break;
      case 1:
        activeList = _monthlyGainers;
        break;
      case 2:
        activeList = _weeklyLosers;
        break;
      case 3:
      default:
        activeList = _highDeliveryGainers;
        break;
    }

    return Column(
      children: [
        // Sub-selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0F1726),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMoverSubTabChip(0, "🟢 1-Week Gainers (${_weeklyGainers.length})"),
                const SizedBox(width: 8),
                _buildMoverSubTabChip(1, "🚀 1-Month Gainers (${_monthlyGainers.length})"),
                const SizedBox(width: 8),
                _buildMoverSubTabChip(2, "🔴 Top Losers (${_weeklyLosers.length})"),
                const SizedBox(width: 8),
                _buildMoverSubTabChip(3, "📦 High Deliv Acc (${_highDeliveryGainers.length})"),
              ],
            ),
          ),
        ),

        // Hint bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: const Color(0xFF0A101D),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RANKED BY LIQUID EXCHANGE VOLUME & % RETURN',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00F0FF),
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                'Tap to inspect OHLC',
                style: TextStyle(color: Colors.white38, fontSize: 9.5),
              ),
            ],
          ),
        ),

        // Active List
        Expanded(
          child: activeList.isEmpty
              ? const Center(
                  child: Text("No records available in this timeframe", style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: activeList.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == activeList.length) {
                      return _buildSebiDisclaimer();
                    }
                    final item = activeList[idx];
                    return _buildMoverStockCard(item, idx + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMoverSubTabChip(int index, String label) {
    final isSelected = _selectedMoverSubTab == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMoverSubTab = index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F0FF).withOpacity(0.18) : const Color(0xFF162032),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00F0FF) : const Color(0xFF25334A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00F0FF) : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMoverStockCard(MarketMoverItem item, int rank) {
    final isGain = item.changePct >= 0;
    final color = isGain ? const Color(0xFF00F5A0) : const Color(0xFFFF5252);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2B3E)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedSymbol = item.symbol;
            });
            _mainTabController.animateTo(0);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Rank Circle
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2638),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Symbol & Base Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.symbol,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.deliveryPct >= 50
                                  ? const Color(0xFF00F5A0).withOpacity(0.15)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.deliveryPct.toStringAsFixed(1)}% Del',
                              style: TextStyle(
                                color: item.deliveryPct >= 50
                                    ? const Color(0xFF00F5A0)
                                    : const Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Base: ₹${item.refPrice.toStringAsFixed(1)} • Vol: ${_formatCompact(item.volume)}',
                        style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // CMP & Return Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.cmp.toStringAsFixed(1)}',
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isGain ? '+' : ''}${item.changePct.toStringAsFixed(2)}%',
                        style: GoogleFonts.robotoMono(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSebiDisclaimer() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFFFFB300), size: 14),
              SizedBox(width: 6),
              Text(
                "SEBI COMPLIANCE & RESEARCH DISCLAIMER",
                style: TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            "This leaderboard ranks securities purely based on historical price and volume percentages extracted from official NSE Bhavcopy files. "
            "It does NOT constitute investment advice, buy/sell calls, or price targets. StockPulse is not SEBI registered. Please consult a SEBI registered investment advisor before trading.",
            style: TextStyle(color: Color(0xFF8896AB), fontSize: 9.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  // 1. Top Stock Selector (Tappable Search) & Filter Chips
  Widget _buildSelectorAndFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0F1726),
      child: Row(
        children: [
          // 🔎 1-Tap Search Trigger Button
          InkWell(
            onTap: _openStockSearchModal,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF162032),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF00F0FF), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _selectedSymbol,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF00F0FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF00F0FF), size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Horizontal Filter Chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('📅 Date', DeliveryFilterMode.latestDate),
                  const SizedBox(width: 6),
                  _filterChip('🔥 Highest Del %', DeliveryFilterMode.highestDelivery),
                  const SizedBox(width: 6),
                  _filterChip('❄️ Lowest Del %', DeliveryFilterMode.lowestDelivery),
                  const SizedBox(width: 6),
                  _filterChip('📊 Max Vol', DeliveryFilterMode.highestVolume),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String title, DeliveryFilterMode mode) {
    final isSelected = _currentFilter == mode;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentFilter = mode);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00F0FF).withOpacity(0.18)
              : const Color(0xFF162032),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00F0FF)
                : const Color(0xFF25334A),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? const Color(0xFF00F0FF) : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 2. High-Level Delivery Summary Bar
  Widget _buildSummaryBar() {
    final records = _stockDatabase[_selectedSymbol] ?? [];
    if (records.isEmpty) return const SizedBox.shrink();

    final avgDel = records.map((e) => e.deliveryPercent).reduce((a, b) => a + b) /
        records.length;
    final maxDel = records.map((e) => e.deliveryPercent).reduce((a, b) => a > b ? a : b);
    final avgVol = records.map((e) => e.tradedQty).reduce((a, b) => a + b) /
        records.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0D1420),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryStat('Total Records', '${records.length} Days'),
          _summaryStat('Avg Delivery', '${avgDel.toStringAsFixed(1)}%',
              color: avgDel >= 50 ? const Color(0xFF00F5A0) : const Color(0xFFFF9800)),
          _summaryStat('Max Delivery', '${maxDel.toStringAsFixed(1)}%',
              color: const Color(0xFF00F5A0)),
          _summaryStat('Avg Vol', _formatCompact(avgVol)),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7A99),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            color: color ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // 3. Historical Record Cards List
  Widget _buildHistoryListView() {
    final records = _getProcessedRecords();

    if (records.isEmpty) {
      return const Center(
        child: Text('No historical data available for this stock',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final row = records[index];
        final isBull = row.isBull;
        final bullColor = const Color(0xFF00F5A0);
        final bearColor = const Color(0xFFFF2A6D);
        final themeColor = isBull ? bullColor : bearColor;
        final double dayChgPct = row.open > 0 ? ((row.close - row.open) / row.open) * 100 : 0.0;
        final bool isStealthAccumulation = row.deliveryPercent >= 70.0 && dayChgPct.abs() <= 1.8;
        final bool isSpeculativePump = dayChgPct >= 4.0 && row.deliveryPercent < 25.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isStealthAccumulation
                  ? const Color(0xFF00FF88).withOpacity(0.5)
                  : (row.deliveryPercent >= 60.0
                      ? const Color(0xFF00F0FF).withOpacity(0.4)
                      : const Color(0xFF1E2B3E)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2436),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          row.date,
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      if (isStealthAccumulation) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF88).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                          ),
                          child: const Text(
                            '🎯 STEALTH ACCUMULATION',
                            style: TextStyle(
                              color: Color(0xFF00FF88),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ] else if (isSpeculativePump) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB703).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.4)),
                          ),
                          child: const Text(
                            '⚠️ SPECULATIVE PUMP',
                            style: TextStyle(
                              color: Color(0xFFFFB703),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ] else if (row.deliveryPercent >= 60.0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F5A0).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'STRONG DELIVERY',
                            style: TextStyle(
                              color: Color(0xFF00F5A0),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                  Text(
                    '₹${row.close.toStringAsFixed(2)}',
                    style: GoogleFonts.robotoMono(
                      color: themeColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // OHLC Matrix
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1019),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ohlcText('O', '₹${row.open.toStringAsFixed(1)}', Colors.white70),
                    _ohlcText('H', '₹${row.high.toStringAsFixed(1)}', bullColor),
                    _ohlcText('L', '₹${row.low.toStringAsFixed(1)}', bearColor),
                    _ohlcText('C', '₹${row.close.toStringAsFixed(1)}', themeColor),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Delivery & Traded Volume Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Traded: ',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                      children: [
                        TextSpan(
                          text: _formatCompact(row.tradedQty),
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: ' (${_formatExact(row.tradedQty)})',
                          style: const TextStyle(color: Colors.white30, fontSize: 8.5),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: 'Delivery: ',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                      children: [
                        TextSpan(
                          text: _formatCompact(row.deliveryQty),
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF00F0FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (row.deliveryPercent / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFF1B2434),
                        color: row.deliveryPercent >= 50
                            ? const Color(0xFF00F5A0)
                            : const Color(0xFF00F0FF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${row.deliveryPercent.toStringAsFixed(2)}%',
                    style: GoogleFonts.robotoMono(
                      color: row.deliveryPercent >= 50
                          ? const Color(0xFF00F5A0)
                          : const Color(0xFF00F0FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
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

  Widget _ohlcText(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
        children: [
          TextSpan(
            text: value,
            style: GoogleFonts.robotoMono(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
