# Danapur Bazaar — file hierarchy aur modification guide

**App ka root:** `apps/danapur_marketplace/`

Repository root par existing StockPulse app hai. Danapur ko modify karte waqt **is folder ke andar** kaam karo; root ka `lib/`, `android/` ya `pubspec.yaml` Danapur ka nahi hai.

Ye guide current cash checkout, expenses, sample data aur completed-order feedback wale structure ko explain karti hai. Neeche diye hue paths, agar otherwise mention nahi kiya gaya, app root ke relative hain.

## 1. Pehle architecture samjho

- **`presentation/` = screen / UI:** buttons, forms, layout, cards, user interaction.
- **`domain/` = data aur business rules:** Shop/Product/Order models, price validation, discount, distance aur review eligibility.
- **`data/` = data kahan se aata hai:** Supabase reads/writes, local saved items aur explicitly local sample records.
- **`core/` = shared code:** multiple features ko chahiye hone wale models, state, theme, location aur widgets.
- **`supabase/` = actual server rules:** database tables, permissions, safe RPC functions. Important restrictions sirf button hide karke enforce nahi hoti.

```text
App start
  lib/main.dart
    ├─ Supabase URL + public key configured
    │    → SupabaseMarketRepository
    └─ Dono blank
         → labelled SampleRepository (device-local test records)

Screens / forms
  → MarketController (shared state / cart / saved items / reload)
  → MarketRepository methods (kuch screens direct repository method call karti hain)
  → Supabase tables / secure RPCs
  → SQL permission + business checks
  → updated data → controller.reload() → screen refresh
```

**Rule:** UI ka appearance `presentation` mein badlo. Business/security rule ke liye Dart domain **aur SQL server implementation** dono check karo.

## 2. Actual folder hierarchy

