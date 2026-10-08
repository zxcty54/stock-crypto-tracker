import os
import io
import json
import re
import time
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
from bs4 import BeautifulSoup
from curl_cffi import requests

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

try:
    import pandas as pd
except ImportError:
    pd = None

# ============================================================
# CONFIGURATION & HEADERS
# ============================================================

OUTPUT_FILE = "macro_telemetry_master.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

COMMON_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

def clean_num(val):
    if val is None:
        return None
    s = str(val).replace(",", "").replace("%", "").strip()
    match = re.search(r'[-+]?\d*\.?\d+', s)
    if match:
        try:
            return float(match.group(0))
        except ValueError:
            return None
    return None

# ============================================================
# 1. DPIIT — EIGHT CORE INDUSTRIES (Cement & Steel)
# ============================================================

def scrape_dpiit_core_industries(session):
    print("🏭 [1/5] Scraping DPIIT Eight Core Industries...")
    result = {
        "source": "DPIIT",
        "cement_production_mt": None,
        "steel_production_mt": None,
        "cement_index": None,
        "steel_index": None,
        "report_date": None,
        "pdf_url": None
    }
    archive_url = "https://eaindustry.nic.in/eight_core_infra.asp"
    try:
        resp = session.get(archive_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code != 200:
            print(f"   ⚠️ DPIIT Archive returned status {resp.status_code}")
            return result

        soup = BeautifulSoup(resp.text, "html.parser")
        pdf_link = None
        for a in soup.find_all("a", href=True):
            href = a['href']
            text = a.get_text().lower()
            if ".pdf" in href.lower() and ("press" in text or "core" in text or "index" in text):
                pdf_link = urljoin("https://eaindustry.nic.in/", href)
                break

        if not pdf_link:
            for a in soup.find_all("a", href=True):
                if ".pdf" in a['href'].lower():
                    pdf_link = urljoin("https://eaindustry.nic.in/", a['href'])
                    break

        if not pdf_link:
            print("   ❌ DPIIT: Press release PDF link not found.")
            return result

        result["pdf_url"] = pdf_link
        print(f"   📄 DPIIT PDF Found: {pdf_link}")

        pdf_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=30, verify=False)
        if pdf_resp.status_code == 200 and pdfplumber:
            with pdfplumber.open(io.BytesIO(pdf_resp.content)) as pdf:
                full_text = "\n".join([page.extract_text() or "" for page in pdf.pages[:5]])
                
                # Cement Production Search
                c_match = re.search(r'Cement\s+[\d\.,\(\)\-]+\s+([\d\.,]+)', full_text, re.IGNORECASE)
                if c_match:
                    result["cement_production_mt"] = clean_num(c_match.group(1))

                # Steel Production Search
                s_match = re.search(r'Steel\s+[\d\.,\(\)\-]+\s+([\d\.,]+)', full_text, re.IGNORECASE)
                if s_match:
                    result["steel_production_mt"] = clean_num(s_match.group(1))

                # Index Points Search
                c_idx = re.search(r'Cement.*?Index.*?(\d{2,3}\.\d+)', full_text, re.IGNORECASE)
                if c_idx:
                    result["cement_index"] = clean_num(c_idx.group(1))

                s_idx = re.search(r'Steel.*?Index.*?(\d{2,3}\.\d+)', full_text, re.IGNORECASE)
                if s_idx:
                    result["steel_index"] = clean_num(s_idx.group(1))

        print(f"   ✅ DPIIT Extracted: Cement: {result['cement_production_mt']} MT | Steel: {result['steel_production_mt']} MT")
    except Exception as e:
        print(f"   ❌ DPIIT Error: {e}")
    return result

# ============================================================
# 2. PPAC — PETROLEUM & GAS (HSD, Bitumen, Petcoke)
# ============================================================

