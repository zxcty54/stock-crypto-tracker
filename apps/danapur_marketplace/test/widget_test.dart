import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/data/controller.dart';
import 'package:danapur_marketplace/data/local_store.dart';
import 'package:danapur_marketplace/data/repository.dart';
import 'package:danapur_marketplace/ui/app.dart';
import 'package:danapur_marketplace/models/market.dart';

Future<void> loadFonts() async {
  final loader = FontLoader('Manrope');
  for (final weight in [400, 500, 600, 700, 800]) {
    loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
  }
  await loader.load();
  await (FontLoader(
    'Roboto',
  )..addFont(rootBundle.load('assets/fonts/Manrope-400.ttf'))).load();
  await (FontLoader('NotoSansDevanagari')
        ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari-400.ttf')))
      .load();
}

Future<MarketController> openApp(
  WidgetTester tester, {
  Size size = const Size(1280, 1000),
  MemoryStore? store,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await loadFonts();
  final storage = store ?? MemoryStore();
  final controller = MarketController(DemoRepository(storage), storage);
  await tester.pumpWidget(DanapurApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('desktop discovery, category, search and save work', (
    tester,
  ) async {
    final controller = await openApp(tester);
    expect(find.text('Danapur ki dukaan,\nab online.'), findsOneWidget);
    expect(
      find.text('Example shops • Your changes stay on this device'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('category-Electronics')),
    );
    await tester.tap(find.byKey(const ValueKey('category-Electronics')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('market-search')),
      'wireless',
    );
    await tester.pumpAndSettle();
    expect(find.text('Wireless earbuds'), findsOneWidget);
    expect(find.text('Everyday cotton shirt'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-sample-earbuds')),
    );
    await tester.tap(find.byKey(const ValueKey('save-sample-earbuds')));
    await tester.pumpAndSettle();
    expect(controller.savedIds, contains('sample-earbuds'));
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Your saved finds'), findsOneWidget);
    expect(find.text('Wireless earbuds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('owner creates a shop and lists a priced product end to end', (
    tester,
  ) async {
    final controller = await openApp(tester);
    await tester.tap(find.byKey(const ValueKey('seller-nav')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-shop')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shop-name')),
      'My Danapur Store',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shop-address')),
      'Test street, Danapur Bazaar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('shop-phone')),
      '9999999999',
    );
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create shop'));
    await tester.pumpAndSettle();
    expect(controller.myShop?.name, 'My Danapur Store');
    await tester.tap(find.byKey(const ValueKey('add-product')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Local test product',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-price')),
      '120.50',
    );
    await tester.tap(find.text('List product'));
    await tester.pumpAndSettle();
    final product = controller.snapshot.products
        .where((p) => p.name == 'Local test product')
        .single;
    expect(product.pricePaise, 12050);
    expect(product.shopId, controller.myShop!.id);
    expect(find.text('Local test product'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete Local test product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.products.any((p) => p.id == product.id), false);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(820, 1000)]) {
    testWidgets(
      'responsive layout at ${size.width.toInt()}px has no overflow',
      (tester) async {
        await openApp(tester, size: size);
        await tester.ensureVisible(
          find.byKey(const ValueKey('category-Electronics')),
        );
        await tester.tap(find.byKey(const ValueKey('category-Electronics')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('My shop'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('create-shop')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'onboarding with keyboard at ${size.width.toInt()}px stays scrollable',
      (tester) async {
        await openApp(tester, size: size);
        await tester.tap(find.text('My shop'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('create-shop')));
      await tester.tap(find.byKey(const ValueKey('create-shop')));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.width > 700 ? 180.0 : 320.0,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('shop-name')));
        await tester.enterText(
          find.byKey(const ValueKey('shop-name')),
          'दानापुर टेस्ट स्टोर',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Close form'));
        await tester.tap(find.byTooltip('Close form'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('create-shop')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('long names and maximum rupee prices fit narrow product cards', (
    tester,
  ) async {
    final controller = await openApp(tester, size: const Size(390, 844));
    await controller.saveShop(
      const ShopDraft(
        name: 'Local demo grocery',
        category: 'Grocery',
        area: 'Danapur Bazaar',
        address: 'Test street, Danapur',
        phone: '9999999999',
      ),
    );
    await controller.saveProduct(
      const ProductDraft(
        name:
            'A local product with a deliberately long name to check narrow card wrapping',
        category: 'Grocery',
        pricePaise: 100000000,
        mrpPaise: 100000000,
        unit: 'large family value pack / box',
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('₹10,00,000').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
