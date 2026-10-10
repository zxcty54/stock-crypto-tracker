import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../seller/presentation/seller.dart';
import '../domain/commerce.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({
    super.key,
    required this.controller,
    this.sellerOnly = false,
  });
  final MarketController controller;
  final bool sellerOnly;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (ctx, _) {
      if (controller.ownerId == null) {
        return SellerAuth(controller: controller);
      }
      final orders =
          controller.snapshot.orders
              .where(
                (o) => sellerOnly
                    ? o.sellerId == controller.ownerId
                    : o.buyerId == controller.ownerId,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CASH ORDERS', icon: Icons.receipt_long_outlined),
          const SizedBox(height: 16),
          Text(
            sellerOnly ? 'Shop orders' : 'Your orders',
            style: Theme.of(ctx).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Amounts and fulfilment status only. This app does not collect or verify digital payments.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (orders.isEmpty)
            const EmptyState(
              title: 'No orders yet',
              message: 'New orders appear here after cash checkout.',
            ),
          ...orders.map(
            (order) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Text(
                          order.shopName,
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        Tag(order.status.toUpperCase()),
                        if (order.isSample)
                          const Tag(
                            'TEST ORDER',
                            color: Color(0xFF98621E),
                            background: Color(0xFFFFF0DC),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      'Order: ${order.id}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      '${updatedLabel(order.createdAt)} • ${order.fulfilment == 'delivery' ? 'Home delivery COD' : 'Shop pickup + cash'}${order.distance == null ? '' : ' • ${order.distance!.toStringAsFixed(0)} m straight-line'}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    ...controller.snapshot.orderLines
                        .where((l) => l.orderId == order.id)
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${line.quantity} × ${line.name} (${line.unit}) — ${money((line.basePaise - line.discountPaise) * line.quantity)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    const Divider(),
                    Text(
                      'Base ${money(order.subtotalPaise)} − discount ${money(order.discountPaise)} + delivery ${money(order.deliveryPaise)}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cash payable: ${money(order.totalPaise)}',
                      style: const TextStyle(
                        color: green,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${order.customerName} • +91${order.phone}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(order.address, style: const TextStyle(fontSize: 12)),
                    if (order.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Status note: ${order.note}',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                    if (!order.closed) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (sellerOnly && order.status == 'placed')
                            OutlinedButton(
                              onPressed: () => _change(ctx, order, 'accepted'),
                              child: const Text('Accept'),
                            ),
                          if (sellerOnly &&
                              ['placed', 'accepted'].contains(order.status))
                            OutlinedButton(
                              onPressed: () => _change(ctx, order, 'ready'),
                              child: const Text('Ready for fulfilment'),
                            ),
                          FilledButton.icon(
                            key: ValueKey('complete-${order.id}'),
                            onPressed: () => _change(ctx, order, 'completed'),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text('Mark complete'),
                          ),
                          TextButton(
                            onPressed: () => _change(ctx, order, 'cancelled'),
                            child: const Text(
                              'Cancel order',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Either buyer or seller may complete/cancel an open order. Completion adds one buyer expense and locks the order; cash settlement remains self-reported.',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  Future<void> _change(
    BuildContext context,
    CashOrder order,
    String status,
  ) async {
    final note = TextEditingController(
      text: status == 'completed'
          ? 'Completed; cash settlement self-reported'
          : status == 'cancelled'
          ? 'Cancelled by participant'
          : 'Seller updated fulfilment',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          status == 'completed'
              ? 'Close this order as complete?'
              : status == 'cancelled'
              ? 'Cancel this order?'
              : 'Update order status',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'completed')
                const Text(
                  'Confirm items were handed over/received. This does not digitally verify cash payment. Closed orders cannot be changed.',
                ),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Status / cancellation note',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, note.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    note.dispose();
    if (result == null || !context.mounted) {
      return;
    }
    if (validateLength(result, 'Note', 3, 300) != null) {
      toast(context, 'Add a note of 3–300 characters.');
      return;
    }
    await runAction(context, () async {
      await controller.repository.changeOrder(order, status, result);
      await controller.reload();
    }, success: 'Order updated.');
  }
}
