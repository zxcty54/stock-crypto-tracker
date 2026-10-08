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

# ============================================================
# CONFIGURATION
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
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Origin": "https://www.npci.org.in",
    "Referer": "https://www.npci.org.in/"
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
# 1. DPIIT (EIGHT CORE INDUSTRIES VIA OFFICIAL PIB ENGINE)
# ============================================================

def scrape_dpiit_core_industries(session):
    print("🏭 [1/5] Scraping DPIIT Eight Core Industries...")
    result = {
        "source": "DPIIT / PIB",
        "cement_production_mt": None,
        "steel_production_mt": None,
        "cement_growth_pct": None,
        "steel_growth_pct": None,
        "overall_core_growth_pct": None,
        "release_title": None,
        "release_url": None
    }
    
    # PIB Ministry of Commerce & Industry Press Releases (Always Accessible Globally)
    pib_api = "https://pib.gov.in/AllRelease.aspx"
    try:
        resp = session.get(pib_api, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            target_link = None
            
            for a in soup.find_all("a", href=True):
                txt = a.get_text().strip()
                if "Eight Core" in txt or "eight core industries" in txt.lower():
                    target_link = urljoin("https://pib.gov.in/", a['href'])
                    result["release_title"] = txt
                    break

            if not target_link:
                # Direct search fallback
                search_url = "https://pib.gov.in/PressReleasePage.aspx?PRID=INDEX_CORE"
                target_link = search_url

            result["release_url"] = target_link
            rel_resp = session.get(target_link, headers=COMMON_HEADERS, timeout=25, verify=False)
            if rel_resp.status_code == 200:
                body_text = rel_resp.text
                
                # Overall core growth
                core_match = re.search(r'Eight Core Industries.*?increased by\s+([\d\.]+)\s*%', body_text, re.IGNORECASE)
                if core_match:
                    result["overall_core_growth_pct"] = clean_num(core_match.group(1))

                # Cement Production & Growth
                cem_match = re.search(r'Cement\s+production.*?increased by\s+([\d\.\-]+)\s*%', body_text, re.IGNORECASE)
                if cem_match:
                    result["cement_growth_pct"] = clean_num(cem_match.group(1))

                # Steel Production & Growth
                steel_match = re.search(r'Steel\s+production.*?increased by\s+([\d\.\-]+)\s*%', body_text, re.IGNORECASE)
                if steel_match:
                    result["steel_growth_pct"] = clean_num(steel_match.group(1))

                # Physical volume scan (in Million Tonnes)
                cem_vol = re.search(r'Cement[^\d\n]+(\d{2}\.\d+)\s*(?:million|MT)', body_text, re.IGNORECASE)
                if cem_vol:
                    result["cement_production_mt"] = clean_num(cem_vol.group(1))

                steel_vol = re.search(r'Steel[^\d\n]+(\d{2}\.\d+)\s*(?:million|MT)', body_text, re.IGNORECASE)
                if steel_vol:
                    result["steel_production_mt"] = clean_num(steel_vol.group(1))

        print(f"   ✅ DPIIT: Cement Growth: {result['cement_growth_pct']}% | Steel Growth: {result['steel_growth_pct']}% | Core Overall: {result['overall_core_growth_pct']}%")
    except Exception as e:
        print(f"   ❌ DPIIT Error: {e}")
    return result

# ============================================================
# 2. PPAC (PETROLEUM CONSUMPTION FORENSIC SCAN)
# ============================================================

def scrape_ppac_consumption(session):
    print("🛢️ [2/5] Scraping PPAC (Diesel, Bitumen, Petcoke)...")
    result = {
        "source": "PPAC",
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None,
        "report_period": None,
        "pdf_url": None
    }
    url = "https://ppac.gov.in/consumption"
    try:
        resp = session.get(url, headers=COMMON_HEADERS, timeout=25, verify=False)
        soup = BeautifulSoup(resp.text, "html.parser")
        
        pdf_link = None
        for a in soup.find_all("a", href=True):
            href = a['href']
            txt = (a.get_text() + " " + href).lower()
            if ".pdf" in href.lower() and ("snapshot" in txt or "icr" in txt or "consumption" in txt):
                pdf_link = urljoin("https://ppac.gov.in/", href)
                break

        if pdf_link:
            result["pdf_url"] = pdf_link
            pdf_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=35, verify=False)
            if pdf_resp.status_code == 200 and pdfplumber:
                with pdfplumber.open(io.BytesIO(pdf_resp.content)) as pdf:
                    for page in pdf.pages[:6]:
                        tables = page.extract_tables()
                        for table in tables:
                            for row in table:
                                if not row:
                                    continue
                                row_joined = " ".join([str(c) for c in row if c]).lower()
                                
                                # Quantity filter: Diesel TMT is always in thousands (e.g., 6500 - 8500 TMT)
                                nums = [clean_num(c) for c in row if clean_num(c) is not None]
                                
                                if ("hsd" in row_joined or "diesel" in row_joined) and not result["hsd_diesel_tmt"]:
                                    valid_hsd = [n for n in nums if 3000 <= n <= 15000]
                                    if valid_hsd:
                                        result["hsd_diesel_tmt"] = valid_hsd[0]

                                if "bitumen" in row_joined and not result["bitumen_tmt"]:
                                    valid_bit = [n for n in nums if 200 <= n <= 2000]
                                    if valid_bit:
                                        result["bitumen_tmt"] = valid_bit[0]

                                if "petcoke" in row_joined and not result["petcoke_tmt"]:
                                    valid_pet = [n for n in nums if 300 <= n <= 3000]
                                    if valid_pet:
                                        result["petcoke_tmt"] = valid_pet[0]

        print(f"   ✅ PPAC Extracted: HSD: {result['hsd_diesel_tmt']} TMT | Bitumen: {result['bitumen_tmt']} TMT | Petcoke: {result['petcoke_tmt']} TMT")
    except Exception as e:
        print(f"   ❌ PPAC Error: {e}")
    return result

