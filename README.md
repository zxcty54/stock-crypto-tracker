# Stock & Crypto Tracker repository

The Aangan Bihar rentals Flutter application is kept in the [`aangan/`](aangan/) folder. Its Android project, Dart sources, assets, Supabase migration, tests, and app-specific setup guide are all inside that folder.

Start with [`aangan/README.md`](aangan/README.md). GitHub Actions builds the arm64 Android preview package and sends the ZIP directly to Telegram using the `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` repository secrets; it does not publish a GitHub Actions artifact.

The StockPulse Flutter application is back at the repository root — `lib/`, `android/`, `assets/` and `pubspec.yaml` — kept fully separate from Aangan. The two apps share no Dart sources or assets: `aangan/` contains only Aangan code and the finance screens exist only at the root. Its release pipeline is [`stockpulse_build_apk.yml`](.github/workflows/stockpulse_build_apk.yml), which builds the signed APK and sends the ZIP to Telegram, and [`generate-key.yml`](.github/workflows/generate-key.yml) is the one-time keystore helper.

---

## 📢 Mainboard IPO Tracker & Auto-Poster (@ipocentral)

Automated Indian Mainboard IPO tracker and Telegram broadcaster for [**https://t.me/ipocentral**](https://t.me/ipocentral) (`@ipocentral`).

### Features
- **Internet Tracking:** Scrapes and aggregates live data from Chittorgarh (Mainboard Report 82), InvestorGain (Live GMP Report 331), NSE India, BSE India, and IPOCentral.
- **Strict Mainboard Filtering:** Tracks strictly Mainboard IPOs (BSE/NSE equities) and automatically filters out SME IPOs (BSE SME / NSE Emerge).
- **Automated Lifecycle Alerts:**
  1. 📢 **New Mainboard IPO Announced:** Comprehensive overview with dates, price band, lot size, min retail investment, total issue size (Fresh Issue + OFS), initial GMP, and registrar.
  2. 🟢 **IPO Opens Today:** Bidding opening alert with live GMP, expected listing price, and retail cut-off bidding reminders.
  3. 🔴 **IPO Closing Today (Last Chance):** Final day alert with live subscription figures (QIB, NII/HNI, Retail, Total) and 5:00 PM cutoff.
  4. 🎯 **Allotment Out Alert:** Basis of allotment notification with 1-click direct links to registrar allotment portals (KFintech, Link Intime, Bigshare, etc.) and BSE/NSE verification portals.
  5. 🚀 **Listing Today (Market Debut):** Listing day alert comparing Issue Price vs Listing Price and listing day gain/loss percentage.
  6. 📊 **Daily GMP Dashboard:** Daily summary table of all active Mainboard IPOs with current GMP and expected gains.
- **State Persistence & Deduplication:** Tracks all state in `ipo_master.json` and records dispatched event IDs in `ipo_posted_log.json` to prevent duplicates.
- **Telegram Bot Configuration:** Reuses the existing `TELEGRAM_BOT_TOKEN` (or `TELEGRAM_TOKEN`) configured in repository secrets and broadcasts to channel `@ipocentral` (configurable via `IPO_TELEGRAM_CHAT_ID` or `TELEGRAM_CHAT_ID`).

### Files
- `ipo_tracker.py`: Main orchestrator, lifecycle event evaluator, and Telegram broadcaster.
- `ipo_scrapers.py`: Multi-source web scrapers, data normalizer, and SME filter.
- `ipo_formatter.py`: HTML-formatted message templates tailored for Telegram.
- `ipo_master.json`: Master database of tracked Mainboard IPOs.
- `ipo_posted_log.json`: Audit log of posted events.
- `.github/workflows/ipo_tracker.yml`: GitHub Actions automated schedule and manual dispatcher.
- `test_ipo_tracker.py`: Comprehensive test suite.

### CLI Usage
```bash
# Run tracker (scrape web, evaluate lifecycle events, and post pending alerts)
python ipo_tracker.py

# Preview pending alerts without sending to Telegram
python ipo_tracker.py --dry-run

# Broadcast daily Mainboard IPO GMP Dashboard to channel
python ipo_tracker.py --summary

# Check status of currently tracked IPOs
python ipo_tracker.py --status

# Test force send a specific lifecycle alert (e.g. for testing)
python ipo_tracker.py --dry-run --force-event ntpc-green-energy IPO_OPENS_TODAY
```

---

The remaining files at the repository root belong to the existing stock/crypto tracking and Telegram publishing tools.
