import 'package:flutter_test/flutter_test.dart';

import 'package:aangan_bihar_rentals/features/rentals/data/bihar_locations.dart';
import 'package:aangan_bihar_rentals/features/rentals/data/demo_listings.dart';
import 'package:aangan_bihar_rentals/features/rentals/models/rental_listing.dart';

void main() {
  group('Bihar location directory', () {
    test('contains all 38 districts', () {
      expect(BiharLocations.districts, hasLength(38));
      expect(BiharLocations.districts, contains('Patna'));
      expect(BiharLocations.districts, contains('West Champaran'));
    });

    test('district selection narrows city and block suggestions', () {
      expect(BiharLocations.townsFor('Patna'), contains('Danapur'));
      expect(BiharLocations.blocksFor('Patna'), contains('Patna Sadar'));
      expect(BiharLocations.townsFor('Arwal'), contains('Arwal'));
    });
  });

  group('ListingFilters', () {
    test('filters are case-insensitive across district, block and locality', () {
      final results = const ListingFilters(
        district: 'patna',
        town: 'pat',
        block: 'sadar',
        locality: 'boring',
      ).apply(demoListings);

      expect(results, hasLength(1));
      expect(results.single.id, 'demo-patna-01');
    });

    test('pet and tenant preference filters only return explicitly allowed homes', () {
      final results = const ListingFilters(
        petsOnly: true,
        bachelorsOnly: true,
      ).apply(demoListings);

      expect(results, isNotEmpty);
      expect(
        results.every((listing) =>
            listing.tenantRules['pets'] == 'allowed' &&
            listing.tenantRules['bachelors'] == 'allowed'),
        isTrue,
      );
    });

    test('rent cap and bedroom minimum can be combined', () {
      final results = const ListingFilters(
        maximumRent: 15000,
        minimumBedrooms: 2,
      ).apply(demoListings);

      expect(results, hasLength(1));
      expect(results.single.district, 'Gaya');
    });

    test('keyword search covers road and landmark details', () {
      final results = const ListingFilters(query: 'rajendra nagar').apply(demoListings);

      expect(results, hasLength(1));
      expect(results.single.id, 'demo-patna-02');
    });
  });
}
