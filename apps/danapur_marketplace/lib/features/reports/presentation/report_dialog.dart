import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../seller/presentation/forms.dart';
import '../domain/content_report.dart';

Future<void> showReportDialog(
  BuildContext context, {
  required MarketController controller,
  required String targetType,
  required String targetId,
  required String targetTitle,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ReportDialog(
    controller: controller,
    targetType: targetType,
    targetId: targetId,
    targetTitle: targetTitle,
  ),
);

class ReportDialog extends StatefulWidget {
  const ReportDialog({
    super.key,
    required this.controller,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
  });
  final MarketController controller;
  final String targetType, targetId, targetTitle;
  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String _reason = reportReasons.first;
  final _details = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.repository.submitReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetTitle: widget.targetTitle,
        reason: _reason,
        details: _details.text.trim(),
      );
      await widget.controller.reload();
      if (mounted) {
        Navigator.pop(context);
        toast(
          context,
          'Report submitted. Our moderation team will investigate.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: 'Report ${widget.targetType}',
    subtitle: widget.targetTitle,
    onSave: _submit,
    busy: _busy,
    error: _error,
    saveLabel: 'Submit report',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Help keep Danapur Bazaar safe and trustworthy. Choose why this listing or review is objectionable:',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _reason,
          decoration: const InputDecoration(labelText: 'Reason for report *'),
          items: reportReasons
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: _busy ? null : (v) => setState(() => _reason = v!),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _details,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Additional details (optional)',
            hintText:
                'Provide specific context to help our moderators evaluate this report.',
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Reports are confidential. Offensive content or abusive users will be moderated or removed.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    ),
  );
}
