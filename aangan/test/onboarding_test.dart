import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aangan_bihar_rentals/features/rentals/screens/onboarding_screen.dart';
import 'package:aangan_bihar_rentals/features/rentals/services/onboarding_store.dart';

void main() {
  group('OnboardingStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('a fresh device has not finished the tour', () async {
      final store = OnboardingStore();
      await store.load();
      expect(store.isCompleted, isFalse);
    });

    test('finishing the tour is remembered for the next launch', () async {
      final first = OnboardingStore();
      await first.load();
      await first.complete();
      expect(first.isCompleted, isTrue);

      final next = OnboardingStore();
      await next.load();
      expect(next.isCompleted, isTrue);
    });

    test('restarting brings the tour back and is persisted too', () async {
      final store = OnboardingStore();
      await store.load();
      await store.complete();
      await store.restart();
      expect(store.isCompleted, isFalse);

      final next = OnboardingStore();
      await next.load();
      expect(next.isCompleted, isFalse);
    });
  });

  group('Onboarding tour', () {
    testWidgets('skip finishes the tour with the explore intent',
        (tester) async {
      OnboardingIntent? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(onFinished: (intent) => chosen = intent),
        ),
      );

      expect(find.textContaining('Bihar ka ghar'), findsOneWidget);
      expect(find.text('Aage badhein'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(chosen, OnboardingIntent.exploreHomes);
    });

    testWidgets('walking the pages ends on the two-way choice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      OnboardingIntent? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(onFinished: (intent) => chosen = intent),
        ),
      );

      await tester.tap(find.text('Aage badhein'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rules pehle'), findsOneWidget);

      await tester.tap(find.text('Aage badhein'));
      await tester.pumpAndSettle();
      expect(find.textContaining('aapke control mein'), findsOneWidget);

      await tester.tap(find.text('Aage badhein'));
      await tester.pumpAndSettle();

      expect(find.text('Ghar dhoondhna hai'), findsOneWidget);
      expect(find.text('Ghar dena hai'), findsOneWidget);

      await tester.tap(find.text('Ghar dena hai'));
      await tester.pump();

      expect(chosen, OnboardingIntent.listProperty);
    });

    testWidgets('replay mode closes instead of skipping', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      OnboardingIntent? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            replay: true,
            onFinished: (intent) => chosen = intent,
          ),
        ),
      );

      expect(find.text('Skip'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      for (int step = 0; step < 3; step++) {
        await tester.tap(find.text('Aage badhein'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Ghar dhoondhna hai'));
      await tester.pump();

      expect(chosen, OnboardingIntent.exploreHomes);
    });
  });
}
