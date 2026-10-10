import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/data/controller.dart';
import 'package:danapur_marketplace/data/local_store.dart';
import 'package:danapur_marketplace/data/repository.dart';
import 'package:danapur_marketplace/data/seed.dart';
import 'package:danapur_marketplace/models/market.dart';

const shopDraft = ShopDraft(name: 'My Test Grocery', category: 'Grocery', area: 'Danapur Bazaar',
  address: 'Test street, Danapur', phone: '9999999999');
const productDraft = ProductDraft(name: 'Fresh test rice', category: 'Grocery', pricePaise: 7250, unit: '1 kg');
class FailingStore extends MemoryStore {
  @override
  Future<void> write(String key, String value) async => throw StateError('quota exceeded');
}
void main() {
  group('prices and validation', () {
    test('decimal rupees are converted to exact integer paise', () {
      expect(parsePrice('72.50'), 7250); expect(parsePrice('0.01'), 1);
      expect(parsePrice(' 999 '), 99900); expect(parsePrice('1000000'), 100000000);
      for (final invalid in ['', '0', '-2', '12.345', '1e3', 'NaN', '1000001', '₹99']) { expect(parsePrice(invalid), isNull, reason: invalid); }
    });
    test('Indian grouping and fractional display', () {
      expect(money(99900), '₹999'); expect(money(129900), '₹1,299');
      expect(money(12345678), '₹1,23,456.78'); expect(money(1), '₹0.01');
    });
    test('shop and product drafts reject invalid values', () {
      expect(shopDraft.validate, returnsNormally); expect(productDraft.validate, returnsNormally);
      expect(validatePhone('9999999999'), isNull); expect(validatePhone('1234567890'), isNotNull);
      expect(() => const ProductDraft(name: 'Rice', category: 'Grocery', pricePaise: -1).validate(), throwsA(isA<MarketException>()));
      expect(() => const ProductDraft(name: 'Rice', category: 'Grocery', pricePaise: 10000, mrpPaise: 9900).validate(), throwsA(isA<MarketException>()));
    });
    test('photos are bounded and cannot be SVG/HTML', () {
      expect(() => PickedPhoto.fromBytes(Uint8List.fromList(utf8.encode('<svg/>'))), throwsA(isA<MarketException>()));
      expect(() => PickedPhoto.fromBytes(Uint8List(PickedPhoto.maxBytes + 1)), throwsA(isA<MarketException>()));
      expect(PickedPhoto.fromBytes(Uint8List.fromList([0xff, 0xd8, 0xff, 0])).extension, 'jpeg');
    });
    test('contact message is encoded and examples have no real phone', () {
      final shop = Shop.fromJson({...shopDraft.toJson(), 'id': 'one', 'owner_id': 'owner', 'updated_at': DateTime.now().toIso8601String()});
      final uri = whatsappUri(shop);
      expect(uri.host, 'wa.me'); expect(uri.path, '/919999999999');
      expect(uri.queryParameters['text'], contains(shop.name));
      expect(() => whatsappUri(exampleMarket().shops.first), throwsA(isA<MarketException>()));
    });
  });
  group('catalogue filters', () {
    test('query matches product, category, shop and neighbourhood', () {
      final snapshot = exampleMarket();
      expect(filterProducts(snapshot, query: 'wireless').single.id, 'sample-earbuds');
      expect(filterProducts(snapshot, query: 'SAGUNA', category: 'Electronics').length, 2);
      expect(filterProducts(snapshot, query: 'sample daily needs').length, 3);
      expect(filterProducts(snapshot, area: 'Gola Road').single.category, 'Fashion');
      expect(filterProducts(snapshot, query: 'not-a-product'), isEmpty);
    });
    test('sort and saved IDs are deterministic', () {
      final snapshot = exampleMarket();
      expect(filterProducts(snapshot, sort: ProductSort.priceLow).first.id, 'sample-milk');
      expect(filterProducts(snapshot, sort: ProductSort.priceHigh).first.id, 'sample-watch');
      expect(filterProducts(snapshot, savedIds: {'sample-rice'}).single.id, 'sample-rice');
    });
  });
  group('local persistence and ownership', () {
    test('shop and product CRUD survive a new repository instance', () async {
      final store = MemoryStore(), repository = DemoRepository(MemoryStore());
      final repo = DemoRepository(store);
      final shop = await repo.saveShop(shopDraft);
      final product = await repo.saveProduct(shop.id, productDraft);
      final restored = await DemoRepository(store).load();
      expect(restored.shops.where((s) => s.id == shop.id).single.name, shopDraft.name);
      expect(restored.products.where((p) => p.id == product.id).single.pricePaise, 7250);
      final edited = await repo.saveProduct(shop.id, const ProductDraft(name: 'Fresh test rice', category: 'Grocery', pricePaise: 8000, isAvailable: false), id: product.id);
      expect(edited.isAvailable, false); expect(edited.pricePaise, 8000);
      await repo.deleteProduct(edited); expect((await repo.load()).products.any((p) => p.id == product.id), false);
      await repo.deleteShop(shop); expect((await repo.load()).shops.any((s) => s.id == shop.id), false);
      expect((await repository.load()).shops.length, 5);
    });
    test('cannot edit or delete sample/other-owner records', () async {
      final repo = DemoRepository(MemoryStore()); final initial = await repo.load();
      expect(() => repo.saveShop(shopDraft, id: initial.shops.first.id), throwsA(isA<MarketException>()));
      expect(() => repo.deleteProduct(initial.products.first), throwsA(isA<MarketException>()));
      expect(() => repo.deleteShop(initial.shops.first), throwsA(isA<MarketException>()));
    });
    test('one shop per owner and create-before-product is enforced', () async {
      final repo = DemoRepository(MemoryStore());
      expect(() => repo.saveProduct('missing', productDraft), throwsA(isA<MarketException>()));
      await repo.saveShop(shopDraft);
      expect(() => repo.saveShop(shopDraft), throwsA(isA<MarketException>()));
    });
    test('unpublishing removes the shop and products from discovery', () async {
      final repo = DemoRepository(MemoryStore()); final shop = await repo.saveShop(shopDraft);
      await repo.saveProduct(shop.id, productDraft);
      await repo.saveShop(const ShopDraft(name: 'My Test Grocery', category: 'Grocery', area: 'Danapur Bazaar', address: 'Test street, Danapur', phone: '9999999999', isPublished: false), id: shop.id);
      expect(filterProducts(await repo.load(), query: 'fresh test rice'), isEmpty);
    });
    test('failed local writes are not shown as successful listings', () async {
      final repo = DemoRepository(FailingStore());
      expect(() => repo.saveShop(shopDraft), throwsA(isA<MarketException>()));
      expect((await repo.load()).shops.length, 5);
    });
    test('corrupt data is not silently replaced and reset recovers it', () async {
      final store = MemoryStore(); await store.write(DemoRepository.storageKey, 'not-json');
      final repo = DemoRepository(store);
      expect(repo.load, throwsA(isA<MarketException>()));
      await repo.resetDemo(); expect((await repo.load()).shops.length, 5);
    });
    test('saved products persist separately from shop data', () async {
      final store = MemoryStore(); final controller = MarketController(DemoRepository(store), store);
      await controller.reload(); await controller.toggleSaved('sample-rice');
      final restored = MarketController(DemoRepository(store), store);
      expect(restored.savedIds, {'sample-rice'});
      await restored.toggleSaved('sample-rice'); expect(restored.savedIds, isEmpty);
      controller.dispose(); restored.dispose();
    });
  });
  group('backend configuration', () {
    test('demo is explicit; partial cloud config fails', () {
      expect(validateBackendConfig('', ''), isNull);
      expect(validateBackendConfig('https://example.supabase.co', ''), isNotNull);
      expect(validateBackendConfig('http://localhost:54321', 'public-key'), isNotNull);
      expect(validateBackendConfig('https://example.supabase.co', 'sb_publishable_example'), isNull);
    });
    test('service-role credentials cannot be embedded', () {
      final payload = base64Url.encode(utf8.encode('{"role":"service_role"}')).replaceAll('=', '');
      expect(validateBackendConfig('https://example.supabase.co', 'header.$payload.signature'), isNotNull);
      expect(validateBackendConfig('https://example.supabase.co', 'sb_secret_example'), isNotNull);
    });
  });
}
