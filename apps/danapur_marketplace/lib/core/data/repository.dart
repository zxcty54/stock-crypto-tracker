import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/market.dart';
import 'package:flutter/foundation.dart';
import '../../features/mandi/domain/mandi.dart';
import '../../features/admin/domain/administration.dart';

abstract class MarketRepository {
  String? get ownerId;
  Stream<void> get authChanges;
  Future<MarketSnapshot> load();
  Future<Shop> saveShop(ShopDraft draft, {String? id});
  Future<Product> saveProduct(String shopId, ProductDraft draft, {String? id});
  Future<void> deleteProduct(Product product);
  Future<void> deleteShop(Shop shop);
  Future<String> uploadPhoto(PickedPhoto photo);
  Future<void> removePhoto(String? url);
  Future<bool> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  bool get needsPasswordUpdate => false;
  Future<String> uploadVerificationPhoto(PickedPhoto photo) async =>
      throw const MarketException('Verification upload is unavailable.');
  Future<void> removeVerificationPhoto(String path) async {}
  Future<String> verificationPhotoUrl(String path) async =>
      throw const MarketException('Sign in to view proof.');
  Future<void> reviewShop(
    String id,
    String decision,
    String note,
    bool whatsappChecked,
  ) async => throw const MarketException('Administrator access required.');
  Future<void> setMandiRate(
    MandiItem item,
    String type,
    String unit,
    int minPaise,
    int maxPaise,
    DateTime date,
    String note,
  ) async => throw const MarketException('Administrator access required.');
  Future<void> setSettings(MarketSettings settings) async =>
      throw const MarketException('Administrator access required.');
  Future<void> addMandiItem(
    String id,
    String name,
    String hindi,
    String category,
    String unit,
  ) async => throw const MarketException('Administrator access required.');
  Future<void> requestPasswordReset(String email) async =>
      throw const MarketException('Password reset is unavailable.');
  Future<void> updatePassword(String password) async =>
      throw const MarketException('Password update is unavailable.');
  Future<void> deleteAccount() async =>
      throw const MarketException('Account deletion is unavailable.');
}

class SupabaseMarketRepository extends MarketRepository {
  SupabaseMarketRepository(this.client);
  final SupabaseClient client;
  bool _passwordRecovery = false;
  @override
  bool get needsPasswordUpdate => _passwordRecovery;
  @override
  String? get ownerId => client.auth.currentUser?.id;
  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((state) {
    if (state.event == AuthChangeEvent.passwordRecovery)
      _passwordRecovery = true;
    if (state.event == AuthChangeEvent.signedOut) _passwordRecovery = false;
  });
  String get _owner =>
      ownerId ?? (throw const MarketException('Sign in to manage your shop.'));
  Future<List<Map<String, dynamic>>> _allRows(String table) async {
    final rows = <Map<String, dynamic>>[];
    const batchSize = 500;
    while (true) {
      final batch = await client
          .from(table)
          .select()
          .order('id')
          .range(rows.length, rows.length + batchSize - 1);
      rows.addAll(batch);
      if (batch.length < batchSize) return rows;
    }
  }

  @override
  Future<MarketSnapshot> load() async {
    final admin =
        ownerId != null && await client.rpc('is_market_admin') == true;
    final results = await Future.wait([
      _allRows('shops'),
      _allRows('products'),
      _allRows('mandi_items'),
      _allRows('current_mandi_rates'),
      _allRows('market_settings'),
    ]);
    return MarketSnapshot(
      shops: results[0].map(Shop.fromJson).toList(),
      products: results[1].map(Product.fromJson).toList(),
      mandiItems: results[2].map(MandiItem.fromJson).toList(),
      mandiRates: results[3].map(MandiRate.fromJson).toList(),
      settings: results[4].isEmpty
          ? const MarketSettings()
          : MarketSettings.fromJson(results[4].first),
      isAdmin: admin,
      audit: admin
          ? (await client
                    .from('market_audit')
                    .select()
                    .order('created_at', ascending: false)
                    .limit(50))
                .map(AuditEntry.fromJson)
                .toList()
          : const [],
    );
  }

  @override
  Future<Shop> saveShop(ShopDraft draft, {String? id}) async {
    draft.validate();
    if (id == null && draft.verificationPhotoPath == null)
      throw const MarketException(
        'Upload a current storefront photo before submitting your shop.',
      );
    final data = {...draft.toJson(), 'owner_id': _owner};
    final row = id == null
        ? await client.from('shops').insert(data).select().single()
        : await client
              .from('shops')
              .update(data)
              .eq('id', id)
              .eq('owner_id', _owner)
              .select()
              .single();
    return Shop.fromJson(row);
  }

  @override
  Future<Product> saveProduct(
    String shopId,
    ProductDraft draft, {
    String? id,
  }) async {
    draft.validate();
    await client
        .from('shops')
        .select('id')
        .eq('id', shopId)
        .eq('owner_id', _owner)
        .single();
    final data = {...draft.toJson(), 'shop_id': shopId};
    final row = id == null
        ? await client.from('products').insert(data).select().single()
        : await client
              .from('products')
              .update(data)
              .eq('id', id)
              .eq('shop_id', shopId)
              .select()
              .single();
    return Product.fromJson(row);
  }

  @override
  Future<void> deleteProduct(Product product) async {
    await client
        .from('shops')
        .select('id')
        .eq('id', product.shopId)
        .eq('owner_id', _owner)
        .single();
    final rows = await client
        .from('products')
        .delete()
        .eq('id', product.id)
        .eq('shop_id', product.shopId)
        .select('id');
    if (rows.isEmpty) {
      throw const MarketException('Product was not found or is not yours.');
    }
    await removePhoto(product.imageUrl);
  }

