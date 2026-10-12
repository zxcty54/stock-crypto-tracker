import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../seller/presentation/seller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.controller});
  final MarketController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (ctx, _) {
      if (controller.ownerId == null) {
        return SellerAuth(controller: controller);
      }
      final isShopOwner = controller.myShop != null;
      final completedOrders = controller.snapshot.orders
          .where(
            (o) => o.buyerId == controller.ownerId && o.status == 'completed',
          )
          .length;
      final totalExpenses = controller.snapshot.expenses
          .where((e) => e.orderId != null)
          .length;

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Tag('ACCOUNT & PRIVACY', icon: Icons.person_outline),
              const SizedBox(height: 16),
              Text('My Account', style: Theme.of(ctx).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text(
                'Manage your profile, active data, and privacy settings.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFEAF1E6),
                            child: const Icon(
                              Icons.person,
                              color: green,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.snapshot.isAdmin
                                      ? 'Administrator'
                                      : isShopOwner
                                      ? 'Shop Owner & Buyer'
                                      : 'Marketplace Buyer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  'User ID: ${controller.ownerId}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 14),
                      Text(
                        'Stored account data: $completedOrders completed orders, $totalExpenses recorded expenses${isShopOwner ? ", 1 active shop profile" : ""}.',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(ctx, '/orders'),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 16,
                            ),
                            label: const Text('My orders'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(ctx, '/expenses'),
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                            ),
                            label: const Text('Expense manager'),
                          ),
                          if (isShopOwner)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(ctx, '/shop-orders'),
                              icon: const Icon(
                                Icons.storefront_outlined,
                                size: 16,
                              ),
                              label: const Text('Shop orders'),
                            ),
                        ],
                      ),
                    ],
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
                        'Security & Deletion',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'In compliance with Google Play User Data policies, you can permanently delete your account and all associated personal data directly from this app.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                runAction(ctx, controller.repository.signOut),
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Sign out'),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('account-delete-btn'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB44337),
                            ),
                            onPressed: () async {
                              final confirmed = await confirm(
                                ctx,
                                'Permanently delete your account?',
                                'All your account data, order history, and personal expenses will be permanently deleted from our servers.\n\n'
                                    'If you have any active/open orders, please complete or cancel them before proceeding.\n\n'
                                    'This action cannot be reversed.',
                              );
                              if (confirmed && ctx.mounted) {
                                await runAction(
                                  ctx,
                                  controller.repository.deleteAccount,
                                  success:
                                      'Account and associated data deleted.',
                                );
                                if (ctx.mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                    ctx,
                                    '/',
                                    (_) => false,
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_forever, size: 16),
                            label: const Text('Delete account & data'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
