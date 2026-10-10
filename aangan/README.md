# Aangan — Bihar rentals, made clearer

Aangan is a Flutter rental app focused on Bihar. It is designed around a simple promise: **show the house rules before a renter has to call**. Owners and local brokers can set policies, add photos and choose how much address/contact detail to reveal. New homes stay private until an admin approves them.

## What is in the app

- **Bihar-first search:** all 38 districts, city/town and block suggestions, plus searchable locality, road and landmark fields. Owners can type smaller towns and blocks that are not yet in the starter directory.
- **Practical rental filters:** rent cap, BHK, home type, pets, bachelors and couples.
- **Flexible house rules:** Yes / No / Discuss first for pets, bachelors, couples, families, daytime visitors, night-time visitors, unannounced guests, late entry, non-veg cooking and smoking.
- **Better listing facts:** rent, deposit, negotiability, maintenance, furnishing, area, availability date, amenities and up to eight photos.
- **Contact privacy:** mobile is private by default. A host may opt in to calls from signed-in renters; in-app text chat remains available without revealing the number.
- **Exact-address privacy:** road, landmark and PIN stay hidden until the host chooses to show them. The public listing view masks these fields at the database layer too.
- **Approval before publication:** new listings are `pending`; only an admin can approve or decline them. Decline notes go back to the owner, who can edit and resubmit.
- **Owner controls:** see review status, resubmit declined listings, pause a live listing or mark it rented.
- **Trust features:** admin-reviewed “Aangan checked” label, listing reports, private conversations and a short safe-renting reminder.
- **Local preview:** with no Supabase settings, Explore uses clearly labelled sample homes so the UI can be tried without a backend.

## Run locally

Install Flutter stable and Android Studio / Android SDK. From the repository root, enter the app folder, then run:

```bash
cd aangan
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Without the two `--dart-define` values, the app opens in preview mode. Real sign-in, listing submission, storage, moderation, phone reveal and chat require the Supabase setup below. **Never put the Supabase `service_role` key in Flutter, GitHub Actions, or a client app.** Only the public anon key belongs in the app; row-level security does the access control.

## Supabase setup

1. Create a Supabase project.
2. In the Supabase SQL editor, run [`supabase/migrations/202610100001_aangan_bihar_rentals.sql`](supabase/migrations/202610100001_aangan_bihar_rentals.sql). It creates profiles, roles, listings, moderation audit, reports, private conversations/messages, RLS policies, RPCs and the private `rental-photos` bucket.
3. In **Authentication → Providers → Email**, enable email sign-in. This app uses a six-digit OTP (`verifyOTP`), so configure the email template to include `{{ .Token }}` rather than relying only on a magic-link button. Set a reasonable OTP expiry/rate limit.
4. Copy the project URL and **anon / publishable key** into your local `--dart-define` values. Do not use the service-role key.
5. Sign in once using the email you want to use as the app administrator. In the SQL editor, grant that existing auth user the admin role:

   ```sql
   insert into public.user_roles (user_id, role)
   select id, 'admin'
   from auth.users
   where lower(email) = lower('YOUR_ADMIN_EMAIL')
   on conflict (user_id, role) do nothing;
   ```

   The admin then signs in with that email OTP. **There is no admin password or secret hardcoded in the app.** Keep control of the admin mailbox and grant this role only to trusted accounts. Admin approval is also enforced in Postgres, not just hidden in the UI.

The migration deliberately separates the private `listings` table from the limited `listing_public` view. Public search cannot read an owner's phone number or hidden road/PIN. Listing images are stored in a private bucket and are signed only when the listing/owner is allowed to see them. Conversation access is restricted to its buyer and seller.

## GitHub Actions

The repository workflow at `../.github/workflows/build_apk.yml` runs on Aangan changes, pull requests to `main`, manual dispatch and pushes to `main` / `arena/**`. It formats and analyzes the app, runs tests, builds an arm64 Android preview APK, packages it as a ZIP, and sends that ZIP **directly to Telegram**. It does not upload a GitHub Actions artifact.

- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` must be configured as GitHub Actions secrets for push/manual builds to deliver the ZIP. Pull requests run checks but never send to Telegram.
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` GitHub Actions secrets are optional. If omitted, the APK is a preview build; if supplied, CI injects them as Dart defines.
- The APK inside the ZIP targets **arm64-v8a** and is a preview build signed with the CI debug key, not a Play Store release. For production, keep a private upload keystore outside Git and provide `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` only to a protected release job. Do not reuse old StockPulse signing credentials.

## Bihar location coverage

The starter directory contains all 38 district names and common city/town/block suggestions for frequently used areas. Every town, block, mohalla, road number and landmark remains free text where needed, so smaller places can still be listed and searched. For a scaled launch, the next data task should be importing and periodically validating the official Bihar district → subdivision → block → town/panchayat directory rather than hard-coding every village into the app.

## Useful next releases

- Visit-slot requests with owner-controlled day/time windows and check-in safety.
- Hindi / English copy switch and optional transliterated search.
- Map-based nearby search with locality-level (not house-level) pin privacy.
- Saved-search alerts, rent comparison and broker-fee receipt / dispute workflows.
- Document/identity verification with explicit consent and safe retention rules.

## Tests

From the repository root:

```bash
cd aangan
flutter test
flutter analyze lib/main.dart lib/app lib/features/rentals test
```
