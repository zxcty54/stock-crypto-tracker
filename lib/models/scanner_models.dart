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