```text
apps/danapur_marketplace/
├── README.md                           # app overview aur guides
├── pubspec.yaml                        # dependencies, version, assets/fonts
├── pubspec.lock                        # tested dependency versions; commit it
├── analysis_options.yaml               # Dart lint rules
├── .env.example                        # named build-config placeholders
├── config/
│   ├── README.md                       # configuration steps
│   ├── app_config.example.json         # blank URL/public-key/callback template
│   └── catalog/
│       └── mandi_items.json            # editable bilingual, unpriced catalogue
├── lib/
│   ├── main.dart                       # startup, config validation, repo selection
│   ├── app/
│   │   └── app.dart                    # MaterialApp, routes, home shell/navigation
│   ├── core/
│   │   ├── config/
│   │   │   └── backend_config.dart     # safe public Supabase config guard
│   │   ├── data/
│   │   │   ├── controller.dart         # shared app state, cart, saved IDs, reload
│   │   │   ├── repository.dart         # API contract + real Supabase implementation
│   │   │   └── local_store.dart        # SharedPreferences wrapper / memory test store
│   │   ├── domain/
│   │   │   └── market.dart             # shops/products/categories/prices/validation
│   │   ├── location/
│   │   │   └── location_service.dart   # foreground GPS permission and accurate fix
│   │   ├── theme/
│   │   │   └── app_theme.dart          # colours, typography, Material theme
│   │   └── widgets/
│   │       └── common.dart             # Brand, tags, art, empty states, links, feedback
│   └── features/
│       ├── admin/
│       │   ├── domain/administration.dart
│       │   └── presentation/
│       │       ├── admin_screen.dart   # restricted admin dashboard/sections
│       │       ├── admin_forms.dart    # shop review, mandi rates/items, settings forms
│       │       └── cash_operations.dart # membership switch/access + sample cleanup
│       ├── onboarding/
│       │   ├── data/welcome_preferences.dart # device-local first-launch completion flag
│       │   └── presentation/welcome_screen.dart # intro pages + persistent entry gate
│       ├── auth/
│       │   └── presentation/password_update.dart
│       ├── catalog/
│       │   └── presentation/
│       │       ├── catalog.dart        # product/shop cards, details, purchase actions
│       │       └── category_gallery.dart # responsive category icon grid
│       ├── seller/
│       │   └── presentation/
│       │       ├── seller.dart         # seller dashboard, email auth, open/closed
│       │       ├── forms.dart          # reusable FormSheet + shop/product forms
│       │       └── verification_status.dart # owner-facing approval / optional WhatsApp
│       ├── mandi/
│       │   ├── domain/mandi.dart        # item/rate models, units, IST date helpers
│       │   └── presentation/mandi_screen.dart
│       ├── orders/
│       │   ├── domain/commerce.dart     # cart/order/expense models, quote, distance
│       │   └── presentation/
│       │       ├── cart_checkout.dart  # quantities, fulfilment, GPS, cash totals/order
│       │       └── orders_screen.dart  # buyer/seller order history and status actions
│       ├── expenses/
│       │   └── presentation/expenses_screen.dart
│       ├── account/
│       │   └── presentation/account_screen.dart # in-app account & personal data deletion
│       ├── reports/
│       │   ├── domain/content_report.dart # UGC violation report models
│       │   └── presentation/
│       │       ├── report_dialog.dart # in-app flag/report form for shops, products & reviews
│       │       └── reports_admin_panel.dart # admin investigation & resolution
│       ├── reviews/
│       │   ├── domain/order_review.dart # completed-buyer eligibility / review model
│       │   └── presentation/
│       │       ├── order_feedback.dart # buyer rating form + public shop feedback
│       │       └── review_moderation.dart # admin publish/hide with reason
│       └── samples/
│           ├── data/
│           │   ├── sample_catalogue.dart # fictional shops/products/prices
│           │   ├── sample_mandi.dart    # local commodity list; not invented rates
│           │   └── sample_repository.dart # persistent device-local test operations
│           └── presentation/sample_controls.dart # explicit test profile selection
├── supabase/
│   ├── migrations/
│   │   ├── 001_marketplace.sql         # base shops/products/media/owner permissions
│   │   ├── 002_verified_marketplace.sql # admin, private proof, mandi/settings/audit
│   │   ├── 003_cash_orders_expenses.sql # cash checkout, 500 m, expenses/membership
│   │   └── 004_completed_order_reviews.sql # completed-buyer feedback + moderation
│   ├── seeds/
│   │   ├── 001_mandi_items.sql         # generated real commodity names; NO prices
│   │   └── 900_sample_catalog.example.sql # OPTIONAL tagged cloud TEST catalogue
│   └── admin/
│       └── first_admin.example.sql    # privileged confirmed-user UUID template
├── docs/
│   ├── STRUCTURE.md
│   ├── PLAY_STORE_GUIDE.md             # Play Console compliance, Data Safety & review guide                    # this file: what to change, where
│   ├── DEPLOYMENT.md                   # actual backend/signing/launch setup
│   └── CASH_COMMERCE.md                # ordering/testing/sample-removal contracts
├── tools/
│   ├── create_build_config.py          # safe public config / dedicated signing restore
│   ├── send_apk_to_telegram.py         # validate one APK → ZIP → confirmed Telegram send
│   ├── generate_mandi_catalog.py       # editable JSON → committed commodity seed SQL
│   ├── generate_assets.py              # regenerate original graphics/icons (dependencies needed)
│   └── ci_diagnostics.py               # credential-redacted compiler failure context
├── test/                               # Dart and offline Python regressions
│   ├── support/                        # synthetic test fixtures, NOT imported by lib/
│   └── sql/                            # disposable CI fixtures/security tests, NOT deployment
├── assets/
│   ├── fonts/                          # bundled fonts and their licences
│   ├── illustrations/                  # original product/storefront SVG assets
│   └── brand.svg                       # brand asset; UI Brand is also drawn in common.dart
├── android/                            # Android build, manifest, signing and icons
└── web/                                # Flutter browser/PWA shell; not auto hosting
```

**Build workflow repository root par hai:** `.github/workflows/danapur_marketplace.yml`.

**`config/app_config.json` actual filled file Git-ignored hai.** Template copy karke values bharo; filled configuration commit mat karo. Same tarah actual filled first-admin SQL file ignore ki ja sakti hai—example file mein UUID placeholder hi rakho.

## 3. “Mujhe X change karna hai” — quick lookup

