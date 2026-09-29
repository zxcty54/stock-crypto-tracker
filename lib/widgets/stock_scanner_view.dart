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

// ---------------- PREMIUM UI WIDGET ----------------
class StockScannerView extends StatefulWidget {
  const StockScannerView({super.key});

  @override
  State<StockScannerView> createState() => _StockScannerViewState();
}

class _StockScannerViewState extends State<StockScannerView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StrategyScannerPayload? _payload;
  String? _selectedDate;
  bool _isLoading = true;
  String? _errorMessage;

  final String _endpointUrl =
      'https://raw.githubusercontent.com/zxcty54/stock-crypto-tracker/refs/heads/main/scanner_output.json';

  // Institutional Design Palette
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
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final payload = StrategyScannerPayload.fromJson(parsed);

        setState(() {
          _payload = payload;
          _selectedDate =
              payload.trackedDates.isNotEmpty ? payload.trackedDates.first : null;
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                minHeight: 58.0,
                maxHeight: 58.0,
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

  // Institutional Executive Header
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: accentNeonGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentNeonGreen,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'QUANT INTELLIGENCE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Volume & Squeeze Hub',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          if (_payload != null && _payload!.trackedDates.isNotEmpty)
            _buildDateSelectorPill(),
        ],
      ),
    );
  }

  // Modern Date Selector Chip
  Widget _buildDateSelectorPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: surfaceCard,
          value: _selectedDate,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: accentCyan, size: 18),
          items: _payload!.trackedDates.map((String date) {
            final isLatest = date == _payload!.latestDate;
            return DropdownMenuItem<String>(
              value: date,
              child: Text(
                isLatest ? '$date • Latest' : date,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLatest ? accentNeonGreen : Colors.white70,
                ),
              ),
            );
          }).toList(),
          onChanged: (newDate) {
            if (newDate != null) {
              HapticFeedback.selectionClick();
              setState(() => _selectedDate = newDate);
            }
          },
        ),
      ),
    );
  }

  // Segmented Pill Tab Bar (Replaces Default TabBar)
  Widget _buildSegmentedTabBar(DayScanRecord? record) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSubtle),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF223048),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentCyan.withOpacity(0.3)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: textMuted,
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, size: 17, color: accentFlame),
                const SizedBox(width: 6),
                Text(
                  'Breakouts (${record?.triggersCount ?? 0})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grain_rounded, size: 17, color: accentCyan),
                const SizedBox(width: 6),
                Text(
                  'Watchlist (${record?.watchlistCount ?? 0})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
        child: CircularProgressIndicator(color: accentCyan, strokeWidth: 2.5),
      );
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

  // TAB 1: TRIGGERS (ACTIONABLE ENTRIES)
  Widget _buildTriggersTab(List<ScannerTrigger> list) {
    if (list.isEmpty) {
      return _buildEmptyState('No Confirmed Breakouts',
          'No stock qualified with 2.0x volume expansion and base resistance breakout on this session.');
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSubtle, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildMicroBadge(
                            label: item.volumeSpike,
                            bg: accentFlame.withOpacity(0.15),
                            textClr: accentFlame,
                            isGlow: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Base Tightness: ${item.baseSqueeze}',
                        style: const TextStyle(fontSize: 12, color: textMuted),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: accentNeonGreen,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMicroBadge(
                      label: 'TRIGGER HIT',
                      bg: accentNeonGreen.withOpacity(0.15),
                      textClr: accentNeonGreen,
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

  // TAB 2: WATCHLIST (PRE-BREAKOUT COILING)
  Widget _buildWatchlistTab(List<ScannerWatchlist> list) {
    if (list.isEmpty) {
      return _buildEmptyState('No Coiling Setups',
          'No stock identified in dry-volume compression within 3% of trigger pivot.');
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSubtle, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildMicroBadge(
                            label: '${item.squeeze} Squeeze',
                            bg: accentCyan.withOpacity(0.12),
                            textClr: accentCyan,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Breakout Pivot: ',
                              style: TextStyle(fontSize: 12, color: textMuted)),
                          Text(
                            '₹${item.triggerLevel.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMicroBadge(
                      label: 'COILING BASE',
                      bg: Colors.white10,
                      textClr: textMuted,
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

  Widget _buildMicroBadge({
    required String label,
    required Color bg,
    required Color textClr,
    bool isGlow = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: surfaceCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar_rounded,
                    size: 28, color: textMuted),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 38),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper Delegate for Pinned Segmented Bar
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
