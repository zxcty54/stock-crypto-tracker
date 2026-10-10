import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../models/rental_listing.dart';
import 'create_listing_screen.dart';
import 'explore_screen.dart';
import 'inbox_screen.dart';
import 'listing_detail_screen.dart';
import 'listing_search_screen.dart';
import 'profile_screen.dart';
import 'saved_listings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _openListing(RentalListing listing) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(listing: listing),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ListingSearchScreen(onOpenListing: _openListing),
      ),
    );
  }

  void _openCreateListing() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CreateListingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          ExploreScreen(
            onOpenListing: _openListing,
            onOpenSearch: _openSearch,
            onCreateListing: _openCreateListing,
          ),
          SavedListingsScreen(onOpenListing: _openListing),
          const InboxScreen(),
          ProfileScreen(onCreateListing: _openCreateListing),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: AanganColors.paleGreen,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
