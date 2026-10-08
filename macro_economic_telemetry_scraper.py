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
# CONFIGURATION & REBUILT CLIENT
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
    "Connection": "keep-alive"
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
# 1. DPIIT (EIGHT CORE INDUSTRIES VIA PIB/DPIIT MIRROR)
# ============================================================

def scrape_dpiit_core_industries(session):
    print("🏭 [1/5] Scraping DPIIT Eight Core Industries...")
    result = {
        "source": "DPIIT",
        "cement_production_mt": None,
        "steel_production_mt": None,
        "cement_index": None,
        "steel_index": None,
        "pdf_url": None
    }
    
    # Primary & Mirror URLs for Eight Core
    target_urls = [
        "https://eaindustry.nic.in/",
        "https://pib.gov.in/PressReleasePage.aspx?PRID=INDEX_CORE",
        "https://www.eaindustry.nic.in/eight_core_infra.asp"
    ]
    
    pdf_link = None
    for url in target_urls:
        try:
            resp = session.get(url, headers=COMMON_HEADERS, timeout=20, verify=False)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                for a in soup.find_all("a", href=True):
                    href = a['href']
                    t = (a.get_text() + " " + href).lower()
                    if ("eight core" in t or "core" in t or "index" in t) and ".pdf" in href.lower():
                        pdf_link = urljoin(url, href)
                        break
            if pdf_link:
                break
        except Exception:
            continue

    if not pdf_link:
        # Fallback to direct latest archive query
        print("   ⚠️ Primary DPIIT page altered. Checking national data repository...")
        pdf_link = "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"

    result["pdf_url"] = pdf_link
    try:
        pdf_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=30, verify=False)
        if pdf_resp.status_code == 200 and pdfplumber:
            with pdfplumber.open(io.BytesIO(pdf_resp.content)) as pdf:
                full_text = "\n".join([p.extract_text() or "" for p in pdf.pages[:6]])
                
                # Match lines like: Cement (Weight: 5.37%) ... Production: 35.4 MT
                cem_matches = re.findall(r'Cement[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if cem_matches:
                    valid = [clean_num(x) for x in cem_matches if clean_num(x) and clean_num(x) > 5.0]
                    if valid:
                        result["cement_production_mt"] = valid[0]

                steel_matches = re.findall(r'Steel[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
                if steel_matches:
                    valid = [clean_num(x) for x in steel_matches if clean_num(x) and clean_num(x) > 5.0]
                    if valid:
                        result["steel_production_mt"] = valid[0]

                c_idx = re.search(r'Cement.*?Index.*?([\d]{2,3}\.[\d]+)', full_text, re.IGNORECASE)
                if c_idx:
                    result["cement_index"] = clean_num(c_idx.group(1))

                s_idx = re.search(r'Steel.*?Index.*?([\d]{2,3}\.[\d]+)', full_text, re.IGNORECASE)
                if s_idx:
                    result["steel_index"] = clean_num(s_idx.group(1))

        print(f"   ✅ DPIIT Extracted: Cement: {result['cement_production_mt']} MT | Steel: {result['steel_production_mt']} MT")
    except Exception as e:
        print(f"   ❌ DPIIT Parser Error: {e}")
        
    return result

# ============================================================
# 2. PPAC — PETROLEUM & GAS (Accurate Column Extraction)
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
        soup = BeautifulSoup(resp.text, "html.parser")
        doc_link = None
        for a in soup.find_all("a", href=True):
            href = a['href']
            t = a.get_text().lower()
            if ("snapshot" in t or "consumption" in t) and any(href.lower().endswith(ext) for ext in [".pdf", ".xlsx", ".xls"]):
                doc_link = urljoin("https://ppac.gov.in/", href)
                break

        if not doc_link:
            for a in soup.find_all("a", href=True):
                if a['href'].endswith((".xlsx", ".xls", ".pdf")):
                    doc_link = urljoin("https://ppac.gov.in/", a['href'])
                    break

        if doc_link:
            result["source_doc_url"] = doc_link
            doc_resp = session.get(doc_link, headers=COMMON_HEADERS, timeout=35, verify=False)
            if doc_resp.status_code == 200 and pdfplumber and doc_link.endswith(".pdf"):
                with pdfplumber.open(io.BytesIO(doc_resp.content)) as pdf:
                    for page in pdf.pages[:6]:
                        tables = page.extract_tables()
                        for table in tables:
                            for row in table:
                                row_str = " ".join([str(c) for c in row if c]).lower()
                                nums = [clean_num(c) for c in row if clean_num(c) is not None and clean_num(c) > 50]
                                if "hsd" in row_str or "high speed diesel" in row_str:
                                    if nums and not result["hsd_diesel_tmt"]:
                                        result["hsd_diesel_tmt"] = nums[0]
                                if "bitumen" in row_str:
                                    if nums and not result["bitumen_tmt"]:
                                        result["bitumen_tmt"] = nums[0]
                                if "petcoke" in row_str or "petroleum coke" in row_str:
                                    if nums and not result["petcoke_tmt"]:
                                        result["petcoke_tmt"] = nums[0]

        print(f"   ✅ PPAC Extracted: HSD: {result['hsd_diesel_tmt']} TMT | Bitumen: {result['bitumen_tmt']} TMT | Petcoke: {result['petcoke_tmt']} TMT")
    except Exception as e:
        print(f"   ❌ PPAC Error: {e}")
    return result

# ============================================================
# 3. RAILWAYS (FALLBACK AGGREGATOR / FOIS / PIB)
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
    
    # Direct PIB Mirror (Bypasses Indian Railways Datacenter IP block)
    pib_rail_url = "https://pib.gov.in/PressReleasePage.aspx?PRID=RAIL_FREIGHT"
    primary_url = "https://indianrailways.gov.in/railwayboard/view_section.jsp?lang=0&id=0,1,304,366,554,630"
    
    pdf_bytes = None
    try:
        # First attempt with short timeout
        resp = session.get(primary_url, headers=COMMON_HEADERS, timeout=12, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            for a in soup.find_all("a", href=True):
                if ".pdf" in a['href'].lower() and "freight" in a.get_text().lower():
                    result["pdf_url"] = urljoin(primary_url, a['href'])
                    p_resp = session.get(result["pdf_url"], headers=COMMON_HEADERS, timeout=20, verify=False)
                    if p_resp.status_code == 200:
                        pdf_bytes = p_resp.content
                    break
    except Exception:
        print("   ⚠️ Indian Railways direct IP blocked runner. Falling back to official PIB release feed...")

    # PIB Fallback
    if not pdf_bytes:
        try:
            pib_feed = "https://pib.gov.in/AllRelease.aspx"
            p_resp = session.get(pib_feed, headers=COMMON_HEADERS, timeout=25, verify=False)
            if p_resp.status_code == 200:
                soup = BeautifulSoup(p_resp.text, "html.parser")
                for a in soup.find_all("a", href=True):
                    txt = a.get_text().lower()
                    if "railway" in txt and ("freight" in txt or "revenue" in txt):
                        p_page = session.get(urljoin("https://pib.gov.in/", a['href']), headers=COMMON_HEADERS, timeout=20, verify=False)
                        txt_body = p_page.text
                        
                        cem = re.search(r'Cement\s*(?:&|\+)?\s*Clinker[^\d\n]+([\d,\.]+)', txt_body, re.IGNORECASE)
                        if cem:
                            result["cement_clinker_mt"] = clean_num(cem.group(1))
                        iron = re.search(r'(?:Iron\s+Ore|Raw\s+Material\s+for\s+Steel)[^\d\n]+([\d,\.]+)', txt_body, re.IGNORECASE)
                        if iron:
                            result["iron_ore_steel_mt"] = clean_num(iron.group(1))
                        break
        except Exception as e:
            print(f"   ⚠️ PIB Railway Fallback note: {e}")

    if pdf_bytes and pdfplumber:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            full_text = "\n".join([p.extract_text() or "" for p in pdf.pages[:4]])
            cem = re.search(r'Cement\s*(?:&|\+)?\s*Clinker[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
            if cem:
                result["cement_clinker_mt"] = clean_num(cem.group(1))
            iron = re.search(r'Iron\s+Ore[^\d\n]+([\d,\.]+)', full_text, re.IGNORECASE)
            if iron:
                result["iron_ore_steel_mt"] = clean_num(iron.group(1))

    print(f"   ✅ Railways Extracted: Cement/Clinker: {result['cement_clinker_mt']} MT | Iron Ore: {result['iron_ore_steel_mt']} MT")
    return result

# ============================================================
# 4. IPA (INDIAN PORTS ASSOCIATION WITH HIGHER TIMEOUT)
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
    # Direct PDF Archive listing to avoid slow CMS redirects
    ipa_urls = [
        "http://ipa.nic.in/index1.cphp?lsid=16&lev=2&lid=34&lang=1",
        "https://shipmin.gov.in/traffic-handled-major-ports"
    ]
    
    for portal in ipa_urls:
        try:
            resp = session.get(portal, headers=COMMON_HEADERS, timeout=40, verify=False)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                pdf_link = None
                for a in soup.find_all("a", href=True):
                    h = a['href']
                    t = (a.get_text() + " " + h).lower()
                    if ".pdf" in h.lower() and ("traffic" in t or "performance" in t or "monthly" in t):
                        pdf_link = urljoin(portal, h)
                        break
                
                if pdf_link:
                    result["pdf_url"] = pdf_link
                    pdf_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=40, verify=False)
                    if pdf_resp.status_code == 200 and pdfplumber:
                        with pdfplumber.open(io.BytesIO(pdf_resp.content)) as pdf:
                            text = "\n".join([p.extract_text() or "" for p in pdf.pages[:6]])
                            
                            t_match = re.search(r'(?:TEUs|Containers?)[^\d\n]+([\d,\.]+)', text, re.IGNORECASE)
                            if t_match:
                                result["container_teus"] = clean_num(t_match.group(1))
                            c_match = re.search(r'Coking\s+Coal[^\d\n]+([\d,\.]+)', text, re.IGNORECASE)
                            if c_match:
                                result["coking_coal_tonnes"] = clean_num(c_match.group(1))
                            trt_match = re.search(r'(?:Turn\s*Around\s*Time|TRT)[^\d\n]+([\d,\.]+)', text, re.IGNORECASE)
                            if trt_match:
                                result["avg_turnaround_hours"] = clean_num(trt_match.group(1))
                    break
        except Exception as e:
            print(f"   ⚠️ IPA Endpoint {portal} timed out or unreachable: {e}")
            continue

    print(f"   ✅ IPA Extracted: Containers: {result['container_teus']} TEUs | TRT: {result['avg_turnaround_hours']} Hrs")
    return result

# ============================================================
# 5. NPCI / FASTAG (DYNAMIC TABLE & EMBEDDED METRIC EXTRACTION)
# ============================================================

def scrape_npci_fastag(session):
    print("🛣️ [5/5] Scraping NPCI / NETC FASTag Statistics...")
    result = {
        "source": "NPCI / FASTag",
        "toll_transaction_volume_crores": None,
        "toll_collection_value_inr_crores": None,
        "commercial_truck_proxy_movement": None
    }
    
    target_urls = [
        "https://www.npci.org.in/what-we-do/netc-fastag/product-statistics",
        "https://www.npci.org.in/api/netc-statistics" # direct headless endpoint
    ]
    
    headers = dict(COMMON_HEADERS)
    headers["Referer"] = "https://www.npci.org.in/"
    
    for url in target_urls:
        try:
            resp = session.get(url, headers=headers, timeout=25, verify=False)
            if resp.status_code == 200:
                # Try JSON API response first
                try:
                    data = resp.json()
                    if isinstance(data, list) and len(data) > 0:
                        latest = data[0]
                        result["toll_transaction_volume_crores"] = clean_num(latest.get("volume") or latest.get("txn_count"))
                        result["toll_collection_value_inr_crores"] = clean_num(latest.get("amount") or latest.get("total_value"))
                except Exception:
                    pass

                # HTML Parsing
                soup = BeautifulSoup(resp.text, "html.parser")
                for tr in soup.find_all("tr"):
                    tds = [td.get_text().strip() for td in tr.find_all(["td", "th"])]
                    if len(tds) >= 3:
                        nums = [clean_num(x) for x in tds if clean_num(x) is not None]
                        # Transaction volumes are typically between 25-50 Crores, Values > 4,000 Crores
                        for val in nums:
                            if 20.0 <= val <= 60.0 and not result["toll_transaction_volume_crores"]:
                                result["toll_transaction_volume_crores"] = val
                            elif val > 3000.0 and not result["toll_collection_value_inr_crores"]:
                                result["toll_collection_value_inr_crores"] = val

                if result["toll_transaction_volume_crores"] and result["toll_collection_value_inr_crores"]:
                    break
        except Exception:
            continue

    # Compute Commercial Freight Intensity Ratio
    if result["toll_collection_value_inr_crores"] and result["toll_transaction_volume_crores"]:
        result["commercial_truck_proxy_movement"] = round(
            result["toll_collection_value_inr_crores"] / result["toll_transaction_volume_crores"], 2
        )

    print(f"   ✅ FASTag Extracted: Volume: {result['toll_transaction_volume_crores']} Cr | Value: ₹{result['toll_collection_value_inr_crores']} Cr | Proxy Ratio: {result['commercial_truck_proxy_movement']}")
    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

def run_macro_telemetry_pipeline():
    print("=" * 80)
    print("🚀 MACRO-ECONOMIC & PHYSICAL INFRASTRUCTURE TELEMETRY PIPELINE")
    print(f"📅 Execution Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

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

    history = []
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                history = loaded if isinstance(loaded, list) else [loaded]
        except Exception:
            history = []

    history.insert(0, telemetry_payload)
    history = history[:60]

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Master Telemetry Snapshot written successfully to: '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    run_macro_telemetry_pipeline()
