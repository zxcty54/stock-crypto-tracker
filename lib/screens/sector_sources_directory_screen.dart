import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ==============================================================================
// DATA MODELS
// ==============================================================================

class SectorSource {
  final String type;
  final String authority;
  final String name;
  final String url;
  final String description;

  SectorSource({
    required this.type,
    required this.authority,
    required this.name,
    required this.url,
    required this.description,
  });

  factory SectorSource.fromJson(Map<String, dynamic> json) {
    return SectorSource(
      type: json['type'] ?? 'SOURCE',
      authority: json['authority'] ?? 'Official Portal',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class SectorItem {
  final int id;
  final String sectorName;
  final String keyFocus;
  final String cadence;
  final List<SectorSource> sources;

  SectorItem({
    required this.id,
    required this.sectorName,
    required this.keyFocus,
    required this.cadence,
    required this.sources,
  });

  factory SectorItem.fromJson(Map<String, dynamic> json) {
    return SectorItem(
      id: json['id'] ?? 0,
      sectorName: json['sector_name'] ?? '',
      keyFocus: json['key_focus'] ?? '',
      cadence: json['cadence'] ?? '',
      sources: (json['sources'] as List? ?? [])
          .map((s) => SectorSource.fromJson(s))
          .toList(),
    );
  }
}

class SectorTheme {
  final String themeId;
  final String themeName;
  final String icon;
  final String description;
  final List<SectorItem> sectors;

  SectorTheme({
    required this.themeId,
    required this.themeName,
    required this.icon,
    required this.description,
    required this.sectors,
  });

  factory SectorTheme.fromJson(Map<String, dynamic> json) {
    return SectorTheme(
      themeId: json['theme_id'] ?? '',
      themeName: json['theme_name'] ?? '',
      icon: json['icon'] ?? '📁',
      description: json['description'] ?? '',
      sectors: (json['sectors'] as List? ?? [])
          .map((s) => SectorItem.fromJson(s))
          .toList(),
    );
  }
}

class SectorLiveFeedItem {
  final String id;
  final int sectorId;
  final String sectorName;
  final String themeName;
  final String themeIcon;
  final String sourceName;
  final String sourceType;
  final String title;
  final String summary;
  final String publishedAt;
  final String kyaDekhnaHai;
  final String sourceUrl;
  final List<String> keyTickers;

  SectorLiveFeedItem({
    required this.id,
    required this.sectorId,
    required this.sectorName,
    required this.themeName,
    required this.themeIcon,
    required this.sourceName,
    required this.sourceType,
    required this.title,
    required this.summary,
    required this.publishedAt,
    required this.kyaDekhnaHai,
    required this.sourceUrl,
    required this.keyTickers,
  });

  factory SectorLiveFeedItem.fromJson(Map<String, dynamic> json) {
    return SectorLiveFeedItem(
      id: json['id'] ?? '',
      sectorId: json['sector_id'] ?? 0,
      sectorName: json['sector_name'] ?? '',
      themeName: json['theme_name'] ?? 'General',
      themeIcon: json['theme_icon'] ?? '📊',
      sourceName: json['source_name'] ?? 'Industry Release',
      sourceType: json['source_type'] ?? 'NEWS',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      publishedAt: json['published_at'] ?? '',
      kyaDekhnaHai: json['kya_dekhna_hai'] ?? '',
      sourceUrl: json['source_url'] ?? '',
      keyTickers: List<String>.from(json['key_tickers'] ?? []),
    );
  }
}

// ==============================================================================
// MAIN SCREEN WIDGET
// ==============================================================================

class SectorSourcesDirectoryScreen extends StatefulWidget {
  const SectorSourcesDirectoryScreen({super.key});

  @override
  State<SectorSourcesDirectoryScreen> createState() =>
      _SectorSourcesDirectoryScreenState();
}

class _SectorSourcesDirectoryScreenState
    extends State<SectorSourcesDirectoryScreen> with SingleTickerProviderStateMixin {
  static const Color kBgDark = Color(0xFF090D16);
  static const Color kCardDark = Color(0xFF131B2A);
  static const Color kBorderSubtle = Color(0xFF1E2B3E);
  static const Color kAccentCyan = Color(0xFF00E5FF);
  static const Color kAccentGreen = Color(0xFF00FF88);
  static const Color kAccentAmber = Color(0xFFFFB703);
  static const Color kAccentPurple = Color(0xFFBB86FC);
  static const Color kTextMuted = Color(0xFF8896AB);

  List<SectorTheme> _themes = [];
  List<SectorLiveFeedItem> _liveFeeds = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedThemeFilter = 'ALL';
  int _currentTabIndex = 0; // 0: Live Telemetry, 1: 47 Sectors Directory

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDirectoryAndFeeds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectoryAndFeeds() async {
    try {
      final dirStr = await rootBundle
          .loadString('assets/data/sector_sources_directory.json');
      final dirJson = jsonDecode(dirStr);
      final rawThemes = (dirJson['themes'] as List? ?? [])
          .map((t) => SectorTheme.fromJson(t))
          .toList();

      final feedStr =
          await rootBundle.loadString('assets/data/sector_live_feed.json');
      final feedJson = jsonDecode(feedStr);
      final rawFeeds = (feedJson['live_feeds'] as List? ?? [])
          .map((f) => SectorLiveFeedItem.fromJson(f))
          .toList();

      if (mounted) {
        setState(() {
          _themes = rawThemes;
          _liveFeeds = rawFeeds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getSourceTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'REGULATOR':
        return kAccentAmber;
      case 'ASSOCIATION':
        return kAccentGreen;
      case 'ORIGINAL':
        return kAccentCyan;
      case 'NEWS':
      case 'NEWS_PRICING':
        return kAccentPurple;
      case 'RESEARCH':
        return const Color(0xFFFF7597);
      case 'PROCUREMENT':
        return const Color(0xFFFF9E00);
      default:
        return Colors.white70;
    }
  }

  // ============================================================================
  // ZERO-BROWSER IN-APP READER SHEET (ALL DATA REMAINS INSIDE THE APP)
  // ============================================================================

  void _openInAppReaderSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String body,
    required String cadence,
    required String url,
    required String authority,
    required String type,
    List<String>? tickers,
  }) {
    HapticFeedback.mediumImpact();
    final badgeColor = _getSourceTypeColor(type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Color(0xFF0D1322),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF2A3B54), width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle & close button row
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: badgeColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        type.replaceAll('_', ' '),
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF1E2B3E), height: 1),

              // Content Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle / Sector Header
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: kAccentCyan),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              subtitle.toUpperCase(),
                              style: GoogleFonts.robotoMono(
                                color: kAccentCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Headline
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Authority Badge Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF22324A)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: badgeColor),
                            const SizedBox(width: 6),
                            Text(
                              "AUTHORITY LAYER: $authority",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // In-App Body Text Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1F2E44)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_stories_rounded, size: 14, color: kAccentGreen),
                                const SizedBox(width: 6),
                                Text(
                                  "IN-APP INTELLIGENCE BRIEFING",
                                  style: GoogleFonts.robotoMono(
                                    color: kAccentGreen,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              body,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFCFD7E6),
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Kya Dekhna Hai Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1C2738)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.track_changes_rounded, size: 13, color: kAccentAmber),
                                const SizedBox(width: 6),
                                Text(
                                  "CADENCE & WHAT TO WATCH:",
                                  style: GoogleFonts.robotoMono(
                                    color: kAccentAmber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              cadence,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (tickers != null && tickers.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text("EXPOSED TICKERS: ", style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: tickers.map((t) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: kAccentCyan.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: kAccentCyan.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      t,
                                      style: GoogleFonts.robotoMono(
                                        color: kAccentCyan,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // URL Copy Action Bar (Zero external browser redirect)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF22324A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, size: 16, color: kAccentCyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Verified source URL copied: $url'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color(0xFF1B273A),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 12, color: Colors.black),
                              label: const Text("Copy Link", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccentCyan,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 1: LIVE SECTOR TELEMETRY CARDS
  // ============================================================================

  Widget _buildLiveTelemetryTab() {
    final filtered = _liveFeeds.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.sectorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.sourceName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesTheme = _selectedThemeFilter == 'ALL' ||
          item.themeName.toLowerCase().contains(_selectedThemeFilter.toLowerCase());

      return matchesSearch && matchesTheme;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 42, color: kTextMuted),
              const SizedBox(height: 10),
              Text(
                "No sector telemetry matching '$_searchQuery'",
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: filtered.length,
      itemBuilder: (ctx, idx) {
        final item = filtered[idx];
        final typeColor = _getSourceTypeColor(item.sourceType);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderSubtle),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              _openInAppReaderSheet(
                context: context,
                title: item.title,
                subtitle: "${item.themeIcon} ${item.sectorName}",
                body: item.summary,
                cadence: item.kyaDekhnaHai,
                url: item.sourceUrl,
                authority: item.sourceName,
                type: item.sourceType,
                tickers: item.keyTickers,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sector Header & Source Badge
                  Row(
                    children: [
                      Text(item.themeIcon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.sectorName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.robotoMono(
                            color: kAccentCyan,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: typeColor.withOpacity(0.35)),
                        ),
                        child: Text(
                          item.sourceName,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Summary
                  Text(
                    item.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFBAC7DB),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bottom Action Bar: Kya Dekhna Hai preview + In-App Tap Guide
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: kTextMuted),
                      const SizedBox(width: 4),
                      Text(
                        item.publishedAt,
                        style: const TextStyle(color: kTextMuted, fontSize: 9.5),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E283A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2A364E)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_rounded, size: 11, color: kAccentCyan),
                            const SizedBox(width: 4),
                            Text(
                              "In-App Read",
                              style: GoogleFonts.plusJakartaSans(
                                color: kAccentCyan,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 2: 47 SECTORS INTELLIGENCE DIRECTORY
  // ============================================================================

  Widget _buildDirectoryTab() {
    final filteredThemes = _themes.where((theme) {
      if (_selectedThemeFilter != 'ALL' &&
          !theme.themeName.toLowerCase().contains(_selectedThemeFilter.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: filteredThemes.length,
      itemBuilder: (ctx, tIdx) {
        final theme = filteredThemes[tIdx];

        final matchedSectors = theme.sectors.where((sector) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return sector.sectorName.toLowerCase().contains(q) ||
              sector.keyFocus.toLowerCase().contains(q) ||
              sector.sources.any((s) => s.name.toLowerCase().contains(q) || s.authority.toLowerCase().contains(q));
        }).toList();

        if (matchedSectors.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Category Header Pill
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Text(theme.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      theme.themeName.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E283A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${matchedSectors.length} Sectors",
                      style: const TextStyle(color: kTextMuted, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Sector Cards inside this Theme
            ...matchedSectors.map((sector) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kCardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sector ID & Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: kAccentCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sector.id.toString().padLeft(2, '0'),
                            style: GoogleFonts.robotoMono(
                              color: kAccentCyan,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            sector.sectorName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Kya Dekhna Hai
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.track_changes_rounded, size: 11, color: kAccentAmber),
                              const SizedBox(width: 4),
                              Text(
                                "KYA DEKHNA HAI:",
                                style: GoogleFonts.robotoMono(
                                  color: kAccentAmber,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sector.keyFocus,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFBAC7DB),
                              fontSize: 10.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 10, color: kTextMuted),
                              const SizedBox(width: 4),
                              Text(
                                "Cadence: ${sector.cadence}",
                                style: const TextStyle(color: kTextMuted, fontSize: 8.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Clickable Source Chips (opens In-App Reader Modal, Zero browser launch)
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: sector.sources.map((src) {
                        final typeColor = _getSourceTypeColor(src.type);
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            _openInAppReaderSheet(
                              context: context,
                              title: "${sector.sectorName} • ${src.name}",
                              subtitle: "${theme.icon} ${theme.themeName}",
                              body: src.description,
                              cadence: "${sector.cadence}\n\nFOCUS:\n${sector.keyFocus}",
                              url: src.url,
                              authority: src.authority,
                              type: src.type,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: typeColor.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hub_rounded, size: 10, color: typeColor),
                                const SizedBox(width: 4),
                                Text(
                                  src.name,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ============================================================================
  // SCREEN SCAFFOLD & APPBAR
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1322),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SECTOR SOURCES & TELEMETRY",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const Text(
              "47 Sectors • 6 Themes • 92 Industry Portals (In-App)",
              style: TextStyle(color: kTextMuted, fontSize: 8.5),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccentCyan))
          : Column(
              children: [
                // Top Tab Selector (Live Telemetry vs 47 Sectors Directory)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentTabIndex = 0);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _currentTabIndex == 0 ? kAccentCyan.withOpacity(0.18) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: _currentTabIndex == 0 ? Border.all(color: kAccentCyan.withOpacity(0.4)) : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flash_on_rounded, size: 12, color: _currentTabIndex == 0 ? kAccentCyan : kTextMuted),
                                const SizedBox(width: 4),
                                Text(
                                  "⚡ Live Sector Feeds",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _currentTabIndex == 0 ? kAccentCyan : kTextMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentTabIndex = 1);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _currentTabIndex == 1 ? kAccentCyan.withOpacity(0.18) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: _currentTabIndex == 1 ? Border.all(color: kAccentCyan.withOpacity(0.4)) : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hub_rounded, size: 12, color: _currentTabIndex == 1 ? kAccentCyan : kTextMuted),
                                const SizedBox(width: 4),
                                Text(
                                  "📚 47 Sectors Directory",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _currentTabIndex == 1 ? kAccentCyan : kTextMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorderSubtle),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: "Search sector, regulator, association (ISMA, FADA, RBI...)",
                        hintStyle: GoogleFonts.plusJakartaSans(color: kTextMuted, fontSize: 10.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: kTextMuted, size: 16),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: kTextMuted, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),

                // Theme Filter Pills
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _buildThemeFilterPill("ALL", "All 47"),
                      _buildThemeFilterPill("AGRI", "🌾 Agri & Inputs"),
                      _buildThemeFilterPill("MANUFACTURING", "🏭 Manufacturing"),
                      _buildThemeFilterPill("ENERGY", "⚡ Energy & Infra"),
                      _buildThemeFilterPill("BANKING", "🏦 Banking & Finance"),
                      _buildThemeFilterPill("HEALTH", "💻 IT & Health"),
                      _buildThemeFilterPill("CONSUMPTION", "🛒 Consumption"),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Content View
                Expanded(
                  child: _currentTabIndex == 0
                      ? _buildLiveTelemetryTab()
                      : _buildDirectoryTab(),
                ),
              ],
            ),
    );
  }

  Widget _buildThemeFilterPill(String filterKey, String label) {
    final isSelected = _selectedThemeFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedThemeFilter = filterKey);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? kAccentCyan.withOpacity(0.18) : const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? kAccentCyan.withOpacity(0.5) : kBorderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? kAccentCyan : kTextMuted,
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
