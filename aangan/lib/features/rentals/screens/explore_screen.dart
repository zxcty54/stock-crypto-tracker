import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../data/demo_listings.dart';
import '../models/rental_listing.dart';
import '../services/app_backend.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/listing_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.onOpenListing,
    required this.onOpenSearch,
    required this.onCreateListing,
  });

  final ValueChanged<RentalListing> onOpenListing;
  final VoidCallback onOpenSearch;
  final VoidCallback onCreateListing;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<RentalListing> _listings = demoListings;
  bool _loading = true;
  String? _loadError;
  String? _districtShortcut;
  String? _tenantShortcut;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    try {
      final listings = await RentalRepository.instance.getPublishedListings();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listings = demoListings;
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  List<RentalListing> get _visibleListings {
    var listings = _listings;
    if (_districtShortcut != null) {
      listings = listings
          .where((listing) => listing.district == _districtShortcut)
          .toList(growable: false);
    }
    if (_tenantShortcut == 'pets') {
      listings = listings
          .where((listing) => listing.tenantRules['pets'] == 'allowed')
          .toList(growable: false);
    } else if (_tenantShortcut == 'bachelors') {
      listings = listings
          .where((listing) => listing.tenantRules['bachelors'] == 'allowed')
          .toList(growable: false);
    } else if (_tenantShortcut == 'couples') {
      listings = listings
          .where((listing) => listing.tenantRules['couples'] == 'allowed')
          .toList(growable: false);
    }
    return listings;
  }

  @override
  Widget build(BuildContext context) {
    final listings = _visibleListings;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadListings,
        color: AanganColors.forest,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(child: _topBar()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            sliver: SliverToBoxAdapter(child: _hero()),
          ),
          if (!AppBackend.isReady || _loadError != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              sliver: SliverToBoxAdapter(
                child: _loadError == null
                    ? const BackendNotice()
                    : _offlineNotice(),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: AanganColors.forest,
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'Find a home that fits',
                    style: TextStyle(
                      color: AanganColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _districtShortcut = null;
                        _tenantShortcut = null;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
            sliver: SliverToBoxAdapter(child: _quickFilters()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 13),
            sliver: SliverToBoxAdapter(
              child: SectionHeading(
                title: _districtShortcut == null
                    ? 'Popular in Bihar'
                    : 'Homes in $_districtShortcut',
                subtitle: _tenantShortcut == null
                    ? 'Clear rent, clear rules. No surprise calls.'
                    : 'Homes that match your preference',
                trailing: TextButton(
                  onPressed: widget.onOpenSearch,
                  child: const Text('See all'),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: Center(
                  child: CircularProgressIndicator(color: AanganColors.forest),
                ),
              ),
            )
          else if (listings.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No homes in this filter yet',
                  message:
                      'Try another district or clear a preference. New Bihar homes are added as owners join.',
                  action: TextButton.icon(
                    onPressed: widget.onOpenSearch,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Open full search'),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList.separated(
                itemCount: listings.length > 4 ? 4 : listings.length,
                itemBuilder: (context, index) => ListingCard(
                  listing: listings[index],
                  onTap: () => widget.onOpenListing(listings[index]),
                ),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
            sliver: SliverToBoxAdapter(child: _districtBrowse()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            sliver: SliverToBoxAdapter(child: _ownerBanner()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
        ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: <Widget>[
        const AanganBrand(),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AanganColors.line),
          ),
          child: IconButton(
            tooltip: 'Browse all Bihar districts',
            onPressed: widget.onOpenSearch,
            icon: const Icon(
              Icons.search_rounded,
              color: AanganColors.forest,
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 22, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AanganColors.forest, AanganColors.forestDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -23,
            top: -34,
            child: Container(
              width: 155,
              height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 22),
              ),
            ),
          ),
          Positioned(
            right: 13,
            top: 35,
            child: Icon(
              Icons.home_work_rounded,
              size: 75,
              color: Colors.white.withValues(alpha: 0.11),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.place_rounded, color: AanganColors.gold, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'MADE FOR BIHAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Apna ghar.\nApne rules.',
                style: TextStyle(
                  color: AanganColors.cream,
                  fontSize: 30,
                  height: 1.05,
                  letterSpacing: -1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const SizedBox(
                width: 240,
                child: Text(
                  'Bihar mein rent dhoondhein — pets, guests aur move-in rules pehle se clear.',
                  style: TextStyle(
                    color: Color(0xFFDCE8DE),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 17),
              FilledButton.icon(
                onPressed: widget.onOpenSearch,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Ghar dhoondhein'),
                style: FilledButton.styleFrom(
                  backgroundColor: AanganColors.cream,
                  foregroundColor: AanganColors.forest,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: <Widget>[
                  _heroStat('38', 'districts'),
                  const SizedBox(width: 18),
                  _heroStat('Private', 'chat'),
                  const SizedBox(width: 18),
                  _heroStat('Human', 'review'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String top, String bottom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          top,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          bottom,
          style: const TextStyle(color: Color(0xFFCAD9CE), fontSize: 9),
        ),
      ],
    );
  }

  Widget _quickFilters() {
    final options = <(String, String, IconData)>[
      ('pets', 'Pets welcome', Icons.pets_outlined),
      ('bachelors', 'Bachelor friendly', Icons.person_outline_rounded),
      ('couples', 'Couples welcome', Icons.favorite_border_rounded),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          ...options.map((option) {
            final selected = _tenantShortcut == option.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected,
                showCheckmark: false,
                onSelected: (value) => setState(
                  () => _tenantShortcut = value ? option.$1 : null,
                ),
                avatar: Icon(
                  option.$3,
                  size: 16,
                  color: selected ? Colors.white : AanganColors.forest,
                ),
                label: Text(option.$2),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AanganColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: Colors.white,
                selectedColor: AanganColors.forest,
                side: BorderSide(
                  color: selected ? AanganColors.forest : AanganColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
          PopupMenuButton<String>(
            tooltip: 'Choose district',
            onSelected: (district) => setState(() {
              _districtShortcut = district == 'All Bihar' ? null : district;
            }),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'All Bihar',
                child: Text('All Bihar'),
              ),
              ...<String>['Patna', 'Gaya', 'Muzaffarpur', 'Bhagalpur']
                  .map((district) => PopupMenuItem<String>(
                        value: district,
                        child: Text(district),
                      )),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: AanganColors.cream,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AanganColors.line),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.location_city_rounded, size: 15, color: AanganColors.forest),
                  const SizedBox(width: 5),
                  Text(
                    _districtShortcut ?? 'City',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AanganColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _districtBrowse() {
    const areas = <(String, String, IconData)>[
      ('Patna', 'Capital city', Icons.account_balance_rounded),
      ('Gaya', 'Temple town', Icons.temple_buddhist_rounded),
      ('Muzaffarpur', 'North Bihar', Icons.eco_rounded),
      ('Bhagalpur', 'Silk city', Icons.water_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeading(
          title: 'Browse by city',
          subtitle: 'Choose a district to get closer to home.',
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: areas.map((area) {
            final selected = _districtShortcut == area.$1;
            return InkWell(
              onTap: () => setState(() {
                _districtShortcut = selected ? null : area.$1;
              }),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: (MediaQuery.sizeOf(context).width - 44) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? AanganColors.paleGreen : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selected ? AanganColors.leaf : AanganColors.line,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : AanganColors.paleGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(area.$3, size: 17, color: AanganColors.forest),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            area.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            area.$2,
                            style: const TextStyle(
                              color: AanganColors.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: widget.onOpenSearch,
          icon: const Icon(Icons.map_outlined, size: 17),
          label: const Text('See all 38 Bihar districts'),
          style: TextButton.styleFrom(foregroundColor: AanganColors.forest),
        ),
      ],
    );
  }

  Widget _ownerBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF3D8C9)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.key_rounded,
              color: AanganColors.terracotta,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Ghar rent pe dena hai?',
                  style: TextStyle(
                    color: AanganColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rules aap set karein. Listing approval ke baad hi live hogi.',
                  style: TextStyle(
                    color: AanganColors.muted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: widget.onCreateListing,
                  icon: const Icon(Icons.add_home_work_outlined, size: 16),
                  label: const Text('List your property'),
                  style: TextButton.styleFrom(
                    foregroundColor: AanganColors.forest,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DD),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Text(
        'Connection nahi ho paayi — abhi demo homes dikh rahe hain. Neeche pull karke phir try karein.',
        style: TextStyle(
          color: Color(0xFF75551F),
          fontSize: 11,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
