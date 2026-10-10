# Danapur Bazaar

An independent Flutter marketplace MVP for **Danapur, Bihar**. The existing StockPulse application at the repository root is not replaced or connected to this app.

## Included

- Responsive Android + web interface with local fonts and original illustrations.
- Product/shop search, category and neighbourhood filters, price sorting.
- Shop pages and product detail pages (`/#/shop/<id>`, `/#/product/<id>`).
- Saved products persisted on the current device, without buyer login.
- One shop per seller, editable business profile, publish/unpublish and shop deletion.
- Product creation/editing/deletion, exact integer-paise prices, optional MRP, units, stock status.
- Gallery photo upload (JPEG/PNG/WebP, maximum 512 KB), or a clearly labelled illustration.
- Direct WhatsApp/call enquiry and Google Maps directions for real seller-entered details.
- Separate Supabase database/auth/storage integration with owner-only row-level-security policies.
- GitHub Actions: analysis, unit/widget tests, disposable Postgres security tests, web and Android APK artifacts.

**No cart, order processing, payments, delivery, verified-seller badges or paid promotion.** Those are not silently simulated.

## Two explicit modes

### 1. Local demo — no credentials required

Both Supabase configuration values empty → demo mode. All bundled shops/products/prices are fictional examples. Example shops have no callable phone number. A demo seller can create a shop and manage products, but changes stay on that browser/device. They are **not shared with other users**. Use the menu → Reset demo to clear them.

### 2. Shared cloud marketplace

Use a **dedicated Supabase project**, not the StockPulse backend.

1. Run [`supabase/001_marketplace.sql`](supabase/001_marketplace.sql) in Supabase SQL Editor. It creates `shops`, `products`, RLS policies, server-owned timestamps and a `catalog-media` bucket. It intentionally inserts **no sample listings**.
2. Enable Email/Password authentication and keep email confirmation enabled. Configure your deployed web URL as the Auth Site URL and allowed redirect URL. Sellers create an account, confirm the email, and sign in. An email confirmation is **not business verification**.
3. Use the project HTTPS URL and **public anon/publishable key**. Never use `service_role` or `sb_secret_…`; the configuration checks reject them.
4. In GitHub repository Settings → Secrets and variables → Actions, add:
   - `DANAPUR_SUPABASE_URL`
   - `DANAPUR_SUPABASE_ANON_KEY`
5. Push app changes or run the **Danapur Marketplace — Flutter builds** workflow on the working branch.

Partial configuration fails explicitly. A cloud error never falls back to fictional demo shops. Buyers need no account; sellers can only modify their own shop/products. Unpublished shops/products are visible only to their owner. Images are intentionally public, even if their shop is unpublished and someone already knows the image URL—do not upload private documents.

Listings load in snapshots; buyers refresh to see new prices. This MVP is not a realtime inventory guarantee. Contact the seller to confirm price/stock before buying.

## Local development

Pinned CI toolchain: **Flutter 3.35.7, Dart 3.9, JDK 17**, Android application ID `in.danapur.bazaar`, Android 7+.

```bash
cd apps/danapur_marketplace
flutter pub get
flutter run -d chrome             # local demo
flutter run                      # attached Android device
flutter analyze --fatal-infos
flutter test --coverage
flutter build web --release --no-web-resources-cdn
flutter build apk --release --split-per-abi
```

For cloud builds, create an **ignored** local configuration JSON (do not commit it) and pass:

```bash
flutter run -d chrome --dart-define-from-file=.env.local.json
```

```json
{
  "DANAPUR_SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",
  "DANAPUR_SUPABASE_ANON_KEY": "YOUR-PUBLIC-ANON-OR-PUBLISHABLE-KEY"
}
```

Serve compiled web assets with any static host. The default build uses `/` as base URL. For GitHub Pages under a repository path, build with `--base-href /stock-crypto-tracker/`. The workflow uploads artifacts; **it does not enable or overwrite an existing GitHub Pages site**.

## GitHub Actions APKs and signing

The workflow is scoped to `apps/danapur_marketplace/**`, and does not use StockPulse's keystore, Telegram bot or backend secrets. It builds separate ARM32, ARM64 and x86_64 APKs. Download the `danapur-bazaar-apks` artifact; ARM64 suits most recent Android phones.

By default, release-optimised APKs are **debug-signed for testing**, not Play Store publication. For release signing, configure dedicated secrets in GitHub (never in chat or Git):

- `DANAPUR_ANDROID_KEYSTORE_BASE64`
- `DANAPUR_KEYSTORE_PASSWORD`
- `DANAPUR_KEY_ALIAS`
- `DANAPUR_KEY_PASSWORD`

All four must be supplied together. The workflow restores the keystore only into the runner's temporary directory. Keep the same upload key for subsequent upgrades.

## Validation and security

`test/market_test.dart` covers currency handling, filters, ownership, persistence, invalid storage, image limits and safe configuration. `test/widget_test.dart` exercises discovery, saves, onboarding, product creation/deletion and mobile/tablet layout.

The CI Postgres service simulates Supabase's `auth.uid()` and storage tables solely for policy tests. It applies the schema twice and checks anonymous reads, private visibility, cross-owner write rejection, invalid prices/MRP, photo ownership, and cascade deletion. **These fixtures must never run on a real Supabase project.** They do not replace live-project integration testing.

## Before a public launch

- Configure and test actual Supabase signup, email deliverability and RLS in your project.
- Add abuse reporting, moderation, business verification and spam/rate controls. Self-reported profiles are not verified businesses.
- Finish account-deletion support and a reviewed privacy/terms policy before Play Store publication. Shop deletion is implemented; auth-account deletion is not.
- Product photos and business contact details are public. Publish only authorised content. The app does not collect buyer location or payment details.
- Treat the in-app privacy copy as an MVP disclosure, not reviewed legal policy.
- Create crawlable, server-rendered shop/product landing pages if organic search is important. Flutter web alone does not provide strong per-listing SEO. Demo HTML is deliberately `noindex`; do not index example shops.
- Paginate/search server-side as the catalogue grows; the MVP uses a client-side catalogue snapshot.
- No guarantee of adoption, current prices, earnings or low competition. The potential moat is genuine local sellers and maintained catalogue data—not the Flutter code.

## Asset credits

Illustrations and icons are original project assets; regenerate using `python tools/generate_assets.py` with Pillow installed. Manrope is bundled under its SIL Open Font License, included in `assets/fonts/OFL.txt`. The Gradle wrapper scripts/JAR come from the official Gradle 8.12 repository.
