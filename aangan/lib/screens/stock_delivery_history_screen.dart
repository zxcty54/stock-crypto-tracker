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

enum DeliveryFilterMode {
  latestDate,
  highestDelivery,
  lowestDelivery,
  highestVolume,
}

// ---------------- SCREEN WIDGET ----------------
class StockDeliveryHistoryScreen extends StatefulWidget {
  final String initialSymbol;

  const StockDeliveryHistoryScreen({
    super.key,
    this.initialSymbol = '360ONE',
  });

  @override
  State<StockDeliveryHistoryScreen> createState() =>
      _StockDeliveryHistoryScreenState();
}

class _StockDeliveryHistoryScreenState
    extends State<StockDeliveryHistoryScreen> {
  final String _dataUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/stock_history_20d.json';

  Map<String, List<StockDayRecord>> _stockDatabase = {};
  late String _selectedSymbol;
  bool _isLoading = true;
  String? _errorMessage;
  DeliveryFilterMode _currentFilter = DeliveryFilterMode.latestDate;

  @override
  void initState() {
    super.initState();
    _selectedSymbol = widget.initialSymbol;
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    try {
      final res = await http.get(
        Uri.parse('$_dataUrl?ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> rawJson = jsonDecode(res.body);
        final Map<String, List<StockDayRecord>> parsed = {};

        rawJson.forEach((sym, records) {
          final list = records as List;
          parsed[sym] = list.map((item) => StockDayRecord.fromList(item)).toList();
        });

        setState(() {
          _stockDatabase = parsed;
          if (!_stockDatabase.containsKey(_selectedSymbol) &&
              _stockDatabase.isNotEmpty) {
            _selectedSymbol = _stockDatabase.keys.first;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load: HTTP ${res.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network connection issue: $e';
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
              : Column(
                  children: [
                    _buildSelectorAndFilterBar(),
                    _buildSummaryBar(),
                    Expanded(child: _buildHistoryListView()),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: row.deliveryPercent >= 60.0
                  ? const Color(0xFF00F0FF).withOpacity(0.4)
                  : const Color(0xFF1E2B3E),
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
                      if (row.deliveryPercent >= 60.0) ...[
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