| Change | File(s) jahan se start karo | Important note |
|---|---|---|
| First launch / welcome content / skip / replay | `features/onboarding/presentation/welcome_screen.dart`, `data/welcome_preferences.dart`, `lib/app/app.dart` | Key `danapur.welcome.v1`; no SQL/auth/GPS permission needed for intro. |
| App start / sample vs real backend | `lib/main.dart`, `core/config/backend_config.dart` | Invalid/live errors ko silently samples mein mat badlo. |
| Supabase URL / public key | `config/app_config.json` or named repository Actions secrets | Public/publishable/anon key only; service-role key Flutter mein nahi. Rebuild required. |
| Home layout / navigation / routes | `lib/app/app.dart` | Search, category filter and sort state bhi yahin hai. |
| Category grid layout | `features/catalog/presentation/category_gallery.dart` | Popular tiles aur all-category expansion yahin; category validation elsewhere bhi hai. |
| Categories / areas / retailer-wholesaler options | `core/domain/market.dart` | SQL constraints `001`/`002`/`003` mein mirrored hain; backend bhi update/test karo. |
| Colours / fonts / button theme | `core/theme/app_theme.dart`, `pubspec.yaml` | Font files/licences `assets/fonts/`; metadata/version aur licence screen consistent rakho. |
| Brand name / UI logo | `core/widgets/common.dart` (`Brand`) | Android label/icons aur web manifest alag files hain. |
| Product/shop cards and detail page | `features/catalog/presentation/catalog.dart` | Listed unit, discount and pickup/delivery condition clear rakho. |
| Seller signup / login / dashboard | `features/seller/presentation/seller.dart` | Auth provider calls real repository mein hain. |
| Shop onboarding / product form fields | `features/seller/presentation/forms.dart` | New field model → repository → SQL → sample repo → tests tak carry karo. |
| Password recovery screen | `features/auth/presentation/password_update.dart` | Actual email/redirect/update calls `core/data/repository.dart`; SMTP setup outside app. |
| Buyer cart / checkout UI | `features/orders/presentation/cart_checkout.dart` | Final totals/eligibility server par rechecked hain. |
| Cart add/remove / quantity / saved state | `core/data/controller.dart` | UI changes ke baad notify/reload; no location stored in the cart. |
| Base price / discount / fee validation | `core/domain/market.dart` | Integer paise use hote hain, money calculation ke liye floating ₹ values mat use karo. |
| Quote / 500 m math | `features/orders/domain/commerce.dart` | Actual order checks `003_cash_orders_expenses.sql` mein bhi same rule enforce karte hain. |
| GPS / permission / accuracy | `core/location/location_service.dart` | Android manifest permissions bhi check karo; background tracking nahi. |
| Shop open/closed | `seller.dart`, shop model/repository | Closed status new orders rokta hai; existing orders auto-cancel nahi hote. |
| Order complete / cancel / accept / ready UI | `features/orders/presentation/orders_screen.dart` | Server transition/party checks `003` mein hain; buttons alone authority nahi. |
| Expense UI / monthly totals | `features/expenses/presentation/expenses_screen.dart` | Order-linked expense server completion RPC se exactly once; manual records alag. |
| Review sirf completed order par | `reviews/domain/order_review.dart`, `reviews/presentation/order_feedback.dart` | `004_completed_order_reviews.sql` is the server authority; cancelled orders allowed nahi. |
| Public review display / admin moderation | `order_feedback.dart`, `review_moderation.dart` | Customer/order identity fields public view mein mat add karo; free text operator inspect kare. |
| Admin screen / new admin section | `features/admin/presentation/admin_screen.dart` | UI admin visibility ke saath actual server privilege checks zaroori hain. |
| Shop approval / mandi rate / settings forms | `features/admin/presentation/admin_forms.dart` | RPC contracts real repository aur SQL mein mapped hain. |
| ₹299 membership switch / access dates | `cash_operations.dart`, `MarketSettings`, SQL `003` | Switch OFF initially; enabling does not collect money. |
| WhatsApp number / support / policy links | **Admin → Settings** | Data `market_settings` mein; code mein token/mobile hard-code mat karo. |
| Mandi commodity names | `config/catalog/mandi_items.json` | `tools/generate_mandi_catalog.py` se seed regenerate; local sample list separate hai. |
| Mandi price UI / units / date labels | `features/mandi/presentation/mandi_screen.dart`, `domain/mandi.dart` | Rates admin enters; old/unpriced records ko current/invented price mat dikhao. |
| Fictional sample products/prices | `features/samples/data/sample_catalogue.dart` | Explicit sample labels and no real contacts. |
| Sample data operations / persistence / test profiles | `features/samples/data/sample_repository.dart` | Same UI/domain, but device-local only; configured Supabase backend has no test-admin switch. |
| Sample removal / restore buttons | `cash_operations.dart`, `sample_controls.dart` | Cloud cleanup RPC targets only tagged records, not real data. |
| Supabase reads / writes / RPC mapping | `core/data/repository.dart` | `MarketRepository` interface + `SupabaseMarketRepository`; no secrets in UI. |
| Android app ID / SDK / signing | `android/app/build.gradle.kts` | Don't reuse StockPulse signing secrets. |
| Android name / permissions / auth callback | `android/app/src/main/AndroidManifest.xml` | Main activity under `.../kotlin/in/danapur/bazaar/MainActivity.kt`. |
| Android launcher icon | `android/app/src/main/res/mipmap-*/ic_launcher.png` | Web icons separate; use asset generator carefully. |
| Web title / PWA icons / bootstrap | `web/index.html`, `web/manifest.json`, `web/icons/`, `web/flutter_bootstrap.js` | No automatic web deployment is configured. |
| App version / dependencies | `pubspec.yaml`, `pubspec.lock` | Dependency changes ke baad genuine Flutter `pub get` and tested lock commit karo. |
| APK build / ZIP / Telegram delivery | root `.github/workflows/danapur_marketplace.yml`, `tools/send_apk_to_telegram.py` | One universal APK inside ZIP; no Actions artifacts; PR builds never send. |

