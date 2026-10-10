import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../models/rental_listing.dart';
import '../services/favorites_store.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/listing_card.dart';

class SavedListingsScreen extends StatefulWidget {
  const SavedListingsScreen({
    super.key,
    required this.onOpenListing,
  });

  final ValueChanged<RentalListing> onOpenListing;

  @override
  State<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends State<SavedListingsScreen> {
  Future<List<RentalListing>>? _listings;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _listings = RentalRepository.instance.getPublishedListings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved homes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh saved homes',
            onPressed: () => setState(_refresh),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 7),
        ],
      ),
      body: AnimatedBuilder(
        animation: FavoritesStore.instance,
        builder: (context, _) {
          final ids = FavoritesStore.instance.ids;
          if (ids.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Your shortlist starts here',
              message:
                  'Tap the heart on any home to save it on this device and compare it later.',
            );
          }
          return FutureBuilder<List<RentalListing>>(
            future: _listings,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Saved homes unavailable',
                  message: 'Pull down or tap refresh to try again.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AanganColors.forest),
                );
              }
              final saved = snapshot.data!
                  .where((listing) => ids.contains(listing.id))
                  .toList();
              if (saved.isEmpty) {
                return const EmptyState(
                  icon: Icons.home_outlined,
                  title: 'Saved homes are no longer live',
                  message:
                      'A host may have removed or rented a home. Browse Explore for new options.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => setState(_refresh),
                color: AanganColors.forest,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                  itemCount: saved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => ListingCard(
                    listing: saved[index],
                    onTap: () => widget.onOpenListing(saved[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
