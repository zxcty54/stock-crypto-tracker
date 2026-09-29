class CorporateAnnouncement {
  final String hash;
  final String symbol;
  final String companyName;
  final String category;
  final String eventType;
  final String broadcastDate;
  final String pdfLink;
  final String headline;
  final bool contentWorthy;
  final String worthinessReason;
  final String analyzedAt;

  CorporateAnnouncement({
    required this.hash,
    required this.symbol,
    required this.companyName,
    required this.category,
    required this.eventType,
    required this.broadcastDate,
    required this.pdfLink,
    required this.headline,
    required this.contentWorthy,
    required this.worthinessReason,
    required this.analyzedAt,
  });

  factory CorporateAnnouncement.fromJson(Map<String, dynamic> json) {
    return CorporateAnnouncement(
      hash: json['hash'] ?? '',
      symbol: json['symbol'] ?? '',
      companyName: json['company_name'] ?? '',
      category: json['category'] ?? 'GENERAL',
      eventType: json['event_type'] ?? '',
      broadcastDate: json['broadcast_date'] ?? '',
      pdfLink: json['pdf_link'] ?? '',
      headline: json['headline'] ?? '',
      contentWorthy: json['content_worthy'] ?? true,
      worthinessReason: json['worthiness_reason'] ?? '',
      analyzedAt: json['analyzed_at'] ?? '',
    );
  }
}

class CorporateFeedPayload {
  final String generatedAt;
  final int worthyCount;
  final int skippedCount;
  final List<CorporateAnnouncement> feed;

  CorporateFeedPayload({
    required this.generatedAt,
    required this.worthyCount,
    required this.skippedCount,
    required this.feed,
  });

  factory CorporateFeedPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['content_feed'] as List? ?? [])
        .map((e) => CorporateAnnouncement.fromJson(e))
        .toList();

    return CorporateFeedPayload(
      generatedAt: json['generated_at'] ?? '',
      worthyCount: json['worthy_count'] ?? list.length,
      skippedCount: json['skipped_count'] ?? 0,
      feed: list,
    );
  }
}
