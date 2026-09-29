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

  // Exactly parses aapka JSON structure:
  // ["2026-09-29", 212.16, 216.45, 209.02, 212.8, 54062, 44.52]
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
  // Aapke repository ka JSON endpoint (ya fallback local/fastly cdn)
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

  // 1. Top Stock Selector & Filter Chips
  Widget _buildSelectorAndFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0F1726),
      child: Column(
        children: [
          Row(
            children: [
              // Stock Picker Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF25334A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSymbol,
                    dropdownColor: const Color(0xFF0F1726),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF00F0FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    items: _stockDatabase.keys
                        .map((sym) => DropdownMenuItem(
                              value: sym,
                              child: Text(sym),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedSymbol = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('📅 Date', DeliveryFilterMode.latestDate),
                      const SizedBox(width: 6),
                      _filterChip('🔥 Highest Del %',
                          DeliveryFilterMode.highestDelivery),
                      const SizedBox(width: 6),
                      _filterChip(
                          '❄️ Lowest Del %', DeliveryFilterMode.lowestDelivery),
                      const SizedBox(width: 6),
                      _filterChip(
                          '📊 Max Vol', DeliveryFilterMode.highestVolume),
                    ],
                  ),
                ),
              ),
            ],
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

  // 2. High-Level Delivery Summary Bar for Selected Stock
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
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B7A99),
                fontSize: 9.5,
                fontWeight: FontWeight.bold)),
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
              // Date, Close Price, and High Accumulation Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F5A0).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('STRONG DELIVERY',
                              style: TextStyle(
                                  color: Color(0xFF00F5A0),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900)),
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

              // Delivery % Progress Bar & Exact Quantity
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
                          style: const TextStyle(
                              color: Colors.white30, fontSize: 8.5),
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

              // Progress Bar with Delivery %
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
            color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold),
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
