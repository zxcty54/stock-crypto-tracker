import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/app/app.dart';
import 'package:danapur_marketplace/core/data/controller.dart';
import 'package:danapur_marketplace/core/data/local_store.dart';
import 'package:danapur_marketplace/core/theme/app_theme.dart';
import 'package:danapur_marketplace/features/onboarding/data/welcome_preferences.dart';
import 'package:danapur_marketplace/features/onboarding/presentation/welcome_screen.dart';
import 'package:danapur_marketplace/features/samples/data/sample_repository.dart';
import 'support/repository.dart';
import 'widget_test.dart' as support;

class FailingWelcomeStore extends MemoryStore {
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('Test write failure');
}

class RecoveryRepository extends FixtureRepository {
  RecoveryRepository(super.store);
  @override
  bool get needsPasswordUpdate => true;
}

void main() {
  test(
    'welcome preference is namespaced and persists separately from sample cleanup',
    () async {
      final store = MemoryStore();
      expect(WelcomePreferences.hasCompleted(store), false);
      await WelcomePreferences.complete(store);
      expect(WelcomePreferences.hasCompleted(store), true);
      final samples = SampleRepository(store);
      await samples.useSampleProfile('admin');
      await samples.removeSampleData();
      expect(WelcomePreferences.hasCompleted(store), true);
      samples.dispose();
    },
  );
  testWidgets(
    'fresh launch shows three intro pages, finish persists and restart skips',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await support.loadFonts();
      final store = MemoryStore();
      var market = MarketController(FixtureRepository(store), store);
      await tester.pumpWidget(DanapurApp(controller: market));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-title-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('market-search')), findsNothing);
      expect(WelcomePreferences.hasCompleted(store), false);
      await tester.tap(find.byKey(const ValueKey('welcome-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-title-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-next')));
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-title-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(WelcomePreferences.hasCompleted(store), true);
      expect(find.byKey(const ValueKey('market-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      market = MarketController(FixtureRepository(store), store);
      await tester.pumpWidget(DanapurApp(controller: market));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-pages')), findsNothing);
      expect(find.byKey(const ValueKey('market-search')), findsOneWidget);
    },
  );
  testWidgets('skip marks welcome complete; menu replay does not reset it', (
    tester,
  ) async {
    await support.loadFonts();
    final store = MemoryStore();
    final market = MarketController(FixtureRepository(store), store);
    await tester.pumpWidget(DanapurApp(controller: market));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pumpAndSettle();
    expect(WelcomePreferences.hasCompleted(store), true);
    await tester.tap(find.byTooltip('Marketplace menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Welcome guide'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('welcome-pages')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('market-search')), findsOneWidget);
    expect(WelcomePreferences.hasCompleted(store), true);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed preference storage does not trap the user in the welcome screen',
    (tester) async {
      await support.loadFonts();
      final store = FailingWelcomeStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: marketTheme(),
          home: FirstLaunchGate(
            store: store,
            child: const Scaffold(body: Text('Marketplace opened')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('welcome-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Marketplace opened'), findsOneWidget);
      expect(WelcomePreferences.hasCompleted(store), false);
      expect(find.textContaining('intro could not be saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'password recovery bypasses the intro without granting completion',
    (tester) async {
      await support.loadFonts();
      final store = MemoryStore();
      final market = MarketController(RecoveryRepository(store), store);
      await tester.pumpWidget(DanapurApp(controller: market));
      await tester.pumpAndSettle();
      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.byKey(const ValueKey('welcome-pages')), findsNothing);
      expect(WelcomePreferences.hasCompleted(store), false);
    },
  );
  testWidgets(
    'shop deep-link route remains reachable before welcome completion',
    (tester) async {
      await support.loadFonts();
      final store = MemoryStore();
      final market = MarketController(FixtureRepository(store), store);
      await tester.pumpWidget(DanapurApp(controller: market));
      await tester.pumpAndSettle();
      final shop = market.snapshot.shops.first;
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/shop/${shop.id}');
      await tester.pumpAndSettle();
      expect(find.text(shop.name), findsWidgets);
      expect(WelcomePreferences.hasCompleted(store), false);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'welcome is scrollable without overflow at ${size.width.toInt()}px and large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await support.loadFonts();
        await tester.pumpWidget(
          MaterialApp(
            theme: marketTheme(),
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(
                ctx,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: WelcomeScreen(localSamples: true, onComplete: () async {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byKey(const ValueKey('welcome-next')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Get started'), findsOneWidget);
        expect(find.byKey(const ValueKey('welcome-skip')), findsOneWidget);
      },
    );
  }
}
