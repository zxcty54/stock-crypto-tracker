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

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def extract_pdf_data(filepath):
    """PDF ka 100% full text aur saari tables nikaalta hai."""
    res = {
        "file_type": "PDF",
        "total_pages": 0,
        "pages_text": {},
        "pages_tables": {}
    }
    if not pdfplumber or not os.path.exists(filepath):
        return res

    try:
        with pdfplumber.open(filepath) as pdf:
            res["total_pages"] = len(pdf.pages)
            for idx, page in enumerate(pdf.pages):
                page_key = f"page_{idx + 1}"
                
                # Full raw text bina kisi filter ke
                text = page.extract_text(layout=False) or ""
                res["pages_text"][page_key] = text
                
                # Saari tables
                tables = page.extract_tables()
                if tables:
                    clean_tables = []
                    for t in tables:
                        clean_t = [[str(c).strip() if c is not None else "" for c in row] for row in t]
                        clean_tables.append(clean_t)
                    res["pages_tables"][page_key] = clean_tables
    except Exception as e:
        res["error"] = str(e)
        print(f"   ❌ Error extracting PDF ({filepath}): {e}")

    return res

def extract_excel_data(filepath):
    """Excel file ki har single sheet ka data structured format mein dump karta hai."""
    res = {
        "file_type": "EXCEL",
        "sheets": {}
    }
    try:
        xl = pd.ExcelFile(filepath)
        for sheet_name in xl.sheet_names:
            df = xl.parse(sheet_name).fillna("")
            res["sheets"][sheet_name] = {
                "columns": [str(c).strip() for c in df.columns],
                "rows": df.astype(str).values.tolist()
            }
    except Exception as e:
        res["error"] = str(e)
        print(f"   ❌ Error extracting Excel ({filepath}): {e}")

    return res

def extract_csv_data(filepath):
    """CSV file ka poora record list of dicts mein dump karta hai."""
    res = {
        "file_type": "CSV",
        "records": []
    }
    try:
        df = pd.read_csv(filepath).fillna("")
        res["records"] = df.to_dict(orient="records")
    except Exception as e:
        res["error"] = str(e)
        print(f"   ❌ Error extracting CSV ({filepath}): {e}")

    return res

def main():
    print("=" * 80)
    print("🚀 DYNAMIC FOLDER SCANNER & FULL CONTENT EXTRACTOR")
    print(f"📂 Scanning Directory: '{INPUT_DIR}'")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

    if not os.path.exists(INPUT_DIR):
        print(f"❌ Directory '{INPUT_DIR}' exist nahi karti.")
        return

    extracted_files = {}
    
    # Folder ke andar ki har ek file ko dynamically scan karein
    all_files = [f for f in os.listdir(INPUT_DIR) if os.path.isfile(os.path.join(INPUT_DIR, f))]
    
    if not all_files:
        print(f"⚠️ Folder '{INPUT_DIR}' khali hai, koi file nahi mili.")
        return

    print(f"🔍 Found {len(all_files)} files. Starting extraction...\n")

    for filename in sorted(all_files):
        filepath = os.path.join(INPUT_DIR, filename)
        file_ext = os.path.splitext(filename)[1].lower()
        size_kb = os.path.getsize(filepath) // 1024

        print(f"📄 Processing: {filename} ({size_kb} KB)...")

        if file_ext == ".pdf":
            extracted_files[filename] = extract_pdf_data(filepath)
            print(f"   ✅ Extracted {extracted_files[filename]['total_pages']} pages from PDF.")

        elif file_ext in [".xlsx", ".xls"]:
            extracted_files[filename] = extract_excel_data(filepath)
            sheets_count = len(extracted_files[filename].get("sheets", {}))
            print(f"   ✅ Extracted {sheets_count} sheets from Excel.")

        elif file_ext == ".csv":
            extracted_files[filename] = extract_csv_data(filepath)
            rows_count = len(extracted_files[filename].get("records", []))
            print(f"   ✅ Extracted {rows_count} records from CSV.")

        else:
            print(f"   ⚠️ Unsupported format '{file_ext}', skipping.")

    # Also check root for FASTag CSV if saved outside
    if os.path.exists("netc_fastag_monthly_3years.csv") and "netc_fastag_monthly_3years.csv" not in extracted_files:
        print("\n🛣️ Processing: netc_fastag_monthly_3years.csv (Root)...")
        extracted_files["netc_fastag_monthly_3years.csv"] = extract_csv_data("netc_fastag_monthly_3years.csv")
        print(f"   ✅ Extracted {len(extracted_files['netc_fastag_monthly_3years.csv'].get('records', []))} records.")

    # Final Master Payload
    master_payload = {
        "metadata": {
            "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            "total_files_extracted": len(extracted_files),
            "file_names": list(extracted_files.keys())
        },
        "extracted_content": extracted_files
    }

    # Save to JSON
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_payload, f, ensure_ascii=False, indent=2)

    output_kb = os.path.getsize(OUTPUT_FILE) // 1024
    print("\n" + "=" * 80)
    print(f"🎉 SUCCESS: Saari files bina hardcoding ke extract ho gayi!")
    print(f"💾 Output Saved To: '{OUTPUT_FILE}' ({output_kb} KB)")
    print("=" * 80)

if __name__ == "__main__":
    main()
