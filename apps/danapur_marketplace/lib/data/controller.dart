import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/market.dart';
import 'local_store.dart';
import 'repository.dart';

class MarketController extends ChangeNotifier {
  MarketController(this.repository, this.store) {
    try { savedIds = (jsonDecode(store.read(savedKey) ?? '[]') as List).cast<String>().toSet(); }
    catch (_) { savedIds = {}; }
    _subscription = repository.authChanges.listen((_) { unawaited(reload()); });
  }
  final MarketRepository repository;
  final LocalStore store;
  static const savedKey = 'danapur.saved.v1';
  late Set<String> savedIds;
  MarketSnapshot snapshot = const MarketSnapshot();
  bool loading = false;
  String? error;
  int _generation = 0;
  Future<void> _savedQueue = Future.value();
  bool _disposed = false;
  StreamSubscription<void>? _subscription;
  bool get isDemo => repository.isDemo;
  String? get ownerId => repository.ownerId;
  Shop? get myShop => snapshot.shops.where((s) => s.ownerId == ownerId).firstOrNull;
  List<Shop> get publicShops => snapshot.shops.where((s) => s.isPublished).toList();
  Shop? visibleShop(String id) => snapshot.shops.where((s) => s.id == id && (s.isPublished || s.ownerId == ownerId)).firstOrNull;
  Product? visibleProduct(String id) => snapshot.products.where((p) => p.id == id && visibleShop(p.shopId) != null).firstOrNull;
  void _notify() { if (!_disposed) notifyListeners(); }
  Future<void> reload() async {
    final generation = ++_generation;
    loading = true; error = null; _notify();
    try {
      final data = await repository.load();
      if (!_disposed && generation == _generation) snapshot = data;
    } catch (e) {
      if (!_disposed && generation == _generation) error = friendlyError(e);
    } finally {
      if (!_disposed && generation == _generation) { loading = false; _notify(); }
    }
  }
  Future<void> toggleSaved(String id) {
    final result = _savedQueue.then((_) async {
      final next = {...savedIds};
      if (!next.remove(id)) next.add(id);
      try { await store.write(savedKey, jsonEncode(next.toList())); }
      catch (_) { throw const MarketException('Could not save favourites on this device.'); }
      savedIds = next; _notify();
    });
    _savedQueue = result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return result;
  }
  Future<Shop> saveShop(ShopDraft draft, {String? id}) async {
    final shop = await repository.saveShop(draft, id: id);
    _generation++; loading = false;
    snapshot = MarketSnapshot(shops: [...snapshot.shops.where((s) => s.id != shop.id), shop], products: snapshot.products);
    error = null; _notify(); return shop;
  }
  Future<Product> saveProduct(ProductDraft draft, {String? id, PickedPhoto? photo}) async {
    final shop = myShop;
    if (shop == null) throw const MarketException('Create your shop first.');
    final previous = id == null ? null : snapshot.products.where((p) => p.id == id).firstOrNull;
    String? uploaded;
    try {
      if (photo != null) uploaded = await repository.uploadPhoto(photo);
      final actual = ProductDraft(name: draft.name, category: draft.category,
        pricePaise: draft.pricePaise, mrpPaise: draft.mrpPaise,
        description: draft.description, unit: draft.unit,
        imageUrl: uploaded ?? draft.imageUrl, illustration: draft.illustration,
        isAvailable: draft.isAvailable);
      final product = await repository.saveProduct(shop.id, actual, id: id);
      _generation++; loading = false;
      snapshot = MarketSnapshot(shops: snapshot.shops, products: [...snapshot.products.where((p) => p.id != product.id), product]);
      error = null; _notify();
      if (previous?.imageUrl != product.imageUrl) await repository.removePhoto(previous?.imageUrl);
      return product;
    } catch (_) {
      if (uploaded != null) await repository.removePhoto(uploaded);
      rethrow;
    }
  }
  Future<void> deleteProduct(Product product) async {
    await repository.deleteProduct(product);
    _generation++; loading = false; error = null;
    snapshot = MarketSnapshot(shops: snapshot.shops, products: snapshot.products.where((p) => p.id != product.id).toList());
    _notify();
  }
  Future<void> deleteMyShop() async {
    final shop = myShop;
    if (shop == null) return;
    await repository.deleteShop(shop);
    _generation++; loading = false; error = null;
    snapshot = MarketSnapshot(shops: snapshot.shops.where((s) => s.id != shop.id).toList(), products: snapshot.products.where((p) => p.shopId != shop.id).toList());
    _notify();
  }
  Future<void> resetDemo() async {
    await repository.resetDemo(); await store.remove(savedKey); savedIds = {}; await reload();
  }
  @override
  void dispose() { _disposed = true; _generation++; unawaited(_subscription?.cancel()); super.dispose(); }
}

String? validateBackendConfig(String url, String key) {
  if (url.isEmpty && key.isEmpty) return null;
  if (url.isEmpty || key.isEmpty) return 'Set both DANAPUR_SUPABASE_URL and DANAPUR_SUPABASE_ANON_KEY, or leave both empty for demo mode.';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || ['localhost', '127.0.0.1', '::1', '[::1]'].contains(uri.host)) return 'Use a valid HTTPS Supabase project URL.';
  if (key.startsWith('sb_secret_')) return 'Never embed a Supabase secret/service-role key in this app. Use a publishable or anon key.';
  if (key.split('.').length == 3) {
    try {
      final body = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))));
      if (body is Map && body['role'] == 'service_role') return 'Never embed a service-role key. Use the public anon key.';
    } catch (_) { return 'The Supabase key is not a valid JWT. Use the public anon or publishable key.'; }
  }
  return null;
}
