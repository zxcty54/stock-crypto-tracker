# Project map

```text
config/
  app_config.example.json     # only URL/public key/callback placeholders
  catalog/mandi_items.json    # editable unpriced bilingual commodity catalogue
lib/
  app/app.dart               # responsive shell and routes
  core/
    config/                  # backend configuration guard
    data/                    # Supabase repository, controller, saved-item store
    domain/                  # shared shop/product contracts and validation
    theme/                   # design tokens and Material theme
    widgets/                 # reusable cards, tags, feedback and contact helpers
  features/
    admin/domain/            # operator settings and audit models
    admin/presentation/      # secure dashboard, approval/rate/settings forms
    auth/presentation/       # recovery-password UI
    catalog/presentation/    # discovery, shop and product detail UI
    mandi/domain/            # commodity/rate contracts and IST date helpers
    mandi/presentation/      # public vegetable/fruit rates and stale-date labels
    seller/presentation/     # account login, onboarding, private proof and catalogue
supabase/
  migrations/                # deploy in numeric order
  seeds/                     # commodity names only; no dummy shops/prices
  admin/                     # first-admin SQL template (manual, privileged)
docs/                        # deployment, operating flow, structure
assets/                      # bundled/licensed fonts and original illustrations
android/                     # universal APK packaging, auth callback, signing
web/                         # Flutter web shell (no auto deployment)
 test/
  support/                   # synthetic fixtures, NEVER imported by shipping lib/
  sql/                       # disposable database/security regressions
 tools/                      # safe configuration, catalogue generation, Telegram ZIP
```

Backend URL/key belong in ignored configuration or GitHub secrets. WhatsApp/operator settings belong in the admin panel. Administrator membership is assigned only in Supabase SQL Editor; there is no magic email, embedded admin password or public role-edit switch.
