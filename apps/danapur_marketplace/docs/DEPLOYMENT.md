# Production deployment checklist

This is a real-backend implementation, not a provisioned or independently audited service. Complete these steps before inviting users.

## 1. Dedicated Supabase project

Never reuse the StockPulse database or service keys. In SQL Editor run, in order:

1. `supabase/migrations/001_marketplace.sql`
2. `supabase/migrations/002_verified_marketplace.sql`
3. `supabase/seeds/001_mandi_items.sql`

These scripts are idempotent. Migrating old shops makes them **pending**, not automatically approved. The catalogue seed installs 117 common/seasonal vegetables/fruits with Hindi names and units, **no prices**. Administrators can extend it in the app.

The disposable `test/sql/fixture.sql` and tests are **never** deployed. They are not a Supabase project.

## 2. Authentication

Enable email/password signup with email confirmation. Set a reviewed production Site URL and allowed web-origin redirects. Add `in.danapur.bazaar://auth-callback` to allowed redirect URLs for Android signup/recovery links. Optional `DANAPUR_AUTH_REDIRECT_URL` overrides the default callback.

Configure a production SMTP provider, sender identity, delivery limits, password policy and auth rate limits. Test signup, confirmation, sign-in, reset-email and recovery-password update on a real phone and your deployed web origin. The built-in email service is not a production mail guarantee. Mobile/SMS OTP is not silently simulated; it is not enabled in this version.

## 3. Client configuration and APK

Fill the ignored JSON described in `config/README.md`, or repository Actions secrets:

- `DANAPUR_SUPABASE_URL`
- `DANAPUR_SUPABASE_ANON_KEY`
- optional `DANAPUR_AUTH_REDIRECT_URL`

Both absent produces a setup-required screen, **not a demo**. Changes require a rebuild. Only a publishable/anon client key is permitted; all privileges come from server RLS/RPC checks, never a bundled admin secret.

For stable release signing set all four dedicated secrets:

- `DANAPUR_ANDROID_KEYSTORE_BASE64`
- `DANAPUR_KEYSTORE_PASSWORD`
- `DANAPUR_KEY_ALIAS`
- `DANAPUR_KEY_PASSWORD`

Without them, the release-optimised APK is debug-signed for installation testing, **not a production-signed Play Store release**. Do not reuse StockPulse's signing key. Keep a securely backed-up stable key; debug keys can change across runners and prevent in-place upgrades.

## 4. First administrator

Create and confirm your account through the app. In Supabase Authentication → Users copy **your account UUID**, edit `supabase/admin/first_admin.example.sql` and run it in SQL Editor. Never share passwords or tokens in chat. Refresh/sign in again. Admin → Settings configures the operator's WhatsApp number, support email, reviewed privacy/terms HTTPS links and mandi name.

Admin status is stored in a server-only table. Sellers cannot assign themselves admin privileges or approve their own shop. Use a separate admin account, strong password, least privilege and protected Supabase/GitHub access. A reviewed MFA requirement is recommended before a public launch; this app does not claim to enforce administrator MFA.

## 5. Shop verification

Owners choose retailer, wholesaler or both, select a shop category/area, enter business contact/address, upload a private storefront/signboard photo and consent to publication after review. The shop is **pending and invisible publicly**. The WhatsApp button opens the configured operator chat with the full request UUID. The owner manually attaches a current shop photo, from the same registered mobile.

The administrator matches the request, sender, storefront and address, then approves/rejects/suspends with a note. The app does not read WhatsApp chats or automatically attach photos. Automatic sync would require an authorised WhatsApp Business API integration and webhook. A manual photo review is not government identity verification, proof of ownership or a guarantee against fraud. Reject questionable requests and require further non-sensitive evidence when appropriate.

Approved shops appear only while published. Changing their identity, business type, category, address/mobile or proof resets approval. Verification images live in a private bucket with owner/admin-only reads and 5-minute signed links. Do not collect Aadhaar, PAN or private identity documents through this flow.

## 6. Mandi operations

No mandi seller signup. Administrators publish actual rates by commodity, wholesale/retail type, unit, IST market date and optional quality/variety note. Fixed or min/max prices are supported. Unpriced items say **Not published**. Old rates say **Previous rate** and show the date; they are never labelled today's rates. Price history and administrator audit entries are retained.

Confirm real rates with a reliable authorised source. A catalogue entry is not a guarantee that an item is locally in stock. Review rate accuracy, corrections, data backups and price-update frequency.

## 7. Telegram workflow, no Actions artifacts

The Danapur workflow tests the database, analyses/tests Flutter and builds one compressed-native-library **universal** APK. It wraps that single APK in `danapur-bazaar.zip` and sends the ZIP directly to Telegram from the build runner. There are **no upload/download-artifact steps**, binary commits or web-hosting side effects. Pull-request builds never send messages. Trusted working-branch/main pushes and manual runs deliver after checks pass.

It reuses existing `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` secrets (documented existing aliases are accepted). The bot must be able to post documents. Public `t.me/channel` links, `@channel` or numeric chat IDs work; private invite links are not chat IDs. No secrets are printed. A confirmed Telegram API message ID is required for success; ambiguous failures are not automatically resent.

## 8. Public launch gates

- Provision and verify your real Supabase project, RLS/storage and all end-to-end auth/approval flows.
- Configure stable signing, SMTP/redirects, operator contact and reviewed privacy/terms pages.
- Test on physical Android devices and deployed web; check Hindi, accessibility/text scale and slow/offline connections.
- Establish reporting/moderation, operator response times, backup/restore, error monitoring, quota alerts, storage retention and incident handling.
- Delete shop/account flows are provided; review audit retention and private-proof orphan cleanup against your privacy policy. Public catalogue images may remain reachable by their known URL until removed; never store private proof there.
- Conduct security/legal review, Play Store Data Safety and release packaging checks. No claim of full production certification, adoption, guaranteed income or legal compliance is made.
