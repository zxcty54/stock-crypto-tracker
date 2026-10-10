import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/market.dart';
import 'local_store.dart';
import 'seed.dart';

abstract interface class MarketRepository {
  bool get isDemo;
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
  Future<void> resetDemo();
}

class DemoRepository implements MarketRepository {
  DemoRepository(this.store);
  final LocalStore store;
  static const storageKey = 'danapur.market.v1';
  MarketSnapshot? _cache;
  @override
  bool get isDemo => true;
  @override
  String get ownerId => 'demo-owner';
  @override
  Stream<void> get authChanges => const Stream.empty();
  @override
  Future<MarketSnapshot> load() async {
    if (_cache != null) return _cache!;
    final raw = store.read(storageKey);
    if (raw == null) return _cache = exampleMarket();
    try {
      return _cache = MarketSnapshot.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      throw const MarketException('Local demo data could not be read. Use “Reset demo” to start again.');
    }
  }
  Future<void> _persist(MarketSnapshot snapshot) async {
    try { await store.write(storageKey, jsonEncode(snapshot.toJson())); }
    catch (_) { throw const MarketException('Could not save on this device. Try a smaller photo or free some browser storage.'); }
    _cache = snapshot;
  }
  @override
  Future<Shop> saveShop(ShopDraft draft, {String? id}) async {
    draft.validate();
    final current = await load();
    final owned = current.shops.where((s) => s.ownerId == ownerId).firstOrNull;
    if (id != null && (owned == null || owned.id != id)) throw const MarketException('You can only edit your own shop.');
    if (id == null && owned != null) throw const MarketException('You already have a shop. Edit it instead.');
    final shop = Shop.fromJson({...draft.toJson(), 'id': id ?? const Uuid().v4(),
      'owner_id': ownerId, 'updated_at': DateTime.now().toUtc().toIso8601String()});
    await _persist(MarketSnapshot(shops: [...current.shops.where((s) => s.id != shop.id), shop], products: current.products));
    return shop;
  }
  @override
  Future<Product> saveProduct(String shopId, ProductDraft draft, {String? id}) async {
    draft.validate();
    final current = await load();
    if (!current.shops.any((s) => s.id == shopId && s.ownerId == ownerId)) throw const MarketException('Create your shop before adding products.');
    if (id != null && !current.products.any((p) => p.id == id && p.shopId == shopId)) throw const MarketException('You can only edit your own products.');
    final product = Product.fromJson({...draft.toJson(), 'id': id ?? const Uuid().v4(),
      'shop_id': shopId, 'updated_at': DateTime.now().toUtc().toIso8601String()});
    await _persist(MarketSnapshot(shops: current.shops, products: [...current.products.where((p) => p.id != product.id), product]));
    return product;
  }
  @override
  Future<void> deleteProduct(Product product) async {
    final current = await load();
    if (!current.shops.any((s) => s.id == product.shopId && s.ownerId == ownerId)) throw const MarketException('You can only delete your own products.');
    await _persist(MarketSnapshot(shops: current.shops, products: current.products.where((p) => p.id != product.id).toList()));
  }
  @override
  Future<void> deleteShop(Shop shop) async {
    if (shop.ownerId != ownerId) throw const MarketException('You can only delete your own shop.');
    final current = await load();
    await _persist(MarketSnapshot(shops: current.shops.where((s) => s.id != shop.id).toList(), products: current.products.where((p) => p.shopId != shop.id).toList()));
  }
  @override
  Future<String> uploadPhoto(PickedPhoto photo) async => 'data:image/${photo.extension};base64,${base64Encode(photo.bytes)}';
  @override
  Future<void> removePhoto(String? url) async {}
  @override
  Future<bool> signUp(String email, String password) async => false;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> resetDemo() async { await store.remove(storageKey); _cache = null; }
}

class SupabaseMarketRepository implements MarketRepository {
  SupabaseMarketRepository(this.client);
  final SupabaseClient client;
  @override
  bool get isDemo => false;
  @override
  String? get ownerId => client.auth.currentUser?.id;
  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});
  String get _owner => ownerId ?? (throw const MarketException('Sign in to manage your shop.'));
  Future<List<Map<String, dynamic>>> _allRows(String table) async {
    final rows = <Map<String, dynamic>>[];
    const batchSize = 500;
    while (true) {
      final batch = await client.from(table).select().order('id').range(rows.length, rows.length + batchSize - 1);
      rows.addAll(batch);
      if (batch.length < batchSize) return rows;
    }
  }
  @override
  Future<MarketSnapshot> load() async {
    final results = await Future.wait([_allRows('shops'), _allRows('products')]);
    return MarketSnapshot(shops: results[0].map(Shop.fromJson).toList(), products: results[1].map(Product.fromJson).toList());
  }
  @override
  Future<Shop> saveShop(ShopDraft draft, {String? id}) async {
    draft.validate();
    final data = {...draft.toJson(), 'owner_id': _owner};
    final row = id == null
      ? await client.from('shops').insert(data).select().single()
      : await client.from('shops').update(data).eq('id', id).eq('owner_id', _owner).select().single();
    return Shop.fromJson(row);
  }
  @override
  Future<Product> saveProduct(String shopId, ProductDraft draft, {String? id}) async {
    draft.validate();
    await client.from('shops').select('id').eq('id', shopId).eq('owner_id', _owner).single();
    final data = {...draft.toJson(), 'shop_id': shopId};
    final row = id == null
      ? await client.from('products').insert(data).select().single()
      : await client.from('products').update(data).eq('id', id).eq('shop_id', shopId).select().single();
    return Product.fromJson(row);
  }
  @override
  Future<void> deleteProduct(Product product) async {
    await client.from('shops').select('id').eq('id', product.shopId).eq('owner_id', _owner).single();
    final rows = await client.from('products').delete().eq('id', product.id).eq('shop_id', product.shopId).select('id');
    if (rows.isEmpty) throw const MarketException('Product was not found or is not yours.');
    await removePhoto(product.imageUrl);
  }
  @override
  Future<void> deleteShop(Shop shop) async {
    final photos = await client.from('products').select('image_url').eq('shop_id', shop.id);
    final rows = await client.from('shops').delete().eq('id', shop.id).eq('owner_id', _owner).select('id');
    if (rows.isEmpty) throw const MarketException('Shop was not found or is not yours.');
    for (final row in photos) { await removePhoto(row['image_url'] as String?); }
  }
  @override
  Future<String> uploadPhoto(PickedPhoto photo) async {
    final path = '$_owner/${const Uuid().v4()}.${photo.extension}';
    await client.storage.from('catalog-media').uploadBinary(path, photo.bytes,
      fileOptions: FileOptions(contentType: 'image/${photo.extension}', upsert: false));
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
    try { await client.storage.from('catalog-media').remove([path]); } catch (_) {}
  }
  @override
  Future<bool> signUp(String email, String password) async {
    final result = await client.auth.signUp(email: email.trim(), password: password);
    return result.session == null;
  }
  @override
  Future<void> signIn(String email, String password) async { await client.auth.signInWithPassword(email: email.trim(), password: password); }
  @override
  Future<void> signOut() => client.auth.signOut();
  @override
  Future<void> resetDemo() async { throw const MarketException('Reset is available only in demo mode.'); }
}

String friendlyError(Object error) {
  if (error is MarketException) return error.message;
  if (error is AuthException) return error.message;
  return 'Could not complete this request. Check your connection and try again.';
}
