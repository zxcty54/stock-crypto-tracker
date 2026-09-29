import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ---------------- MODELS ----------------
class ScannerTrigger {
  final String symbol;
  final double close;
  final String volumeSpike;
  final String baseSqueeze;

  ScannerTrigger({
    required this.symbol,
    required this.close,
    required this.volumeSpike,
    required this.baseSqueeze,
  });

  factory ScannerTrigger.fromJson(Map<String, dynamic> json) {
    return ScannerTrigger(
      symbol: json['symbol'] ?? '',
      close: (json['close'] as num?)?.toDouble() ?? 0.0,
      volumeSpike: json['volume_spike'] ?? '',
      baseSqueeze: json['base_squeeze'] ?? '',
    );
  }
}

class ScannerWatchlist {
  final String symbol;
  final double close;
  final double triggerLevel;
  final String squeeze;

  ScannerWatchlist({
    required this.symbol,
    required this.close,
    required this.triggerLevel,
    required this.squeeze,
  });

  factory ScannerWatchlist.fromJson(Map<String, dynamic> json) {
    return ScannerWatchlist(
      symbol: json['symbol'] ?? '',
      close: (json['close'] as num?)?.toDouble() ?? 0.0,
      triggerLevel: (json['trigger_level'] as num?)?.toDouble() ?? 0.0,
      squeeze: json['squeeze'] ?? '',
    );
  }
}

class DayScanRecord {
  final int triggersCount;
  final int watchlistCount;
  final List<ScannerTrigger> triggers;
  final List<ScannerWatchlist> watchlist;

  DayScanRecord({
    required this.triggersCount,
    required this.watchlistCount,
    required this.triggers,
    required this.watchlist,
  });

  factory DayScanRecord.fromJson(Map<String, dynamic> json) {
    return DayScanRecord(
      triggersCount: json['triggers_count'] ?? 0,
      watchlistCount: json['watchlist_count'] ?? 0,
      triggers: (json['triggers'] as List? ?? [])
          .map((e) => ScannerTrigger.fromJson(e))
          .toList(),
      watchlist: (json['watchlist'] as List? ?? [])
          .map((e) => ScannerWatchlist.fromJson(e))
          .toList(),
    );
  }
}

class StrategyScannerPayload {
  final String lastUpdated;
  final List<String> trackedDates;
  final String latestDate;
  final Map<String, DayScanRecord> history;

  StrategyScannerPayload({
    required this.lastUpdated,
    required this.trackedDates,
    required this.latestDate,
    required this.history,
  });

