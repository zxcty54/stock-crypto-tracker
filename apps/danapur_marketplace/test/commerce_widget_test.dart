import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/app/app.dart';
import 'package:danapur_marketplace/core/data/controller.dart';
import 'package:danapur_marketplace/core/data/local_store.dart';
import 'package:danapur_marketplace/features/samples/data/sample_repository.dart';
import 'widget_test.dart' as support;

void main() {
  testWidgets(
    'sample buyer can checkout cash, complete and see one expense on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await support.loadFonts();
      final store = MemoryStore(), repo = SampleRepository(MemoryStore());
      final market = MarketController(SampleRepository(store), store);
      await tester.pumpWidget(DanapurApp(controller: market));
      await tester.pumpAndSettle();
      expect(
        find.text('Sample records • device-local testing, not real orders'),
        findsOneWidget,
      );
      market.addToCart(
        market.snapshot.products.firstWhere((p) => p.id == 'sample-rice'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-cart')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('checkout-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('checkout-name')),
        'Test buyer',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('checkout-phone')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('checkout-phone')),
        '9999999999',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byType(CheckboxListTile)),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('place-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('place-order')));
      await tester.pumpAndSettle();
      expect(market.snapshot.orders.single.status, 'placed');
      expect(market.snapshot.orders.single.totalPaise, 7500);
      final id = market.snapshot.orders.single.id;
      await tester.ensureVisible(find.byKey(ValueKey('complete-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('complete-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(market.snapshot.orders.single.status, 'completed');
      expect(market.snapshot.expenses.single.amountPaise, 7500);
      expect(tester.takeException(), isNull);
      repo.dispose();
    },
  );
  testWidgets(
    'category gallery is a grid and includes footwear and photography',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await support.loadFonts();
      final store = MemoryStore();
      final market = MarketController(SampleRepository(store), store);
      await tester.pumpWidget(DanapurApp(controller: market));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-Footwear')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('category-Photography')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('category-Footwear')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-Footwear')));
      await tester.pumpAndSettle();
      expect(find.text('Walking shoes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
