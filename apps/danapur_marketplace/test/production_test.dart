import 'package:flutter_test/flutter_test.dart';
import 'package:danapur_marketplace/core/domain/market.dart';
import 'package:danapur_marketplace/core/config/backend_config.dart';
import 'package:danapur_marketplace/features/mandi/domain/mandi.dart';
import 'package:danapur_marketplace/features/admin/domain/administration.dart';

Shop shop({String status = 'pending', bool published = true}) => Shop(
  id: '11111111-1111-4111-8111-111111111111',
  ownerId: 'owner',
  name: 'Actual application shop',
  category: 'Hardware',
  area: 'Danapur Bazaar',
  address: 'Test storefront address',
  phone: '9999999999',
  updatedAt: DateTime.utc(2026, 10, 10),
  reviewStatus: status,
  isPublished: published,
  businessType: 'Wholesaler',
  verificationPhotoPath: 'owner/front.jpeg',
);

void main() {
  test('new shops default to pending even when publication is enabled', () {
    expect(shop().isPublic, false);
    expect(shop(status: 'approved').isPublic, true);
    expect(shop(status: 'approved', published: false).isPublic, false);
  });
  test('all non-approved statuses are hidden from product discovery', () {
    final product = Product(
      id: 'p',
      shopId: shop().id,
      name: 'Test tool',
      category: 'Hardware',
      pricePaise: 1234,
      updatedAt: DateTime.utc(2026),
    );
    for (final status in ['pending', 'rejected', 'suspended']) {
      expect(
        filterProducts(
          MarketSnapshot(
            shops: [shop(status: status)],
            products: [product],
          ),
        ),
        isEmpty,
      );
    }
    expect(
      filterProducts(
        MarketSnapshot(
          shops: [shop(status: 'approved')],
          products: [product],
        ),
      ),
      hasLength(1),
    );
  });
  test('retailer wholesaler and both are valid business types', () {
    for (final type in businessTypes) {
      ShopDraft(
        name: 'Test shop',
        category: 'Furniture',
        area: 'Danapur Bazaar',
        address: 'Test shop address',
        phone: '9999999999',
        businessType: type,
      ).validate();
    }
  });
  test('invalid business type cannot be submitted', () {
    expect(
      () => const ShopDraft(
        name: 'Test shop',
        category: 'Hardware',
        area: 'Danapur Bazaar',
        address: 'Test shop address',
        phone: '9999999999',
        businessType: 'Unrecognised',
      ).validate(),
      throwsA(isA<MarketException>()),
    );
  });
  test('expanded shop categories include hardware furniture and produce', () {
    expect(
      categories,
      containsAll([
        'Hardware',
        'Furniture',
        'Fresh produce',
        'Electrical',
        'Building materials',
        'Books & stationery',
      ]),
    );
  });
  test(
    'verification WhatsApp encodes full request ID and business contact',
    () {
      final uri = verificationWhatsappUri(shop(), '8888888888');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/918888888888');
      expect(uri.queryParameters['text'], contains(shop().id));
      expect(uri.queryParameters['text'], contains('Wholesaler'));
      expect(uri.queryParameters['text'], contains('attach'));
    },
  );
  test('missing operator WhatsApp is not simulated', () {
    expect(
      () => verificationWhatsappUri(shop(), ''),
      throwsA(isA<MarketException>()),
    );
  });
  test('shop review and business fields survive serialization', () {
    final restored = Shop.fromJson(shop(status: 'approved').toJson());
    expect(restored.reviewStatus, 'approved');
    expect(restored.verificationPhotoPath, 'owner/front.jpeg');
    expect(restored.businessType, 'Wholesaler');
  });
  test('blank config permits explicit local sample records', () {
    expect(validateBackendConfig('', ''), isNull);
  });
  test('mandi dates use explicit yyyy-mm-dd values', () {
    expect(mandiDateKey(DateTime(2026, 2, 3)), '2026-02-03');
  });
  test('only prices actually dated today are current', () {
    final today = indiaNow();
    MandiRate rate(DateTime date) => MandiRate(
      id: 'r',
      itemId: 'potato',
      priceType: 'wholesale',
      unit: 'kg',
      minPaise: 2000,
      maxPaise: 2500,
      effectiveDate: date,
      updatedAt: DateTime.now(),
    );
    expect(rate(today).isToday, true);
    expect(rate(today.subtract(const Duration(days: 1))).isToday, false);
  });
  test(
    'snapshot mutations preserve administrator mandi and settings state',
    () {
      final original = MarketSnapshot(
        isAdmin: true,
        settings: const MarketSettings(verificationPhone: '8888888888'),
        mandiItems: const [
          MandiItem(
            id: 'potato',
            name: 'Potato',
            hindiName: 'आलू',
            category: 'Vegetables',
          ),
        ],
      );
      final changed = original.copyWith(shops: [shop()]);
      expect(changed.isAdmin, true);
      expect(changed.settings.verificationPhone, '8888888888');
      expect(changed.mandiItems.single.hindiName, 'आलू');
    },
  );
}
