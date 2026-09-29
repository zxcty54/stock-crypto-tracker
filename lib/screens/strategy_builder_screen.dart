import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ---------------- DATA MODEL ----------------
class ReplayCandle {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  ReplayCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory ReplayCandle.fromMap(Map<String, dynamic> map) {
    return ReplayCandle(
      date: map['date'] ?? '',
      open: (map['open'] as num).toDouble(),
      high: (map['high'] as num).toDouble(),
      low: (map['low'] as num).toDouble(),
      close: (map['close'] as num).toDouble(),
      volume: (map['vol'] as num?)?.toInt() ?? 0,
    );
  }

  factory ReplayCandle.fromList(List dynamicList) {
    return ReplayCandle(
      date: dynamicList[0].toString(),
      open: (dynamicList[1] as num).toDouble(),
      high: (dynamicList[2] as num).toDouble(),
      low: (dynamicList[3] as num).toDouble(),
      close: (dynamicList[4] as num).toDouble(),
      volume: (dynamicList[5] as num).toInt(),
    );
  }

  bool get isBull => close >= open;
}

// ---------------- MAIN STRATEGY BUILDER SCREEN ----------------
class StrategyBuilderScreen extends StatefulWidget {
  const StrategyBuilderScreen({super.key});

  @override
  State<StrategyBuilderScreen> createState() => _StrategyBuilderScreenState();
}

class _StrategyBuilderScreenState extends State<StrategyBuilderScreen> {
  final String _jsonUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/historical_3yr_ohlc.json';

  Map<String, List<ReplayCandle>> _masterDatabase = {};
  String _selectedSymbol = 'TCS';
  bool _isLoading = true;
  String? _errorMessage;

  List<ReplayCandle> _activeSeries = [];
  int _cursor = 40;
  Timer? _timer;
  bool _isPlaying = false;
  final int _speedMs = 700;

