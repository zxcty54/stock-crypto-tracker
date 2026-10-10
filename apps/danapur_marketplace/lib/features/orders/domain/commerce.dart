import 'dart:math' as math;
import '../../../core/domain/market.dart';

class GeoFix {
  const GeoFix(
    this.latitude,
    this.longitude, {
    this.accuracy = 0,
    required this.measuredAt,
  });
  final double latitude, longitude, accuracy;
  final DateTime measuredAt;
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      accuracy.isFinite &&
      accuracy >= 0 &&
      accuracy <= 50 &&
      DateTime.now().difference(measuredAt).inSeconds <= 120 &&
      measuredAt.difference(DateTime.now()).inSeconds <= 30;
}

double distanceMetres(double aLat, double aLon, double bLat, double bLon) {
  double rad(double n) => n * math.pi / 180;
  final h =
      math.pow(math.sin(rad(bLat - aLat) / 2), 2) +
      math.cos(rad(aLat)) *
          math.cos(rad(bLat)) *
          math.pow(math.sin(rad(bLon - aLon) / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
}

class CartLine {
  const CartLine(this.productId, this.quantity);
  final String productId;
  final int quantity;
  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
  };
}

class OrderLine {
  const OrderLine({
    required this.id,
    required this.orderId,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.basePaise,
    required this.discountPaise,
    this.deliveryExtraPaise = 0,
  });
  final String id, orderId, name, category, unit;
  final int quantity, basePaise, discountPaise, deliveryExtraPaise;
  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    id: json['id'] as String,
    orderId: json['order_id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    unit: json['unit'] as String,
    quantity: (json['quantity'] as num).toInt(),
    basePaise: (json['base_paise'] as num).toInt(),
    discountPaise: (json['discount_paise'] as num).toInt(),
    deliveryExtraPaise: (json['delivery_extra_paise'] as num?)?.toInt() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'name': name,
    'category': category,
    'unit': unit,
    'quantity': quantity,
    'base_paise': basePaise,
    'discount_paise': discountPaise,
    'delivery_extra_paise': deliveryExtraPaise,
  };
}

class CashOrder {
  const CashOrder({
    required this.id,
    required this.shopName,
    required this.shopCategory,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.fulfilment,
    required this.subtotalPaise,
    required this.discountPaise,
    required this.deliveryPaise,
    required this.totalPaise,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.buyerId,
    this.sellerId,
    this.shopId,
    this.distance,
    this.note = '',
    this.isSample = false,
  });
  final String id,
      shopName,
      shopCategory,
      customerName,
      phone,
      address,
      fulfilment,
      status,
      note;
  final String? buyerId, sellerId, shopId;
  final double? distance;
  final int subtotalPaise, discountPaise, deliveryPaise, totalPaise;
  final DateTime createdAt, updatedAt;
  final bool isSample;
  bool get closed => status == 'completed' || status == 'cancelled';
  factory CashOrder.fromJson(Map<String, dynamic> json) => CashOrder(
    id: json['id'] as String,
    buyerId: json['buyer_id'] as String?,
    sellerId: json['seller_id'] as String?,
    shopId: json['shop_id'] as String?,
    shopName: json['shop_name'] as String,
    shopCategory: json['shop_category'] as String,
    customerName: json['customer_name'] as String,
    phone: json['customer_phone'] as String,
    address: json['address'] as String,
    fulfilment: json['fulfilment'] as String,
    distance: (json['distance_m'] as num?)?.toDouble(),
    subtotalPaise: (json['subtotal_paise'] as num).toInt(),
    discountPaise: (json['discount_paise'] as num).toInt(),
    deliveryPaise: (json['delivery_paise'] as num).toInt(),
    totalPaise: (json['total_paise'] as num).toInt(),
    status: json['status'] as String,
    note: json['status_note'] as String? ?? '',
    isSample: json['is_sample'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'buyer_id': buyerId,
    'seller_id': sellerId,
    'shop_id': shopId,
    'shop_name': shopName,
    'shop_category': shopCategory,
    'customer_name': customerName,
    'customer_phone': phone,
    'address': address,
    'fulfilment': fulfilment,
    'distance_m': distance,
    'subtotal_paise': subtotalPaise,
    'discount_paise': discountPaise,
    'delivery_paise': deliveryPaise,
    'total_paise': totalPaise,
    'status': status,
    'status_note': note,
    'is_sample': isSample,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class PersonalExpense {
  const PersonalExpense({
    required this.id,
    required this.amountPaise,
    required this.category,
    required this.note,
    required this.date,
    this.orderId,
    this.isSample = false,
  });
  final String id, category, note;
  final String? orderId;
  final int amountPaise;
  final DateTime date;
  final bool isSample;
  factory PersonalExpense.fromJson(Map<String, dynamic> json) =>
      PersonalExpense(
        id: json['id'] as String,
        orderId: json['order_id'] as String?,
        amountPaise: (json['amount_paise'] as num).toInt(),
        category: json['category'] as String,
        note: json['note'] as String? ?? '',
        date: DateTime.parse(json['spent_on'] as String),
        isSample: json['is_sample'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'amount_paise': amountPaise,
    'category': category,
    'note': note,
    'spent_on': date.toIso8601String().split('T').first,
    'is_sample': isSample,
  };
}

class CartQuote {
  const CartQuote(
    this.shop,
    this.subtotal,
    this.discount,
    this.delivery,
    this.distance,
  );
  final Shop shop;
  final int subtotal, discount, delivery;
  final double? distance;
  int get total => subtotal - discount + delivery;
}

CartQuote quoteCart(
  MarketSnapshot snapshot,
  List<CartLine> lines,
  String mode,
  GeoFix? fix,
) {
  if (lines.isEmpty || lines.length > 20) {
    throw const MarketException('Add 1–20 products to your cart.');
  }
  if (!['pickup', 'delivery'].contains(mode)) {
    throw const MarketException('Choose delivery or pickup.');
  }
  if (lines.map((l) => l.productId).toSet().length != lines.length) {
    throw const MarketException('Combine duplicate cart lines.');
  }
  Shop? shop;
  int sub = 0, discount = 0, delivery = 0;
  double? distance;
  for (final line in lines) {
    final product = snapshot.products
        .where((p) => p.id == line.productId)
        .firstOrNull;
    if (product == null ||
        !product.isAvailable ||
        line.quantity < 1 ||
        line.quantity > 100) {
      throw const MarketException(
        'A cart item is unavailable or its quantity is invalid.',
      );
    }
    final current = snapshot.shops
        .where((s) => s.id == product.shopId)
        .firstOrNull;
    if (current == null ||
        !current.isPublic ||
        !current.isOpen ||
        (shop != null && shop.id != current.id)) {
      throw const MarketException('One open, approved shop per checkout.');
    }
    shop = current;
    if (!snapshot.settings.membershipActive(current)) {
      throw const MarketException('This shop is not accepting new app orders.');
    }
    sub += product.pricePaise * line.quantity;
    discount += product.discountPaise * line.quantity;
    if (mode == 'delivery') {
      if (!current.offersDelivery ||
          !product.deliveryAllowed ||
          current.latitude == null ||
          current.longitude == null) {
        throw const MarketException(
          'A product is pickup-only, or the shop does not offer delivery.',
        );
      }
      if (fix == null || !fix.valid) {
        throw const MarketException(
          'Get a recent accurate location, or choose pickup.',
        );
      }
      distance = distanceMetres(
        current.latitude!,
        current.longitude!,
        fix.latitude,
        fix.longitude,
      );
      if (distance > 500) {
        throw const MarketException(
          'Home-delivery COD is limited to 500 m straight-line distance. Choose pickup.',
        );
      }
      delivery += product.deliveryExtraPaise * line.quantity;
    }
  }
  if (mode == 'delivery') {
    delivery += shop!.deliveryBasePaise;
  }
  final quote = CartQuote(shop!, sub, discount, delivery, distance);
  if (quote.total <= 0 || quote.total > 1000000000) {
    throw const MarketException('Cart total is outside the supported limit.');
  }
  return quote;
}
