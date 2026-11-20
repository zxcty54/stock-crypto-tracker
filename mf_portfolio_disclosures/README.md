# 📂 Mutual Fund Portfolio Disclosures & Historical Snapshot Architecture

This directory stores monthly statutory Mutual Fund portfolio disclosure files (`.csv`, `.xlsx`) published by Asset Management Companies (AMCs) following SEBI's mandate (by 10th of each month) and versioned chronological snapshots.

### 🗄️ Directory Structure
- **`snapshots/snapshot_YYYY_MM.json`**: Chronological monthly portfolio snapshots (e.g. `snapshot_2026_10.json`, `snapshot_2026_11.json`). Enables rolling multi-month delta calculations.
- **`infiltrations_ledger.json`**: Multi-month institutional ledger tracking when each stock was first infiltrated, how many cycles it has been held, and its MoM position trajectory.
- **`sample_disclosure_template.csv`**: Template demonstrating required CSV columns (`Name of the Instrument`, `% to Net Assets`, etc.).
- **`previous_portfolio_snapshot.json`**: Legacy snapshot fallback for backward compatibility.

### 🔄 Multi-Month Base Progression (How Month 1 vs Month 2 works)
1. **Cycle 1 (e.g. October -> November)**:
   - Base = `snapshot_2026_10.json` (October).
   - Ingestion = November disclosure files.
   - Any stock present in Nov but absent in Oct is flagged as 🟢 **`FRESH_ENTRY`** with `first_detected_cycle: "November 2026"`.
   - Snapshot is saved to `snapshots/snapshot_2026_11.json`.

2. **Cycle 2 (e.g. November -> December)**:
   - Base automatically advances to `snapshot_2026_11.json` (November).
   - Ingestion = December disclosure files.
   - Any brand new stock bought in Dec becomes the new 🟢 **`FRESH_ENTRY`**.
   - Stocks entered in Nov:
     - If stake increased >25% -> Upgraded to 🚀 **`AGGRESSIVE_ACCUMULATION`**.
     - If stake held steady -> Tracked in `infiltrations_ledger.json` as `Active (2 cycles held)`.
     - If liquidated -> Flagged as 🔴 **`SILENT_DUMPING`**.
