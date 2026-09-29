import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ---------------- DATA MODELS ----------------
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

  // Exact JSON Array: ["2023-09-29", 3537.2, 3568.45, 3505.55, 3528.6, 2243791]
  factory ReplayCandle.fromList(List dynamicList) {
    return ReplayCandle(
      date: dynamicList[0].toString(),
      open: (dynamicList[1] as num).toDouble(),
      high: (dynamicList[2] as num).toDouble(),
      low: (dynamicList[3] as num).toDouble(),
      close: (dynamicList[4] as num).toDouble(),
      volume: dynamicList.length > 5
          ? (dynamicList[5] is num
              ? (dynamicList[5] as num).toInt()
              : int.tryParse(dynamicList[5].toString()) ?? 0)
          : 0,
    );
  }

  bool get isBull => close >= open;
}

class ClosedTrade {
  final String symbol;
  final String side;
  final double entryPrice;
  final double exitPrice;
  final double qty;
  final double pnl;
  final String entryDate;
  final String exitDate;
  final String reason;

  ClosedTrade({
    required this.symbol,
    required this.side,
    required this.entryPrice,
    required this.exitPrice,
    required this.qty,
    required this.pnl,
    required this.entryDate,
    required this.exitDate,
    required this.reason,
  });

  bool get isWin => pnl > 0;
}

// ---------------- MAIN TERMINAL SCREEN ----------------
class StrategyBuilderScreen extends StatefulWidget {
  const StrategyBuilderScreen({super.key});

  @override
  State<StrategyBuilderScreen> createState() => _StrategyBuilderScreenState();
}

