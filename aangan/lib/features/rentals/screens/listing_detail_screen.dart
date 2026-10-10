import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/aangan_app.dart';
import '../models/rental_listing.dart';
import '../services/app_backend.dart';
import '../services/favorites_store.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final RentalListing listing;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  int _photoIndex = 0;
  bool _busy = false;

  RentalListing get listing => widget.listing;

  @override
  Widget build(BuildContext context) {
    final photos = listing.photos;
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AanganColors.canvas,
            foregroundColor: AanganColors.ink,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(7),
              child: _roundAction(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            actions: <Widget>[
              AnimatedBuilder(
                animation: FavoritesStore.instance,
                builder: (context, _) {
                  final saved = FavoritesStore.instance.contains(listing.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _roundAction(
                      icon: saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: saved
                          ? AanganColors.terracotta
                          : AanganColors.ink,
                      tooltip: saved ? 'Remove saved home' : 'Save this home',
                      onPressed: () => FavoritesStore.instance.toggle(listing.id),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _roundAction(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share listing',
                  onPressed: () => _showMessage(
                    'Share link feature will be available when the listing is live.',
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (photos.isEmpty)
                    const _DetailPhotoFallback()
                  else
                    PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (index) => setState(() => _photoIndex = index),
                      itemBuilder: (context, index) => _DetailPhoto(url: photos[index]),
                    ),
                  if (photos.length > 1)
                    Positioned(
                      right: 17,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          '${_photoIndex + 1} / ${photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                Row(
                  children: <Widget>[
                    if (listing.isVerified) ...<Widget>[
                      const Icon(
                        Icons.verified_rounded,
                        color: AanganColors.forest,
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Aangan checked',
                        style: TextStyle(
                          color: AanganColors.forest,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 9),
                    ],
                    Expanded(
                      child: Text(
                        '${listing.propertyType} · ${listing.furnishing}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AanganColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  listing.title,
                  style: const TextStyle(
                    color: AanganColors.ink,
                    fontSize: 25,
                    height: 1.16,
                    letterSpacing: -0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: AanganColors.leaf,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _publicAddress,
                        style: const TextStyle(
                          color: AanganColors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _priceCard(),
                if (listing.listerType == 'broker') ...<Widget>[
                  const SizedBox(height: 9),
                  _brokerageDisclosure(),
                ],
                const SizedBox(height: 16),
                _homeFacts(),
                if (listing.maintenanceIncluded || listing.availableFrom != null) ...<Widget>[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      if (listing.maintenanceIncluded)
                        const _InfoChip(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Maintenance included',
                        ),
                      if (listing.availableFrom != null)
                        _InfoChip(
                          icon: Icons.calendar_month_outlined,
                          label:
                              'Available ${listing.availableFrom!.day}/${listing.availableFrom!.month}/${listing.availableFrom!.year}',
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 25),
                const SectionHeading(title: 'About this home'),
                const SizedBox(height: 9),
                Text(
                  listing.description,
                  style: const TextStyle(
                    color: Color(0xFF58655C),
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
                if (listing.amenities.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 25),
                  const SectionHeading(
                    title: 'What you get',
                    subtitle: 'A few everyday comforts, listed up front.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: listing.amenities
                        .map((amenity) => _AmenityChip(label: amenity))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 25),
                const SectionHeading(
                  title: 'House rules, upfront',
                  subtitle:
                      'Owner-set preferences. “Discuss first” means ask before planning.',
                ),
                const SizedBox(height: 12),
                _rulesGrid(),
                const SizedBox(height: 25),
                const SectionHeading(title: 'Listing host'),
                const SizedBox(height: 10),
                _hostCard(),
                const SizedBox(height: 18),
                _safetyNote(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _reportListing,
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('Report this listing'),
                    style: TextButton.styleFrom(
                      foregroundColor: AanganColors.muted,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomContactBar(),
    );
  }

  String get _publicAddress {
    final parts = <String>[
      listing.locality,
      listing.block,
      listing.town,
      listing.district,
    ].where((part) => part.trim().isNotEmpty).toList();
    if (listing.showExactAddress) {
      if (listing.road.isNotEmpty) parts.insert(0, listing.road);
      if (listing.landmark.isNotEmpty) parts.add('Near ${listing.landmark}');
      if (listing.pincode.isNotEmpty) parts.add(listing.pincode);
    }
    return parts.join(' · ');
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color iconColor = AanganColors.ink,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor, size: 19),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _priceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AanganColors.paleGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '₹${formatRupees(listing.monthlyRent)}',
                  style: const TextStyle(
                    color: AanganColors.forest,
                    fontSize: 25,
                    height: 1,
                    letterSpacing: -0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'per month${listing.rentNegotiable ? ' · negotiable' : ''}',
                  style: const TextStyle(
                    color: AanganColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 38, color: const Color(0xFFD1DED1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '₹${formatRupees(listing.deposit)}',
                  style: const TextStyle(
                    color: AanganColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'security deposit',
                  style: TextStyle(color: AanganColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brokerageDisclosure() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AanganColors.paleOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.receipt_long_outlined,
              size: 17, color: AanganColors.terracotta),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Broker fee: ${listing.brokerFee}. Confirm the exact amount before a visit.',
              style: const TextStyle(
                color: AanganColors.ink,
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeFacts() {
    final facts = <(IconData, String)>[
      (Icons.bed_outlined, '${listing.bedrooms} bedrooms'),
      (Icons.shower_outlined, '${listing.bathrooms} bathrooms'),
      (Icons.square_foot_rounded, '${listing.areaSqft} sq ft'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AanganColors.line),
      ),
      child: Row(
        children: facts
            .map(
              (fact) => Expanded(
                child: Column(
                  children: <Widget>[
                    Icon(fact.$1, color: AanganColors.forest, size: 19),
                    const SizedBox(height: 6),
                    Text(
                      fact.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AanganColors.ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _rulesGrid() {
    const importantRules = <String>[
      'pets',
      'bachelors',
      'couples',
      'families',
      'visitors',
      'night_visitors',
      'unknown_visitors',
      'late_entry',
      'non_veg',
      'smoking',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: importantRules.map((key) {
        return RulePill(
          label: houseRuleLabels[key] ?? key,
          value: listing.tenantRules[key] ?? 'discuss',
        );
      }).toList(),
    );
  }

  Widget _hostCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AanganColors.line),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              color: AanganColors.paleGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AanganColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  listing.hostName,
                  style: const TextStyle(
                    color: AanganColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.listerType == 'broker'
                      ? 'Local broker · ${listing.brokerFee}'
                      : 'Direct property owner · no brokerage',
                  style: const TextStyle(
                    color: AanganColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (listing.isVerified)
            const Icon(Icons.verified_rounded, color: AanganColors.forest, size: 19),
        ],
      ),
    );
  }

  Widget _safetyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4E0B7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined, color: Color(0xFF9A6B1F), size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Safe renting tip: ghar dekhne ke baad hi token dein. Owner/agent ID, rent, deposit aur maintenance ko written agreement mein confirm karein.',
              style: TextStyle(
                color: Color(0xFF75551F),
                fontSize: 11,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomContactBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AanganColors.line)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: PrimaryButton(
                label: 'Message host',
                icon: Icons.chat_bubble_outline_rounded,
                isLoading: _busy,
                onPressed: _messageHost,
              ),
            ),
            const SizedBox(width: 9),
            Material(
              color: AanganColors.paleGreen,
              borderRadius: BorderRadius.circular(15),
              child: IconButton(
                tooltip: 'Call if the host allows it',
                onPressed: _callHost,
                icon: const Icon(
                  Icons.call_outlined,
                  color: AanganColors.forest,
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _requireSignIn() async {
    if (!AppBackend.isReady) {
      _showMessage('Connect Supabase to start a real chat or call.');
      return false;
    }
    if (AppBackend.currentUser != null) return true;
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );
    return signedIn == true && AppBackend.currentUser != null;
  }

  Future<void> _messageHost() async {
    if (_busy || !await _requireSignIn()) return;
    setState(() => _busy = true);
    try {
      final conversationId =
          await RentalRepository.instance.createConversation(listing);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            listingTitle: listing.title,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Chat open nahi ho paaya: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _callHost() async {
    if (!await _requireSignIn()) return;
    try {
      final phone = await RentalRepository.instance.getOwnerPhone(listing.id);
      if (!mounted) return;
      if (phone == null) {
        _showMessage('Host ne phone number private rakha hai — message bhejein.');
        return;
      }
      final uri = Uri(scheme: 'tel', path: phone);
      if (!await launchUrl(uri)) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Call the host'),
            content: SelectableText(phone),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) _showMessage('Phone number abhi available nahi hai.');
    }
  }

  Future<void> _reportListing() async {
    if (!await _requireSignIn()) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String selected = 'Incorrect information';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Report this home'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <String>[
                'Incorrect information',
                'Duplicate listing',
                'Suspicious or unsafe',
                'Already rented',
              ].map((choice) {
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: choice,
                  groupValue: selected,
                  title: Text(choice, style: const TextStyle(fontSize: 13)),
                  onChanged: (value) => setDialogState(() => selected = value!),
                );
              }).toList(),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Submit report'),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null || !mounted) return;
    try {
      await RentalRepository.instance.reportListing(
        listingId: listing.id,
        reason: reason,
      );
      if (mounted) _showMessage('Thanks — our team will review this listing.');
    } catch (error) {
      if (mounted) _showMessage('Report submit nahi hua: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailPhoto extends StatelessWidget {
  const _DetailPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const _DetailPhotoFallback(),
      errorWidget: (_, __, ___) => const _DetailPhotoFallback(),
    );
  }
}

class _DetailPhotoFallback extends StatelessWidget {
  const _DetailPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AanganColors.paleGreen,
      child: const Center(
        child: Icon(
          Icons.home_work_outlined,
          color: AanganColors.leaf,
          size: 68,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AanganColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AanganColors.forest, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AanganColors.ink,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AanganColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check_circle_outline_rounded,
              color: AanganColors.leaf, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AanganColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
