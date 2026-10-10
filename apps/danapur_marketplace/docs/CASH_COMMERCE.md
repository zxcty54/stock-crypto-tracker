# Cash ordering, delivery and testing

## Cash only

There is **no online payment gateway**, credit-card/UPI checkout, automated collection, refund engine or digital cash receipt. Checkout displays the server-computed amount. Buyer or seller can mark an open order completed or cancelled with a note. Completed/cancelled orders are locked. Seller can also accept and mark ready. Completion is self-reported: coordinate actual cash settlement with the shop.

One shop per cart/checkout, maximum 20 distinct products and 1–100 whole **listed units** per item. A unit may be a 500 g pack, 1 kg, piece, pair, etc. Multi-shop fulfilment, fractional quantities, couriers/ETAs and service appointment scheduling are not simulated.

## Prices and delivery

- Seller sets a base unit price and optional fixed ₹ / percentage discount. Percentage conversion is integer-paise arithmetic, rounded down.
- Shop sets an optional base delivery fee per order.
- Each product independently allows/disallows delivery and may add a handling charge **per unit**. Heavy 50 kg goods can be pickup-only while light packs can be delivered.
- Checkout shows base product total − discounts + shop delivery fee + per-unit handling. Pickup has no delivery charge.
- Server rechecks current prices/discounts, approved/published/open shop, availability, membership access and every product's delivery flag. Client-supplied totals are never accepted. Saved order prices/item names remain unchanged if listings are edited/deleted later.

## 500 m rule

Home-delivery COD requires the shop's coordinates and buyer's recent accurate foreground location. The server computes a **500 m inclusive straight-line radius**, not road/walking distance. Browser needs HTTPS/location permission; Android needs precise foreground permission. Accuracy must be ≤50 m and fix age ≤2 minutes. No background tracking or startup permission prompt. Denial, timeout, low accuracy, missing coordinates, >500 m or delivery-disabled items → use shop pickup/cash at shop instead.

Location originates from the client/device and is not cryptographic proof of physical presence. Obvious platform mock locations are rejected, but a malicious device/API client can still falsify coordinates. The seller must confirm address/fulfilment. Do not describe this as anti-fraud-certified geofencing. Shop coordinate changes reset its approval.

Order address/mobile/location are readable only by that buyer and assigned seller, not by anonymous users, other sellers or a nonparticipant admin. Review privacy/retention legally before launch. Active orders must close/cancel before account/shop deletion.

## Expense manager

Completing an order creates exactly one private buyer expense, including delivery/discount effects. Open/cancelled orders do not count. Order-linked expenses are immutable; manual expenses can be added/edited/deleted. Monthly totals and category breakdown include the account's records. No bank connection, payment verification or accounting/tax certification.

## ₹299 future membership

Onboarding is free. Admin **Membership & samples** controls a server-enforced membership switch, OFF initially. First activation starts a 30-day grace period. After grace, expired access pauses new app orders but does not hide order history or prevent closing existing orders. Admin extends access through a date after managing offline collection/records separately. Turning the switch on does not charge anyone, set up a recurring debit or issue a payment receipt. The 30-day grace date is not reset by toggling off/on. Communicate terms before enabling it.

## Sample records without a separate app

With both Supabase fields blank, the same final UI/domain runs against explicitly device-local sample records and test profiles. The banner and test order/expense tags identify them. **No real accounts, shared orders, seller notifications, deliveries or cash collection occur.** Invalid/partial/cloud failures never fall back to samples.

Open **Sample data / test profiles** (header/menu):

1. **Test buyer** — add sample groceries, checkout pickup or choose the explicitly fictional test location for a delivery-eligibility test, then complete/cancel.
2. **Test seller** — manage Sample Daily Needs, product delivery/pricing, open/closed status and incoming orders.
3. **Test admin** — review uploaded local test photos, enter local sample mandi rates, test membership controls, remove/restore samples.

Local test admin/profile selection does not exist on a configured Supabase backend. Do not use the local simulator to claim RLS/live-role verification. Local records survive restart, but are not shared across phones.

**Remove data:** choose Test admin → Admin → Membership & samples → Remove sample data. It removes the local test catalogue/orders/expenses; Restore local samples recreates the fictional catalogue. On a real backend the same action deletes only server-tagged sample shops/products/orders/expenses, preserving real records.

For an optional cloud test catalogue use `supabase/seeds/900_sample_catalog.example.sql`, supply a confirmed dedicated test owner's UUID and use a different confirmed buyer. It is explicitly fictional and bypasses real shop verification only through privileged SQL Editor for tagged test records. Never fabricate Auth users, collect payments, call the sample mobile or imply it represents a verified actual business. The app disables contacts for sample shops.

## Actual launch still requires

Dedicated Supabase migrations/auth/SMTP, real role/storage/order/privacy integration tests, stable Danapur signing, physical GPS/permission testing, reviewed cash cancellation/refund and membership terms, legal/tax policies, backups/monitoring and operational moderation. This is not a claim of Flipkart/Meesho logistics, inventory reservations, verified payments or guaranteed delivery.


## Feedback: only after completion

My orders shows **Rate completed order** only to that order's buyer after completion. Choose 1–5 stars, optionally add a comment, then Submit feedback. There is one review per order. Pending/accepted/ready/cancelled orders have no feedback action and the server rejects attempts. Feedback awaits administrator moderation before appearing on the shop page. Use Test admin → Admin → Order feedback to publish/hide local sample feedback; all local test comments disappear when samples are removed.

No customer/order identity fields are public, and comments should never contain private contact/location/identity information. Admin must inspect free text fairly across all ratings. Reviews are order-linked, not proof that cash was digitally verified. No pre-order feedback form was added.
