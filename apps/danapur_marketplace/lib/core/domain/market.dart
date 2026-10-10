import '../../features/reviews/domain/order_review.dart';
import '../../features/orders/domain/commerce.dart';
import '../../features/mandi/domain/mandi.dart';
import '../../features/admin/domain/administration.dart';
import 'dart:typed_data';

const categories = [
  'Grocery',
  'Electronics',
  'Fashion',
  'Home',
  'Hardware',
  'Furniture',
  'Electrical',
  'Building materials',
  'Books & stationery',
  'Pharmacy & healthcare',
  'Automotive',
  'Jewellery',
  'Fresh produce',
  'Sports & toys',
  'Other',
  'Footwear',
  'Garments',
  'Photography',
  'Mobile & accessories',
  'Computer & accessories',
  'Beauty & cosmetics',
  'Bags & luggage',
  'Kitchen & appliances',
  'Dairy',
  'Meat & fish',
  'Bakery',
  'Restaurant & snacks',
  'Optical',
  'Watches',
  'Baby & kids',
  'Pet supplies',
  'Agriculture & seeds',
  'Paints & plumbing',
  'Tools & machinery',
  'Handicrafts & gifts',
  'Tailoring',
  'Repairs & services',
  'Printing & signage',
  'Books & education',
  'Food & sweets',
];
const areas = [
  'Danapur Bazaar',
  'Saguna More',
  'Gola Road',
  'RPS More',
  'Takiyapar',
  'Nasriganj',
  'Bibiganj',
  'Other in Danapur',
];

const businessTypes = ['Retailer', 'Wholesaler', 'Retailer & wholesaler'];
const reviewStatuses = ['pending', 'approved', 'rejected', 'suspended'];

class MarketException implements Exception {
  const MarketException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Shop {
  const Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.area,
    required this.address,
    required this.phone,
    required this.updatedAt,
    this.businessType = 'Retailer',
    this.isOpen = true,
    this.offersDelivery = false,
    this.latitude,
    this.longitude,
    this.deliveryBasePaise = 0,
    this.reviewStatus = 'pending',
    this.paidThrough,
    this.isSample = false,
    this.verificationPhotoPath,
    this.reviewNote = '',
    this.description = '',
    this.hours = '',
    this.isPublished = true,
  });
  final String id,
      ownerId,
      name,
      category,
      area,
      address,
      phone,
      description,
      hours;
  final String businessType, reviewStatus, reviewNote;
  final String? verificationPhotoPath;
  final DateTime? paidThrough;
  final bool isSample;
  bool get isPublic => isPublished && reviewStatus == 'approved';
  final bool isOpen, offersDelivery;
  final double? latitude, longitude;
  final int deliveryBasePaise;
  final bool isPublished;
  final DateTime updatedAt;
  bool get isExample => isSample || ownerId.startsWith('sample-');

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    businessType: json['business_type'] as String? ?? 'Retailer',
    isOpen: json['is_open'] as bool? ?? true,
    offersDelivery: json['offers_delivery'] as bool? ?? false,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    deliveryBasePaise: (json['delivery_base_paise'] as num?)?.toInt() ?? 0,
    paidThrough: json['paid_through'] == null
        ? null
        : DateTime.parse(json['paid_through'] as String),
    isSample: json['is_sample'] as bool? ?? false,
    reviewStatus: json['review_status'] as String? ?? 'pending',
    verificationPhotoPath: json['verification_photo_path'] as String?,
    reviewNote: json['review_note'] as String? ?? '',
    name: json['name'] as String,
    category: json['category'] as String,
    area: json['area'] as String,
    address: json['address'] as String,
    phone: json['phone'] as String,
    description: json['description'] as String? ?? '',
    hours: json['hours'] as String? ?? '',
    isPublished: json['is_published'] as bool? ?? true,
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'business_type': businessType,
    'is_open': isOpen,
    'offers_delivery': offersDelivery,
    'latitude': latitude,
    'longitude': longitude,
    'delivery_base_paise': deliveryBasePaise,
    'review_status': reviewStatus,
    'paid_through': paidThrough?.toIso8601String(),
    'is_sample': isSample,
    'verification_photo_path': verificationPhotoPath,
    'review_note': reviewNote,
    'name': name,
    'category': category,
    'area': area,
    'address': address,
    'phone': phone,
    'description': description,
    'hours': hours,
    'is_published': isPublished,
    'updated_at': updatedAt.toIso8601String(),
  };
}

