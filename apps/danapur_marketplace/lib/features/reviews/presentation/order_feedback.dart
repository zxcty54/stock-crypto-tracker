import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../orders/domain/commerce.dart';
import '../../seller/presentation/forms.dart';
import '../domain/order_review.dart';

class OrderFeedbackPanel extends StatelessWidget {
  const OrderFeedbackPanel({
    super.key,
    required this.controller,
    required this.order,
  });
  final MarketController controller;
  final CashOrder order;
  @override
  Widget build(BuildContext context) {
    // No prompt/form before completion, for cancelled orders or for sellers.
    if (order.status != 'completed' || order.buyerId != controller.ownerId) {
      return const SizedBox.shrink();
    }
    final submitted = controller.snapshot.privateReviews
        .where(
          (review) =>
              review.orderId == order.id &&
              review.buyerId == controller.ownerId,
        )
        .firstOrNull;
    if (submitted != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tag(
              'Feedback ${submitted.status} • ${submitted.rating}/5',
              icon: Icons.star_outline,
            ),
            if (submitted.comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  submitted.comment,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (submitted.moderationNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Moderation note: ${submitted.moderationNote}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ),
          ],
        ),
      );
    }
    if (!canLeaveOrderReview(
      order,
      controller.ownerId,
      controller.snapshot.privateReviews,
    )) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: ValueKey('review-${order.id}'),
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  OrderReviewForm(controller: controller, order: order),
            ),
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Rate completed order'),
          ),
          const SizedBox(height: 6),
          const Text(
            'One rating/comment per completed order, from its buyer only. Public comments appear after moderation. Order-linked does not mean digitally verified payment.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class OrderReviewForm extends StatefulWidget {
  const OrderReviewForm({
    super.key,
    required this.controller,
    required this.order,
  });
  final MarketController controller;
  final CashOrder order;
  @override
  State<OrderReviewForm> createState() => _OrderReviewFormState();
}

class _OrderReviewFormState extends State<OrderReviewForm> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      validateOrderReview(_rating, _comment.text);
      await widget.controller.repository.submitOrderReview(
        widget.order,
        _rating,
        _comment.text,
      );
      await widget.controller.reload();
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Feedback submitted for moderation.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: 'How was your completed order?',
    subtitle:
        'Only this order buyer can submit. No feedback before completion or on cancelled orders.',
    onSave: _submit,
    busy: _busy,
    error: _error,
    saveLabel: 'Submit feedback',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shop experience',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          children: List.generate(
            5,
            (index) => IconButton(
              key: ValueKey('review-star-${index + 1}'),
              tooltip: '${index + 1} stars',
              onPressed: _busy
                  ? null
                  : () => setState(() => _rating = index + 1),
              icon: Icon(
                index < _rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: const Color(0xFFD79B27),
                size: 30,
              ),
            ),
          ),
        ),
        Text(
          _rating == 0 ? 'Choose 1–5 stars' : '$_rating / 5',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('order-review-comment'),
          controller: _comment,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Comment (optional)',
            hintText: 'Share your shop/order experience',
            helperText:
                'Do not include mobile numbers, addresses, IDs or abusive content.',
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Moderation checks privacy/abuse and applies to positive and negative feedback alike. It is not government identity or payment verification.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class ShopFeedbackSection extends StatelessWidget {
  const ShopFeedbackSection({
    super.key,
    required this.controller,
    required this.shopId,
  });
  final MarketController controller;
  final String shopId;
  @override
  Widget build(BuildContext context) {
    final reviews =
        controller.snapshot.publicReviews
            .where((review) => review.shopId == shopId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final average = reviews.isEmpty
        ? null
        : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
              reviews.length;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Completed-order feedback',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Buyers can post only after completion. Public order/customer fields are not shared. Comments are moderated; never include contact, address or identity details.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (average == null)
            const Text(
              'No published feedback yet.',
              style: TextStyle(color: muted),
            )
          else ...[
            Tag(
              '${average.toStringAsFixed(1)} / 5 • ${reviews.length} order-linked reviews',
              icon: Icons.star_rounded,
            ),
            const SizedBox(height: 14),
            ...reviews
                .take(20)
                .map(
                  (review) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              Tag(
                                '${review.rating}/5',
                                icon: Icons.star_rounded,
                              ),
                              const Text(
                                'Order-linked customer',
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                              if (review.isSample) const Tag('TEST FEEDBACK'),
                            ],
                          ),
                          if (review.comment.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(review.comment),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            updatedLabel(review.createdAt),
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
