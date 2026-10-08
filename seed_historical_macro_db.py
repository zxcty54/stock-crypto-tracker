#!/usr/bin/env python3
"""
STRICT GOVERNMENT SCRAPER (ZERO DUMMY DATA / ZERO SYNTHETIC FALLBACK)
- Sources:
    1. DPIIT Core 8 (Cement & Steel Production)
    2. PPAC Historical Data Files (HSD & Bitumen)
- Behavior:
    - If real data is retrieved -> Appends to 'macro_historical_db.json'
    - If scrape fails -> RAISES EXCEPTION AND EXITS (No fake numbers allowed)
"""

import os
import sys
import io
import re
import json
import urllib.request
from datetime import datetime, timezone, timedelta

DB_FILE = "macro_historical_db.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive"
}

def fetch_bytes_with_retry(url, retries=3):
    """Bina dummy fallback ke real bytes fetch karta hai."""
    req = urllib.request.Request(url, headers=HEADERS)
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            print(f"   🌐 [Attempt {attempt}/{retries}] Connecting to: {url}")
            with urllib.request.urlopen(req, timeout=30) as resp:
                if resp.status == 200:
                    return resp.read()
                else:
                    raise RuntimeError(f"HTTP Status {resp.status} received from {url}")
        except Exception as e:
            last_err = e
            print(f"   ⚠️ Attempt {attempt} failed: {e}")
    raise RuntimeError(f"FATAL: Failed to reach {url} after {retries} retries: {last_err}")

# =====================================================================
# 1. DPIIT CORE 8 HARVESTER (Cement & Steel)
# =====================================================================
def get_dpiit_real_numbers():
    print("\n🔍 [1/2] Connecting to DPIIT (Office of the Economic Adviser)...")
    try:
        import pdfplumber
    except ImportError:
        print("❌ 'pdfplumber' library not found. Run: pip install pdfplumber")
        sys.exit(1)

    # DPIIT publishes regular monthly press releases at eaindustry.nic.in
    # Direct endpoint to Core Industries release
    dpiit_url = "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"
    
    pdf_bytes = fetch_bytes_with_retry(dpiit_url, retries=2)
    print(f"   📦 PDF downloaded successfully ({len(pdf_bytes)} bytes). Parsing tables...")

    cement_val = None
    steel_val = None
    period_str = None

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        full_text = ""
        for page_idx, page in enumerate(pdf.pages):
            text = page.extract_text() or ""
            full_text += f"\n--- Page {page_idx+1} ---\n" + text

            # Month extraction (e.g., "Monthly Index of Eight Core Industries for September, 2026")
            if not period_str:
                month_match = re.search(r"for\s+([A-Za-z]+),\s+(202\d)", text, re.IGNORECASE)
                if month_match:
                    period_str = f"{month_match.group(1)} {month_match.group(2)}"

            # Statement II: Physical Production row matching
            # Format usually: Cement | Weight | April | May ... | Cumulative
            for line in text.split("\n"):
                if re.match(r"^cement\b", line.strip(), re.IGNORECASE):
                    numbers = re.findall(r"[\d\.]+", line)
                    if len(numbers) >= 2:
                        cement_val = float(numbers[-1])  # latest recorded production
                if re.match(r"^steel\b", line.strip(), re.IGNORECASE):
                    numbers = re.findall(r"[\d\.]+", line)
                    if len(numbers) >= 2:
                        steel_val = float(numbers[-1])

    if cement_val is None or steel_val is None:
        raise ValueError("CRITICAL: DPIIT table format changed. Could not parse Cement or Steel rows from PDF.")

    print(f"   ✅ Real Extracted Data ({period_str}): Cement = {cement_val} MT, Steel = {steel_val} MT")
    return {"cement": cement_val, "steel": steel_val, "period": period_str or NOW.strftime("%b %Y")}

# =====================================================================
# 2. PPAC PETROLEUM HARVESTER (High-Speed Diesel & Bitumen)
# =====================================================================
def get_ppac_real_numbers():
    print("\n🔍 [2/2] Connecting to PPAC (Ministry of Petroleum & Natural Gas)...")
    
    # PPAC Monthly Ready Reckoner / Consumption Snapshot
    ppac_url = "https://ppac.gov.in/consumption"
    html_bytes = fetch_bytes_with_retry(ppac_url, retries=2)
    html_text = html_bytes.decode("utf-8", errors="ignore")

    # Search for HSD and Bitumen figures inside table tags
    hsd_match = re.search(r"HSD.*?([\d,]+\.?\d*)", html_text, re.DOTALL)
    bitumen_match = re.search(r"Bitumen.*?([\d,]+\.?\d*)", html_text, re.DOTALL)

    if not (hsd_match and bitumen_match):
        # Fallback to direct PPAC monthly bulletin link if table regex misses
        raise RuntimeError("CRITICAL: Failed to locate dynamic HSD/Bitumen elements on PPAC website.")

    hsd_val = float(hsd_match.group(1).replace(",", ""))
    bitumen_val = float(bitumen_match.group(1).replace(",", ""))

    print(f"   ✅ Real PPAC Extracted: HSD = {hsd_val} TMT, Bitumen = {bitumen_val} TMT")
    return {"hsd": hsd_val, "bitumen": bitumen_val}

# =====================================================================
# PIPELINE EXECUTION (STRICT FAIL-SAFE)
# =====================================================================
def main():
    print("=" * 75)
    print("🚀 EXECUTING STRICT NO-DUMMY REAL SCRAPER")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 75)

    # 1. Harvesters chalenge (Agar data nahi mila, yahi pe crash hoga)
    dpiit_data = get_dpiit_real_numbers()
    ppac_data = get_ppac_real_numbers()

    # 2. Agar dono ka genuine data aa gaya, tabhi DB update hoga
    print("\n💾 Updating verified data into database...")

    if not os.path.exists(DB_FILE):
        db = {"version": "7.0-strict-real-telemetry", "sectors": {}}
    else:
        with open(DB_FILE, "r", encoding="utf-8") as f:
            db = json.load(f)

    month_key = NOW.strftime("%Y-%m")

    # Update Cement
    cem_sec = db["sectors"].setdefault("CEMENT", {
        "sector": "Cement & Clinker",
        "monthly_demand": [],
        "source": "DPIIT Core 8 Official PDF"
    })
    cem_sec["monthly_demand"].append({
        "month": month_key,
        "value": dpiit_data["cement"],
        "unit": "Million Tonnes"
    })

    # Update Steel
    steel_sec = db["sectors"].setdefault("STEEL", {
        "sector": "Primary Steel Manufacturing",
        "monthly_demand": [],
        "source": "DPIIT Core 8 Official PDF"
    })
    steel_sec["monthly_demand"].append({
        "month": month_key,
        "value": dpiit_data["steel"],
        "unit": "Million Tonnes"
    })

    # Update Logistics (HSD)
    hsd_sec = db["sectors"].setdefault("LOGISTICS", {
        "sector": "Commercial Fleet Logistics",
        "monthly_demand": [],
        "source": "PPAC Ministry of Petroleum"
    })
    hsd_sec["monthly_demand"].append({
        "month": month_key,
        "value": ppac_data["hsd"],
        "unit": "Thousand MT (HSD)"
    })

    with open(DB_FILE, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, indent=2)

    print(f"🎉 SUCCESS: Real government figures written to '{DB_FILE}'. Zero dummy fallback used.")

if __name__ == "__main__":
    main()
