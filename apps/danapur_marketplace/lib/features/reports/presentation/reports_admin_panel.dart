import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../domain/content_report.dart';

class ReportsAdminPanel extends StatefulWidget {
  const ReportsAdminPanel({super.key, required this.controller});
  final MarketController controller;
  @override
  State<ReportsAdminPanel> createState() => _ReportsAdminPanelState();
}

class _ReportsAdminPanelState extends State<ReportsAdminPanel> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.snapshot.isAdmin) {
      return const SizedBox.shrink();
    }
    final reports =
        widget.controller.snapshot.reports
            .where((r) => r.status == _status)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Content Reports',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'In-app user reports for objectionable shops, products, or reviews. In compliance with Google Play UGC policy, investigate and take action on violations.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: ['pending', 'investigated', 'dismissed']
              .map(
                (status) => ChoiceChip(
                  label: Text(
                    '${status[0].toUpperCase()}${status.substring(1)}',
                  ),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        if (reports.isEmpty)
          const EmptyState(
            title: 'No reports in this view',
            message:
                'User-submitted reports for offensive or misleading content appear here.',
            icon: Icons.flag_outlined,
          ),
        ...reports.map(
          (report) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Tag(
                        report.targetType.toUpperCase(),
                        color: const Color(0xFFB44337),
                        background: const Color(0xFFFDE8E7),
                      ),
                      Tag(report.status.toUpperCase()),
                      if (report.isSample) const Tag('TEST REPORT'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report.targetTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${report.reason}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB44337),
                    ),
                  ),
                  if (report.details.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'User details: ${report.details}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Target ID: ${report.targetId} • Submitted ${updatedLabel(report.createdAt)}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  if (report.statusNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Resolution note: ${report.statusNote}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                  if (report.status == 'pending') ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _resolve(report, 'investigated'),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Resolve violation'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _resolve(report, 'dismissed'),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Dismiss report'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _resolve(ContentReport report, String status) async {
    final note = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          status == 'investigated'
              ? 'Resolve report violation?'
              : 'Dismiss report?',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status == 'investigated'
                    ? 'Confirm investigation and action taken on this report (e.g. content removed or seller contacted).'
                    : 'Confirm this report was evaluated and dismissed as invalid or resolved.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: note,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Action / resolution note *',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, note.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    note.dispose();
    if (result == null || !mounted) {
      return;
    }
    if (result.trim().length < 3 || result.trim().length > 300) {
      toast(context, 'Add a note of 3–300 characters.');
      return;
    }
    await runAction(context, () async {
      await widget.controller.repository.resolveReport(
        report.id,
        status,
        result,
      );
      await widget.controller.reload();
    }, success: 'Report $status.');
  }
}
