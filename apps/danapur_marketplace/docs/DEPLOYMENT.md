# Deployment — actual backend and production launch

The final application supports cash orders and removable sample data. Samples are not proof of live Supabase integration or actual fulfilment. Read [CASH_COMMERCE.md](CASH_COMMERCE.md) for the delivery/pricing/privacy/testing contracts.

## 1. Dedicated Supabase project

Never reuse StockPulse's backend or service keys. Run in SQL Editor, in order:

1. `supabase/migrations/001_marketplace.sql`
2. `supabase/migrations/002_verified_marketplace.sql`
3. `supabase/migrations/003_cash_orders_expenses.sql`
4. `supabase/migrations/004_completed_order_reviews.sql`
5. `supabase/seeds/001_mandi_items.sql`

The scripts are idempotent. Old shops require review; no actual shop/product prices are automatically inserted. The mandi seed adds 117 unpriced common/seasonal commodities. **Never run `test/sql/` fixture files in a real project.**

Optional cloud TEST catalogue: `supabase/seeds/900_sample_catalog.example.sql`. Use a dedicated confirmed test owner UUID and a different confirmed buyer; do not replace a real business owner. Samples are explicitly fictional and must not receive real cash/deliveries. Admin can remove only tagged sample records. Test Auth accounts are not silently fabricated or deleted.

## 2. Authentication and privacy

Enable email/password signup with confirmation and configure a production SMTP sender, password policy and auth rate limits. Buyers sign in to order or store personal expenses; discovery remains public. Set Auth Site URL and allowed web-origin redirects; allow Android `in.danapur.bazaar://auth-callback`. Optional `DANAPUR_AUTH_REDIRECT_URL` overrides the default callback. Test signup/confirmation/recovery on actual devices/origin.

Order address, mobile and GPS are private to the buyer/assigned seller. Personal expenses belong only to their user; there is no bank connection. No background GPS tracking. Review retention/export/deletion, cash cancellation/disputes, business contacts, location consent and sample-data wording in operator privacy/terms before public launch.

## 3. URL/key configuration

Copy `config/app_config.example.json` to ignored `config/app_config.json`. Fill only dedicated HTTPS project URL and **publishable/anon** key. Never embed a secret/service-role/admin key.

For CI set repository Actions secrets `DANAPUR_SUPABASE_URL`, `DANAPUR_SUPABASE_ANON_KEY` and optional `DANAPUR_AUTH_REDIRECT_URL`. Rebuild after changes. Both blank → clearly labelled device-local sample records/test profiles; partial/invalid/live backend failures never fall back to samples. A configured backend has no local test-admin profile switch.

## 4. First admin and approvals

Create/confirm your own normal Auth account. Copy its UUID from Supabase Authentication → Users; fill/run `supabase/admin/first_admin.example.sql` in privileged SQL Editor. Refresh/sign in again. There is no public admin self-assignment, hard-coded admin password or magic email.

Admin panel is the final approval authority. Owners upload a private storefront/signboard photo; admin reviews it and approves/rejects/suspends with a reason. WhatsApp is optional extra evidence/contact, not mandatory approval or automatically read/synced. If used, set the operator's WhatsApp number in Admin → Settings and match full request ID/sender/address. No Aadhaar/PAN collection; photo review is not government identity certification or guaranteed fraud prevention.

Changing identity, proof or shop coordinates resets approval. Verification bucket is private with owner/admin-only signed reads. Require a separate protected admin account and reviewed MFA/security procedures before launch; local sample admin tests do not enforce live security.

## 5. Shop, delivery, orders and expenses

Owners choose retailer/wholesaler/both, category, open/closed status, optional shop delivery and base fee. Capture precise location while standing at the real storefront. Each listing chooses base price, ₹/% discount, delivery eligibility and per-unit handling charge. Decline delivery for heavy/bulky products. Units/prices/tax terms are the seller's responsibility; this is not a GST invoice engine.

Home-delivery COD is an inclusive **500 m straight-line** radius, not a route distance. GPS fix must be recent/accurate; denied/imprecise/outside/pickup-only cases use pickup/cash at shop. Client location is not cryptographic proof of presence; sellers confirm real addresses. No courier fleet, ETA promise, reservation or delivery guarantee.

One shop per checkout. Backend validates/locks current prices and eligibility, computes totals and snapshots lines. Buyer/seller can complete/cancel; completion is self-reported, not a digital payment receipt. Seller may accept/mark ready. Closed orders cannot change. Completion adds one buyer expense; cancelled/open orders do not. Close orders before deleting shop/account.

## 6. Membership (OFF initially)

Onboarding is free. Admin → Membership & samples toggles the future ₹299/month access policy, with a 30-day grace from first activation. Expired access pauses new orders only. Admin can manually extend dates after offline arrangements/records. **No online gateway, recurring debit or automatic money collection.** Communicate reviewed terms before activation.

## 7. Stable signing and Telegram ZIP

Set all dedicated signing secrets: `DANAPUR_ANDROID_KEYSTORE_BASE64`, `DANAPUR_KEYSTORE_PASSWORD`, `DANAPUR_KEY_ALIAS`, `DANAPUR_KEY_PASSWORD`. Without them, release-optimised builds are debug-signed for installation testing—not production-signed Play Store releases. Never reuse StockPulse's signing key. Backup/protect a stable key; runner debug keys may prevent upgrades without uninstalling.

Workflow validates genuine Postgres policies/cash commerce, locked Flutter dependencies, analysis/domain/widgets and configuration/ZIP tests. It builds one universal APK, wraps it in `danapur-bazaar.zip` and sends directly from the runner using existing Telegram secrets. **No upload/download Actions artifacts, binary commits or PR notifications.** Token/chat values are not printed; API message confirmation is required. Private Telegram invite links are not Bot API chat IDs.

## 8. Launch checks still required

Real backend/email/role/storage/orders/expense integration; physical Android GPS/permission and HTTPS browser checks; stable signing; legally reviewed location/cash/membership/privacy/tax terms; abuse/reporting/moderation; owner support, cash disputes and refunds outside this app; backups/restore, error monitoring, quota alerts, orphan-media retention and incident procedures. No claim of full production certification, guaranteed fraud prevention, logistics capacity, adoption/income or legal compliance.


## Completed-order feedback

Only the order's authenticated buyer can submit 1–5 stars and an optional comment (≤500 Unicode characters), **after status `completed`**. Placed/accepted/ready/cancelled orders, sellers, anonymous users and other buyers cannot submit, even through the API. One immutable submission per order; a pending/hidden review cannot be replaced with a second one.

Feedback starts pending. Admin → Order feedback publishes/hides with an audited reason; apply the same privacy/spam/abuse policy to positive and negative ratings. Do not suppress a review merely because it is negative. Public shop feedback uses an explicit sanitized projection: order IDs, buyer IDs, names, phones, address/location and moderation notes are not public fields. Free-text may still contain personal information, so the operator must inspect it before publication.

The label is **order-linked**, never “verified purchase/payment”: cash-order completion is self-reported. There is no general before-order comment/feedback box, open comment thread or seller rating submission. Sample feedback is labelled and removed with sample records.