def scrape_ppac_consumption(session):
    print("🛢️ [2/5] Scraping PPAC (Diesel, Bitumen, Petcoke)...")
    result = {
        "source": "PPAC",
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None,
        "source_doc_url": None
    }
    target_url = "https://ppac.gov.in/consumption"
    try:
        resp = session.get(target_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code != 200:
            print(f"   ⚠️ PPAC returned status {resp.status_code}")
            return result

        soup = BeautifulSoup(resp.text, "html.parser")
        doc_link = None
        for a in soup.find_all("a", href=True):
            href = a['href']
            text = a.get_text().lower()
            if ("snapshot" in text or "consumption" in text) and (href.endswith(".pdf") or href.endswith(".xlsx") or href.endswith(".xls")):
                doc_link = urljoin("https://ppac.gov.in/", href)
                break

        if not doc_link:
            for a in soup.find_all("a", href=True):
                if a['href'].endswith((".xlsx", ".xls", ".pdf")):
                    doc_link = urljoin("https://ppac.gov.in/", a['href'])
                    break

        if not doc_link:
            print("   ❌ PPAC: Snapshot/Consumption file link not found.")
            return result

        result["source_doc_url"] = doc_link
        print(f"   📄 PPAC File Found: {doc_link}")

        doc_resp = session.get(doc_link, headers=COMMON_HEADERS, timeout=30, verify=False)
        if doc_resp.status_code == 200:
            content_bytes = doc_resp.content

            if doc_link.endswith(".pdf") and pdfplumber:
                with pdfplumber.open(io.BytesIO(content_bytes)) as pdf:
                    full_text = "\n".join([page.extract_text() or "" for page in pdf.pages[:6]])
                    
                    # HSD / Diesel regex (in Thousand Metric Tonnes)
                    hsd_match = re.search(r'(?:HSD|Diesel)[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                    if hsd_match:
                        result["hsd_diesel_tmt"] = clean_num(hsd_match.group(1))

                    # Bitumen
                    bit_match = re.search(r'Bitumen[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                    if bit_match:
                        result["bitumen_tmt"] = clean_num(bit_match.group(1))

                    # Petcoke
                    pet_match = re.search(r'Petcoke[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                    if pet_match:
                        result["petcoke_tmt"] = clean_num(pet_match.group(1))

            elif doc_link.endswith((".xlsx", ".xls")) and pd:
                excel_data = pd.read_excel(io.BytesIO(content_bytes), sheet_name=None)
                for sheet_name, df in excel_data.items():
                    df_str = df.astype(str)
                    for col in df_str.columns:
                        for idx, val in enumerate(df_str[col]):
                            val_lower = val.lower()
                            if "hsd" in val_lower or "diesel" in val_lower:
                                nums = [clean_num(x) for x in df.iloc[idx].values if clean_num(x) is not None]
                                if nums and not result["hsd_diesel_tmt"]:
                                    result["hsd_diesel_tmt"] = nums[0]
                            if "bitumen" in val_lower:
                                nums = [clean_num(x) for x in df.iloc[idx].values if clean_num(x) is not None]
                                if nums and not result["bitumen_tmt"]:
                                    result["bitumen_tmt"] = nums[0]
                            if "petcoke" in val_lower:
                                nums = [clean_num(x) for x in df.iloc[idx].values if clean_num(x) is not None]
                                if nums and not result["petcoke_tmt"]:
                                    result["petcoke_tmt"] = nums[0]

        print(f"   ✅ PPAC Extracted: HSD: {result['hsd_diesel_tmt']} TMT | Bitumen: {result['bitumen_tmt']} TMT | Petcoke: {result['petcoke_tmt']} TMT")
    except Exception as e:
        print(f"   ❌ PPAC Error: {e}")
    return result

# ============================================================
# 3. RAILWAYS (CRIS / RAILWAY BOARD) — FREIGHT REVENUE TRAFFIC
# ============================================================

def scrape_railways_freight(session):
    print("🚂 [3/5] Scraping Ministry of Railways (Freight Traffic)...")
    result = {
        "source": "Indian Railways",
        "cement_clinker_mt": None,
        "iron_ore_steel_mt": None,
        "rakes_loaded_per_day": None,
        "pdf_url": None
    }
    board_url = "https://indianrailways.gov.in/railwayboard/view_section.jsp?lang=0&id=0,1,304,366,554,630"
    try:
        resp = session.get(board_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code != 200:
            print(f"   ⚠️ Railways portal returned status {resp.status_code}")
            return result

        soup = BeautifulSoup(resp.text, "html.parser")
        pdf_link = None
        for a in soup.find_all("a", href=True):
            href = a['href']
            text = a.get_text().lower()
            if ".pdf" in href.lower() and ("revenue" in text or "freight" in text or "statement" in text):
                pdf_link = urljoin("https://indianrailways.gov.in/railwayboard/", href)
                break

        if not pdf_link:
            for a in soup.find_all("a", href=True):
                if a['href'].lower().endswith(".pdf"):
                    pdf_link = urljoin("https://indianrailways.gov.in/railwayboard/", a['href'])
                    break

        if not pdf_link:
            print("   ❌ Railways: Freight PDF link not found.")
            return result

        result["pdf_url"] = pdf_link
        print(f"   📄 Railways PDF Found: {pdf_link}")

        pdf_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=30, verify=False)
        if pdf_resp.status_code == 200 and pdfplumber:
            with pdfplumber.open(io.BytesIO(pdf_resp.content)) as pdf:
                full_text = "\n".join([page.extract_text() or "" for page in pdf.pages[:4]])

                # Cement Loading regex (Million Tonnes)
                cem_match = re.search(r'Cement\s*(?:&|\+)?\s*Clinker[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if cem_match:
                    result["cement_clinker_mt"] = clean_num(cem_match.group(1))

                # Iron Ore / Steel raw materials
                iron_match = re.search(r'(?:Iron\s+Ore|Raw\s+Material\s+for\s+Steel)[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if iron_match:
                    result["iron_ore_steel_mt"] = clean_num(iron_match.group(1))

                # Rakes Loaded per day
                rakes_match = re.search(r'(?:Rakes\s+per\s+day|Total\s+Rakes)[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if rakes_match:
                    result["rakes_loaded_per_day"] = clean_num(rakes_match.group(1))

        print(f"   ✅ Railways Extracted: Cement/Clinker: {result['cement_clinker_mt']} MT | Iron Ore: {result['iron_ore_steel_mt']} MT")
    except Exception as e:
        print(f"   ❌ Railways Error: {e}")
    return result

# ============================================================
# 4. IPA (INDIAN PORTS ASSOCIATION) — CONTAINER & CARGO EXIM
# ============================================================

def scrape_ipa_ports(session):
    print("⚓ [4/5] Scraping Indian Ports Association (Cargo & Container)...")
    result = {
        "source": "IPA",
        "container_teus": None,
        "coking_coal_tonnes": None,
        "thermal_coal_tonnes": None,
        "avg_turnaround_hours": None,
        "pdf_url": None
    }
    portal_url = "http://ipa.nic.in/index1.cphp?lsid=16&lev=2&lid=34&lang=1"
    try:
        resp = session.get(portal_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code != 200:
            print(f"   ⚠️ IPA portal returned status {resp.status_code}")
            return result

        soup = BeautifulSoup(resp.text, "html.parser")
        pdf_link = None
        for a in soup.find_all("a", href=True):
            href = a['href']
            text = a.get_text().lower()
            if ".pdf" in href.lower() and ("performance" in text or "traffic" in text or "monthly" in text):
                pdf_link = urljoin("http://ipa.nic.in/", href)
                break

        if not pdf_link:
            for a in soup.find_all("a", href=True):
                if a['href'].lower().endswith(".pdf"):
                    pdf_link = urljoin("http://ipa.nic.in/", a['href'])
                    break

        if not pdf_link:
            print("   ❌ IPA: Performance report PDF link not found.")
            return result

        result["pdf_url"] = pdf_link
        print(f"   📄 IPA PDF Found: {pdf_link}")

        pdf_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=30, verify=False)
        if pdf_resp.status_code == 200 and pdfplumber:
            with pdfplumber.open(io.BytesIO(pdf_resp.content)) as pdf:
                full_text = "\n".join([page.extract_text() or "" for page in pdf.pages[:6]])

                # TEUs container volume
                teu_match = re.search(r'(?:TEUs|Containers?)[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if teu_match:
                    result["container_teus"] = clean_num(teu_match.group(1))

                # Coking & Thermal Coal
                coking_match = re.search(r'Coking\s+Coal[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if coking_match:
                    result["coking_coal_tonnes"] = clean_num(coking_match.group(1))

                thermal_match = re.search(r'Thermal\s+Coal[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if thermal_match:
                    result["thermal_coal_tonnes"] = clean_num(thermal_match.group(1))

                # Turn Around Time (TRT)
                trt_match = re.search(r'(?:Turn\s*Around\s*Time|TRT)[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if trt_match:
                    result["avg_turnaround_hours"] = clean_num(trt_match.group(1))

        print(f"   ✅ IPA Extracted: Containers: {result['container_teus']} TEUs | TRT: {result['avg_turnaround_hours']} Hrs")
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")
    return result

# ============================================================
# 5. NPCI / NETC — FASTAG COMMERCIAL TOLL TELEMETRY
# ============================================================

def scrape_npci_fastag(session):
    print("🛣️ [5/5] Scraping NPCI / NETC FASTag Statistics...")
    result = {
        "source": "NPCI / FASTag",
        "toll_transaction_volume_crores": None,
        "toll_collection_value_inr_crores": None,
        "commercial_truck_proxy_movement": None
    }
    url = "https://www.npci.org.in/what-we-do/netc-fastag/product-statistics"
    try:
        resp = session.get(url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code != 200:
            print(f"   ⚠️ NPCI returned status {resp.status_code}")
            return result

        soup = BeautifulSoup(resp.text, "html.parser")
        
        # Scrape tables for latest monthly stats
        table = soup.find("table")
        if table:
            rows = table.find_all("tr")
            if len(rows) > 1:
                latest_cols = [td.get_text().strip() for td in rows[1].find_all(["td", "th"])]
                if len(latest_cols) >= 3:
                    result["toll_transaction_volume_crores"] = clean_num(latest_cols[1])
                    result["toll_collection_value_inr_crores"] = clean_num(latest_cols[2])

        # Regex fallback from general text if table markup is dynamic
        if not result["toll_transaction_volume_crores"]:
            vol_match = re.search(r'(?:Transaction\s+Volume|Count)[^\d\n]+([\d,\.]+)\s*(?:Cr|Crore)?', resp.text, re.IGNORECASE)
            if vol_match:
                result["toll_transaction_volume_crores"] = clean_num(vol_match.group(1))

        if not result["toll_collection_value_inr_crores"]:
            val_match = re.search(r'(?:Collection\s+Value|Total\s+Value)[^\d\n]+(?:₹|Rs\.?)?\s*([\d,\.]+)\s*(?:Cr|Crore)?', resp.text, re.IGNORECASE)
            if val_match:
                result["toll_collection_value_inr_crores"] = clean_num(val_match.group(1))

        # Commercial Movement Proxy: Volume to Value ratio or heavy vehicle allocation
        if result["toll_collection_value_inr_crores"] and result["toll_transaction_volume_crores"]:
            result["commercial_truck_proxy_movement"] = round(
                result["toll_collection_value_inr_crores"] / result["toll_transaction_volume_crores"], 2
            )

        print(f"   ✅ FASTag Extracted: Volume: {result['toll_transaction_volume_crores']} Cr | Value: ₹{result['toll_collection_value_inr_crores']} Cr")
    except Exception as e:
        print(f"   ❌ NPCI FASTag Error: {e}")
    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

def run_macro_telemetry_pipeline():
    print("=" * 80)
    print("🚀 MACRO-ECONOMIC & PHYSICAL INFRASTRUCTURE TELEMETRY PIPELINE")
    print(f"📅 Execution Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

    # Browser impersonation session
    session = requests.Session(impersonate="chrome124")

    telemetry_payload = {
        "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "metrics": {
            "dpiit_eight_core": scrape_dpiit_core_industries(session),
            "ppac_petroleum": scrape_ppac_consumption(session),
            "railways_freight": scrape_railways_freight(session),
            "ipa_ports": scrape_ipa_ports(session),
            "fastag_road_logistics": scrape_npci_fastag(session)
        }
    }

    # Load existing history or write fresh
    history = []
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                history = loaded if isinstance(loaded, list) else [loaded]
        except Exception:
            history = []

    history.insert(0, telemetry_payload)
    history = history[:60]  # Store last 60 execution snapshots

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Master Telemetry Snapshot written successfully to: '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    run_macro_telemetry_pipeline()