class Product {
  const Product({
    required this.id,
    required this.shopId,
    required this.name,
    required this.category,
    required this.pricePaise,
    required this.updatedAt,
    this.mrpPaise,
    this.discountPaise = 0,
    this.deliveryAllowed = false,
    this.deliveryExtraPaise = 0,
    this.description = '',
    this.unit = 'each',
    this.imageUrl,
    this.illustration = 'bag',
    this.isAvailable = true,
  });
  final String id, shopId, name, category, description, unit, illustration;
  final String? imageUrl;
  final int pricePaise;
  final int? mrpPaise;
  final bool deliveryAllowed;
  final int discountPaise, deliveryExtraPaise;
  int get sellingPaise => pricePaise - discountPaise;
  final bool isAvailable;
  final DateTime updatedAt;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    shopId: json['shop_id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    pricePaise: (json['price_paise'] as num).toInt(),
    discountPaise: (json['discount_paise'] as num?)?.toInt() ?? 0,
    deliveryAllowed: json['delivery_allowed'] as bool? ?? false,
    deliveryExtraPaise: (json['delivery_extra_paise'] as num?)?.toInt() ?? 0,
    mrpPaise: (json['mrp_paise'] as num?)?.toInt(),
    description: json['description'] as String? ?? '',
    unit: json['unit'] as String? ?? 'each',
    imageUrl: json['image_url'] as String?,
    illustration: json['illustration'] as String? ?? 'bag',
    isAvailable: json['is_available'] as bool? ?? true,
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'name': name,
    'category': category,
    'price_paise': pricePaise,
    'discount_paise': discountPaise,
    'delivery_allowed': deliveryAllowed,
    'delivery_extra_paise': deliveryExtraPaise,
    'mrp_paise': mrpPaise,
    'description': description,
    'unit': unit,
    'image_url': imageUrl,
    'illustration': illustration,
    'is_available': isAvailable,
    'updated_at': updatedAt.toIso8601String(),
  };
}

