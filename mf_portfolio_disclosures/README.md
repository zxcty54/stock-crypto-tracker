# 📂 Mutual Fund Portfolio Disclosures Ingestion Directory

This directory stores monthly statutory Mutual Fund portfolio disclosure files (`.csv`, `.xlsx`, `.xls`) published by Asset Management Companies (AMCs) following SEBI's monthly disclosure mandate (10th of each month).

### 🚀 Automated Ingestion & MoM Delta Tracking
When `mf_smart_money_hunter.py` executes (e.g. via GitHub Actions on the 11th of each month):
1. **Auto-Downloader**: Checks public statutory URLs for new disclosure files.
2. **Universal Ingestion**: Scans this folder for any `<fund_id>_monthly.csv` or `.xlsx` files and automatically extracts:
   - Equity Stock Holdings & Weights
   - Cash / TREPS / Liquid Allocation %
   - Total Scheme AUM
3. **Month-over-Month Delta Detection**: Compares current portfolio with `previous_portfolio_snapshot.json` to automatically detect:
   - 🟢 **Fresh Buys (`FRESH_ENTRY`)**: Newly introduced positions.
   - 🚀 **Heavy Buildup (`AGGRESSIVE_ACCUMULATION`)**: Holdings increased by >25%.
   - 🔴 **Slashing / Exits (`SILENT_DUMPING`)**: Holdings trimmed by >30% or completely sold.
4. **Resilient Fallback**: If no new file is placed, the engine preserves the calibrated baseline while enriching live daily NAVs via AMFI Open API (`api.mfapi.in`) and Gemini AI.

### 📝 Sample Naming Convention
- `ppfas_flexi_monthly.csv` (Parag Parikh Flexi Cap)
- `quant_small_monthly.xlsx` (Quant Small Cap)
- `hdfc_midcap_monthly.csv` (HDFC Mid-Cap Opportunities)
