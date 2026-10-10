import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

class CashOperationsPanel extends StatelessWidget {
  const CashOperationsPanel({super.key, required this.controller});
  final MarketController controller;
  @override
  Widget build(BuildContext context) {
    if (!controller.snapshot.isAdmin) {
      return const SizedBox.shrink();
    }
    final settings = controller.snapshot.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership controls',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Shop onboarding is free. Future membership: ₹299/month. OFF by default. No online payment gateway, recurring debit or automatic payment receipt is created.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.billingEnabled,
                  title: const Text('Enable monthly membership policy'),
                  subtitle: const Text(
                    'First activation gives all shops a 30-day grace period. Later expired access pauses new orders; existing orders remain accessible.',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (enabled) async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          enabled
                              ? 'Enable ₹299/month membership?'
                              : 'Disable membership enforcement?',
                        ),
                        content: const Text(
                          'This only changes membership/access policy. It does not collect money. Inform shop owners and manage offline payment/access records separately.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Back'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      await runAction(context, () async {
                        await controller.repository.configureBilling(enabled);
                        await controller.reload();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ...controller.snapshot.shops.map(
          (shop) => Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${shop.businessType} • ${settings.membershipActive(shop) ? 'Access active' : 'Membership access expired'}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  if (shop.paidThrough != null)
                    Text(
                      'Access through: ${updatedLabel(shop.paidThrough!)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: now.add(const Duration(days: 30)),
                        firstDate: now.add(const Duration(days: 1)),
                        lastDate: now.add(const Duration(days: 730)),
                      );
                      if (date == null || !context.mounted) {
                        return;
                      }
                      await runAction(context, () async {
                        await controller.repository.extendMembership(
                          shop,
                          DateTime(date.year, date.month, date.day, 23, 59),
                          'Administrator extended access; no online payment collected',
                        );
                        await controller.reload();
                      });
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Extend membership access'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sample-data controls',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Remove only tagged sample shops/products, test orders and test expenses. Real records are not selected. This is not an account or full-database reset.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (await confirm(
                              context,
                              'Remove sample records?',
                              'Tagged sample catalogue, test orders and test expenses will be removed. Real records remain.',
                            ) &&
                            context.mounted) {
                          await runAction(context, () async {
                            await controller.repository.removeSampleData();
                            controller.clearCart();
                            await controller.reload();
                          }, success: 'Sample records removed.');
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove sample data'),
                    ),
                    if (controller.repository.sampleProfilesEnabled)
                      TextButton(
                        onPressed: () => runAction(context, () async {
                          await controller.repository.restoreSampleData();
                          controller.clearCart();
                          await controller.reload();
                        }),
                        child: const Text('Restore local samples'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