class MarketSnapshot {
  const MarketSnapshot({
    this.shops = const [],
    this.products = const [],
    this.mandiItems = const [],
    this.mandiRates = const [],
    this.isAdmin = false,
    this.settings = const MarketSettings(),
    this.audit = const [],
    this.orders = const [],
    this.orderLines = const [],
    this.expenses = const [],
    this.publicReviews = const [],
    this.privateReviews = const [],
  });
  final List<Shop> shops;
  final List<Product> products;
  final List<MandiItem> mandiItems;
  final List<MandiRate> mandiRates;
  final bool isAdmin;
  final MarketSettings settings;
  final List<AuditEntry> audit;
  final List<CashOrder> orders;
  final List<OrderLine> orderLines;
  final List<PersonalExpense> expenses;
  final List<OrderReview> publicReviews, privateReviews;
  MarketSnapshot copyWith({List<Shop>? shops, List<Product>? products}) =>
      MarketSnapshot(
        shops: shops ?? this.shops,
        products: products ?? this.products,
        mandiItems: mandiItems,
        mandiRates: mandiRates,
        isAdmin: isAdmin,
        settings: settings,
        audit: audit,
        orders: orders,
        orderLines: orderLines,
        expenses: expenses,
        publicReviews: publicReviews,
        privateReviews: privateReviews,
      );
  factory MarketSnapshot.fromJson(Map<String, dynamic> json) => MarketSnapshot(
    shops: (json['shops'] as List)
        .map((e) => Shop.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    products: (json['products'] as List)
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'shops': shops.map((e) => e.toJson()).toList(),
    'products': products.map((e) => e.toJson()).toList(),
  };
}

class ShopDraft {
  const ShopDraft({
    required this.name,
    required this.category,
    required this.area,
    required this.address,
    required this.phone,
    this.businessType = 'Retailer',
    this.isOpen = true,
    this.offersDelivery = false,
    this.latitude,
    this.longitude,
    this.deliveryBasePaise = 0,
    this.verificationPhotoPath,
    this.description = '',
    this.hours = '',
    this.isPublished = true,
  });
  final String name, category, area, address, phone, description, hours;
  final String businessType;
  final String? verificationPhotoPath;
  final bool isOpen, offersDelivery;
  final double? latitude, longitude;
  final int deliveryBasePaise;
  final bool isPublished;
  Map<String, dynamic> toJson() => {
    'business_type': businessType,
    'is_open': isOpen,
    'offers_delivery': offersDelivery,
    'latitude': latitude,
    'longitude': longitude,
    'delivery_base_paise': deliveryBasePaise,
    if (verificationPhotoPath != null)
      'verification_photo_path': verificationPhotoPath,
    'name': name.trim(),
    'category': category,
    'area': area,
    'address': address.trim(),
    'phone': phone.trim(),
    'description': description.trim(),
    'hours': hours.trim(),
    'is_published': isPublished,
  };
  void validate() {
    if (deliveryBasePaise < 0 ||
        deliveryBasePaise > 10000000 ||
        ((latitude == null) != (longitude == null)) ||
        (latitude != null &&
            (!latitude!.isFinite ||
                !longitude!.isFinite ||
                latitude! < -90 ||
                latitude! > 90 ||
                longitude! < -180 ||
                longitude! > 180)) ||
        (offersDelivery && latitude == null)) {
      throw const MarketException(
        'Choose valid shop coordinates and delivery charges.',
      );
    }
    if (!businessTypes.contains(businessType)) {
      throw const MarketException('Choose retailer or wholesaler.');
    }
    final errors = [
      validateLength(name, 'Shop name', 3, 80),
      validateLength(address, 'Address', 6, 180),
      validatePhone(phone),
      validateLength(description, 'Description', 0, 400),
      validateLength(hours, 'Opening hours', 0, 80),
    ];
    if (!categories.contains(category) || !areas.contains(area)) {
      throw const MarketException('Choose a valid category and Danapur area.');
    }
    for (final error in errors) {
      if (error != null) {
        throw MarketException(error);
      }
    }
  }
}

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.category,
    required this.pricePaise,
    this.mrpPaise,
    this.discountPaise = 0,
    this.deliveryAllowed = false,
    this.deliveryExtraPaise = 0,
    this.description = '',
    this.unit = 'each',
    this.imageUrl,
    this.illustration = 'bag',
    this.isAvailable = true,
  });
  final String name, category, description, unit, illustration;
  final int pricePaise;
  final int? mrpPaise;
  final String? imageUrl;
  final bool deliveryAllowed;
  final int discountPaise, deliveryExtraPaise;
  int get sellingPaise => pricePaise - discountPaise;
  final bool isAvailable;
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'category': category,
    'price_paise': pricePaise,
    'discount_paise': discountPaise,
    'delivery_allowed': deliveryAllowed,
    'delivery_extra_paise': deliveryExtraPaise,
    'mrp_paise': mrpPaise,
    'description': description.trim(),
    'unit': unit.trim(),
    'image_url': imageUrl,
    'illustration': illustration,
    'is_available': isAvailable,
  };
  void validate() {
    if (discountPaise < 0 ||
        discountPaise >= pricePaise ||
        deliveryExtraPaise < 0 ||
        deliveryExtraPaise > 10000000) {
      throw const MarketException(
        'Discount must be below base price; delivery charge must be valid.',
      );
    }
    for (final error in [
      validateLength(name, 'Product name', 3, 100),
      validateLength(description, 'Description', 0, 800),
      validateLength(unit, 'Unit', 1, 32),
    ]) {
      if (error != null) {
        throw MarketException(error);
      }
    }
    if (!categories.contains(category)) {
      throw const MarketException('Choose a valid category.');
    }
    if (pricePaise <= 0 || pricePaise > 100000000) {
      throw const MarketException(
        'Price must be between ₹0.01 and ₹10,00,000.',
      );
    }
    if (mrpPaise != null && (mrpPaise! < pricePaise || mrpPaise! > 100000000)) {
      throw const MarketException(
        'MRP must be at least the selling price, up to ₹10,00,000.',
      );
    }
  }
}

String? validateLength(String? value, String label, int min, int max) {
  final length = (value ?? '').trim().length;
  if (length < min || length > max) {
    return '$label must be $min–$max characters.';
  }
  return null;
}

String? validatePhone(String? value) =>
    RegExp(r'^[6-9]\d{9}$').hasMatch((value ?? '').trim())
    ? null
    : 'Enter a valid 10-digit Indian mobile number.';

