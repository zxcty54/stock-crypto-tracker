import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/core/data/local_store.dart';
import 'package:danapur_marketplace/core/domain/market.dart';
import 'package:danapur_marketplace/features/reviews/domain/order_review.dart';
import 'package:danapur_marketplace/features/orders/domain/commerce.dart';
import 'package:danapur_marketplace/features/samples/data/sample_repository.dart';

CashOrder order(String status) => CashOrder(
  id: 'order',
  buyerId: 'buyer',
  sellerId: 'seller',
  shopId: 'shop',
  shopName: 'Test shop',
  shopCategory: 'Grocery',
  customerName: 'Private name',
  phone: '9999999999',
  address: 'Private address',
  fulfilment: 'pickup',
  subtotalPaise: 1000,
  discountPaise: 0,
  deliveryPaise: 0,
  totalPaise: 1000,
  status: status,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('feedback is unavailable for every non-completed order status', () {
    for (final status in ['placed', 'accepted', 'ready', 'cancelled']) {
      expect(canLeaveOrderReview(order(status), 'buyer', const []), false);
    }
  });
  test('only the completed-order buyer gets the feedback action', () {
    expect(canLeaveOrderReview(order('completed'), 'buyer', const []), true);
    expect(canLeaveOrderReview(order('completed'), 'seller', const []), false);
    expect(
      canLeaveOrderReview(order('completed'), 'outsider', const []),
      false,
    );
    expect(canLeaveOrderReview(order('completed'), null, const []), false);
  });
  test('one order review stays one even while hidden or pending', () {
    for (final status in ['pending', 'published', 'hidden']) {
      final review = OrderReview(
        id: 'review',
        orderId: 'order',
        buyerId: 'buyer',
        shopId: 'shop',
        rating: 1,
        comment: 'Negative feedback',
        status: status,
        createdAt: DateTime.utc(2026),
      );
      expect(canLeaveOrderReview(order('completed'), 'buyer', [review]), false);
    }
  });
  test('rating and Unicode comment limits are validated', () {
    for (final rating in [1, 2, 3, 4, 5]) {
      validateOrderReview(rating, '');
    }
    expect(() => validateOrderReview(0, ''), throwsA(isA<MarketException>()));
    expect(() => validateOrderReview(6, ''), throwsA(isA<MarketException>()));
    validateOrderReview(5, List.filled(500, 'अ').join());
    expect(
      () => validateOrderReview(5, List.filled(501, 'अ').join()),
      throwsA(isA<MarketException>()),
    );
  });
  test('public projection omits buyer/order IDs and moderation reason', () {
    final review = OrderReview(
      id: 'review',
      orderId: 'private-order',
      buyerId: 'private-buyer',
      shopId: 'shop',
      rating: 2,
      comment: 'Public feedback',
      status: 'published',
      moderationNote: 'Private reason',
      createdAt: DateTime.utc(2026),
    );
    final safe = review.publicProjection();
    expect(safe.orderId, isNull);
    expect(safe.buyerId, isNull);
    expect(safe.moderationNote, isEmpty);
    expect(safe.rating, 2);
  });
  test(
    'sample backend also rejects early, cancelled and other-party feedback',
    () async {
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
      var row = (await repo.load()).orders.single;
      await expectLater(
        repo.submitOrderReview(row, 5, 'Too early'),
        throwsA(isA<MarketException>()),
      );
      await repo.changeOrder(row, 'cancelled', 'Buyer cancelled');
      row = (await repo.load()).orders.single;
      await expectLater(
        repo.submitOrderReview(row, 1, 'Cancelled'),
        throwsA(isA<MarketException>()),
      );
      repo.dispose();
    },
  );
  test(
    'completed feedback is pending until admin, negative ratings allowed, persisted and removable',
    () async {
      final store = MemoryStore();
      final repo = SampleRepository(store);
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
      var row = (await repo.load()).orders.single;
      await repo.changeOrder(row, 'completed', 'Buyer received order');
      row = (await repo.load()).orders.single;
      await repo.useSampleProfile('seller');
      await expectLater(
        repo.submitOrderReview(row, 5, 'Not the buyer'),
        throwsA(isA<MarketException>()),
      );
      await repo.useSampleProfile('buyer');
      await repo.submitOrderReview(row, 1, 'A fair negative experience');
      var data = await repo.load();
      expect(data.privateReviews.single.status, 'pending');
      expect(data.publicReviews, isEmpty);
      await expectLater(
        repo.submitOrderReview(row, 5, 'Duplicate'),
        throwsA(isA<MarketException>()),
      );
      await expectLater(
        repo.moderateOrderReview(
          data.privateReviews.single,
          true,
          'Self-approve',
        ),
        throwsA(isA<MarketException>()),
      );
      final restored = SampleRepository(store);
      expect((await restored.load()).privateReviews.single.rating, 1);
      restored.dispose();
      await repo.useSampleProfile('admin');
      await repo.moderateOrderReview(
        data.privateReviews.single,
        true,
        'Meets privacy and abuse policy',
      );
      data = await repo.load();
      expect(data.publicReviews.single.rating, 1);
      expect(data.publicReviews.single.buyerId, isNull);
      expect(data.publicReviews.single.orderId, isNull);
      await repo.moderateOrderReview(
        data.privateReviews.single,
        false,
        'Hide for test moderation',
      );
      expect((await repo.load()).publicReviews, isEmpty);
      await repo.removeSampleData();
      expect((await repo.load()).privateReviews, isEmpty);
      repo.dispose();
    },
  );
  test('snapshot catalogue mutations preserve feedback lists', () {
    final review = OrderReview(
      id: 'review',
      shopId: 'shop',
      rating: 4,
      comment: 'Good',
      createdAt: DateTime.utc(2026),
    );
    final data = MarketSnapshot(
      publicReviews: [review],
      privateReviews: [review],
    );
    expect(data.copyWith(products: const []).publicReviews.single.id, 'review');
    expect(data.copyWith(shops: const []).privateReviews.single.id, 'review');
  });
}
