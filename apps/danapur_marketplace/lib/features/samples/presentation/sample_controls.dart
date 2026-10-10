import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

class SampleControls extends StatelessWidget {
  const SampleControls({super.key, required this.controller});
  final MarketController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Sample records, final app flow',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Supabase is not configured in this build. These fictional records and explicit test profiles are stored only on this device. Orders do not notify real sellers, deliver items or collect cash. Never use test profiles as live administrator/security verification.',
        style: TextStyle(color: muted, height: 1.6),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: ['buyer', 'seller', 'admin']
            .map(
              (role) => OutlinedButton.icon(
                onPressed: () => runAction(context, () async {
                  controller.clearCart();
                  await controller.repository.useSampleProfile(role);
                  await controller.reload();
                }, success: 'Local test $role profile selected.'),
                icon: Icon(
                  role == 'buyer'
                      ? Icons.shopping_bag_outlined
                      : role == 'seller'
                      ? Icons.storefront_outlined
                      : Icons.admin_panel_settings_outlined,
                ),
                label: Text('Test $role'),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      const Text(
        'Buyer: cart, delivery/pickup, cash orders and expenses. Seller: Sample Daily Needs, delivery controls and incoming orders. Admin: membership switch and sample removal. Configure Supabase to use actual accounts, owner-only policies and shared orders.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/admin'),
        icon: const Icon(Icons.settings_outlined),
        label: const Text('Open admin controls'),
      ),
      const SizedBox(height: 16),
      const Text(
        'Select the explicit Test admin profile first to remove/restore sample records. A configured live backend never offers local test admin profiles.',
        style: TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );
}
