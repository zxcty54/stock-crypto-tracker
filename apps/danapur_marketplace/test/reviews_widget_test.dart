import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/core/data/controller.dart';
import 'package:danapur_marketplace/core/data/local_store.dart';
import 'package:danapur_marketplace/core/theme/app_theme.dart';
import 'package:danapur_marketplace/features/orders/domain/commerce.dart';
import 'package:danapur_marketplace/features/orders/presentation/orders_screen.dart';
import 'package:danapur_marketplace/features/reviews/presentation/order_feedback.dart';
import 'package:danapur_marketplace/features/samples/data/sample_repository.dart';
import 'widget_test.dart' as support;

void main() {
  testWidgets(
    'feedback button appears only after completion and submits once on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await support.loadFonts();
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
      final market = MarketController(repo, store);
      await market.reload();
      final row = market.snapshot.orders.single;
      await tester.pumpWidget(
        MaterialApp(
          theme: marketTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: OrdersScreen(controller: market),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('review-${row.id}')), findsNothing);
      await repo.changeOrder(row, 'completed', 'Buyer received order');
      await market.reload();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ValueKey('review-${row.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('review-${row.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-star-1')));
      await tester.enterText(
        find.byKey(const ValueKey('order-review-comment')),
        'Fair one-star feedback',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();
      expect(market.snapshot.privateReviews.single.rating, 1);
      expect(market.snapshot.privateReviews.single.status, 'pending');
      expect(market.snapshot.publicReviews, isEmpty);
      expect(find.byKey(ValueKey('review-${row.id}')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      market.dispose();
    },
  );
  testWidgets(
    'published shop feedback displays no customer identity or order ID',
    (tester) async {
      await support.loadFonts();
      final store = MemoryStore();
      final repo = SampleRepository(store);
      await repo.placeCashOrder(
        'sample-grocery',
        const [CartLine('sample-rice', 1)],
        'pickup',
        'Private buyer name',
        '9999999999',
        'Private delivery address',
        null,
        'request',
      );
      var row = (await repo.load()).orders.single;
      await repo.changeOrder(row, 'completed', 'Complete');
      row = (await repo.load()).orders.single;
      await repo.submitOrderReview(row, 4, 'Order-linked feedback');
      var data = await repo.load();
      await repo.useSampleProfile('admin');
      await repo.moderateOrderReview(
        data.privateReviews.single,
        true,
        'Meets moderation rules',
      );
      final market = MarketController(repo, store);
      await market.reload();
      await tester.pumpWidget(
        MaterialApp(
          theme: marketTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShopFeedbackSection(
                controller: market,
                shopId: 'sample-grocery',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order-linked feedback'), findsOneWidget);
      expect(find.text('Private buyer name'), findsNothing);
      expect(find.textContaining('9999999999'), findsNothing);
      expect(find.textContaining(row.id), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      market.dispose();
    },
  );
}
