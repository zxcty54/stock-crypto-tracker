import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ---------------- MODELS ----------------
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

// ---------------- UI SCREEN ----------------
class CorporateAnnouncementsScreen extends StatefulWidget {
  const CorporateAnnouncementsScreen({super.key});

  @override
  State<CorporateAnnouncementsScreen> createState() =>
      _CorporateAnnouncementsScreenState();
}

class _CorporateAnnouncementsScreenState
    extends State<CorporateAnnouncementsScreen> {
  CorporateFeedPayload? _payload;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'ALL';

  final String _endpointUrl =
      'https://fastly.jsdelivr.net/gh/zxcty54/stock-crypto-tracker@main/nse_content_feed.json';

  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color borderSubtle = Color(0xFF202C42);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color textMuted = Color(0xFF8896AB);

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
          '$_endpointUrl?ts=${DateTime.now().millisecondsSinceEpoch}');
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
        setState(() {
          _payload = CorporateFeedPayload.fromJson(parsed);
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Sync failed (HTTP ${response.statusCode})';
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

  List<CorporateAnnouncement> get _filteredFeed {
    if (_payload == null) return [];
    if (_selectedCategory == 'ALL') return _payload!.feed;
    return _payload!.feed
        .where((item) =>
            item.category.toUpperCase() == _selectedCategory.toUpperCase())
        .toList();
  }

  List<String> get _categories {
    if (_payload == null) return ['ALL'];
    final set = <String>{'ALL'};
    for (var item in _payload!.feed) {
      if (item.category.isNotEmpty) set.add(item.category);
    }
    return set.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: accentCyan,
          backgroundColor: surfaceCard,
          onRefresh: _fetchFeed,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_payload != null && !_isLoading)
                SliverToBoxAdapter(child: _buildCategoryChips()),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00E676),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EXCHANGE INTELLIGENCE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Corporate Filings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              if (_payload != null)
                Text(
                  '${_payload!.worthyCount} material disclosures analyzed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textMuted,
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: accentCyan),
            onPressed: _fetchFeed,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat.replaceAll('_', ' ')),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              backgroundColor: surfaceCard,
              selectedColor: accentCyan.withOpacity(0.18),
              side: BorderSide(
                color: isSelected ? accentCyan : borderSubtle,
                width: 1.2,
              ),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? accentCyan : textMuted,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: accentCyan, strokeWidth: 2.5),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 42),
              const SizedBox(height: 10),
              Text(_errorMessage!, style: const TextStyle(color: textMuted)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _fetchFeed,
                icon: const Icon(Icons.refresh, color: accentCyan),
                label: const Text('Retry Sync', style: TextStyle(color: accentCyan)),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filteredFeed;
    if (list.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'No filings found for category $_selectedCategory',
            style: const TextStyle(color: textMuted),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => AnnouncementCard(item: list[index]),
          childCount: list.length,
        ),
      ),
    );
  }
}

// ---------------- CARD ITEM ----------------
class AnnouncementCard extends StatelessWidget {
  final CorporateAnnouncement item;
  const AnnouncementCard({super.key, required this.item});

  Color _getCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'BUYBACK':
        return const Color(0xFFFFD700);
      case 'ORDER':
      case 'ORDER_WIN':
        return const Color(0xFF00E5FF);
      case 'BONUS':
        return const Color(0xFFD500F9);
      case 'COMMERCIAL_PRODUCTION':
        return const Color(0xFFFF9100);
      case 'CAPACITY_EXPANSION':
      case 'CAPEX':
        return const Color(0xFF00E676);
      case 'JV':
      case 'JOINT_VENTURE':
        return const Color(0xFF2979FF);
      case 'NEW_PRODUCT':
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toUpperCase()) {
      case 'BUYBACK':
        return Icons.monetization_on_rounded;
      case 'ORDER':
      case 'ORDER_WIN':
        return Icons.assignment_turned_in_rounded;
      case 'BONUS':
        return Icons.card_giftcard_rounded;
      case 'COMMERCIAL_PRODUCTION':
        return Icons.factory_rounded;
      case 'CAPACITY_EXPANSION':
      case 'CAPEX':
        return Icons.trending_up_rounded;
      case 'JV':
      case 'JOINT_VENTURE':
        return Icons.handshake_rounded;
      case 'NEW_PRODUCT':
        return Icons.rocket_launch_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getCategoryColor(item.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF202C42), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: themeColor.withOpacity(0.35), width: 0.9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getCategoryIcon(item.category),
                          size: 13, color: themeColor),
                      const SizedBox(width: 5),
                      Text(
                        item.category.replaceAll('_', ' '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: themeColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D2638),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2A364E)),
                  ),
                  child: Text(
                    'NSE: ${item.symbol}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.companyName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF8896AB),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.headline,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F19),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1B2334)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insights_rounded,
                      size: 15, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.worthinessReason,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFFB0BAC9),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 13, color: Color(0xFF8896AB)),
                const SizedBox(width: 5),
                Text(
                  item.broadcastDate,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF8896AB),
                  ),
                ),
                const Spacer(),
                if (item.pdfLink.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item.pdfLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('NSE filing link copied to clipboard!'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Color(0xFF131B2A),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E283A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              size: 13, color: Color(0xFFFF5252)),
                          const SizedBox(width: 4),
                          Text(
                            'NSE PDF',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
