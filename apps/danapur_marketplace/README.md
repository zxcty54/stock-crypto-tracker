# Danapur Bazaar

Flutter Android/web marketplace for **Danapur, Bihar**: approved retailers/wholesalers, product discovery, cash-only orders, optional 500 m home delivery, personal expenses and admin-controlled mandi rates. Existing StockPulse code/backend/signing remains independent.

## Start here

- [Configuration](config/README.md): Supabase URL/public-key placeholders.
- [Deployment](docs/DEPLOYMENT.md): migrations, auth, admin, signing and launch gates.
- **[Cash commerce & sample testing](docs/CASH_COMMERCE.md)**: delivery/pricing/order/expense/membership contracts and how to test/remove sample records.
- [Folder map](docs/STRUCTURE.md): feature-first source structure.

## Buyer experience

- Responsive, bundled English/Hindi fonts; **icon-grid categories**, popular/all-category views and lowest discounted-item-price sorting.
- Expanded directory including footwear, garments, photography, grocery, furniture, hardware, electronics and more. `Other` covers uncommon businesses; not a claim to list every possible category.
- Search/area/category filters, shop/product details and device-local saved products.
- One-shop cart → cash checkout with base/discount/delivery/handling breakdown; authenticated buyer orders.
- COD home delivery only where **shop + each product opt in**, accurate/recent location supports ≤500 m straight-line eligibility, shop is open/approved and membership allows orders. Otherwise pickup + cash at shop.
- Buyer rating/comment **only after order completion**, one per order, server enforced; public shop feedback only after fair admin moderation. No pre-order/cancelled-order feedback or public customer identity.
- Private order history; buyer or assigned seller completes/cancels open orders. Completion is self-reported, not digitally verified payment.
- Monthly expense manager: completed orders once + editable manual expenses; cancelled/open orders excluded.

## Sellers and administration

- Free onboarding, retailer/wholesaler/both and expanded categories.
- Mandatory private storefront photo and **admin-panel approval**. WhatsApp is optional extra proof/contact, not the source of approval authority.
- Pending/rejected/suspended/hidden shops are not public; identity/location/proof changes trigger review.
- Product base prices, ₹/% discounts, units, optional MRP, per-product delivery eligibility and per-unit handling fee.
- Shop-level delivery opt-in/base fee, foreground shop GPS capture and open/closed-for-orders control.
- Restricted admin: review/reject/suspend, 117 unpriced bilingual common/seasonal fruit/vegetable commodities, dated wholesale/retail rates/ranges/units/history, contact/policy settings and audit activity.
- **₹299/month future membership switch OFF initially**. Admin can later enable policy and manually extend access dates. No online collection, recurring debit or payment receipt. First activation grants 30-day grace; expired access pauses new orders.
- Email confirmation/recovery/deep links, owner-only writes, narrow privileged RPCs, participant-only order/location reads and private expense records.

## Removable samples, same final application

As explicitly requested, blank Supabase values now load **labelled device-local sample records** and explicit buyer/seller/admin test profiles in the same final application structure. The app does not pretend these are live accounts/shared orders or real deliveries. It does not collect credentials for test profiles.

Header/menu → **Sample data / test profiles**. Choose Test buyer for cash checkout, Test seller for delivery/product/order management, Test admin for approval/mandi/membership/sample removal. Admin → Membership & samples removes/restores local test data. Partial/malformed/live backend errors fail clearly, never silently switch to samples.

A configured backend has **no local test-admin bypass**. Optional privileged cloud sample seed is documented separately and uses real confirmed test Auth IDs. Sample shops cannot be contacted as real businesses. Removal selects only tagged sample records, not the production database.

## Builds and Telegram

Pinned Flutter **3.35.7**, Dart **3.9**, Java **17**, Android ID `in.danapur.bazaar`, Android 7+.

```bash
cd apps/danapur_marketplace
flutter pub get --enforce-lockfile
flutter run                         # local labelled sample records if no config
flutter run --dart-define-from-file=config/app_config.json
flutter analyze --fatal-infos
flutter test --coverage
flutter build apk --release --dart-define-from-file=config/app_config.json
```

`.github/workflows/danapur_marketplace.yml` tests actual disposable Postgres policies/idempotency/cash commerce, Flutter/domain/responsive UI and Python configuration/ZIP contracts. It builds **one universal APK** (ARMv7/ARM64/x86_64), wraps it in **danapur-bazaar.zip** and sends it directly to existing Telegram secrets after checks pass. **No upload/download GitHub Actions artifacts or binary commits; PR builds never send Telegram.**

Release optimisation is not production signing: absent dedicated Danapur keystore secrets, the APK is debug-signed for installation testing. Supabase/SMTP/role/GPS/physical-device/legal/operational launch checks still need completion. No online payment gateway, bank integration, courier/ETA guarantee, inventory reservation, multi-shop checkout, formal identity certification or legal/tax certification is silently simulated.
