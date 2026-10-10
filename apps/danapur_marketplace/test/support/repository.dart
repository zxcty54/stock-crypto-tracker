import '../../lib/features/mandi/domain/mandi.dart';
import '../../lib/features/admin/domain/administration.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../lib/core/domain/market.dart';
import '../../lib/core/data/local_store.dart';
import '../../lib/core/data/repository.dart';
import 'fixtures.dart';

class FixtureRepository extends MarketRepository {
  FixtureRepository(
    this.store, {
    this.staff = false,
    this.commodities = const [],
    this.rates = const [],
    this.settings = const MarketSettings(),
  });
  final bool staff;
  final List<MandiItem> commodities;
  final List<MandiRate> rates;
  final MarketSettings settings;
  MarketSnapshot _extras(MarketSnapshot snapshot) => MarketSnapshot(
    shops: snapshot.shops,
    products: snapshot.products,
    isAdmin: staff,
    mandiItems: commodities,
    mandiRates: rates,
    settings: settings,
  );
  final LocalStore store;
  static const storageKey = 'danapur.market.v1';
  MarketSnapshot? _cache;

  @override
  String get ownerId => 'demo-owner';
  @override
  Stream<void> get authChanges => const Stream.empty();
  @override
  Future<MarketSnapshot> load() async {
    if (_cache != null) return _extras(_cache!);
    final raw = store.read(storageKey);
    if (raw == null) {
      _cache = exampleMarket();
      return _extras(_cache!);
    }
    try {
      _cache = MarketSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return _extras(_cache!);
    } catch (_) {
      throw const MarketException(
        'Local demo data could not be read. Use “Reset demo” to start again.',
      );
    }
  }

  Future<void> _persist(MarketSnapshot snapshot) async {
    try {
      await store.write(storageKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      throw const MarketException(
        'Could not save on this device. Try a smaller photo or free some browser storage.',
      );
    }
    _cache = snapshot;
  }

  @override
  Future<Shop> saveShop(ShopDraft draft, {String? id}) async {
    draft.validate();
    final current = await load();
    final owned = current.shops.where((s) => s.ownerId == ownerId).firstOrNull;
    if (id != null && (owned == null || owned.id != id)) {
      throw const MarketException('You can only edit your own shop.');
    }
    if (id == null && owned != null) {
      throw const MarketException('You already have a shop. Edit it instead.');
    }
    final shop = Shop.fromJson({
      ...draft.toJson(),
      'id': id ?? const Uuid().v4(),
      'owner_id': ownerId,
      'review_status': 'approved',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _persist(
      MarketSnapshot(
        shops: [...current.shops.where((s) => s.id != shop.id), shop],
        products: current.products,
      ),
    );
    return shop;
  }

  @override
  Future<Product> saveProduct(
    String shopId,
    ProductDraft draft, {
    String? id,
  }) async {
    draft.validate();
    final current = await load();
    if (!current.shops.any((s) => s.id == shopId && s.ownerId == ownerId)) {
      throw const MarketException('Create your shop before adding products.');
    }
    if (id != null &&
        !current.products.any((p) => p.id == id && p.shopId == shopId)) {
      throw const MarketException('You can only edit your own products.');
    }
    final product = Product.fromJson({
      ...draft.toJson(),
      'id': id ?? const Uuid().v4(),
      'shop_id': shopId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _persist(
      MarketSnapshot(
        shops: current.shops,
        products: [
          ...current.products.where((p) => p.id != product.id),
          product,
        ],
      ),
    );
    return product;
  }

  @override
  Future<void> deleteProduct(Product product) async {
    final current = await load();
    if (!current.shops.any(
      (s) => s.id == product.shopId && s.ownerId == ownerId,
    )) {
      throw const MarketException('You can only delete your own products.');
    }
    await _persist(
      MarketSnapshot(
        shops: current.shops,
        products: current.products.where((p) => p.id != product.id).toList(),
      ),
    );
  }

  @override
  Future<void> deleteShop(Shop shop) async {
    if (shop.ownerId != ownerId) {
      throw const MarketException('You can only delete your own shop.');
    }
    final current = await load();
    await _persist(
      MarketSnapshot(
        shops: current.shops.where((s) => s.id != shop.id).toList(),
        products: current.products.where((p) => p.shopId != shop.id).toList(),
      ),
    );
  }

  @override
  Future<String> uploadPhoto(PickedPhoto photo) async =>
      'data:image/${photo.extension};base64,${base64Encode(photo.bytes)}';
  @override
  Future<void> removePhoto(String? url) async {}
  @override
  Future<bool> signUp(String email, String password) async => false;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  Future<void> resetDemo() async {
    await store.remove(storageKey);
    _cache = null;
  }
}
