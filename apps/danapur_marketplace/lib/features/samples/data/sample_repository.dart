import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/data/local_store.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../admin/domain/administration.dart';
import '../../mandi/domain/mandi.dart';
import '../../orders/domain/commerce.dart';
import 'sample_catalogue.dart';

// Same application/domain/UI; explicitly device-local TEST records, not live orders.
class SampleRepository extends MarketRepository {
  SampleRepository(this.store) {
    final saved = store.read(key);
    if (saved != null) {
      try {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        _shops = (data['shops'] as List)
            .map((x) => Shop.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList();
        _products = (data['products'] as List)
            .map((x) => Product.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList();
        _orders = (data['orders'] as List)
            .map((x) => CashOrder.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList();
        _lines = (data['lines'] as List)
            .map((x) => OrderLine.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList();
        _expenseRows = (data['expenses'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        _proofs = Map<String, String>.from(data['proofs'] as Map? ?? {});
        _settings = MarketSettings.fromJson(
          Map<String, dynamic>.from(data['settings'] as Map? ?? {}),
        );
        _role = data['role'] as String? ?? 'buyer';
        _commodities = (data['commodities'] as List? ?? [])
            .map(
              (row) =>
                  MandiItem.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        if (_commodities.isEmpty) {
          _commodities = sampleCatalogue().mandiItems;
        }
        _rates = (data['rates'] as List? ?? [])
            .map(
              (row) =>
                  MandiRate.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        _requests = Map<String, String>.from(data['requests'] as Map? ?? {});
      } catch (_) {
        _seed();
      }
    } else {
      _seed();
    }
  }
  final LocalStore store;
  static const key = 'danapur.sample.v2';
  final _events = StreamController<void>.broadcast();
  List<Shop> _shops = [];
  List<Product> _products = [];
  List<CashOrder> _orders = [];
  List<OrderLine> _lines = [];
  List<Map<String, dynamic>> _expenseRows = [];
  List<MandiItem> _commodities = sampleCatalogue().mandiItems;
  List<MandiRate> _rates = [];
  Map<String, String> _proofs = {};
  Map<String, String> _requests = {};
  String _role = 'buyer';
  MarketSettings _settings = const MarketSettings();
  void _seed() {
    final seed = sampleCatalogue();
    _shops = seed.shops;
    _products = seed.products;
    _orders = [];
    _lines = [];
    _expenseRows = [];
    _commodities = sampleCatalogue().mandiItems;
    _rates = [];
    _proofs = {};
    _requests = {};
    _settings = const MarketSettings();
  }

  @override
  void dispose() {
    unawaited(_events.close());
  }

  @override
  bool get sampleProfilesEnabled => true;
  @override
  String? get ownerId => _role == 'signed-out' ? null : 'sample-$_role';
  @override
  Stream<void> get authChanges => _events.stream;
  void _staff() {
    if (_role != 'admin') {
      throw const MarketException(
        'Choose the explicit local test admin profile. Live admin roles require Supabase.',
      );
    }
  }

  Future<void> _persist() async {
    await store.write(
      key,
      jsonEncode({
        'shops': _shops.map((s) => s.toJson()).toList(),
        'products': _products.map((p) => p.toJson()).toList(),
        'orders': _orders.map((o) => o.toJson()).toList(),
        'lines': _lines.map((l) => l.toJson()).toList(),
        'expenses': _expenseRows,
        'proofs': _proofs,
        'settings': {
          'verification_phone': _settings.verificationPhone,
          'support_email': _settings.supportEmail,
          'privacy_url': _settings.privacyUrl,
          'terms_url': _settings.termsUrl,
          'billing_enabled': _settings.billingEnabled,
          'billing_started_at': _settings.billingStartedAt?.toIso8601String(),
          'mandi_name': _settings.mandiName,
        },
        'role': _role,
        'commodities': _commodities
            .map(
              (item) => {
                'id': item.id,
                'name': item.name,
                'hindi_name': item.hindiName,
                'category': item.category,
                'default_unit': item.defaultUnit,
                'is_active': item.active,
              },
            )
            .toList(),
        'rates': _rates
            .map(
              (rate) => {
                'id': rate.id,
                'item_id': rate.itemId,
                'price_type': rate.priceType,
                'unit': rate.unit,
                'min_paise': rate.minPaise,
                'max_paise': rate.maxPaise,
                'effective_date': mandiDateKey(rate.effectiveDate),
                'updated_at': rate.updatedAt.toIso8601String(),
                'note': rate.note,
              },
            )
            .toList(),
        'requests': _requests,
      }),
    );
  }

  @override
  Future<MarketSnapshot> load() async {
    final visibleOrders = _orders
        .where((o) => o.buyerId == ownerId || o.sellerId == ownerId)
        .toList();
    final ids = visibleOrders.map((o) => o.id).toSet();
    return MarketSnapshot(
      shops: _shops,
      products: _products,
      isAdmin: _role == 'admin',
      settings: _settings,
      mandiItems: _commodities,
      mandiRates: _rates,
      orders: visibleOrders,
      orderLines: _lines.where((l) => ids.contains(l.orderId)).toList(),
      expenses: _expenseRows
          .where((e) => e['user_id'] == ownerId)
          .map(PersonalExpense.fromJson)
          .toList(),
    );
  }

  @override
  Future<void> useSampleProfile(String role) async {
    if (!['buyer', 'seller', 'admin'].contains(role)) {
      throw const MarketException('Choose a test profile.');
    }
    _role = role;
    await _persist();
    _events.add(null);
  }

  @override
  Future<void> restoreSampleData() async {
    _staff();
    _seed();
    await _persist();
  }

  @override
  Future<void> removeSampleData() async {
    _staff();
    _shops = [];
    _products = [];
    _orders = [];
    _lines = [];
    _expenseRows = [];
    _commodities = sampleCatalogue().mandiItems;
    _rates = [];
    _proofs = {};
    _requests = {};
    await _persist();
  }

  @override
  Future<Shop> saveShop(ShopDraft draft, {String? id}) async {
    draft.validate();
    if (ownerId == null) {
      throw const MarketException('Choose a test profile first.');
    }
    final existing = _shops.where((s) => s.ownerId == ownerId).firstOrNull;
    if (id == null && existing != null || id != null && existing?.id != id) {
      throw const MarketException(
        'One shop per owner; edit only your own shop.',
      );
    }
    final shop = Shop.fromJson({
      ...draft.toJson(),
      'id': id ?? const Uuid().v4(),
      'owner_id': ownerId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'review_status': 'pending',
      'is_sample': true,
    });
    _shops = [..._shops.where((s) => s.id != shop.id), shop];
    await _persist();
    return shop;
  }

  @override
  Future<Product> saveProduct(
    String shopId,
    ProductDraft draft, {
    String? id,
  }) async {
    draft.validate();
    if (!_shops.any((s) => s.id == shopId && s.ownerId == ownerId)) {
      throw const MarketException('Only the shop owner can edit products.');
    }
    if (id != null && !_products.any((p) => p.id == id && p.shopId == shopId)) {
      throw const MarketException('Product not owned by this shop.');
    }
    final product = Product.fromJson({
      ...draft.toJson(),
      'id': id ?? const Uuid().v4(),
      'shop_id': shopId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    _products = [..._products.where((p) => p.id != product.id), product];
    await _persist();
    return product;
  }

  @override
  Future<void> deleteProduct(Product product) async {
    if (!_shops.any((s) => s.id == product.shopId && s.ownerId == ownerId)) {
      throw const MarketException('Only the owner can delete products.');
    }
    _products.removeWhere((p) => p.id == product.id);
    await _persist();
  }

  @override
  Future<void> deleteShop(Shop shop) async {
    if (shop.ownerId != ownerId) {
      throw const MarketException('Only the owner can delete the shop.');
    }
    _shops.removeWhere((s) => s.id == shop.id);
    _products.removeWhere((p) => p.shopId == shop.id);
    await _persist();
  }

  @override
  Future<String> uploadPhoto(PickedPhoto photo) async =>
      'data:image/${photo.extension};base64,${base64Encode(photo.bytes)}';
  @override
  Future<void> removePhoto(String? url) async {}
  @override
  Future<String> uploadVerificationPhoto(PickedPhoto photo) async {
    final path = '$ownerId/${const Uuid().v4()}.${photo.extension}';
    _proofs[path] = await uploadPhoto(photo);
    await _persist();
    return path;
  }

  @override
  Future<String> verificationPhotoUrl(String path) async =>
      _proofs[path] ??
      (throw const MarketException(
        'Sample shop has no real storefront photo.',
      ));
  @override
  Future<void> removeVerificationPhoto(String path) async {
    _proofs.remove(path);
    await _persist();
  }

  @override
  Future<void> reviewShop(
    String id,
    String decision,
    String note,
    bool checked,
  ) async {
    _staff();
    final shop = _shops.where((s) => s.id == id).first;
    if (decision == 'approved' &&
        (!checked || shop.verificationPhotoPath == null)) {
      throw const MarketException('Review the private photo and proof first.');
    }
    _shops = _shops
        .map(
          (s) => s.id == id
              ? Shop.fromJson({
                  ...s.toJson(),
                  'review_status': decision,
                  'review_note': note,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
              : s,
        )
        .toList();
    await _persist();
  }

  @override
  Future<void> setShopOpen(Shop shop, bool open) async {
    if (shop.ownerId != ownerId) {
      throw const MarketException('Only owner can change opening status.');
    }
    _shops = _shops
        .map(
          (s) => s.id == shop.id
              ? Shop.fromJson({...s.toJson(), 'is_open': open})
              : s,
        )
        .toList();
    await _persist();
  }

  @override
  Future<String> placeCashOrder(
    String shopId,
    List<CartLine> items,
    String mode,
    String name,
    String phone,
    String address,
    GeoFix? fix,
    String requestId,
  ) async {
    if (ownerId == null) {
      throw const MarketException('Choose the sample buyer profile.');
    }
    final requestKey = '$ownerId/$requestId';
    if (_requests.containsKey(requestKey)) {
      return _requests[requestKey]!;
    }
    final quote = quoteCart(await load(), items, mode, fix);
    if (quote.shop.ownerId == ownerId) {
      throw const MarketException(
        'Use the buyer test profile, not the owner, to order.',
      );
    }
    for (final error in [
      validateLength(name, 'Name', 2, 80),
      validatePhone(phone),
      validateLength(address, 'Address', 6, 300),
    ]) {
      if (error != null) {
        throw MarketException(error);
      }
    }
    final id = const Uuid().v4(), now = DateTime.now().toUtc();
    _orders.add(
      CashOrder(
        id: id,
        buyerId: ownerId,
        sellerId: quote.shop.ownerId,
        shopId: shopId,
        shopName: quote.shop.name,
        shopCategory: quote.shop.category,
        customerName: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
        fulfilment: mode,
        distance: quote.distance,
        subtotalPaise: quote.subtotal,
        discountPaise: quote.discount,
        deliveryPaise: quote.delivery,
        totalPaise: quote.total,
        status: 'placed',
        createdAt: now,
        updatedAt: now,
        isSample: true,
      ),
    );
    for (final item in items) {
      final p = _products.firstWhere((p) => p.id == item.productId);
      _lines.add(
        OrderLine(
          id: const Uuid().v4(),
          orderId: id,
          name: p.name,
          category: p.category,
          unit: p.unit,
          quantity: item.quantity,
          basePaise: p.pricePaise,
          discountPaise: p.discountPaise,
          deliveryExtraPaise: mode == 'delivery' ? p.deliveryExtraPaise : 0,
        ),
      );
    }
    _requests[requestKey] = id;
    await _persist();
    return id;
  }

  @override
  Future<void> changeOrder(CashOrder order, String status, String note) async {
    final current = _orders.firstWhere((o) => o.id == order.id);
    if (ownerId != current.buyerId && ownerId != current.sellerId) {
      throw const MarketException(
        'Only the buyer or seller can update an order.',
      );
    }
    if (current.closed) {
      if (current.status == status) {
        return;
      }
      throw const MarketException('Closed orders cannot change.');
    }
    if (['accepted', 'ready'].contains(status) && ownerId != current.sellerId) {
      throw const MarketException('Only seller can accept or prepare.');
    }
    if (!['accepted', 'ready', 'completed', 'cancelled'].contains(status) ||
        validateLength(note, 'Note', 3, 300) != null) {
      throw const MarketException('Choose a valid action and note.');
    }
    _orders = _orders
        .map(
          (o) => o.id == current.id
              ? CashOrder.fromJson({
                  ...o.toJson(),
                  'status': status,
                  'status_note': note,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
              : o,
        )
        .toList();
    if (status == 'completed' &&
        !_expenseRows.any((e) => e['order_id'] == current.id)) {
      _expenseRows.add({
        'id': const Uuid().v4(),
        'user_id': current.buyerId,
        'order_id': current.id,
        'amount_paise': current.totalPaise,
        'category': current.shopCategory,
        'note': 'Sample order at ${current.shopName}',
        'spent_on': mandiDateKey(indiaNow()),
        'is_sample': true,
      });
    }
    await _persist();
  }

  @override
  Future<void> saveExpense(
    String? id,
    int paise,
    String category,
    String note,
    DateTime date,
  ) async {
    if (ownerId == null ||
        paise <= 0 ||
        paise > 1000000000 ||
        category.trim().isEmpty ||
        mandiDateKey(date).compareTo(mandiDateKey(indiaNow())) > 0) {
      throw const MarketException(
        'Choose a valid expense and past/today date.',
      );
    }
    if (id != null &&
        !_expenseRows.any(
          (e) =>
              e['id'] == id && e['user_id'] == ownerId && e['order_id'] == null,
        )) {
      throw const MarketException('Only your manual expenses can be edited.');
    }
    _expenseRows.removeWhere((e) => e['id'] == id);
    _expenseRows.add({
      'id': id ?? const Uuid().v4(),
      'user_id': ownerId,
      'amount_paise': paise,
      'category': category,
      'note': note,
      'spent_on': date.toIso8601String().split('T').first,
      'is_sample': true,
    });
    await _persist();
  }

  @override
  Future<void> deleteExpense(PersonalExpense expense) async {
    if (!_expenseRows.any(
      (e) =>
          e['id'] == expense.id &&
          e['user_id'] == ownerId &&
          e['order_id'] == null,
    )) {
      throw const MarketException('Only your manual expenses can be deleted.');
    }
    _expenseRows.removeWhere((e) => e['id'] == expense.id);
    await _persist();
  }

  @override
  Future<void> configureBilling(bool enabled) async {
    _staff();
    _settings = MarketSettings(
      billingEnabled: enabled,
      billingStartedAt: _settings.billingStartedAt ?? DateTime.now(),
      verificationPhone: _settings.verificationPhone,
    );
    await _persist();
  }

  @override
  Future<void> extendMembership(Shop shop, DateTime until, String note) async {
    _staff();
    _shops = _shops
        .map(
          (s) => s.id == shop.id
              ? Shop.fromJson({
                  ...s.toJson(),
                  'paid_through': until.toUtc().toIso8601String(),
                })
              : s,
        )
        .toList();
    await _persist();
  }

  @override
  Future<void> setSettings(MarketSettings settings) async {
    _staff();
    _settings = MarketSettings(
      verificationPhone: settings.verificationPhone,
      supportEmail: settings.supportEmail,
      privacyUrl: settings.privacyUrl,
      termsUrl: settings.termsUrl,
      mandiName: settings.mandiName,
      billingEnabled: _settings.billingEnabled,
      billingStartedAt: _settings.billingStartedAt,
    );
    await _persist();
  }

  @override
  Future<void> setMandiRate(
    MandiItem item,
    String type,
    String unit,
    int min,
    int max,
    DateTime date,
    String note,
  ) async {
    _staff();
    if (!mandiPriceTypes.contains(type) ||
        !mandiUnits.contains(unit) ||
        min < 1 ||
        max < min ||
        max > 100000000 ||
        mandiDateKey(date).compareTo(mandiDateKey(indiaNow())) > 0) {
      throw const MarketException('Use valid prices, unit and market date.');
    }
    final rate = MandiRate(
      id: const Uuid().v4(),
      itemId: item.id,
      priceType: type,
      unit: unit,
      minPaise: min,
      maxPaise: max,
      effectiveDate: date,
      updatedAt: DateTime.now().toUtc(),
      note: note,
    );
    _rates = [
      ..._rates.where((r) => r.itemId != item.id || r.priceType != type),
      rate,
    ];
    await _persist();
  }

  @override
  Future<void> addMandiItem(
    String id,
    String name,
    String hindi,
    String category,
    String unit,
  ) async {
    _staff();
    if (_commodities.any((item) => item.id == id) ||
        !RegExp(r'^[a-z][a-z0-9_-]{1,49}$').hasMatch(id) ||
        !['Vegetables', 'Fruits'].contains(category) ||
        !mandiUnits.contains(unit)) {
      throw const MarketException('Use a unique valid commodity and unit.');
    }
    _commodities = [
      ..._commodities,
      MandiItem(
        id: id,
        name: name,
        hindiName: hindi,
        category: category,
        defaultUnit: unit,
      ),
    ];
    await _persist();
  }

  @override
  Future<bool> signUp(
    String email,
    String password,
  ) async => throw const MarketException(
    'Configure Supabase for real accounts. Use explicit test profiles without entering credentials.',
  );
  @override
  Future<void> signIn(
    String email,
    String password,
  ) async => throw const MarketException(
    'Configure Supabase for real accounts. Use explicit test profiles without entering credentials.',
  );
  @override
  Future<void> signOut() async {
    _role = 'signed-out';
    await _persist();
    _events.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    throw const MarketException(
      'This is a local test profile, not an Auth account. Remove sample data from the sample-data controls.',
    );
  }
}
