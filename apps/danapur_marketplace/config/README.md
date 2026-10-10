# Configuration — start here

1. Copy `app_config.example.json` to **`app_config.json`** (Git-ignored).
2. Fill `DANAPUR_SUPABASE_URL` with your dedicated project's HTTPS URL.
3. Fill `DANAPUR_SUPABASE_ANON_KEY` with its **publishable** key or legacy **anon** key. Never use a secret/service-role key.
4. Usually leave `DANAPUR_AUTH_REDIRECT_URL` empty: Android uses `in.danapur.bazaar://auth-callback`; web uses its own origin. Allow those redirects in Supabase Auth settings.

```bash
flutter run --dart-define-from-file=config/app_config.json
flutter build apk --release --dart-define-from-file=config/app_config.json
```

For GitHub builds, put the same two values in repository Actions secrets named `DANAPUR_SUPABASE_URL` and `DANAPUR_SUPABASE_ANON_KEY`. **Do not commit a filled configuration file.** Setting secrets does not itself trigger a build: manually run the workflow after it has been merged, or push a relevant app/workflow change on the working branch.

Invalid/live backend errors never fall back to samples. Both values blank → clearly labelled device-local sample records and explicit test profiles; partial/malformed/privileged configuration fails clearly. Samples can be removed/restored from the test admin controls. A configured backend never offers local test admin profiles; cloud data is installed only via the documented optional tagged seed. Mandi names are prelisted but no rates are invented. Supabase migrations, commodity seeds and first-admin setup still need to be run—URL/key alone do not create the database.

The verification WhatsApp number, support contact, policy links and mandi title are edited in **Admin → Settings**, not hard-coded. Shop categories, areas and business types live in `lib/core/domain/market.dart` and are mirrored in SQL constraints. The editable unpriced vegetable/fruit catalogue is `catalog/mandi_items.json`; regenerate its seed with `python3 tools/generate_mandi_catalog.py`. Administrators can also add commodities in the app.

Signing and Telegram secrets are separate from these public client settings. See `../docs/DEPLOYMENT.md`.