  @override
  Future<void> deleteShop(Shop shop) async {
    final photos = await client
        .from('products')
        .select('image_url')
        .eq('shop_id', shop.id);
    final rows = await client
        .from('shops')
        .delete()
        .eq('id', shop.id)
        .eq('owner_id', _owner)
        .select('id');
    if (rows.isEmpty) {
      throw const MarketException('Shop was not found or is not yours.');
    }
    if (shop.verificationPhotoPath != null)
      await removeVerificationPhoto(shop.verificationPhotoPath!);
    for (final row in photos) {
      await removePhoto(row['image_url'] as String?);
    }
  }

  @override
  Future<String> uploadPhoto(PickedPhoto photo) async {
    final path = '$_owner/${const Uuid().v4()}.${photo.extension}';
    await client.storage
        .from('catalog-media')
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(
            contentType: 'image/${photo.extension}',
            upsert: false,
          ),
        );
    return client.storage.from('catalog-media').getPublicUrl(path);
  }

  @override
  Future<void> removePhoto(String? url) async {
    if (url == null || ownerId == null) return;
    final base = client.storage.from('catalog-media').getPublicUrl('');
    if (!url.startsWith(base)) return;
    final path = Uri.decodeComponent(url.substring(base.length));
    if (!path.startsWith('$ownerId/')) return;
    // Database writes are already committed. Cleanup is best-effort, never
    // turn a successful deletion into a misleading failed-save message.
    try {
      await client.storage.from('catalog-media').remove([path]);
    } catch (_) {}
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final result = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _authRedirect,
    );
    return result.session == null;
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  String get _authRedirect {
    const configured = String.fromEnvironment('DANAPUR_AUTH_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    return kIsWeb
        ? Uri.base.replace(path: '/', query: '', fragment: '').toString()
        : 'in.danapur.bazaar://auth-callback';
  }

  @override
  Future<String> uploadVerificationPhoto(PickedPhoto photo) async {
    final path = '$_owner/${const Uuid().v4()}.${photo.extension}';
    await client.storage
        .from('shop-verification')
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(
            contentType: 'image/${photo.extension}',
            upsert: false,
          ),
        );
    return path;
  }

  @override
  Future<void> removeVerificationPhoto(String path) async {
    if (!path.startsWith('$ownerId/')) return;
    try {
      await client.storage.from('shop-verification').remove([path]);
    } catch (_) {}
  }

  @override
  Future<String> verificationPhotoUrl(String path) =>
      client.storage.from('shop-verification').createSignedUrl(path, 300);
  @override
  Future<void> reviewShop(
    String id,
    String decision,
    String note,
    bool whatsappChecked,
  ) async {
    await client.rpc(
      'review_market_shop',
      params: {
        'p_shop_id': id,
        'p_decision': decision,
        'p_note': note.trim(),
        'p_whatsapp_checked': whatsappChecked,
      },
    );
  }

  @override
  Future<void> setMandiRate(
    MandiItem item,
    String type,
    String unit,
    int minPaise,
    int maxPaise,
    DateTime date,
    String note,
  ) async {
    await client.rpc(
      'set_mandi_rate',
      params: {
        'p_item_id': item.id,
        'p_price_type': type,
        'p_unit': unit,
        'p_min_paise': minPaise,
        'p_max_paise': maxPaise,
        'p_effective_date': mandiDateKey(date),
        'p_note': note.trim(),
      },
    );
  }

  @override
  Future<void> setSettings(MarketSettings settings) async {
    await client.rpc(
      'set_market_settings',
      params: {
        'p_phone': settings.verificationPhone,
        'p_email': settings.supportEmail,
        'p_privacy_url': settings.privacyUrl,
        'p_terms_url': settings.termsUrl,
        'p_mandi_name': settings.mandiName,
      },
    );
  }

  @override
  Future<void> addMandiItem(
    String id,
    String name,
    String hindi,
    String category,
    String unit,
  ) async {
    await client.rpc(
      'add_mandi_item',
      params: {
        'p_id': id,
        'p_name': name.trim(),
        'p_hindi': hindi.trim(),
        'p_category': category,
        'p_unit': unit,
      },
    );
  }

  @override
  Future<void> requestPasswordReset(String email) => client.auth
      .resetPasswordForEmail(email.trim(), redirectTo: _authRedirect);
  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
    _passwordRecovery = false;
  }

  @override
  Future<void> deleteAccount() async {
    if (await client.rpc('can_delete_market_account') != true)
      throw const MarketException(
        'Create another administrator before deleting the last admin account.',
      );
    final own = await client
        .from('shops')
        .select()
        .eq('owner_id', _owner)
        .maybeSingle();
    if (own != null) await deleteShop(Shop.fromJson(own));
    await client.rpc('delete_market_account');
    await client.auth.signOut();
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}

String friendlyError(Object error) {
  if (error is MarketException) return error.message;
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '42501')
      return 'This account is not permitted to perform that action.';
    if (error.code == 'PGRST205' || error.code == '42P01')
      return 'The Supabase database is not installed. Run the documented migrations and catalogue seed, then refresh.';
    if (error.code == '23505')
      return 'That shop or commodity already exists. Edit the existing record instead.';
    if (error.code == 'P0001') return error.message;
  }
  return 'Could not complete this request. Check your connection and try again.';
}
