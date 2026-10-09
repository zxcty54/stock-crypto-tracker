import os
import json
import pandas as pd
from datetime import datetime, timezone, timedelta

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

INPUT_DIR = "downloaded_macro_pdfs"
OUTPUT_FILE = "macro_raw_extracted_dump.json"
FASTAG_CSV_FILE = "netc_fastag_monthly_3years.csv"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def extract_full_pdf(filepath):
    """PDF ka 100% text aur saari structured tables bina kisi filter ke nikaalta hai."""
    result = {
        "file_name": os.path.basename(filepath),
        "total_pages": 0,
        "full_text_by_page": {},
        "tables_by_page": {}
    }
    
    if not pdfplumber or not os.path.exists(filepath):
        return result

    try:
        with pdfplumber.open(filepath) as pdf:
            result["total_pages"] = len(pdf.pages)
            for idx, page in enumerate(pdf.pages):
                page_num = idx + 1
                
                # 1. Pura raw text
                text = page.extract_text(layout=False) or ""
                result["full_text_by_page"][f"page_{page_num}"] = text
                
                # 2. Saari structured tables
                extracted_tables = page.extract_tables()
                if extracted_tables:
                    clean_tables = []
                    for table in extracted_tables:
                        # Clean None values in table cells
                        clean_t = [[str(cell).strip() if cell is not None else "" for cell in row] for row in table]
                        clean_tables.append(clean_t)
                    result["tables_by_page"][f"page_{page_num}"] = clean_tables

    except Exception as e:
        print(f"   ❌ Error extracting {filepath}: {e}")

    return result

def extract_full_excel(filepath):
    """Excel sheet ki har ek sheet ka pura data structured format mein nikaalta hai."""
    result = {
        "file_name": os.path.basename(filepath),
        "sheets": {}
    }
    
    if not filepath or not os.path.exists(filepath):
        return result

    try:
        xl = pd.ExcelFile(filepath)
        for sheet_name in xl.sheet_names:
            df = xl.parse(sheet_name).fillna("")
            # Har sheet ka pura data list of lists / dicts mein convert karein
            result["sheets"][sheet_name] = {
                "columns": [str(col).strip() for col in df.columns],
                "rows": df.astype(str).values.tolist()
            }
    except Exception as e:
        print(f"   ❌ Error extracting Excel {filepath}: {e}")

    return result

def extract_full_csv(filepath):
    """Pura CSV data bina truncation ke load karta hai."""
    if not os.path.exists(filepath):
        return []
    try:
        df = pd.read_csv(filepath).fillna("")
        return df.to_dict(orient="records")
    except Exception as e:
        print(f"   ❌ Error loading CSV {filepath}: {e}")
        return []

def main():
    print("=" * 80)
    print("🚀 FULL RAW DOCUMENT EXTRACTOR (ZERO TRUNCATION / NO SUMMARY)")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

    if not os.path.exists(INPUT_DIR):
        print(f"❌ Directory '{INPUT_DIR}' exist nahi karti.")
        return

    # Files scan karein
    eight_core_pdf = None
    wpi_pdf = None
    ipa_excel = None

    for fname in os.listdir(INPUT_DIR):
        lower = fname.lower()
        full_p = os.path.join(INPUT_DIR, fname)
        if "core" in lower and lower.endswith(".pdf"):
            eight_core_pdf = full_p
        elif "wpi" in lower and lower.endswith(".pdf"):
            wpi_pdf = full_p
        elif ("ipa" in lower or "ports" in lower) and lower.endswith((".xlsx", ".xls")):
            ipa_excel = full_p

    master_payload = {
        "extraction_metadata": {
            "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            "status": "RAW_FULL_EXTRACTION"
        },
        "dpiit_eight_core_raw": {},
        "dpiit_wpi_raw": {},
        "ipa_ports_raw": {},
        "netc_fastag_raw_table": []
    }

    # 1. Eight Core PDF ka full content
    if eight_core_pdf:
        print(f"📑 Extracting 100% content from Eight Core PDF: {eight_core_pdf}...")
        master_payload["dpiit_eight_core_raw"] = extract_full_pdf(eight_core_pdf)
    else:
        print("⚠️ Eight Core PDF nahi mila.")

    # 2. WPI PDF ka full content
    if wpi_pdf:
        print(f"📑 Extracting 100% content from WPI PDF: {wpi_pdf}...")
        master_payload["dpiit_wpi_raw"] = extract_full_pdf(wpi_pdf)
    else:
        print("⚠️ WPI PDF nahi mila.")

    # 3. IPA Ports Excel ka full sheet data
    if ipa_excel:
        print(f"📊 Extracting all rows/columns from IPA Ports Excel: {ipa_excel}...")
        master_payload["ipa_ports_raw"] = extract_full_excel(ipa_excel)
    else:
        print("⚠️ IPA Excel file nahi mili.")

    # 4. FASTag full history table
    if os.path.exists(FASTAG_CSV_FILE):
        print(f"🛣️ Loading complete FASTag historical CSV: {FASTAG_CSV_FILE}...")
        master_payload["netc_fastag_raw_table"] = extract_full_csv(FASTAG_CSV_FILE)
    else:
        print("⚠️ FASTag CSV nahi mila.")

    # Single master raw JSON dump
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_payload, f, ensure_ascii=False, indent=2)

    file_size_kb = os.path.getsize(OUTPUT_FILE) // 1024
    print("\n" + "=" * 80)
    print(f"✅ SUCCESS: Poora raw content extract ho gaya!")
    print(f"💾 File Saved: '{OUTPUT_FILE}' ({file_size_kb} KB)")
    print("=" * 80)

if __name__ == "__main__":
    main()
