import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/demo_listings.dart';
import '../models/rental_listing.dart';
import 'app_backend.dart';

class RentalRepository {
  RentalRepository._();

  static final RentalRepository instance = RentalRepository._();

  Future<List<RentalListing>> getPublishedListings() async {
    if (!AppBackend.isReady) return demoListings;

    final rows = await AppBackend.client
        .from('listing_public')
        .select()
        .order('created_at', ascending: false)
        .limit(120);
    final listings = (rows as List<dynamic>)
        .map((row) => RentalListing.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
    return Future.wait(listings.map(_attachSignedPhotos));
  }

  Future<List<RentalListing>> getMyListings() async {
    final user = AppBackend.currentUser;
    if (user == null) return const <RentalListing>[];

    final rows = await AppBackend.client
        .from('listings')
        .select()
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);
    final listings = (rows as List<dynamic>)
        .map((row) => RentalListing.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
    return Future.wait(listings.map(_attachSignedPhotos));
  }

  Future<List<RentalListing>> getPendingListings() async {
    final rows = await AppBackend.client
        .from('listings')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    final listings = (rows as List<dynamic>)
        .map((row) => RentalListing.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
    return Future.wait(listings.map(_attachSignedPhotos));
  }

  Future<RentalListing> _attachSignedPhotos(RentalListing listing) async {
    if (listing.photoPaths.isEmpty) return listing;
    final urls = <String>[];
    for (final path in listing.photoPaths) {
      try {
        urls.add(await AppBackend.client.storage
            .from('rental-photos')
            .createSignedUrl(path, 3600));
      } catch (_) {
        // A missing/expired photo should not prevent the rest of the listing
        // from being viewed.
      }
    }
    return listing.copyWith(photos: urls);
  }

  Future<void> submitListing({
    required Map<String, dynamic> fields,
    required List<XFile> photos,
  }) async {
    final user = AppBackend.currentUser;
    if (user == null) throw AuthException('Sign in before submitting a home.');
    if (photos.isEmpty) {
      throw const FormatException('Please add at least one clear property photo.');
    }

    final inserted = await AppBackend.client
        .from('listings')
        .insert(<String, dynamic>{
          ...fields,
          'owner_id': user.id,
          'status': 'pending',
          'photo_paths': <String>[],
        })
        .select('id')
        .single();
    final listingId = inserted['id'].toString();
    final uploadedPaths = <String>[];

    try {
      for (final photo in photos.take(8)) {
        final bytes = await FlutterImageCompress.compressWithList(
          await photo.readAsBytes(),
          minWidth: 1800,
          minHeight: 1800,
          quality: 82,
          format: CompressFormat.jpeg,
        );
        final path =
            '${user.id}/$listingId/${DateTime.now().microsecondsSinceEpoch}.jpg';
        await AppBackend.client.storage.from('rental-photos').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: false,
              ),
            );
        uploadedPaths.add(path);
      }

      await AppBackend.client
          .from('listings')
          .update(<String, dynamic>{'photo_paths': uploadedPaths})
          .eq('id', listingId)
          .eq('owner_id', user.id);
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await AppBackend.client.storage.from('rental-photos').remove(uploadedPaths);
        } catch (_) {}
      }
      try {
        await AppBackend.client
            .from('listings')
            .delete()
            .eq('id', listingId)
            .eq('owner_id', user.id);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> reviewListing({
    required String listingId,
    required String decision,
    String? note,
  }) async {
    await AppBackend.client.rpc(
      'admin_review_listing',
      params: <String, dynamic>{
        'p_listing_id': listingId,
        'p_decision': decision,
        'p_note': note,
      },
    );
  }

  Future<void> resubmitListing(String listingId) async {
    await AppBackend.client.rpc(
      'resubmit_listing',
      params: <String, dynamic>{'p_listing_id': listingId},
    );
  }

  Future<void> setOwnerListingStatus(String listingId, String status) async {
    await AppBackend.client.rpc(
      'set_my_listing_status',
      params: <String, dynamic>{
        'p_listing_id': listingId,
        'p_status': status,
      },
    );
  }

  Future<void> reportListing({
    required String listingId,
    required String reason,
  }) async {
    final user = AppBackend.currentUser;
    if (user == null) throw AuthException('Sign in to report a listing.');
    await AppBackend.client.from('listing_reports').insert(<String, dynamic>{
      'listing_id': listingId,
      'reporter_id': user.id,
      'reason': reason,
    });
  }

  Future<String> createConversation(RentalListing listing) async {
    final response = await AppBackend.client.rpc(
      'get_or_create_conversation',
      params: <String, dynamic>{'p_listing_id': listing.id},
    );
    return response.toString();
  }

  Future<String?> getOwnerPhone(String listingId) async {
    final response = await AppBackend.client.rpc(
      'get_owner_contact_phone',
      params: <String, dynamic>{'p_listing_id': listingId},
    );
    if (response == null || response.toString().isEmpty) return null;
    return response.toString();
  }

  Future<List<Map<String, dynamic>>> getMyConversations() async {
    final user = AppBackend.currentUser;
    if (user == null) return const <Map<String, dynamic>>[];
    final rows = await AppBackend.client
        .from('conversations')
        .select('id, listing_id, listing_title, buyer_id, seller_id, last_message_at')
        .or('buyer_id.eq.${user.id},seller_id.eq.${user.id}')
        .order('last_message_at', ascending: false);

    final result = <Map<String, dynamic>>[];
    for (final raw in rows as List<dynamic>) {
      final thread = Map<String, dynamic>.from(raw as Map);
      final latest = await AppBackend.client
          .from('messages')
          .select('body, created_at, sender_id')
          .eq('conversation_id', thread['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      result.add(<String, dynamic>{...thread, 'latest_message': latest});
    }
    return result;
  }
}