int? parsePrice(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(value)) {
    return null;
  }
  final parts = value.split('.');
  final paise =
      int.parse(parts.first) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return paise > 0 && paise <= 100000000 ? paise : null;
}

String priceInput(int paise) =>
    '${paise ~/ 100}${paise % 100 == 0 ? '' : '.${(paise % 100).toString().padLeft(2, '0')}'}';
String money(int paise) {
  var digits = (paise ~/ 100).toString();
  if (digits.length > 3) {
    final tail = digits.substring(digits.length - 3);
    var head = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    groups.insert(0, head);
    digits = '${groups.join(',')},$tail';
  }
  return '₹$digits${paise % 100 == 0 ? '' : '.${(paise % 100).toString().padLeft(2, '0')}'}';
}

class PickedPhoto {
  const PickedPhoto._(this.bytes, this.extension);
  final Uint8List bytes;
  final String extension;
  static const maxBytes = 512 * 1024;
  static PickedPhoto fromBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const MarketException('Choose a photo under 512 KB.');
    }
    String? extension;
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      extension = 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      extension = 'jpeg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      extension = 'webp';
    }
    if (extension == null) {
      throw const MarketException('Use a JPEG, PNG or WebP photo.');
    }
    return PickedPhoto._(bytes, extension);
  }
}

enum ProductSort { newest, priceLow, priceHigh }

List<Product> filterProducts(
  MarketSnapshot snapshot, {
  String query = '',
  String? category,
  String? area,
  ProductSort sort = ProductSort.newest,
  Set<String>? savedIds,
}) {
  final shops = {
    for (final shop in snapshot.shops.where((s) => s.isPublic)) shop.id: shop,
  };
  final words = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty);
  final result = snapshot.products.where((p) {
    final shop = shops[p.shopId];
    if (shop == null ||
        (category != null && p.category != category) ||
        (area != null && shop.area != area) ||
        (savedIds != null && !savedIds.contains(p.id))) {
      return false;
    }
    final text =
        '${p.name} ${p.description} ${p.category} ${shop.name} ${shop.area}'
            .toLowerCase();
    return words.every(text.contains);
  }).toList();
  result.sort(
    (a, b) => switch (sort) {
      ProductSort.newest => b.updatedAt.compareTo(a.updatedAt),
      ProductSort.priceLow => a.sellingPaise.compareTo(b.sellingPaise),
      ProductSort.priceHigh => b.sellingPaise.compareTo(a.sellingPaise),
    },
  );
  return result;
}

Uri whatsappUri(Shop shop, [Product? product]) {
  if (validatePhone(shop.phone) != null) {
    throw const MarketException('The shop contact number is unavailable.');
  }
  final message = product == null
      ? 'Namaste! I found ${shop.name} on Danapur Bazaar. I would like to enquire about your shop.'
      : 'Namaste! I found ${product.name} (${money(product.sellingPaise)} / ${product.unit}) at ${shop.name} on Danapur Bazaar. Is it available?';
  return Uri.https('wa.me', '91${shop.phone}', {'text': message});
}

Uri verificationWhatsappUri(Shop shop, String phone) {
  if (validatePhone(phone) != null) {
    throw const MarketException(
      'The administrator has not configured verification WhatsApp yet. Your request remains pending.',
    );
  }
  return Uri.https('wa.me', '91$phone', {
    'text':
        'Namaste! Danapur Bazaar shop verification.\nRequest: ${shop.id}\nShop: ${shop.name}\nType: ${shop.businessType}\nAddress: ${shop.address}\nRegistered mobile: +91${shop.phone}\nI will attach a current storefront photo showing the shop signboard. Please review my onboarding request.',
  });
}

int? parseCharge(String input) =>
    input.trim().isEmpty || RegExp(r'^0(?:\.0{1,2})?$').hasMatch(input.trim())
    ? 0
    : parsePrice(input);
int? discountFromInput(String input, int basePaise, {bool percent = false}) {
  if (!percent) {
    final value = parseCharge(input);
    return value != null && value < basePaise ? value : null;
  }
  final raw = input.trim();
  if (raw.isEmpty) {
    return 0;
  }
  if (!RegExp(r'^\d{1,2}(?:\.\d{1,2})?$').hasMatch(raw)) {
    return null;
  }
  final parts = raw.split('.');
  final basis =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  if (basis >= 10000) {
    return null;
  }
  return basePaise * basis ~/ 10000;
}
