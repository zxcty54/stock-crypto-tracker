import '../../../core/domain/market.dart';
import '../../orders/domain/commerce.dart';

class OrderReview {
  const OrderReview({
    required this.id,
    required this.shopId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.orderId,
    this.buyerId,
    this.status = 'published',
    this.moderationNote = '',
    this.isSample = false,
  });
  final String id, shopId, comment, status, moderationNote;
  final String? orderId, buyerId;
  final int rating;
  final DateTime createdAt;
  final bool isSample;
  factory OrderReview.fromJson(Map<String, dynamic> json) => OrderReview(
    id: json['id'] as String,
    shopId: json['shop_id'] as String,
    rating: (json['rating'] as num).toInt(),
    comment: json['comment_text'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    orderId: json['order_id'] as String?,
    buyerId: json['buyer_id'] as String?,
    status: json['moderation_status'] as String? ?? 'published',
    moderationNote: json['moderation_note'] as String? ?? '',
    isSample: json['is_sample'] as bool? ?? false,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'rating': rating,
    'comment_text': comment,
    'created_at': createdAt.toUtc().toIso8601String(),
    'order_id': orderId,
    'buyer_id': buyerId,
    'moderation_status': status,
    'moderation_note': moderationNote,
    'is_sample': isSample,
  };
  OrderReview publicProjection() => OrderReview(
    id: id,
    shopId: shopId,
    rating: rating,
    comment: comment,
    createdAt: createdAt,
    isSample: isSample,
  );
}

bool canLeaveOrderReview(
  CashOrder order,
  String? userId,
  Iterable<OrderReview> reviews,
) =>
    userId != null &&
    order.buyerId == userId &&
    order.status == 'completed' &&
    order.shopId != null &&
    !reviews.any((review) => review.orderId == order.id);
void validateOrderReview(int rating, String comment) {
  if (rating < 1 || rating > 5 || comment.trim().runes.length > 500) {
    throw const MarketException(
      'Choose 1–5 stars and an optional comment up to 500 characters.',
    );
  }
}
