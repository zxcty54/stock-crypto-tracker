import 'package:danapur_marketplace/core/config/backend_config.dart';
import 'support/repository.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/core/data/controller.dart';
import 'package:danapur_marketplace/core/data/local_store.dart';
import 'support/fixtures.dart';
import 'package:danapur_marketplace/core/domain/market.dart';

const shopDraft = ShopDraft(
  name: 'My Test Grocery',
  category: 'Grocery',
  area: 'Danapur Bazaar',
  address: 'Test street, Danapur',
  phone: '9999999999',
);
const productDraft = ProductDraft(
  name: 'Fresh test rice',
  category: 'Grocery',
  pricePaise: 7250,
  unit: '1 kg',
);

class FailingStore extends MemoryStore {
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('quota exceeded');
}

class DelayedStore extends MemoryStore {
  final pending = <Completer<void>>[];
  @override
  Future<void> write(String key, String value) async {
    final gate = Completer<void>();
    pending.add(gate);
    await gate.future;
    await super.write(key, value);
  }
}

class FailOnceStore extends MemoryStore {
  bool failed = false;
  @override
  Future<void> write(String key, String value) async {
    if (!failed) {
      failed = true;
      throw StateError('simulated write failure');
    }
    await super.write(key, value);
  }
}

void main() {
  group('prices and validation', () {
    test('decimal rupees are converted to exact integer paise', () {
      expect(parsePrice('72.50'), 7250);
      expect(parsePrice('0.01'), 1);
      expect(parsePrice(' 999 '), 99900);
      expect(parsePrice('1000000'), 100000000);
      for (final invalid in [
        '',
        '0',
        '-2',
        '12.345',
        '1e3',
        'NaN',
        '1000001',
        '₹99',
      ]) {
        expect(parsePrice(invalid), isNull, reason: invalid);
      }
    });
    test('Indian grouping and fractional display', () {
      expect(money(99900), '₹999');
      expect(money(129900), '₹1,299');
      expect(money(12345678), '₹1,23,456.78');
      expect(money(1), '₹0.01');
    });
    test('shop and product drafts reject invalid values', () {
      expect(shopDraft.validate, returnsNormally);
      expect(productDraft.validate, returnsNormally);
      expect(validatePhone('9999999999'), isNull);
      expect(validatePhone('1234567890'), isNotNull);
      expect(
        () => const ProductDraft(
          name: 'Rice',
          category: 'Grocery',
          pricePaise: -1,
        ).validate(),
        throwsA(isA<MarketException>()),
      );
      expect(
        () => const ProductDraft(
          name: 'Rice',
          category: 'Grocery',
          pricePaise: 10000,
          mrpPaise: 9900,
        ).validate(),
        throwsA(isA<MarketException>()),
      );
    });
    test('photos are bounded and cannot be SVG/HTML', () {
      expect(
        () => PickedPhoto.fromBytes(Uint8List.fromList(utf8.encode('<svg/>'))),
        throwsA(isA<MarketException>()),
      );
      expect(
        () => PickedPhoto.fromBytes(Uint8List(PickedPhoto.maxBytes + 1)),
        throwsA(isA<MarketException>()),
      );
      expect(
        PickedPhoto.fromBytes(
          Uint8List.fromList([0xff, 0xd8, 0xff, 0]),
        ).extension,
        'jpeg',
      );
    });
    test('contact message is encoded and examples have no real phone', () {
      final shop = Shop.fromJson({
        ...shopDraft.toJson(),
        'id': 'one',
        'owner_id': 'owner',
        'updated_at': DateTime.now().toIso8601String(),
      });
      final uri = whatsappUri(shop);
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919999999999');
      expect(uri.queryParameters['text'], contains(shop.name));
      expect(
        () => whatsappUri(exampleMarket().shops.first),
        throwsA(isA<MarketException>()),
      );
    });
  });
  group('catalogue filters', () {
    test('query matches product, category, shop and neighbourhood', () {
      final snapshot = exampleMarket();
      expect(
        filterProducts(snapshot, query: 'wireless').single.id,
        'sample-earbuds',
      );
      expect(
        filterProducts(
          snapshot,
          query: 'SAGUNA',
          category: 'Electronics',
        ).length,
        2,
      );
      expect(filterProducts(snapshot, query: 'sample daily needs').length, 3);
      expect(
        filterProducts(snapshot, area: 'Gola Road').single.category,
        'Fashion',
      );
      expect(filterProducts(snapshot, query: 'not-a-product'), isEmpty);
    });
    test('sort and saved IDs are deterministic', () {
      final snapshot = exampleMarket();
      expect(
        filterProducts(snapshot, sort: ProductSort.priceLow).first.id,
        'sample-milk',
      );
      expect(
        filterProducts(snapshot, sort: ProductSort.priceHigh).first.id,
        'sample-watch',
      );
      expect(
        filterProducts(snapshot, savedIds: {'sample-rice'}).single.id,
        'sample-rice',
      );
    });
  });
  group('local persistence and ownership', () {
    test('shop and product CRUD survive a new repository instance', () async {
      final store = MemoryStore(),
          repository = FixtureRepository(MemoryStore());
      final repo = FixtureRepository(store);
      final shop = await repo.saveShop(shopDraft);
      final product = await repo.saveProduct(shop.id, productDraft);
      final restored = await FixtureRepository(store).load();
      expect(
        restored.shops.where((s) => s.id == shop.id).single.name,
        shopDraft.name,
      );
      expect(
        restored.products.where((p) => p.id == product.id).single.pricePaise,
        7250,
      );
      final edited = await repo.saveProduct(
        shop.id,
        const ProductDraft(
          name: 'Fresh test rice',
          category: 'Grocery',
          pricePaise: 8000,
          isAvailable: false,
        ),
        id: product.id,
      );
      expect(edited.isAvailable, false);
      expect(edited.pricePaise, 8000);
      await repo.deleteProduct(edited);
      expect(
        (await repo.load()).products.any((p) => p.id == product.id),
        false,
      );
      await repo.deleteShop(shop);
      expect((await repo.load()).shops.any((s) => s.id == shop.id), false);
      expect((await repository.load()).shops.length, 5);
    });
    test('cannot edit or delete sample/other-owner records', () async {
      final repo = FixtureRepository(MemoryStore());
      final initial = await repo.load();
      expect(
        () => repo.saveShop(shopDraft, id: initial.shops.first.id),
        throwsA(isA<MarketException>()),
      );
      expect(
        () => repo.deleteProduct(initial.products.first),
        throwsA(isA<MarketException>()),
      );
      expect(
        () => repo.deleteShop(initial.shops.first),
        throwsA(isA<MarketException>()),
      );
    });
    test('one shop per owner and create-before-product is enforced', () async {
      final repo = FixtureRepository(MemoryStore());
      expect(
        () => repo.saveProduct('missing', productDraft),
        throwsA(isA<MarketException>()),
      );
      await repo.saveShop(shopDraft);
      expect(() => repo.saveShop(shopDraft), throwsA(isA<MarketException>()));
    });
    test('unpublishing removes the shop and products from discovery', () async {
      final repo = FixtureRepository(MemoryStore());
      final shop = await repo.saveShop(shopDraft);
      await repo.saveProduct(shop.id, productDraft);
      await repo.saveShop(
        const ShopDraft(
          name: 'My Test Grocery',
          category: 'Grocery',
          area: 'Danapur Bazaar',
          address: 'Test street, Danapur',
          phone: '9999999999',
          isPublished: false,
        ),
        id: shop.id,
      );
      expect(
        filterProducts(await repo.load(), query: 'fresh test rice'),
        isEmpty,
      );
    });
    test('failed local writes are not shown as successful listings', () async {
      final repo = FixtureRepository(FailingStore());
      expect(() => repo.saveShop(shopDraft), throwsA(isA<MarketException>()));
      expect((await repo.load()).shops.length, 5);
    });
    test(
      'corrupt data is not silently replaced and reset recovers it',
      () async {
        final store = MemoryStore();
        await store.write(FixtureRepository.storageKey, 'not-json');
        final repo = FixtureRepository(store);
        expect(repo.load, throwsA(isA<MarketException>()));
        await repo.resetDemo();
        expect((await repo.load()).shops.length, 5);
      },
    );
    test('saved products persist separately from shop data', () async {
      final store = MemoryStore();
      final controller = MarketController(FixtureRepository(store), store);
      await controller.reload();
      await controller.toggleSaved('sample-rice');
      final restored = MarketController(FixtureRepository(store), store);
      expect(restored.savedIds, {'sample-rice'});
      await restored.toggleSaved('sample-rice');
      expect(restored.savedIds, isEmpty);
      controller.dispose();
      restored.dispose();
    });
  });
  test('rapid favourite writes are serialized without lost updates', () async {
    final store = DelayedStore();
    final controller = MarketController(FixtureRepository(store), store);
    final first = controller.toggleSaved('sample-rice');
    final second = controller.toggleSaved('sample-earbuds');
    await Future<void>.delayed(Duration.zero);
    expect(store.pending.length, 1);
    expect(controller.savedIds, isEmpty);
    store.pending[0].complete();
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(store.pending.length, 2);
    expect(controller.savedIds, {'sample-rice'});
    store.pending[1].complete();
    await second;
    expect(controller.savedIds, {'sample-rice', 'sample-earbuds'});
    expect(
      (jsonDecode(store.read(MarketController.savedKey)!) as List).toSet(),
      controller.savedIds,
    );
    controller.dispose();
  });
  test('a failed favourite write does not poison the write queue', () async {
    final store = FailOnceStore();
    final controller = MarketController(FixtureRepository(store), store);
    await expectLater(
      controller.toggleSaved('sample-rice'),
      throwsA(isA<MarketException>()),
    );
    await controller.toggleSaved('sample-earbuds');
    expect(controller.savedIds, {'sample-earbuds'});
    controller.dispose();
  });
  group('backend configuration', () {
    test('demo is explicit; partial cloud config fails', () {
      expect(validateBackendConfig('', ''), isNotNull);
      expect(
        validateBackendConfig('https://example.supabase.co', ''),
        isNotNull,
      );
      expect(
        validateBackendConfig('http://localhost:54321', 'public-key'),
        isNotNull,
      );
      expect(
        validateBackendConfig(
          'https://example.supabase.co',
          'sb_publishable_example',
        ),
        isNull,
      );
    });
    test('legacy anon JWT is allowed but session/privileged roles are not', () {
      for (final role in [
        'anon',
        'authenticated',
        'postgres',
        'supabase_admin',
      ]) {
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'role': role})))
            .replaceAll('=', '');
        final error = validateBackendConfig(
          'https://example.supabase.co',
          'header.$payload.signature',
        );
        expect(error == null, role == 'anon');
      }
    });
    test('malformed and opaque keys fail rather than falling back to demo', () {
      final body = base64Url.encode(utf8.encode('[]')).replaceAll('=', '');
      for (final key in [
        'unknown-key',
        'sb_publishable_',
        'sb_publishable_has spaces',
        'header.$body.signature',
      ]) {
        expect(
          validateBackendConfig('https://example.supabase.co', key),
          isNotNull,
        );
      }
    });
    test('service-role credentials cannot be embedded', () {
      final payload = base64Url
          .encode(utf8.encode('{"role":"service_role"}'))
          .replaceAll('=', '');
      expect(
        validateBackendConfig(
          'https://example.supabase.co',
          'header.$payload.signature',
        ),
        isNotNull,
      );
      expect(
        validateBackendConfig(
          'https://example.supabase.co',
          'sb_secret_example',
        ),
        isNotNull,
      );
    });
  });
}
