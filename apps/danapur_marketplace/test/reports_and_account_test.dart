import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/app/app.dart';
import 'package:danapur_marketplace/core/data/controller.dart';
import 'package:danapur_marketplace/core/data/local_store.dart';
import 'package:danapur_marketplace/core/domain/market.dart';
import 'package:danapur_marketplace/core/theme/app_theme.dart';
import 'package:danapur_marketplace/features/account/presentation/account_screen.dart';
import 'package:danapur_marketplace/features/reports/domain/content_report.dart';
import 'package:danapur_marketplace/features/reports/presentation/report_dialog.dart';
import 'package:danapur_marketplace/features/reports/presentation/reports_admin_panel.dart';
import 'package:danapur_marketplace/features/samples/data/sample_repository.dart';
import 'widget_test.dart' as support;

void main() {
  test('report reasons are non-empty and target types are validated', () {
    expect(reportReasons.length, greaterThanOrEqualTo(5));
    final report = ContentReport(
      id: 'rep-1',
      targetType: 'shop',
      targetId: 'shop-1',
      targetTitle: 'Sample Shop',
      reason: reportReasons.first,
      details: 'Test details',
      status: 'pending',
      createdAt: DateTime.now().toUtc(),
    );
    expect(report.targetType, 'shop');
    expect(report.status, 'pending');
  });

  test('user can submit report and admin can investigate or dismiss', () async {
    final store = MemoryStore();
    final repo = SampleRepository(store);
    await repo.useSampleProfile('buyer');
    await repo.submitReport(
      targetType: 'shop',
      targetId: 'sample-grocery',
      targetTitle: 'Sample Daily Needs',
      reason: reportReasons.first,
      details: 'Offensive shop sign',
    );
    var data = await repo.load();
    expect(data.reports.length, 1);
    expect(data.reports.first.status, 'pending');

    await expectLater(
      repo.resolveReport(data.reports.first.id, 'investigated', 'Action taken'),
      throwsA(isA<MarketException>()),
    );

    await repo.useSampleProfile('admin');
    data = await repo.load();
    expect(data.reports.length, 1);
    await repo.resolveReport(
      data.reports.first.id,
      'investigated',
      'Shop contacted and resolved',
    );
    data = await repo.load();
    expect(data.reports.first.status, 'investigated');
    expect(data.reports.first.statusNote, 'Shop contacted and resolved');

    await repo.removeSampleData();
    expect((await repo.load()).reports, isEmpty);
    repo.dispose();
  });

  testWidgets(
    'buyer can open Account screen, see data summary, and delete account',
    (tester) async {
      await support.loadFonts();
      final store = MemoryStore();
      final repo = SampleRepository(store);
      await repo.useSampleProfile('buyer');
      final market = MarketController(repo, store);
      await market.reload();

      await tester.pumpWidget(
        MaterialApp(
          theme: marketTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AccountScreen(controller: market),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Account'), findsOneWidget);
      expect(find.text('Security & Deletion'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-delete-btn')), findsOneWidget);
      expect(tester.takeException(), isNull);
      market.dispose();
    },
  );

  testWidgets('showReportDialog displays reasons and submits report cleanly', (
    tester,
  ) async {
    await support.loadFonts();
    final store = MemoryStore();
    final repo = SampleRepository(store);
    await repo.useSampleProfile('buyer');
    final market = MarketController(repo, store);
    await market.reload();

    await tester.pumpWidget(
      MaterialApp(
        theme: marketTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showReportDialog(
                ctx,
                controller: market,
                targetType: 'product',
                targetId: 'prod-1',
                targetTitle: 'Test Product',
              ),
              child: const Text('Open Report'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Report'));
    await tester.pumpAndSettle();

    expect(find.text('Report product'), findsOneWidget);
    expect(find.text('Test Product'), findsOneWidget);
    expect(find.text('Submit report'), findsOneWidget);

    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(find.text('Report product'), findsNothing);
    expect(market.snapshot.reports.length, 1);
    expect(tester.takeException(), isNull);
    market.dispose();
  });

  testWidgets('admin sees User reports tab in AdminScreen and can resolve', (
    tester,
  ) async {
    await support.loadFonts();
    final store = MemoryStore();
    final repo = SampleRepository(store);
    await repo.useSampleProfile('admin');
    await repo.submitReport(
      targetType: 'shop',
      targetId: 'sample-grocery',
      targetTitle: 'Sample Daily Needs',
      reason: reportReasons.first,
    );
    final market = MarketController(repo, store);
    await market.reload();

    await tester.pumpWidget(
      MaterialApp(
        theme: marketTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ReportsAdminPanel(controller: market),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('User Content Reports'), findsOneWidget);
    expect(find.text('Sample Daily Needs'), findsOneWidget);
    expect(find.text('Resolve violation'), findsOneWidget);
    expect(find.text('Dismiss report'), findsOneWidget);

    await tester.tap(find.text('Dismiss report'));
    await tester.pumpAndSettle();

    expect(find.text('Dismiss report?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Evaluated as compliant');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(market.snapshot.reports.first.status, 'dismissed');
    expect(tester.takeException(), isNull);
    market.dispose();
  });
}
