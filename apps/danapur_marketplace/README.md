# Danapur Bazaar

A Flutter marketplace for **Danapur, Bihar**, with approved local retailers/wholesalers, product listings and administrator-published vegetable/fruit mandi rates. This is independent of the StockPulse app at the repository root.

## Start here

1. **[Configuration](config/README.md)** — Supabase URL/public key placeholders; never commit filled credentials.
2. **[Deployment](docs/DEPLOYMENT.md)** — migrations, email auth, first admin, WhatsApp verification, signing and launch gates.
3. **[Folder map](docs/STRUCTURE.md)** — organised app/features/configuration folders.

**There is no runtime demo mode.** Without a configured backend, the APK displays a setup-required screen. It does not invent shops, products or mandi prices. Test fixtures exist only under `test/support/` and are never imported by shipping code. Supabase itself is not provisioned automatically.

## Marketplace

- Professional responsive Material interface, consistent spacing/cards/status states and bundled English/Hindi fonts.
- Product/shop discovery, categories/neighbourhood filters, exact integer-paise pricing and saved products on-device.
- Retailer, wholesaler or both, with expanded categories including hardware, furniture, electrical, building materials, stationery, healthcare, automotive, fresh produce and more.
- Email/password signup with email confirmation, real password-reset email/recovery UI and Android auth deep links.
- One shop per owner; product create/edit/delete, photos, stock, unit and optional MRP.
- Direct seller WhatsApp/call/maps enquiries. **No checkout, payments, delivery or sales guarantees.**

## Shop verification

- Mandatory private storefront/signboard photo on onboarding.
- New requests are **pending** and hidden publicly, even if the owner enables publication.
- WhatsApp opens the configured operator chat with the full request ID. The owner attaches a shop photo manually, from their registered business mobile.
- Restricted admin panel reviews photo/sender and approves, rejects or suspends with an owner-visible reason.
- Editing identity/contact/category/business type/proof resets approval. Seller-side self-approval and admin self-assignment are rejected by server policies/functions.
- Private owner/admin-only verification bucket; short-lived signed photo links. **No Aadhaar/PAN collection.** A manual photo review is not government identity certification or absolute fraud prevention.

## Mandi and administrator workspace

- **117 common/seasonal vegetables and fruits**, bilingual English/Hindi names and sensible default units. Not a claim to cover every possible crop/variety; admins can add more.
- No mandi shop-owner onboarding. Only authorised administrators edit rates.
- Separate wholesale/retail rates, per kg/dozen/piece/bunch/100 kg, fixed or min/max prices, IST market date and optional variety/quality note.
- Unpriced items say **Not published**. Old rates show **Previous rate** and a date—not today's price.
- Private queue, approval/rejection/suspension, rate editor, commodity creation, WhatsApp/support/policy settings and audit log in the same Android/web app.
- Admin membership is installed only through privileged Supabase SQL Editor using the confirmed account UUID; never an embedded admin password or public role switch.

## Local builds

Pinned CI: Flutter **3.35.7**, Dart **3.9**, Java **17**. Android ID `in.danapur.bazaar`, Android 7+.

```bash
cd apps/danapur_marketplace
flutter pub get --enforce-lockfile
# First fill the Git-ignored config/app_config.json, as documented.
flutter run --dart-define-from-file=config/app_config.json
flutter run -d chrome --dart-define-from-file=config/app_config.json
flutter analyze --fatal-infos
flutter test --coverage
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/app_config.json
flutter build apk --release --dart-define-from-file=config/app_config.json
```

## CI and Telegram delivery

`.github/workflows/danapur_marketplace.yml` runs idempotent real Postgres ownership/admin/visibility/private-storage/rate-history tests before Flutter analysis/domain/widget tests. It builds **one universal APK** containing ARMv7, ARM64 and x86_64, wraps it in **`danapur-bazaar.zip`**, and sends the ZIP directly from the build runner using the existing repository Telegram secrets. **No GitHub upload/download artifacts or binary commits.** PR builds never send Telegram messages.

Native libraries are compressed to keep the single APK/ZIP below the public Bot API upload limit. Delivery validates the correct package/ABIs and requires Telegram's JSON success and message ID. No tokens/chat values are printed.

The APK is release-optimised but **debug-signed for installation testing until dedicated Danapur signing secrets are supplied**. See the deployment guide. Existing StockPulse keystore/backend secrets are not reused. Empty Supabase configuration produces setup-required, not a functioning public service; configure and rebuild before onboarding real users.

## Security and launch boundaries

RLS and narrow administrator RPCs are the source of authority, not UI visibility. Owner IDs/listing IDs are immutable. Verification media is private; public product media is business content. Role and audit tables have no client-write grants. Mandirates keep history and server-owned authors/timestamps. Account/shop deletion and last-admin protection are implemented.

CI fixtures do not test your live Supabase project, SMTP, physical device, real WhatsApp sender matching or production legal compliance. Complete the deployment guide's actual backend/device/security/operations/privacy/signing checks before public launch. Admin MFA enforcement, operational abuse/reporting controls, backup/monitoring and a reviewed legal policy remain launch gates, not silently claimed completed services.

Manrope and Noto Sans Devanagari fonts and licenses are bundled and available from About → Open-source licenses; there is no startup font CDN dependency. Original SVG illustrations remain in `assets/`. The Gradle wrapper/license comes from official Gradle 8.12 sources.