  factory StrategyScannerPayload.fromJson(Map<String, dynamic> json) {
    final historyMap = <String, DayScanRecord>{};
    if (json['history'] != null) {
      (json['history'] as Map<String, dynamic>).forEach((key, val) {
        historyMap[key] = DayScanRecord.fromJson(val);
      });
    }

    final dates = (json['tracked_dates'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    final latestStr = json['latest'] != null
        ? json['latest']['date'] ?? ''
        : (dates.isNotEmpty ? dates.last : '');

    return StrategyScannerPayload(
      lastUpdated: json['last_updated'] ?? '',
      trackedDates: dates.reversed.toList(),
      latestDate: latestStr,
      history: historyMap,
    );
  }
}

// ---------------- UI SCREEN ----------------
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StrategyScannerPayload? _payload;
  String? _selectedDate;
  bool _isLoading = true;
  String? _errorMessage;

  final String _endpointUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/scanner_output.json';

  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color borderSubtle = Color(0xFF202C42);
  static const Color accentNeonGreen = Color(0xFF00E676);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentFlame = Color(0xFFFF9100);
  static const Color textMuted = Color(0xFF8896AB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _fetchScannerData();
  }

  Future<void> _fetchScannerData() async {
    HapticFeedback.lightImpact();
    try {
      final uri =
          Uri.parse('$_endpointUrl?ts=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final payload = StrategyScannerPayload.fromJson(parsed);

        setState(() {
          _payload = payload;
          if (_selectedDate == null ||
              !payload.trackedDates.contains(_selectedDate)) {
            _selectedDate =
                payload.trackedDates.isNotEmpty ? payload.trackedDates.first : null;
          }
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Data sync failed (HTTP ${response.statusCode})';
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

  DayScanRecord? _getCurrentRecord() {
    if (_payload == null || _selectedDate == null) return null;
    return _payload!.history[_selectedDate];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRecord = _getCurrentRecord();

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_payload != null && _payload!.trackedDates.isNotEmpty)
              SliverToBoxAdapter(child: _buildDateTimelineStrip()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                minHeight: 56.0,
                maxHeight: 56.0,
                child: Container(
                  color: bgDark,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: _buildSegmentedTabBar(currentRecord),
                ),
              ),
            ),
          ],
          body: _buildContent(currentRecord),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isLatest = _selectedDate == _payload?.latestDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isLatest ? accentNeonGreen : Colors.amberAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isLatest ? accentNeonGreen : Colors.amberAccent)
                              .withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isLatest ? 'LIVE MARKET SCAN' : 'HISTORICAL BACKTEST AUDIT',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: isLatest ? accentCyan : Colors.amberAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Squeeze & Breakouts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchScannerData();
            },
            icon: const Icon(Icons.refresh_rounded, color: accentCyan, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimelineStrip() {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _payload!.trackedDates.length,
        itemBuilder: (context, index) {
          final date = _payload!.trackedDates[index];
          final isSelected = date == _selectedDate;
          final isLatest = date == _payload!.latestDate;
          final record = _payload!.history[date];
          final triggerHits = record?.triggersCount ?? 0;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDate = date);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF223048) : surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? (isLatest ? accentNeonGreen : accentCyan)
                      : borderSubtle,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isLatest ? Icons.flash_on : Icons.history_rounded,
                    size: 14,
                    color: isSelected
                        ? (isLatest ? accentNeonGreen : accentCyan)
                        : textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : textMuted,
                    ),
                  ),
                  if (triggerHits > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: accentFlame.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$triggerHits',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentFlame,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentedTabBar(DayScanRecord? record) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderSubtle),
      ),
      padding: const EdgeInsets.all(3),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF223048),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accentCyan.withOpacity(0.3)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: textMuted,
        tabs: [
          Tab(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, size: 16, color: accentFlame),
                const SizedBox(width: 6),
                Text(
                  'Breakouts (${record?.triggersCount ?? 0})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          Tab(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grain_rounded, size: 16, color: accentCyan),
                const SizedBox(width: 6),
                Text(
                  'Watchlist (${record?.watchlistCount ?? 0})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DayScanRecord? currentRecord) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: accentCyan, strokeWidth: 2.5));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(color: textMuted)),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchScannerData();
              },
              icon: const Icon(Icons.refresh, color: accentCyan),
              label: const Text('Retry Connection',
                  style: TextStyle(color: accentCyan)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: accentCyan,
      backgroundColor: surfaceCard,
      onRefresh: _fetchScannerData,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildTriggersTab(currentRecord?.triggers ?? []),
          _buildWatchlistTab(currentRecord?.watchlist ?? []),
        ],
      ),
    );
  }

  Widget _buildTriggersTab(List<ScannerTrigger> list) {
    if (list.isEmpty) {
      return _buildEmptyState(
        'No Breakouts on $_selectedDate',
        'None of the stocks satisfied the 2x volume expansion and base high breakout criteria on this trading session.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.symbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildBadge(
                            label: item.volumeSpike,
                            bg: accentFlame.withOpacity(0.18),
                            textClr: accentFlame,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Coil Range: ${item.baseSqueeze} (5-day base)',
                        style: const TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.close.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: accentNeonGreen,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'TRIGGER ENTRY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentNeonGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWatchlistTab(List<ScannerWatchlist> list) {
    if (list.isEmpty) {
      return _buildEmptyState(
        'No Squeeze Setups on $_selectedDate',
        'No stocks were in dry-volume compression within 3% of trigger pivot on this trading day.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.symbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildBadge(
                            label: '${item.squeeze} Squeeze',
                            bg: accentCyan.withOpacity(0.12),
                            textClr: accentCyan,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pivot Level: ₹${item.triggerLevel.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.close.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'COILING BASE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(
      {required String label, required Color bg, required Color textClr}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textClr.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textClr,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: surfaceCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar_rounded, size: 26, color: textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: textMuted, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
