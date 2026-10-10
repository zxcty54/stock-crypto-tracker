import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../domain/order_review.dart';

class ReviewModerationPanel extends StatefulWidget {
  const ReviewModerationPanel({super.key, required this.controller});
  final MarketController controller;
  @override
  State<ReviewModerationPanel> createState() => _ReviewModerationPanelState();
}

class _ReviewModerationPanelState extends State<ReviewModerationPanel> {
  String _status = 'pending';
  @override
  Widget build(BuildContext context) {
    if (!widget.controller.snapshot.isAdmin) {
      return const SizedBox.shrink();
    }
    final reviews =
        widget.controller.snapshot.privateReviews
            .where((review) => review.status == _status)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completed-order feedback',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Only the completed order buyer can submit, once per order. Review privacy, spam and abuse consistently for positive and negative comments. Do not hide a review simply because it is negative. Public review data excludes customer/order identity fields.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: ['pending', 'published', 'hidden']
              .map(
                (status) => ChoiceChip(
                  label: Text(status),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        if (reviews.isEmpty)
          const EmptyState(
            title: 'No feedback in this view',
            message:
                'Reviews appear only after a buyer submits feedback on a completed order.',
            icon: Icons.rate_review_outlined,
          ),
        ...reviews.map((review) {
          final shop = widget.controller.snapshot.shops
              .where((shop) => shop.id == review.shopId)
              .firstOrNull;
          return Card(
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
                        shop?.name ?? 'Shop feedback',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Tag('${review.rating}/5', icon: Icons.star_outline),
                      if (review.isSample) const Tag('TEST FEEDBACK'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    review.comment.isEmpty
                        ? 'Rating only — no comment'
                        : review.comment,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    updatedLabel(review.createdAt),
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  if (review.moderationNote.isNotEmpty)
                    Text(
                      'Last reason: ${review.moderationNote}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      if (review.status != 'published')
                        FilledButton.icon(
                          key: ValueKey('publish-review-${review.id}'),
                          onPressed: () => _moderate(review, true),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: const Text('Publish feedback'),
                        ),
                      if (review.status != 'hidden')
                        OutlinedButton.icon(
                          onPressed: () => _moderate(review, false),
                          icon: const Icon(
                            Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          label: const Text('Hide with reason'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _moderate(OrderReview review, bool publish) async {
    final note = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(publish ? 'Publish this feedback?' : 'Hide this feedback?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Check the free-text comment for personal information, spam or abuse. Apply the same policy to every rating.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: note,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Moderation reason *',
                  helperText: 'Visible privately to the author.',
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
    if (reason == null || !mounted) {
      return;
    }
    if (reason.trim().length < 3 || reason.trim().length > 300) {
      toast(context, 'Add a reason of 3–300 characters.');
      return;
    }
    await runAction(context, () async {
      await widget.controller.repository.moderateOrderReview(
        review,
        publish,
        reason,
      );
      await widget.controller.reload();
    }, success: 'Feedback moderation saved.');
  }
}
