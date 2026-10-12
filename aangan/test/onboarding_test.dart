import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aangan_bihar_rentals/features/rentals/screens/onboarding_screen.dart';
import 'package:aangan_bihar_rentals/features/rentals/services/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('OnboardingStore', () {
    test('reports an unfinished flow on a fresh install', () async {
      expect(await OnboardingStore.isCompleted(), isFalse);
    });

    test('remembers the flow as completed once marked', () async {
      await OnboardingStore.markCompleted();
      expect(await OnboardingStore.isCompleted(), isTrue);
    });
  });

  group('OnboardingScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required VoidCallback onCompleted,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(onCompleted: onCompleted),
        ),
      );
    }

    testWidgets('renders the first slide and skips straight to the app',
        (tester) async {
      var completed = false;
      await pumpScreen(tester, onCompleted: () => completed = true);

      expect(find.text('बिहार का अपना रेंटल आँगन'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('aangan'), findsOneWidget);
      expect(completed, isFalse);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(await OnboardingStore.isCompleted(), isTrue);
    });

    testWidgets('walks through every slide before finishing', (tester) async {
      var completed = false;
      await pumpScreen(tester, onCompleted: () => completed = true);

      expect(find.text('शुरू करें'), findsNothing);

      for (var taps = 1; taps < 4; taps += 1) {
        await tester.tap(find.text('आगे'));
        await tester.pumpAndSettle();
        expect(completed, isFalse);
      }

      expect(find.text('शुरू करें'), findsOneWidget);
      await tester.tap(find.text('शुरू करें'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(await OnboardingStore.isCompleted(), isTrue);
    });

    testWidgets('swiping pages keeps the pinned controls in place',
        (tester) async {
      var completed = false;
      await pumpScreen(tester, onCompleted: () => completed = true);

      await tester.fling(
        find.byType(PageView),
        const Offset(-420, 0),
        900,
      );
      await tester.pumpAndSettle();

      expect(find.text('सीधा बात कीजिए'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('आगे'), findsOneWidget);
      expect(completed, isFalse);
    });
  });
}
