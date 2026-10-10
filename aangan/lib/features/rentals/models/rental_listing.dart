import 'package:intl/intl.dart';

const Map<String, String> houseRuleLabels = <String, String>{
  'pets': 'Pets',
  'bachelors': 'Bachelors',
  'couples': 'Couples',
  'families': 'Families',
  'visitors': 'Visitors',
  'night_visitors': 'Night-time visitors',
  'unknown_visitors': 'Unannounced guests',
  'late_entry': 'Late entry',
  'non_veg': 'Non-veg cooking',
  'smoking': 'Smoking',
};

String ruleValueLabel(String? value) {
  switch (value) {
    case 'allowed':
      return 'Allowed';
    case 'not_allowed':
      return 'Not allowed';
    default:
      return 'Discuss first';
  }
}

class RentalListing {
  const RentalListing({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.district,
    required this.town,
    required this.block,
    required this.locality,
    required this.road,
    required this.landmark,
    required this.pincode,
    required this.propertyType,
    required this.furnishing,
    required this.listerType,
    required this.brokerFee,
    required this.hostName,
    required this.status,
    required this.monthlyRent,
    required this.deposit,
    required this.bedrooms,
    required this.bathrooms,
    required this.areaSqft,
    required this.rentNegotiable,
    required this.maintenanceIncluded,
    required this.showExactAddress,
    required this.amenities,
    required this.tenantRules,
    required this.photos,
    required this.photoPaths,
    required this.createdAt,
    this.availableFrom,
    this.rejectionNote = '',
  });

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String district;
  final String town;
  final String block;
  final String locality;
  final String road;
  final String landmark;
  final String pincode;
  final String propertyType;
  final String furnishing;
  final String listerType;
  final String brokerFee;
  final String hostName;
  final String status;
  final int monthlyRent;
  final int deposit;
  final int bedrooms;
  final int bathrooms;
  final int areaSqft;
  final bool rentNegotiable;
  final bool maintenanceIncluded;
  final bool showExactAddress;
  final List<String> amenities;
  final Map<String, String> tenantRules;
  final List<String> photos;
  final List<String> photoPaths;
  final DateTime createdAt;
  final DateTime? availableFrom;
  final String rejectionNote;

  bool get isVerified => status == 'published';
  String get firstPhoto => photos.isEmpty ? '' : photos.first;
  String get fullArea => <String>[locality, block, town, district]
      .where((part) => part.trim().isNotEmpty)
      .toSet()
      .join(', ');

  RentalListing copyWith({List<String>? photos}) {
    return RentalListing(
      id: id,
      ownerId: ownerId,
      title: title,
      description: description,
      district: district,
      town: town,
      block: block,
      locality: locality,
      road: road,
      landmark: landmark,
      pincode: pincode,
      propertyType: propertyType,
      furnishing: furnishing,
      listerType: listerType,
      brokerFee: brokerFee,
      hostName: hostName,
      status: status,
      monthlyRent: monthlyRent,
      deposit: deposit,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      areaSqft: areaSqft,
      rentNegotiable: rentNegotiable,
      maintenanceIncluded: maintenanceIncluded,
      showExactAddress: showExactAddress,
      amenities: amenities,
      tenantRules: tenantRules,
      photos: photos ?? this.photos,
      photoPaths: photoPaths,
      createdAt: createdAt,
      availableFrom: availableFrom,
      rejectionNote: rejectionNote,
    );
  }

  factory RentalListing.fromMap(Map<String, dynamic> map) {
    final rawRules = map['tenant_rules'];
    final rules = <String, String>{};
    if (rawRules is Map) {
      rawRules.forEach((key, value) {
        if (value != null) rules[key.toString()] = value.toString();
      });
    }

    return RentalListing(
      id: map['id']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Rental home',
      description: map['description']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      town: map['town']?.toString() ?? '',
      block: map['block']?.toString() ?? '',
      locality: map['locality']?.toString() ?? '',
      road: map['road']?.toString() ?? '',
      landmark: map['landmark']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '',
      propertyType: map['property_type']?.toString() ?? 'Apartment',
      furnishing: map['furnishing']?.toString() ?? 'Unfurnished',
      listerType: map['lister_type']?.toString() ?? 'owner',
      brokerFee: map['broker_fee']?.toString() ?? 'No brokerage',
      hostName: map['host_name']?.toString() ?? 'Aangan host',
      status: map['status']?.toString() ?? 'pending',
      monthlyRent: _asInt(map['monthly_rent']),
      deposit: _asInt(map['deposit']),
      bedrooms: _asInt(map['bedrooms']),
      bathrooms: _asInt(map['bathrooms']),
      areaSqft: _asInt(map['area_sqft']),
      rentNegotiable: map['rent_negotiable'] == true,
      maintenanceIncluded: map['maintenance_included'] == true,
      showExactAddress: map['show_exact_address'] == true,
      amenities: _asStringList(map['amenities']),
      tenantRules: rules,
      photos: const <String>[],
      photoPaths: _asStringList(map['photo_paths']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      availableFrom: DateTime.tryParse(map['available_from']?.toString() ?? ''),
      rejectionNote: map['rejection_note']?.toString() ?? '',
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}

class ListingFilters {
  const ListingFilters({
    this.query = '',
    this.district,
    this.town,
    this.block,
    this.locality,
    this.minimumBedrooms,
    this.propertyType,
    this.maximumRent,
    this.petsOnly = false,
    this.bachelorsOnly = false,
    this.couplesOnly = false,
  });

  final String query;
  final String? district;
  final String? town;
  final String? block;
  final String? locality;
  final int? minimumBedrooms;
  final String? propertyType;
  final int? maximumRent;
  final bool petsOnly;
  final bool bachelorsOnly;
  final bool couplesOnly;

  List<RentalListing> apply(Iterable<RentalListing> listings) {
    final search = query.trim().toLowerCase();
    bool includesLocation(String? term, String actual) {
      final cleanTerm = term?.trim().toLowerCase() ?? '';
      return cleanTerm.isEmpty || actual.toLowerCase().contains(cleanTerm);
    }

    return listings.where((listing) {
      if (district != null && listing.district.toLowerCase() != district!.toLowerCase()) {
        return false;
      }
      if (!includesLocation(town, listing.town)) return false;
      if (!includesLocation(block, listing.block)) return false;
      if (!includesLocation(locality, '${listing.locality} ${listing.road} ${listing.landmark}')) {
        return false;
      }
      if (minimumBedrooms != null && listing.bedrooms < minimumBedrooms!) {
        return false;
      }
      if (propertyType != null && listing.propertyType != propertyType) {
        return false;
      }
      if (maximumRent != null && listing.monthlyRent > maximumRent!) {
        return false;
      }
      if (petsOnly && listing.tenantRules['pets'] != 'allowed') return false;
      if (bachelorsOnly && listing.tenantRules['bachelors'] != 'allowed') {
        return false;
      }
      if (couplesOnly && listing.tenantRules['couples'] != 'allowed') {
        return false;
      }
      if (search.isNotEmpty) {
        final haystack = <String>[
          listing.title,
          listing.description,
          listing.district,
          listing.town,
          listing.block,
          listing.locality,
          listing.road,
          listing.landmark,
          listing.propertyType,
        ].join(' ').toLowerCase();
        if (!haystack.contains(search)) return false;
      }
      return true;
    }).toList(growable: false);
  }
}

String formatRupees(int amount) =>
    NumberFormat.decimalPattern('en_IN').format(amount);
