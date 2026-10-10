import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../data/bihar_locations.dart';
import '../models/rental_listing.dart';
import '../services/app_backend.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/listing_card.dart';

class ListingSearchScreen extends StatefulWidget {
  const ListingSearchScreen({
    super.key,
    required this.onOpenListing,
  });

  final ValueChanged<RentalListing> onOpenListing;

  @override
  State<ListingSearchScreen> createState() => _ListingSearchScreenState();
}

class _ListingSearchScreenState extends State<ListingSearchScreen> {
  final _queryController = TextEditingController();
  final _townController = TextEditingController();
  final _blockController = TextEditingController();
  final _localityController = TextEditingController();
  final _maxRentController = TextEditingController();

  List<RentalListing> _allListings = <RentalListing>[];
  String? _district;
  String? _propertyType;
  int? _bedrooms;
  bool _petsOnly = false;
  bool _bachelorsOnly = false;
  bool _couplesOnly = false;
  bool _loading = true;
  String? _error;

  static const _propertyTypes = <String>[
    'Apartment',
    'Independent floor',
    'Independent house',
    'Studio',
    'PG / shared home',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _townController.dispose();
    _blockController.dispose();
    _localityController.dispose();
    _maxRentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final listings = await RentalRepository.instance.getPublishedListings();
      if (!mounted) return;
      setState(() {
        _allListings = listings;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  ListingFilters get _filters => ListingFilters(
        query: _queryController.text,
        district: _district,
        town: _townController.text.trim().isEmpty
            ? null
            : _townController.text.trim(),
        block: _blockController.text.trim().isEmpty
            ? null
            : _blockController.text.trim(),
        locality: _localityController.text.trim().isEmpty
            ? null
            : _localityController.text.trim(),
        minimumBedrooms: _bedrooms,
        propertyType: _propertyType,
        maximumRent: int.tryParse(_maxRentController.text.trim()),
        petsOnly: _petsOnly,
        bachelorsOnly: _bachelorsOnly,
        couplesOnly: _couplesOnly,
      );

  List<RentalListing> get _results => _filters.apply(_allListings);

  int get _activeFilterCount {
    var count = 0;
    if (_district != null) count++;
    if (_townController.text.trim().isNotEmpty) count++;
    if (_blockController.text.trim().isNotEmpty) count++;
    if (_localityController.text.trim().isNotEmpty) count++;
    if (_bedrooms != null) count++;
    if (_propertyType != null) count++;
    if (_maxRentController.text.trim().isNotEmpty) count++;
    if (_petsOnly) count++;
    if (_bachelorsOnly) count++;
    if (_couplesOnly) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find a rental',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _clear,
            child: const Text('Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                children: <Widget>[
                  if (!AppBackend.isReady) ...<Widget>[
                    const BackendNotice(),
                    const SizedBox(height: 14),
                  ],
                  _filterPanel(),
                  const SizedBox(height: 23),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _loading
                              ? 'Searching Bihar homes…'
                              : '${results.length} ${results.length == 1 ? 'home' : 'homes'} found',
                          style: const TextStyle(
                            color: AanganColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_activeFilterCount > 0)
                        Text(
                          '$_activeFilterCount filters',
                          style: const TextStyle(
                            color: AanganColors.forest,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Could not load homes',
                        message: 'Check your connection and pull down to retry.',
                      ),
                    )
                  else if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(35),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AanganColors.forest,
                        ),
                      ),
                    )
                  else if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 26),
                      child: EmptyState(
                        icon: Icons.manage_search_rounded,
                        title: 'No matching homes yet',
                        message:
                            'Try widening your budget or removing a filter. Every listing shows its house rules upfront.',
                      ),
                    )
                  else
                    ...results.map(
                      (listing) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ListingCard(
                          listing: listing,
                          onTap: () => widget.onOpenListing(listing),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPanel() {
    final townSuggestions = _district == null
        ? BiharLocations.allTownNames()
        : BiharLocations.townsFor(_district);
    final blockSuggestions = _district == null
        ? BiharLocations.allBlockNames()
        : BiharLocations.blocksFor(_district);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AanganColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Keyword or landmark',
              hintText: 'e.g. Boring Road, balcony, near station',
              prefixIcon: Icon(Icons.search_rounded, color: AanganColors.forest),
            ),
          ),
          const SizedBox(height: 11),
          DropdownButtonFormField<String?>(
            value: _district,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'District · Bihar',
              prefixIcon: Icon(Icons.map_outlined, color: AanganColors.forest),
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All 38 districts'),
              ),
              ...BiharLocations.districts.map(
                (district) => DropdownMenuItem<String?>(
                  value: district,
                  child: Text(district),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              if (_district != value) {
                _townController.clear();
                _blockController.clear();
              }
              _district = value;
            }),
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Expanded(
                child: _suggestedTextField(
                  controller: _townController,
                  label: 'City / town',
                  icon: Icons.location_city_outlined,
                  suggestions: townSuggestions,
                  hint: 'Patna, Danapur…',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _suggestedTextField(
                  controller: _blockController,
                  label: 'Block',
                  icon: Icons.grid_view_rounded,
                  suggestions: blockSuggestions,
                  hint: 'Patna Sadar…',
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _suggestedTextField(
            controller: _localityController,
            label: 'Locality / road / landmark',
            icon: Icons.signpost_outlined,
            suggestions: const <String>[
              'Boring Road',
              'Kankarbagh',
              'Rajendra Nagar',
              'Bailey Road',
              'AP Colony',
              'Mithanpura',
            ],
            hint: 'Search a neighbourhood',
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _propertyType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Home type',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Any type'),
                    ),
                    ..._propertyTypes.map(
                      (type) => DropdownMenuItem<String?>(
                        value: type,
                        child: Text(type, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _propertyType = value),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: _maxRentController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Max rent / month',
                    prefixText: '₹ ',
                    hintText: '20,000',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Bedrooms',
            style: TextStyle(
              color: AanganColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            children: <int?>[null, 1, 2, 3].map((bedrooms) {
              final selected = _bedrooms == bedrooms;
              return ChoiceChip(
                label: Text(bedrooms == null ? 'Any' : '$bedrooms+ BHK'),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _bedrooms = bedrooms),
                selectedColor: AanganColors.paleGreen,
                backgroundColor: AanganColors.canvas,
                labelStyle: TextStyle(
                  color: selected ? AanganColors.forest : AanganColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected ? AanganColors.leaf : AanganColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              _toggleChip(
                'Pets welcome',
                Icons.pets_outlined,
                _petsOnly,
                (value) => _petsOnly = value,
              ),
              _toggleChip(
                'Bachelors',
                Icons.person_outline_rounded,
                _bachelorsOnly,
                (value) => _bachelorsOnly = value,
              ),
              _toggleChip(
                'Couples',
                Icons.favorite_border_rounded,
                _couplesOnly,
                (value) => _couplesOnly = value,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> suggestions,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: AanganColors.forest, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 14,
            ),
          ),
        ),
        if (suggestions.isNotEmpty && controller.text.isEmpty) ...<Widget>[
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length > 5 ? 5 : suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) => InkWell(
                onTap: () => setState(() {
                  controller.text = suggestions[index];
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                }),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AanganColors.canvas,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    suggestions[index],
                    style: const TextStyle(
                      color: AanganColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _toggleChip(
    String label,
    IconData icon,
    bool selected,
    ValueChanged<bool> update,
  ) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (value) => setState(() => update(value)),
      avatar: Icon(
        icon,
        size: 15,
        color: selected ? AanganColors.forest : AanganColors.muted,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? AanganColors.forest : AanganColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AanganColors.canvas,
      selectedColor: AanganColors.paleGreen,
      side: BorderSide(
        color: selected ? AanganColors.leaf : AanganColors.line,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _clear() {
    setState(() {
      _queryController.clear();
      _townController.clear();
      _blockController.clear();
      _localityController.clear();
      _maxRentController.clear();
      _district = null;
      _propertyType = null;
      _bedrooms = null;
      _petsOnly = false;
      _bachelorsOnly = false;
      _couplesOnly = false;
    });
  }
}
