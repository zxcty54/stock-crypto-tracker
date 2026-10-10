# Stock & Crypto Tracker repository

The Aangan Bihar rentals Flutter application is kept in the [`aangan/`](aangan/) folder. Its Android project, Dart sources, assets, Supabase migration, tests, and app-specific setup guide are all inside that folder.

Start with [`aangan/README.md`](aangan/README.md). GitHub Actions builds the arm64 Android preview package and sends the ZIP directly to Telegram using the `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` repository secrets; it does not publish a GitHub Actions artifact.

The remaining files at the repository root belong to the existing stock/crypto tracking and Telegram publishing tools.
