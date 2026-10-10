import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../models/rental_listing.dart';
import '../services/favorites_store.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.horizontal = false,
  });

  final RentalListing listing;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final imageHeight = horizontal ? 164.0 : 205.0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AanganColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ListingImage(url: listing.firstPhoto),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              listing.isVerified
                                  ? Icons.verified_rounded
                                  : Icons.schedule_rounded,
                              size: 13,
                              color: listing.isVerified
                                  ? AanganColors.forest
                                  : const Color(0xFF9A6B1F),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              listing.isVerified ? 'AANGAN CHECKED' : 'IN REVIEW',
                              style: TextStyle(
                                color: listing.isVerified
                                    ? AanganColors.forest
                                    : const Color(0xFF9A6B1F),
                                fontSize: 8,
                                letterSpacing: 0.45,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedBuilder(
                        animation: FavoritesStore.instance,
                        builder: (context, _) {
                          final saved = FavoritesStore.instance.contains(listing.id);
                          return Material(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: saved ? 'Remove from saved' : 'Save home',
                              onPressed: () =>
                                  FavoritesStore.instance.toggle(listing.id),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                saved
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: saved
                                    ? AanganColors.terracotta
                                    : AanganColors.ink,
                                size: 19,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 11,
                      left: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AanganColors.forestDark.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          listing.listerType == 'broker'
                              ? 'LOCAL BROKER'
                              : 'DIRECT OWNER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AanganColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.location_on_outlined,
                          color: AanganColors.leaf,
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${listing.locality}, ${listing.town}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AanganColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 7,
                      children: <Widget>[
                        _Fact(icon: Icons.bed_outlined, text: '${listing.bedrooms} BHK'),
                        _Fact(
                          icon: Icons.square_foot_rounded,
                          text: '${listing.areaSqft} sq ft',
                        ),
                        if (listing.tenantRules['pets'] == 'allowed')
                          const _Fact(icon: Icons.pets_outlined, text: 'Pets ok'),
                      ],
                    ),
                    const SizedBox(height: 13),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '₹${formatRupees(listing.monthlyRent)}',
                          style: const TextStyle(
                            color: AanganColors.forest,
                            fontSize: 19,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 1),
                          child: Text(
                            '/ month',
                            style: TextStyle(
                              color: AanganColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (listing.rentNegotiable)
                          const Text(
                            'Negotiable',
                            style: TextStyle(
                              color: AanganColors.terracotta,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingImage extends StatelessWidget {
  const _ListingImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _ImageFallback();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, _) => const _ImageFallback(),
      errorWidget: (context, _, __) => const _ImageFallback(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFE9EEE7), Color(0xFFD8E4D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.home_work_outlined,
          size: 48,
          color: AanganColors.leaf,
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: AanganColors.leaf),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AanganColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
