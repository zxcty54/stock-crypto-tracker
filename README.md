# Stock & Crypto Tracker repository

The Aangan Bihar rentals Flutter application is kept in the [`aangan/`](aangan/) folder. Its Android project, Dart sources, assets, Supabase migration, tests, and app-specific setup guide are all inside that folder.

Start with [`aangan/README.md`](aangan/README.md). GitHub Actions builds the arm64 Android preview package and sends the ZIP directly to Telegram using the `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` repository secrets; it does not publish a GitHub Actions artifact.

The StockPulse Flutter application is back at the repository root — `lib/`, `android/`, `assets/` and `pubspec.yaml` — kept fully separate from Aangan. Its release pipeline is [`stockpulse_build_apk.yml`](.github/workflows/stockpulse_build_apk.yml), which builds the signed APK and sends the ZIP to Telegram, and [`generate-key.yml`](.github/workflows/generate-key.yml) is the one-time keystore helper.

The remaining files at the repository root belong to the existing stock/crypto tracking and Telegram publishing tools.