class _StrategyBuilderScreenState extends State<StrategyBuilderScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final String _jsonUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/historical_3yr_ohlc.json';

  Map<String, List<ReplayCandle>> _masterDatabase = {};
  String _selectedSymbol = 'TCS';
  bool _isLoading = true;
  String? _errorMessage;

  // Replay State
  List<ReplayCandle> _activeSeries = [];
  int _cursor = 50;
  Timer? _timer;
  bool _isPlaying = false;
  final int _speedMs = 600;
  bool _isLandscape = false;

  // Viewport Scale & Pan
  double _visibleCandlesCount = 42.0;
  double _scrollOffset = 0.0;
  double _verticalScaleMultiplier = 1.0;
  Offset? _crosshairPosition;

  // Account Ledger
  double _virtualCapital = 500000.0;
  final double _orderQty = 50.0;

  // Position State
  String? _positionSide;
  double? _entryPrice;
  double? _stopLoss;
  double? _takeProfit;
  String? _entryDate;
  int? _entryCursorIndex; // Entry candle ka track rakhne ke liye

  final List<ClosedTrade> _tradeHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchDataset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  Future<void> _fetchDataset() async {
    try {
      final res = await http.get(
        Uri.parse('$_jsonUrl?ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
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
          _initSession(_selectedSymbol);
        });
      } else {
        setState(() {
          _errorMessage = 'Sync failed: HTTP ${res.statusCode}';
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

  void _initSession(String symbol) {
    final candles = _masterDatabase[symbol] ?? [];
    if (candles.length < 90) return;

    final randomStart = Random().nextInt(candles.length - 80) + 40;

    setState(() {
      _activeSeries = candles;
      _cursor = randomStart;
      _scrollOffset = 0.0;
      _verticalScaleMultiplier = 1.0;
      _entryPrice = null;
      _positionSide = null;
      _stopLoss = null;
      _takeProfit = null;
      _entryCursorIndex = null;
      _crosshairPosition = null;
      _stopEngine();
    });
  }

  void _stepOneBar() {
    if (_cursor >= _activeSeries.length - 1) {
      _stopEngine();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _cursor++;
      _evaluateAutoBrackets();
    });
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
        setState(() {
          _cursor++;
          _evaluateAutoBrackets();
        });
      } else {
        _stopEngine();
      }
    });
  }

  void _stopEngine() {
    _timer?.cancel();
    if (_isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  // Bracket Auto-Execution (Sirf nayi candles par trigger hoga)
  void _evaluateAutoBrackets() {
    if (_positionSide == null || _entryPrice == null || _entryCursorIndex == null) return;
    if (_cursor <= _entryCursorIndex!) return; // Entry candle par execute nahi hoga

    final bar = _activeSeries[_cursor];

    if (_positionSide == 'LONG') {
      if (_stopLoss != null && bar.low <= _stopLoss!) {
        _closeTrade(_stopLoss!, 'STOP LOSS HIT');
      } else if (_takeProfit != null && bar.high >= _takeProfit!) {
        _closeTrade(_takeProfit!, 'TARGET HIT');
      }
    } else if (_positionSide == 'SHORT') {
      if (_stopLoss != null && bar.high >= _stopLoss!) {
        _closeTrade(_stopLoss!, 'STOP LOSS HIT');
      } else if (_takeProfit != null && bar.low <= _takeProfit!) {
        _closeTrade(_takeProfit!, 'TARGET HIT');
      }
    }
  }

  // Order Placement Modal (Auto-pause + Custom SL/TP Setup)
  void _openOrderDialog(String side) {
    if (_positionSide != null || _activeSeries.isEmpty) return;

    // 1. Sabse pehle running engine ko PAUSE karein
    _stopEngine();
    HapticFeedback.mediumImpact();

    final ltp = _activeSeries[_cursor].close;
    final lastLow = _activeSeries[_cursor].low;
    final lastHigh = _activeSeries[_cursor].high;

    // Realistic Default SL: Technical swing low/high or min 2.5%
    double initialSl;
    double initialTp;

    if (side == 'LONG') {
      final swingSl = lastLow * 0.995;
      initialSl = min(swingSl, ltp * 0.975); // At least 2.5% room
      final risk = ltp - initialSl;
      initialTp = ltp + (risk * 2.0); // 1:2 R:R default
    } else {
      final swingSl = lastHigh * 1.005;
      initialSl = max(swingSl, ltp * 1.025);
      final risk = initialSl - ltp;
      initialTp = ltp - (risk * 2.0);
    }

    double tempSl = initialSl;
    double tempTp = initialTp;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final riskPerShare = (ltp - tempSl).abs();
            final rewardPerShare = (tempTp - ltp).abs();
            final totalRisk = riskPerShare * _orderQty;
            final totalReward = rewardPerShare * _orderQty;
            final rrRatio = riskPerShare > 0 ? (rewardPerShare / riskPerShare).toStringAsFixed(1) : "0";

            return Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: side == 'LONG' ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              side == 'LONG' ? 'BUY ORDER' : 'SELL ORDER',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_selectedSymbol @ ₹${ltp.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF25334A), height: 16),

                  // Risk-Reward Summary Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0F1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E2B3E)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Risk: -₹${totalRisk.toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('R:R 1:$rrRatio',
                            style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.w800, fontSize: 12)),
                        Text('Target: +₹${totalReward.toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Stop Loss Controller
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('STOP LOSS',
                          style: TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.w800, fontSize: 12)),
                      Text('₹${tempSl.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _stepperBtn(Icons.remove, () {
                        setModalState(() {
                          tempSl = side == 'LONG' ? tempSl - (ltp * 0.005) : tempSl - (ltp * 0.005);
                        });
                      }),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFFF2A6D),
                            thumbColor: const Color(0xFFFF2A6D),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: tempSl,
                            min: side == 'LONG' ? ltp * 0.90 : ltp * 1.005,
                            max: side == 'LONG' ? ltp * 0.995 : ltp * 1.10,
                            onChanged: (v) => setModalState(() => tempSl = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _stepperBtn(Icons.add, () {
                        setModalState(() {
                          tempSl = side == 'LONG' ? tempSl + (ltp * 0.005) : tempSl + (ltp * 0.005);
                        });
                      }),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Target Controller
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TARGET / TAKE PROFIT',
                          style: TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.w800, fontSize: 12)),
                      Text('₹${tempTp.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _stepperBtn(Icons.remove, () {
                        setModalState(() {
                          tempTp = side == 'LONG' ? tempTp - (ltp * 0.005) : tempTp - (ltp * 0.005);
                        });
                      }),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF00F5A0),
                            thumbColor: const Color(0xFF00F5A0),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: tempTp,
                            min: side == 'LONG' ? ltp * 1.005 : ltp * 0.85,
                            max: side == 'LONG' ? ltp * 1.15 : ltp * 0.995,
                            onChanged: (v) => setModalState(() => tempTp = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _stepperBtn(Icons.add, () {
                        setModalState(() {
                          tempTp = side == 'LONG' ? tempTp + (ltp * 0.005) : tempTp + (ltp * 0.005);
                        });
                      }),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Execute Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: side == 'LONG' ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeTrade(side, ltp, tempSl, tempTp);
                      },
                      child: Text(
                        'CONFIRM ${side == 'LONG' ? 'BUY' : 'SHORT'} ORDER',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
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

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2B3E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  void _executeTrade(String side, double ltp, double sl, double tp) {
    final double marginRequired = ltp * _orderQty;
    if (_virtualCapital < marginRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Margin unavailable for this trade size!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _positionSide = side;
      _entryPrice = ltp;
      _entryDate = _activeSeries[_cursor].date;
      _entryCursorIndex = _cursor; // Abhi ki candle mark kar li
      _stopLoss = sl;
      _takeProfit = tp;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Position active! Replay paused. Step forward bar-by-bar when ready.'),
        backgroundColor: const Color(0xFF131B2A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _closeTrade(double exitPrice, String reason) {
    if (_positionSide == null || _entryPrice == null) return;
    HapticFeedback.mediumImpact();

    final diff = exitPrice - _entryPrice!;
    final pnl = _positionSide == 'LONG' ? (diff * _orderQty) : (-diff * _orderQty);

    final record = ClosedTrade(
      symbol: _selectedSymbol,
      side: _positionSide!,
      entryPrice: _entryPrice!,
      exitPrice: exitPrice,
      qty: _orderQty,
      pnl: pnl,
      entryDate: _entryDate ?? '',
      exitDate: _activeSeries[_cursor].date,
      reason: reason,
    );

    setState(() {
      _virtualCapital += pnl;
      _tradeHistory.insert(0, record);
      _positionSide = null;
      _entryPrice = null;
      _stopLoss = null;
      _takeProfit = null;
      _entryDate = null;
      _entryCursorIndex = null;
      _stopEngine(); // Trade end hone par pause kar diya
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$reason: ${pnl >= 0 ? "+" : ""}₹${pnl.toStringAsFixed(1)}'),
        backgroundColor: pnl >= 0 ? const Color(0xFF00F0FF) : const Color(0xFFFF2A6D),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double _getUnrealizedPnl(double currentLtp) {
    if (_entryPrice == null || _positionSide == null) return 0.0;
    final diff = currentLtp - _entryPrice!;
    return _positionSide == 'LONG' ? (diff * _orderQty) : (-diff * _orderQty);
  }

  String _formatVolume(int vol) {
    if (vol >= 1000000) {
      return '${(vol / 1000000).toStringAsFixed(1)}M';
    } else if (vol >= 1000) {
      return '${(vol / 1000).toStringAsFixed(0)}K';
    }
    return vol.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B12),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2)),
      );
    }

    if (_errorMessage != null || _activeSeries.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B12),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text(_errorMessage ?? 'Data unavailable',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
              TextButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchDataset();
                },
                child: const Text('Retry Connection', style: TextStyle(color: Color(0xFF00F0FF))),
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

    final wins = _tradeHistory.where((t) => t.isWin).length;
    final winRate = _tradeHistory.isNotEmpty
        ? ((wins / _tradeHistory.length) * 100).toStringAsFixed(0)
        : "0";

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      endDrawer: _buildHistoryDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(winRate),
            _buildOHLCVHud(currentCandle),

            // Interactive Viewport
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    right: 65,
                    child: GestureDetector(
                      onScaleUpdate: (details) {
                        setState(() {
                          if (details.scale != 1.0) {
                            _visibleCandlesCount =
                                (_visibleCandlesCount / details.scale).clamp(15.0, 95.0);
                          } else if (details.focalPointDelta.dx != 0) {
                            _scrollOffset += details.focalPointDelta.dx * 0.5;
                            _scrollOffset = _scrollOffset.clamp(-150.0, 150.0);
                          }
                        });
                      },
                      onScaleEnd: (_) => setState(() => _scrollOffset = 0.0),
                      onLongPressStart: (e) {
                        HapticFeedback.selectionClick();
                        setState(() => _crosshairPosition = e.localPosition);
                      },
                      onLongPressMoveUpdate: (e) =>
                          setState(() => _crosshairPosition = e.localPosition),
                      onLongPressEnd: (_) => setState(() => _crosshairPosition = null),
                      child: Container(
                        color: const Color(0xFF070B12),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: TradingViewProPainter(
                            candles: visibleSlice,
                            visibleCount: _visibleCandlesCount.toInt(),
                            scrollOffset: _scrollOffset,
                            verticalScaleMultiplier: _verticalScaleMultiplier,
                            crosshair: _crosshairPosition,
                            entryPrice: _entryPrice,
                            stopLoss: _stopLoss,
                            takeProfit: _takeProfit,
                            positionSide: _positionSide,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Right Scale Drag Zoomer
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: 65,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          _verticalScaleMultiplier -= details.primaryDelta! * 0.008;
                          _verticalScaleMultiplier = _verticalScaleMultiplier.clamp(0.4, 3.5);
                        });
                      },
                      onDoubleTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _verticalScaleMultiplier = 1.0);
                      },
                      child: Container(
                        color: const Color(0xFF070B12).withOpacity(0.01),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_positionSide != null) _buildActivePositionBanner(currentLtp, unrealized),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String winRate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFF0F1726),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  fontSize: 13,
                ),
                items: _masterDatabase.keys
                    .map((sym) => DropdownMenuItem(value: sym, child: Text(sym)))
                    .toList(),
                onChanged: (sym) {
                  if (sym != null) {
                    setState(() => _selectedSymbol = sym);
                    _initSession(sym);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 20),
            tooltip: 'Random Time Slice',
            onPressed: () => _initSession(_selectedSymbol),
          ),
          IconButton(
            icon: Icon(
              _isLandscape ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_landscape_rounded,
              color: Colors.white70,
              size: 20,
            ),
            tooltip: 'Rotate View',
            onPressed: _toggleOrientation,
          ),
          const Spacer(),
          Builder(
            builder: (ctx) => TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF162032),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              icon: const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFF00F0FF)),
              label: Text(
                'Journal (${_tradeHistory.length})',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOHLCVHud(ReplayCandle c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      color: const Color(0xFF0A0F1A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _hudLabel('O', c.open.toStringAsFixed(1)),
                  _hudLabel('H', c.high.toStringAsFixed(1)),
                  _hudLabel('L', c.low.toStringAsFixed(1)),
                  _hudLabel('C', c.close.toStringAsFixed(1),
                      color: c.isBull ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D)),
                  _hudLabel('Vol', _formatVolume(c.volume), color: const Color(0xFF00F0FF)),
                  if (_verticalScaleMultiplier != 1.0)
                    Text(' [Zoom: ${_verticalScaleMultiplier.toStringAsFixed(1)}x]',
                        style: const TextStyle(fontSize: 9, color: Colors.amberAccent)),
                ],
              ),
            ),
          ),
          Text(c.date, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7A99))),
        ],
      ),
    );
  }

  Widget _hudLabel(String tag, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: RichText(
        text: TextSpan(
          text: '$tag ',
          style: const TextStyle(color: Color(0xFF5A6882), fontSize: 10, fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: val,
              style: TextStyle(
                color: color ?? Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePositionBanner(double currentLtp, double unrealized) {
    final isProfit = unrealized >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF141D2D),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _positionSide == 'LONG' ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _positionSide!,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entry: ₹${_entryPrice!.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    'SL: ₹${_stopLoss?.toStringAsFixed(1) ?? "-"} | TP: ₹${_takeProfit?.toStringAsFixed(1) ?? "-"}',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '${isProfit ? "+" : ""}₹${unrealized.toStringAsFixed(1)}',
            style: TextStyle(
              color: isProfit ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2A6D),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () => _closeTrade(currentLtp, 'MANUAL EXIT'),
            child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1726),
        border: Border(top: BorderSide(color: Color(0xFF1E2B3E))),
      ),
      child: Row(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white60),
                onPressed: () {
                  if (_cursor > 40) setState(() => _cursor -= 5);
                },
              ),
              FloatingActionButton.small(
                backgroundColor: const Color(0xFF00F0FF),
                onPressed: _togglePlay,
                child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Color(0xFF00F0FF), size: 28),
                onPressed: _stepOneBar,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F5A0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _positionSide == null ? () => _openOrderDialog('LONG') : null,
              child: const Text('BUY / LONG',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2A6D),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _positionSide == null ? () => _openOrderDialog('SHORT') : null,
              child: const Text('SELL / SHORT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0A0F1A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TRADE AUDIT LOG',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF00F0FF))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E2B3E), height: 1),
            if (_tradeHistory.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No trades logged in this session',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _tradeHistory.length,
                  itemBuilder: (context, index) {
                    final item = _tradeHistory[index];
                    final isWin = item.isWin;
                    final color = isWin ? const Color(0xFF00F5A0) : const Color(0xFFFF2A6D);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111927),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E2B3E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.symbol} • ${item.side}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13)),
                              Text('${isWin ? "+" : ""}₹${item.pnl.toStringAsFixed(1)}',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('In: ₹${item.entryPrice.toStringAsFixed(1)} → Out: ₹${item.exitPrice.toStringAsFixed(1)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(item.reason,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Dates: ${item.entryDate} to ${item.exitDate}',
                              style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- TRADINGVIEW PRO CUSTOM PAINTER ----------------
class TradingViewProPainter extends CustomPainter {
  final List<ReplayCandle> candles;
  final int visibleCount;
  final double scrollOffset;
  final double verticalScaleMultiplier;
  final Offset? crosshair;
  final double? entryPrice;
  final double? stopLoss;
  final double? takeProfit;
  final String? positionSide;

  TradingViewProPainter({
    required this.candles,
    required this.visibleCount,
    required this.scrollOffset,
    required this.verticalScaleMultiplier,
    required this.crosshair,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.positionSide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    const double priceAxisWidth = 65.0;
    const double volumeHeight = 65.0;

    final chartWidth = size.width;
    final chartHeight = size.height - volumeHeight;

    final count = min(visibleCount, candles.length);
    final displayCandles = candles.sublist(candles.length - count);

    double maxPrice = displayCandles.map((c) => c.high).reduce(max);
    double minPrice = displayCandles.map((c) => c.low).reduce(min);
    int maxVol = displayCandles.map((c) => c.volume).reduce(max);
    if (maxVol <= 0) maxVol = 1;

    if (entryPrice != null) {
      if (stopLoss != null) {
        maxPrice = max(maxPrice, stopLoss!);
        minPrice = min(minPrice, stopLoss!);
      }
      if (takeProfit != null) {
        maxPrice = max(maxPrice, takeProfit!);
        minPrice = min(minPrice, takeProfit!);
      }
    }

    double baseRange = maxPrice - minPrice;
    if (baseRange <= 0) baseRange = 1.0;

    final double midPrice = (maxPrice + minPrice) / 2;
    final double adjustedRange = (baseRange / verticalScaleMultiplier);

    maxPrice = midPrice + (adjustedRange / 2);
    minPrice = midPrice - (adjustedRange / 2);
    double range = maxPrice - minPrice;

    final gridPaint = Paint()
      ..color = const Color(0xFF141C2B)
      ..strokeWidth = 0.8;

    const int gridDivisions = 5;
    for (int i = 0; i <= gridDivisions; i++) {
      final y = chartHeight * (i / gridDivisions);
      canvas.drawLine(Offset(0, y), Offset(chartWidth + priceAxisWidth, y), gridPaint);

      final p = maxPrice - (range * (i / gridDivisions));
      final tp = TextPainter(
        text: TextSpan(
          text: p.toStringAsFixed(1),
          style: const TextStyle(color: Color(0xFF4B5B75), fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartWidth + 6, y - 6));
    }

    canvas.drawLine(Offset(0, chartHeight), Offset(chartWidth + priceAxisWidth, chartHeight), gridPaint);
    final volLabelPainter = TextPainter(
      text: TextSpan(
        text: 'Vol Max ${_formatVolume(maxVol)}',
        style: const TextStyle(color: Color(0xFF3B4860), fontSize: 8, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    volLabelPainter.paint(canvas, Offset(4, chartHeight + 2));

    final candleWidth = chartWidth / displayCandles.length;
    final bullColor = const Color(0xFF00F5A0);
    final bearColor = const Color(0xFFFF2A6D);
    final wickPaint = Paint()..strokeWidth = 1.2;

    for (int i = 0; i < displayCandles.length; i++) {
      final c = displayCandles[i];
      final isBull = c.isBull;
      final color = isBull ? bullColor : bearColor;
      wickPaint.color = color;

      final x = i * candleWidth + (candleWidth / 2) + scrollOffset;

      final openY = chartHeight - ((c.open - minPrice) / range) * chartHeight;
      final closeY = chartHeight - ((c.close - minPrice) / range) * chartHeight;
      final highY = chartHeight - ((c.high - minPrice) / range) * chartHeight;
      final lowY = chartHeight - ((c.low - minPrice) / range) * chartHeight;

      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      final topY = min(openY, closeY);
      final bodyHeight = max((openY - closeY).abs(), 2.0);

      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - (candleWidth * 0.36), topY, candleWidth * 0.72, bodyHeight),
          const Radius.circular(2.0),
        ),
        bodyPaint,
      );

      final double normalizedVol = (c.volume / maxVol).clamp(0.0, 1.0);
      final double vHeight = normalizedVol * (volumeHeight - 12);

      final vPaint = Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - (candleWidth * 0.30), size.height - vHeight, candleWidth * 0.60, vHeight),
          const Radius.circular(1.0),
        ),
        vPaint,
      );
    }

    // Bracket Levels
    if (entryPrice != null) {
      _drawGlowLine(canvas, chartWidth, entryPrice!, minPrice, range, chartHeight,
          positionSide == 'LONG' ? bullColor : bearColor, 'ENTRY');

      if (stopLoss != null) {
        _drawGlowLine(canvas, chartWidth, stopLoss!, minPrice, range, chartHeight,
            const Color(0xFFFF2A6D), 'SL');
      }

      if (takeProfit != null) {
        _drawGlowLine(canvas, chartWidth, takeProfit!, minPrice, range, chartHeight,
            const Color(0xFF00F5A0), 'TP');
      }
    }

    // Interactive Crosshair HUD
    if (crosshair != null && crosshair!.dx <= chartWidth && crosshair!.dy <= chartHeight) {
      final chPaint = Paint()
        ..color = Colors.white38
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(0, crosshair!.dy), Offset(chartWidth + priceAxisWidth, crosshair!.dy), chPaint);
      canvas.drawLine(Offset(crosshair!.dx, 0), Offset(crosshair!.dx, size.height), chPaint);

      final hoverPrice = maxPrice - ((crosshair!.dy / chartHeight) * range);

      final badgePaint = Paint()..color = const Color(0xFF00F0FF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chartWidth + 2, crosshair!.dy - 9, priceAxisWidth - 4, 18),
          const Radius.circular(4),
        ),
        badgePaint,
      );

      final badgeText = TextPainter(
        text: TextSpan(
          text: hoverPrice.toStringAsFixed(1),
          style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      badgeText.paint(canvas, Offset(chartWidth + 8, crosshair!.dy - 5));
    }
  }

  void _drawGlowLine(Canvas canvas, double chartWidth, double price, double minPrice,
      double range, double chartHeight, Color color, String label) {
    final y = chartHeight - ((price - minPrice) / range) * chartHeight;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.4;

    canvas.drawLine(Offset(0, y), Offset(chartWidth, y), linePaint);

    final bgPaint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(chartWidth + 2, y - 8, 48, 16),
        const Radius.circular(3),
      ),
      bgPaint,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$label ${price.toStringAsFixed(0)}',
        style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(chartWidth + 5, y - 5));
  }

  String _formatVolume(int vol) {
    if (vol >= 1000000) {
      return '${(vol / 1000000).toStringAsFixed(1)}M';
    } else if (vol >= 1000) {
      return '${(vol / 1000).toStringAsFixed(0)}K';
    }
    return vol.toString();
  }

  @override
  bool shouldRepaint(covariant TradingViewProPainter oldDelegate) => true;
}