## 4. Feature data-flow examples

### Product price / delivery setting

```text
Seller ProductForm (forms.dart)
  → ProductDraft validation (market.dart)
  → MarketController.saveProduct (controller.dart)
  → MarketRepository.saveProduct (repository.dart)
  → Supabase products table + owner RLS / price constraints
  → updated snapshot → buyer card / checkout
```

### Cash order

```text
CartCheckoutScreen
  → local quoteCart preview + requested foreground GPS
  → repository.placeCashOrder
  → SQL place_cash_order RPC (003)
       validates shop, buyer, current prices, per-product delivery and radius
  → server-owned immutable order + lines
  → reload → OrdersScreen
  → completion RPC → exactly one private buyer expense
```

### Completed-order feedback

```text
Completed buyer order → OrderFeedbackPanel / form
  → canLeaveOrderReview / validateOrderReview
  → repository.submitOrderReview
  → SQL submit_completed_review (004)
       checks completed status, actual buyer and unique order
  → pending private review
  → admin moderation RPC
  → sanitized public_shop_reviews projection
  → ShopFeedbackSection
```

### Samples

`lib/main.dart` sirf **dono backend values blank** hone par `SampleRepository` select karta hai. Usmein same repository methods/UI run hoti hai, par records device-local aur test-labelled hain. Supabase configured ho to real Auth, tables aur server RPCs use hote hain. Sample profile selection real backend admin privileges nahi deta.

## 5. Safe modification checklist

1. Apne change ki UI file aur relevant model/domain identify karo.
2. Data field ya business/security rule badal rahe ho to real repository **aur SQL migration/RPC** bhi check karo.
3. Sample repository ko equivalent test behaviour do; sample labels/clear controls preserve karo.
4. Affected Dart/domain/widget/SQL tests update/add karo.
5. App root se checks run karo:

   ```bash
   cd apps/danapur_marketplace
   flutter pub get --enforce-lockfile
   dart format lib test
   flutter analyze --fatal-infos
   flutter test --coverage
   python3 -m unittest discover -s test -p '*_test.py' -v
   ```

6. Database fixture tests sirf disposable CI database mein run hote hain. `test/sql/fixture.sql` real Supabase par **kabhi run mat karo**.
7. Existing deployed project ke liye **new numbered migration** prefer karo (next `005_...sql`), rather than silently changing an already-applied schema. New migration ko deployment guide aur CI order/idempotency tests mein include karo.
8. No online payment/verified-cash claims, customer privacy, 500 m delivery gates, pending-shop visibility aur completed-only feedback enforce hone chahiye.

## 6. Data rules ke liye matching test files

| Behaviour | Tests |
|---|---|
| Shop/product currency, ownership, filters, saved items | `test/market_test.dart` |
| Approval/business types/settings/mandi contracts | `test/production_test.dart` |
| Cart, fees, distance, cash order/expense/membership/sample operations | `test/commerce_test.dart` |
| Welcome persistence, skip/replay, recovery bypass, deep routes, landscape/large text | `test/welcome_test.dart` |
| Existing responsive seller/catalogue/admin layout | `test/widget_test.dart` |
| Actual sample cash checkout → completion → expense; category grid | `test/commerce_widget_test.dart` |
| Completed-only buyer review, uniqueness, public projection, local persistence | `test/reviews_test.dart` |
| Mobile feedback submission / public display privacy | `test/reviews_widget_test.dart` |
| Supabase-compatible disposable auth/storage setup | `test/sql/fixture.sql` — CI ONLY |
| Shop/admin/private-media policy regressions | `test/sql/rls_test.sql` |
| Server cash pricing, radius, privacy, expenses and membership | `test/sql/commerce_test.sql` |
| No early/cancelled/other-party reviews, moderation and public privacy | `test/sql/reviews_test.sql` |
| Safe config / catalogue contracts / credential-safe Telegram ZIP | `test/*_test.py` |

**Shuru karne ka best order:** `README.md` → ye guide → `lib/main.dart` → `lib/app/app.dart` → jis feature ko modify karna hai uska `presentation` → related `domain`/repository → SQL.
