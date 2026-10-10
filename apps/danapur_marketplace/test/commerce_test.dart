import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/core/data/local_store.dart';
import 'package:danapur_marketplace/core/domain/market.dart';
import 'package:danapur_marketplace/features/orders/domain/commerce.dart';
import 'package:danapur_marketplace/features/samples/data/sample_repository.dart';
import 'package:danapur_marketplace/features/samples/data/sample_catalogue.dart';

void main() {
  test(
    'haversine measures zero and distinguishes 499 and 501 metre boundaries',
    () {
      expect(distanceMetres(25, 85, 25, 85), 0);
      final d = distanceMetres(25, 85, 25 + 499 / 111194.92664455874, 85);
      expect(d, closeTo(499, 0.02));
      expect(
        distanceMetres(25, 85, 25 + 501 / 111194.92664455874, 85),
        greaterThan(500),
      );
    },
  );
  test(
    'delivery quote includes shop base plus per-unit handling and discounts',
    () {
      final data = sampleCatalogue(), shop = data.shops.first;
      final fix = GeoFix(
        shop.latitude!,
        shop.longitude!,
        measuredAt: DateTime.now(),
      );
      final quote = quoteCart(
        data,
        const [CartLine('sample-rice', 2), CartLine('sample-oil', 1)],
        'delivery',
        fix,
      );
      expect(quote.subtotal, 31000);
      expect(quote.discount, 2000);
      expect(quote.delivery, 2500);
      expect(quote.total, 31500);
    },
  );
  test('bulky goods can only be picked up', () {
    final data = sampleCatalogue(), shop = data.shops.first;
    final fix = GeoFix(
      shop.latitude!,
      shop.longitude!,
      measuredAt: DateTime.now(),
    );
    expect(
      () =>
          quoteCart(data, const [CartLine('sample-bulk', 1)], 'delivery', fix),
      throwsA(isA<MarketException>()),
    );
    expect(
      quoteCart(
        data,
        const [CartLine('sample-bulk', 1)],
        'pickup',
        null,
      ).delivery,
      0,
    );
  });
  test(
    'outside radius or imprecise/stale GPS does not enable COD delivery',
    () {
      final data = sampleCatalogue(), shop = data.shops.first;
      for (final fix in [
        GeoFix(
          shop.latitude! + 0.01,
          shop.longitude!,
          measuredAt: DateTime.now(),
        ),
        GeoFix(
          shop.latitude!,
          shop.longitude!,
          accuracy: 100,
          measuredAt: DateTime.now(),
        ),
        GeoFix(
          shop.latitude!,
          shop.longitude!,
          measuredAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ]) {
        expect(
          () => quoteCart(
            data,
            const [CartLine('sample-rice', 1)],
            'delivery',
            fix,
          ),
          throwsA(isA<MarketException>()),
        );
      }
    },
  );
  test('closed shops and mixed-shop carts cannot check out', () {
    final data = sampleCatalogue();
    final closed = Shop.fromJson({
      ...data.shops.first.toJson(),
      'is_open': false,
    });
    expect(
      () => quoteCart(
        data.copyWith(shops: [closed]),
        const [CartLine('sample-rice', 1)],
        'pickup',
        null,
      ),
      throwsA(isA<MarketException>()),
    );
    expect(
      () => quoteCart(
        data,
        const [CartLine('sample-rice', 1), CartLine('sample-shirt', 1)],
        'pickup',
        null,
      ),
      throwsA(isA<MarketException>()),
    );
  });
  test('discount amounts and percentages use integer paise', () {
    expect(discountFromInput('10', 10000), 1000);
    expect(discountFromInput('12.50', 10000, percent: true), 1250);
    expect(discountFromInput('50', 99, percent: true), 49);
    expect(discountFromInput('100', 10000, percent: true), isNull);
    expect(discountFromInput('100.00', 10000), isNull);
    expect(parseCharge('0'), 0);
  });
  test('category sorting uses discounted selling price', () {
    final data = sampleCatalogue();
    final list = filterProducts(
      data,
      category: 'Grocery',
      sort: ProductSort.priceLow,
    );
    expect(list.first.id, 'sample-rice');
    expect(list.first.sellingPaise, 7500);
  });
  test('shop and product delivery configuration survives JSON', () {
    final data = sampleCatalogue();
    final shop = Shop.fromJson(data.shops.first.toJson()),
        product = Product.fromJson(data.products.first.toJson());
    expect(shop.offersDelivery, true);
    expect(shop.deliveryBasePaise, 2000);
    expect(product.deliveryAllowed, true);
    expect(product.discountPaise, 500);
  });
  test('no local test credentials or online payments are simulated', () async {
    final repo = SampleRepository(MemoryStore());
    expect(repo.sampleProfilesEnabled, true);
    await expectLater(
      repo.signIn('user@example.test', 'not-a-real-password'),
      throwsA(isA<MarketException>()),
    );
  });
  test(
    'buyer and seller can close orders once; buyer expense is private',
    () async {
      final store = MemoryStore(), repo = SampleRepository(MemoryStore());
      final local = SampleRepository(store);
      final id = await local.placeCashOrder(
        'sample-grocery',
        const [CartLine('sample-rice', 2)],
        'pickup',
        'Test buyer',
        '9999999999',
        'Pickup at sample shop',
        null,
        'test-request',
      );
      var data = await local.load();
      expect(data.orders.single.totalPaise, 15000);
      expect(data.expenses, isEmpty);
      await local.useSampleProfile('seller');
      data = await local.load();
      expect(data.orders.single.id, id);
      await local.changeOrder(
        data.orders.single,
        'completed',
        'Seller handed over goods',
      );
      await local.changeOrder(
        data.orders.single,
        'completed',
        'Repeated confirmation',
      );
      expect((await local.load()).expenses, isEmpty);
      await local.useSampleProfile('buyer');
      data = await local.load();
      expect(data.expenses.single.amountPaise, 15000);
      expect(data.expenses.single.orderId, id);
      final restored = SampleRepository(store);
      expect((await restored.load()).orders.single.status, 'completed');
      expect((await restored.load()).expenses, hasLength(1));
      await expectLater(
        restored.changeOrder(
          (await restored.load()).orders.single,
          'cancelled',
          'Trying to undo',
        ),
        throwsA(isA<MarketException>()),
      );
      expect((await repo.load()).orders, isEmpty);
    },
  );
  test('cancelled orders do not add spending', () async {
    final repo = SampleRepository(MemoryStore());
    await repo.placeCashOrder(
      'sample-grocery',
      const [CartLine('sample-rice', 1)],
      'pickup',
      'Test buyer',
      '9999999999',
      'Pickup at sample shop',
      null,
      'request',
    );
    final order = (await repo.load()).orders.single;
    await repo.changeOrder(order, 'cancelled', 'Buyer changed mind');
    expect((await repo.load()).expenses, isEmpty);
  });
  test(
    'manual expenses can be changed but another test profile cannot see them',
    () async {
      final repo = SampleRepository(MemoryStore());
      await repo.saveExpense(
        null,
        5500,
        'Travel',
        'Test bus fare',
        DateTime(2026, 1, 1),
      );
      var e = (await repo.load()).expenses.single;
      await repo.saveExpense(
        e.id,
        6500,
        'Travel',
        'Corrected test entry',
        DateTime(2026, 1, 1),
      );
      e = (await repo.load()).expenses.single;
      expect(e.amountPaise, 6500);
      await repo.useSampleProfile('seller');
      expect((await repo.load()).expenses, isEmpty);
      await expectLater(repo.deleteExpense(e), throwsA(isA<MarketException>()));
      await repo.useSampleProfile('buyer');
      await repo.deleteExpense(e);
      expect((await repo.load()).expenses, isEmpty);
    },
  );
  test(
    'membership defaults off; buyer cannot enable monetization or remove samples',
    () async {
      final repo = SampleRepository(MemoryStore());
      expect((await repo.load()).settings.billingEnabled, false);
      await expectLater(
        repo.configureBilling(true),
        throwsA(isA<MarketException>()),
      );
      await expectLater(
        repo.removeSampleData(),
        throwsA(isA<MarketException>()),
      );
      await repo.useSampleProfile('admin');
      await repo.configureBilling(true);
      expect((await repo.load()).settings.billingEnabled, true);
      await repo.removeSampleData();
      expect((await repo.load()).shops, isEmpty);
      await repo.restoreSampleData();
      expect((await repo.load()).shops, isNotEmpty);
    },
  );
}