# ============================================================
# 3. RAILWAYS (VIA PIB RAILWAYS RELEASE - ZERO IP BLOCK)
# ============================================================

def scrape_railways_freight(session):
    print("🚂 [3/5] Scraping Ministry of Railways (Freight Traffic)...")
    result = {
        "source": "Ministry of Railways / PIB",
        "originating_freight_mt": None,
        "freight_revenue_cr": None,
        "cement_clinker_mt": None,
        "iron_ore_mt": None,
        "report_title": None,
        "source_url": None
    }
    
    # Query PIB for Ministry of Railways monthly loading records
    pib_url = "https://pib.gov.in/AllRelease.aspx"
    try:
        resp = session.get(pib_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            target_href = None
            
            for a in soup.find_all("a", href=True):
                txt = a.get_text().strip()
                if "Railway" in txt and ("Freight" in txt or "freight" in txt.lower()):
                    target_href = urljoin("https://pib.gov.in/", a['href'])
                    result["report_title"] = txt
                    break

            if target_href:
                result["source_url"] = target_href
                rel_resp = session.get(target_href, headers=COMMON_HEADERS, timeout=25, verify=False)
                txt_content = rel_resp.text
                
                # Total Freight Loading (in MT)
                total_match = re.search(r'(?:freight loading of|originating freight of)\s*([\d\.,]+)\s*MT', txt_content, re.IGNORECASE)
                if total_match:
                    result["originating_freight_mt"] = clean_num(total_match.group(1))

                # Revenue (in Rs. Cr)
                rev_match = re.search(r'(?:freight revenue of|revenue of)\s*(?:Rs\.?)?\s*([\d\.,]+)\s*crore', txt_content, re.IGNORECASE)
                if rev_match:
                    result["freight_revenue_cr"] = clean_num(rev_match.group(1))

                # Cement & Clinker
                cem = re.search(r'([\d\.,]+)\s*MT\s*of\s*Cement', txt_content, re.IGNORECASE)
                if not cem:
                    cem = re.search(r'Cement[^\d\n]+([\d\.,]+)\s*MT', txt_content, re.IGNORECASE)
                if cem:
                    result["cement_clinker_mt"] = clean_num(cem.group(1))

                # Iron Ore
                iron = re.search(r'([\d\.,]+)\s*MT\s*of\s*Iron\s*Ore', txt_content, re.IGNORECASE)
                if not iron:
                    iron = re.search(r'Iron\s*Ore[^\d\n]+([\d\.,]+)\s*MT', txt_content, re.IGNORECASE)
                if iron:
                    result["iron_ore_mt"] = clean_num(iron.group(1))

        print(f"   ✅ Railways: Total: {result['originating_freight_mt']} MT | Revenue: ₹{result['freight_revenue_cr']} Cr | Cement: {result['cement_clinker_mt']} MT | Iron Ore: {result['iron_ore_mt']} MT")
    except Exception as e:
        print(f"   ❌ Railways Error: {e}")
    return result

# ============================================================
# 4. IPA (INDIAN PORTS ASSOCIATION / SAGARMALA DASHBOARD)
# ============================================================

def scrape_ipa_ports(session):
    print("⚓ [4/5] Scraping Indian Ports Association (Cargo Traffic)...")
    result = {
        "source": "IPA / Ministry of Ports",
        "total_traffic_mt": None,
        "container_teus": None,
        "coking_coal_mt": None,
        "source_url": None
    }
    
    # Mirror via Ministry of Ports Press Releases on PIB
    pib_url = "https://pib.gov.in/AllRelease.aspx"
    try:
        resp = session.get(pib_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            target_href = None
            
            for a in soup.find_all("a", href=True):
                txt = a.get_text().strip().lower()
                if ("major ports" in txt or "traffic handled" in txt or "cargo traffic" in txt):
                    target_href = urljoin("https://pib.gov.in/", a['href'])
                    break

            if target_href:
                result["source_url"] = target_href
                p_resp = session.get(target_href, headers=COMMON_HEADERS, timeout=25, verify=False)
                t_content = p_resp.text
                
                tot = re.search(r'([\d\.,]+)\s*Million\s*Tonnes.*?cargo', t_content, re.IGNORECASE)
                if tot:
                    result["total_traffic_mt"] = clean_num(tot.group(1))
                    
                teu = re.search(r'([\d\.,]+)\s*(?:million)?\s*TEUs', t_content, re.IGNORECASE)
                if teu:
                    result["container_teus"] = clean_num(teu.group(1))

        print(f"   ✅ Ports/IPA Extracted: Total Cargo: {result['total_traffic_mt']} MT | Containers: {result['container_teus']} TEUs")
    except Exception as e:
        print(f"   ❌ IPA Ports Error: {e}")
    return result

# ============================================================
# 5. NPCI / FASTAG (API & HIGHWAY TOLL METRICS ENGINE)
# ============================================================

def scrape_npci_fastag(session):
    print("🛣️ [5/5] Scraping NPCI / NETC FASTag Statistics...")
    result = {
        "source": "NPCI / NETC FASTag",
        "month": None,
        "toll_transaction_volume_crores": None,
        "toll_collection_value_inr_crores": None,
        "commercial_truck_proxy_index": None
    }
    
    # NPCI Direct Static Table & API Endpoints
    target_url = "https://www.npci.org.in/what-we-do/netc-fastag/product-statistics"
    
    try:
        resp = session.get(target_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            
            # 1. Search all tables
            tables = soup.find_all("table")
            for table in tables:
                rows = table.find_all("tr")
                for r in rows:
                    cols = [c.get_text().strip() for c in r.find_all(["td", "th"])]
                    if len(cols) >= 3:
                        c_month = cols[0]
                        nums = [clean_num(c) for c in cols[1:] if clean_num(c) is not None]
                        
                        # Valid FASTag volumes are typically 25 - 45 Cr; Value is 4,000 - 7,000 Cr
                        vol = next((n for n in nums if 20.0 <= n <= 55.0), None)
                        val = next((n for n in nums if n >= 3000.0), None)
                        
                        if vol and val and not result["toll_transaction_volume_crores"]:
                            result["month"] = c_month
                            result["toll_transaction_volume_crores"] = vol
                            result["toll_collection_value_inr_crores"] = val
                            break

            # 2. Regex fallback over page text if tables use custom div classes
            if not result["toll_transaction_volume_crores"]:
                all_nums = re.findall(r'([\d,\.]+)\s*(?:Cr|Crores?)', resp.text, re.IGNORECASE)
                cleaned = [clean_num(n) for n in all_nums if clean_num(n)]
                vol = next((n for n in cleaned if 20.0 <= n <= 55.0), None)
                val = next((n for n in cleaned if n >= 3000.0), None)
                if vol and val:
                    result["toll_transaction_volume_crores"] = vol
                    result["toll_collection_value_inr_crores"] = val

        # Calculate Freight Intensity (Value per Transaction ratio)
        if result["toll_collection_value_inr_crores"] and result["toll_transaction_volume_crores"]:
            result["commercial_truck_proxy_index"] = round(
                result["toll_collection_value_inr_crores"] / result["toll_transaction_volume_crores"], 2
            )

        print(f"   ✅ FASTag: Month: {result['month']} | Volume: {result['toll_transaction_volume_crores']} Cr | Value: ₹{result['toll_collection_value_inr_crores']} Cr | Proxy Index: {result['commercial_truck_proxy_index']}")
    except Exception as e:
        print(f"   ❌ FASTag Error: {e}")
    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

def run_macro_telemetry_pipeline():
    print("=" * 80)
    print("🚀 MACRO-ECONOMIC & PHYSICAL INFRASTRUCTURE TELEMETRY ENGINE")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
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
    print(f"💾 Snapshot successfully committed to '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    run_macro_telemetry_pipeline()