  double _virtualCapital = 200000.0;
  double? _entryPrice;
  String? _positionSide;
  final double _qty = 50;
  double _realizedPnl = 0.0;
  int _tradeCount = 0;
  int _winCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchHistoricalDataset();
  }

  Future<void> _fetchHistoricalDataset() async {
    try {
      final res = await http.get(
        Uri.parse('$_jsonUrl?ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> raw = jsonDecode(res.body);
        final Map<String, List<ReplayCandle>> parsed = {};

        raw.forEach((key, val) {
          final list = val as List;
          if (list.isNotEmpty && list.first is Map) {
            parsed[key] = list.map((e) => ReplayCandle.fromMap(e)).toList();
          } else {
            parsed[key] = list.map((e) => ReplayCandle.fromList(e)).toList();
          }
        });

        setState(() {
          _masterDatabase = parsed;
          if (_masterDatabase.isNotEmpty && !_masterDatabase.containsKey(_selectedSymbol)) {
            _selectedSymbol = _masterDatabase.keys.first;
          }
          _isLoading = false;
          _initBlindSession(_selectedSymbol);
        });
      } else {
        setState(() {
          _errorMessage = 'Sync failed (HTTP ${res.statusCode})';
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

  void _initBlindSession(String symbol) {
    final candles = _masterDatabase[symbol] ?? [];
    if (candles.length < 80) return;

    final randomStart = Random().nextInt(candles.length - 70) + 40;

    setState(() {
      _activeSeries = candles;
      _cursor = randomStart;
      _entryPrice = null;
      _positionSide = null;
      _stopEngine();
    });
  }

  void _stepOneBar() {
    if (_cursor >= _activeSeries.length - 1) {
      _stopEngine();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _cursor++);
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopEngine();
    } else {
      _startEngine();
    }
  }

  void _startEngine() {
    setState(() => _isPlaying = true);
    _timer = Timer.periodic(Duration(milliseconds: _speedMs), (_) {
      if (_cursor < _activeSeries.length - 1) {
        setState(() => _cursor++);
      } else {
        _stopEngine();
      }
    });
  }

  void _stopEngine() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _executeOrder(String side) {
    if (_positionSide != null || _activeSeries.isEmpty) return;
    HapticFeedback.heavyImpact();
    final ltp = _activeSeries[_cursor].close;

    setState(() {
      _positionSide = side;
      _entryPrice = ltp;
    });
  }

  void _exitOrder() {
    if (_positionSide == null || _entryPrice == null) return;
    HapticFeedback.mediumImpact();
    final ltp = _activeSeries[_cursor].close;
    final diff = ltp - _entryPrice!;
    final pnl = _positionSide == 'LONG' ? (diff * _qty) : (-diff * _qty);

    setState(() {
      _realizedPnl += pnl;
      _virtualCapital += pnl;
      _tradeCount++;
      if (pnl > 0) _winCount++;
      _positionSide = null;
      _entryPrice = null;
    });
  }

  double _getUnrealizedPnl(double currentLtp) {
    if (_entryPrice == null || _positionSide == null) return 0.0;
    final diff = currentLtp - _entryPrice!;
    return _positionSide == 'LONG' ? (diff * _qty) : (-diff * _qty);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D16),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }

    if (_errorMessage != null || _activeSeries.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text(_errorMessage ?? 'Historical dataset not found',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchHistoricalDataset();
                },
                icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
                label: const Text('Retry Connection', style: TextStyle(color: Color(0xFF00E5FF))),
              ),
            ],
          ),
        ),
      );
    }

    final visibleSlice = _activeSeries.sublist(0, _cursor + 1);
    final currentCandle = visibleSlice.last;
    final currentLtp = currentCandle.close;
    final unrealized = _getUnrealizedPnl(currentLtp);
    final winPercent =
        _tradeCount > 0 ? ((_winCount / _tradeCount) * 100).toStringAsFixed(0) : "0";

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(winPercent),
            _buildMetricsBar(currentLtp),
            Expanded(
              child: Container(
                color: const Color(0xFF0D121F),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: RealisticChartPainter(
                    candles: visibleSlice,
                    entryPrice: _entryPrice,
                    positionSide: _positionSide,
                  ),
                ),
              ),
            ),
            if (_positionSide != null) _buildActiveTradeBanner(unrealized),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String winPercent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF131B2A),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSymbol,
                dropdownColor: const Color(0xFF131B2A),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                items: _masterDatabase.keys
                    .map((sym) => DropdownMenuItem(value: sym, child: Text(sym)))
                    .toList(),
                onChanged: (sym) {
                  if (sym != null) {
                    setState(() => _selectedSymbol = sym);
                    _initBlindSession(sym);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 20),
            tooltip: 'Random Time Slice',
            onPressed: () => _initBlindSession(_selectedSymbol),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E283A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'WIN RATE: $winPercent%',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(double ltp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0E1626),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VIRTUAL CAPITAL',
                  style: TextStyle(fontSize: 10, color: Colors.white54)),
              Text('₹${_virtualCapital.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('DATE: ${_activeSeries[_cursor].date}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF))),
              Text(
                'LTP: ₹${ltp.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _activeSeries[_cursor].isBull
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF3366),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTradeBanner(double unrealized) {
    final isProfit = unrealized >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _positionSide == 'LONG'
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF3366),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _positionSide!,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Entry: ₹${_entryPrice!.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Text(
            '${isProfit ? "+" : ""}₹${unrealized.toStringAsFixed(1)}',
            style: TextStyle(
              color: isProfit ? const Color(0xFF00E676) : const Color(0xFFFF3366),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: _exitOrder,
            child: const Text('Exit',
                style: TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF131B2A),
        border: Border(top: BorderSide(color: Color(0xFF202C42))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white60),
                onPressed: () {
                  if (_cursor > 40) setState(() => _cursor -= 5);
                },
              ),
              FloatingActionButton.small(
                backgroundColor: const Color(0xFF00E5FF),
                onPressed: _togglePlay,
                child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: Color(0xFF00E5FF), size: 28),
                tooltip: 'Next Bar (Step)',
                onPressed: _stepOneBar,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _positionSide == null ? () => _executeOrder('LONG') : null,
                  child: const Text('BUY / LONG',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3366),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _positionSide == null ? () => _executeOrder('SHORT') : null,
                  child: const Text('SELL / SHORT',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- ACCURATE CHART PAINTER ----------------
class RealisticChartPainter extends CustomPainter {
  final List<ReplayCandle> candles;
  final double? entryPrice;
  final String? positionSide;

  RealisticChartPainter({
    required this.candles,
    required this.entryPrice,
    required this.positionSide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    const double priceAxisWidth = 55.0;
    final chartWidth = size.width - priceAxisWidth;

    final displayCandles = candles.length > 40 ? candles.sublist(candles.length - 40) : candles;

    double maxPrice = displayCandles.map((c) => c.high).reduce(max);
    double minPrice = displayCandles.map((c) => c.low).reduce(min);
    double range = maxPrice - minPrice;
    if (range <= 0) range = 1.0;

    maxPrice += range * 0.08;
    minPrice -= range * 0.08;
    range = maxPrice - minPrice;

    final gridPaint = Paint()
      ..color = const Color(0xFF1E283A)
      ..strokeWidth = 0.8;

    const int gridDivisions = 5;
    for (int i = 0; i <= gridDivisions; i++) {
      final y = size.height * (i / gridDivisions);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      final priceAtLine = maxPrice - (range * (i / gridDivisions));
      final textSpan = TextSpan(
        text: priceAtLine.toStringAsFixed(1),
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(chartWidth + 6, y - 6));
    }

    final candleWidth = chartWidth / displayCandles.length;
    final bullColor = const Color(0xFF00E676);
    final bearColor = const Color(0xFFFF3366);
    final linePaint = Paint()..strokeWidth = 1.2;

    for (int i = 0; i < displayCandles.length; i++) {
      final c = displayCandles[i];
      final isBull = c.isBull;
      final color = isBull ? bullColor : bearColor;
      linePaint.color = color;

      final x = i * candleWidth + (candleWidth / 2);

      final openY = size.height - ((c.open - minPrice) / range) * size.height;
      final closeY = size.height - ((c.close - minPrice) / range) * size.height;
      final highY = size.height - ((c.high - minPrice) / range) * size.height;
      final lowY = size.height - ((c.low - minPrice) / range) * size.height;

      canvas.drawLine(Offset(x, highY), Offset(x, lowY), linePaint);

      final topY = min(openY, closeY);
      final bodyHeight = max((openY - closeY).abs(), 2.0);

      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - (candleWidth * 0.35), topY, candleWidth * 0.7, bodyHeight),
          const Radius.circular(1.5),
        ),
        bodyPaint,
      );
    }

    if (entryPrice != null) {
      final entryY = size.height - ((entryPrice! - minPrice) / range) * size.height;
      final tradeLinePaint = Paint()
        ..color = positionSide == 'LONG' ? bullColor : bearColor
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, entryY), Offset(chartWidth, entryY), tradeLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RealisticChartPainter oldDelegate) => true;
}
