import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

class PasswordUpdatePanel extends StatefulWidget {
  const PasswordUpdatePanel({super.key, required this.controller});
  final MarketController controller;
  @override
  State<PasswordUpdatePanel> createState() => _PasswordUpdatePanelState();
}

class _PasswordUpdatePanelState extends State<PasswordUpdatePanel> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController(),
      _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.repository.updatePassword(_password.text);
      await widget.controller.reload();
      if (mounted) {
        _password.clear();
        _confirmation.clear();
        toast(context, 'Password updated.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_reset, color: green, size: 36),
                const SizedBox(height: 20),
                Text(
                  'Set a new password',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Opened from your Supabase recovery email. Choose a strong, unique password.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => (value ?? '').length >= 10
                      ? null
                      : 'Use at least 10 characters.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (value) => value == _password.text
                      ? null
                      : 'Passwords do not match.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Updating…' : 'Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
