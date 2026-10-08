import os
import io
import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
from bs4 import BeautifulSoup
from curl_cffi import requests

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

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
    "Accept-Language": "en-US,en;q=0.9"
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

def fetch_pib_rss_links(session, min_id, keywords):
    """Bypasses ASP.NET ViewState by reading PIB's raw Ministry RSS feeds."""
    rss_url = f"https://pib.gov.in/RssMain.aspx?ModId=6&MinId={min_id}"
    try:
        resp = session.get(rss_url, headers=COMMON_HEADERS, timeout=20, verify=False)
        if resp.status_code == 200:
            root = ET.fromstring(resp.content)
            for item in root.findall(".//item"):
                title = (item.find("title").text or "").strip()
                link = (item.find("link").text or "").strip()
                if any(kw.lower() in title.lower() for kw in keywords):
                    return title, link
    except Exception:
        pass
    return None, None

# ============================================================
# 1. DPIIT — EIGHT CORE INDUSTRIES (VIA PIB RSS)
# ============================================================

def scrape_dpiit_core_industries(session):
    print("🏭 [1/5] Scraping DPIIT Eight Core Industries...")
    result = {
        "source": "DPIIT",
        "cement_growth_pct": None,
        "steel_growth_pct": None,
        "overall_core_growth_pct": None,
        "cement_production_mt": None,
        "steel_production_mt": None,
        "release_title": None,
        "url": None
    }
    
    # MinId=8 is Ministry of Commerce & Industry
    title, link = fetch_pib_rss_links(session, min_id=8, keywords=["eight core", "core industries", "index of eight"])
    
    # Fallback to direct PR search if RSS is during transition
    if not link:
        link = "https://pib.gov.in/PressReleasePage.aspx?PRID=INDEX_CORE"
    
    result["url"] = link
    result["release_title"] = title or "Index of Eight Core Industries"
    
    try:
        resp = session.get(link, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            text = resp.text
            
            # Overall Core growth
            m_core = re.search(r'(?:increased by|growth of)\s+([\d\.\-]+)\s*%', text, re.IGNORECASE)
            if m_core:
                result["overall_core_growth_pct"] = clean_num(m_core.group(1))

            # Cement growth
            m_cem = re.search(r'Cement\s+production[^\d\n%]+(?:increased|declined|growth)?.*?([\d\.\-]+)\s*%', text, re.IGNORECASE)
            if m_cem:
                result["cement_growth_pct"] = clean_num(m_cem.group(1))

            # Steel growth
            m_stl = re.search(r'Steel\s+production[^\d\n%]+(?:increased|declined|growth)?.*?([\d\.\-]+)\s*%', text, re.IGNORECASE)
            if m_stl:
                result["steel_growth_pct"] = clean_num(m_stl.group(1))

            # Production volumes
            v_cem = re.search(r'Cement[^\d\n]+([\d,\.]+)\s*(?:million|MT)', text, re.IGNORECASE)
            if v_cem:
                result["cement_production_mt"] = clean_num(v_cem.group(1))

            v_stl = re.search(r'Steel[^\d\n]+([\d,\.]+)\s*(?:million|MT)', text, re.IGNORECASE)
            if v_stl:
                result["steel_production_mt"] = clean_num(v_stl.group(1))

        print(f"   ✅ DPIIT: Core Growth: {result['overall_core_growth_pct']}% | Cement: {result['cement_growth_pct']}% | Steel: {result['steel_growth_pct']}%")
    except Exception as e:
        print(f"   ❌ DPIIT Error: {e}")
        
    return result

# ============================================================
# 2. PPAC — DIESEL, BITUMEN & PETCOKE (TEXT-STREAM REGEX)
# ============================================================

def scrape_ppac_consumption(session):
    print("🛢️ [2/5] Scraping PPAC (Diesel, Bitumen, Petcoke)...")
    result = {
        "source": "PPAC",
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None,
        "pdf_url": None
    }
    
    url = "https://ppac.gov.in/consumption"
    try:
        resp = session.get(url, headers=COMMON_HEADERS, timeout=25, verify=False)
        soup = BeautifulSoup(resp.text, "html.parser")
        
        pdf_link = None
        for a in soup.find_all("a", href=True):
            h = a['href']
            t = (a.get_text() + " " + h).lower()
            if ".pdf" in h.lower() and ("snapshot" in t or "icr" in t or "consumption" in t):
                pdf_link = urljoin("https://ppac.gov.in/", h)
                break

        if pdf_link:
            result["pdf_url"] = pdf_link
            p_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=35, verify=False)
            if p_resp.status_code == 200 and pdfplumber:
                with pdfplumber.open(io.BytesIO(p_resp.content)) as pdf:
                    full_text = "\n".join([page.extract_text() or "" for page in pdf.pages[:6]])
                    
                    # Target lines with fuel names followed by quantity columns
                    for line in full_text.split("\n"):
                        l_lower = line.lower()
                        # Extract all numbers on this line
                        nums = [clean_num(x) for x in re.findall(r'[\d,]+\.?\d*', line)]
                        nums = [n for n in nums if n is not None]

                        if ("hsd" in l_lower or "high speed diesel" in l_lower) and not result["hsd_diesel_tmt"]:
                            # Typical monthly HSD is between 5,000 and 10,000 TMT
                            hsd_candidates = [n for n in nums if 3000 <= n <= 12000]
                            if hsd_candidates:
                                result["hsd_diesel_tmt"] = hsd_candidates[0]

                        if "bitumen" in l_lower and not result["bitumen_tmt"]:
                            # Bitumen monthly is typically 300 to 1,500 TMT
                            bit_candidates = [n for n in nums if 100 <= n <= 2000]
                            if bit_candidates:
                                result["bitumen_tmt"] = bit_candidates[0]

                        if ("petcoke" in l_lower or "petroleum coke" in l_lower) and not result["petcoke_tmt"]:
                            # Petcoke monthly is typically 400 to 2,500 TMT
                            pet_candidates = [n for n in nums if 200 <= n <= 3000]
                            if pet_candidates:
                                result["petcoke_tmt"] = pet_candidates[0]

        print(f"   ✅ PPAC Extracted: HSD: {result['hsd_diesel_tmt']} TMT | Bitumen: {result['bitumen_tmt']} TMT | Petcoke: {result['petcoke_tmt']} TMT")
    except Exception as e:
        print(f"   ❌ PPAC Error: {e}")
    return result

# ============================================================
# 3. RAILWAYS (VIA PIB RSS - MINID 26)
# ============================================================

def scrape_railways_freight(session):
    print("🚂 [3/5] Scraping Ministry of Railways (Freight Traffic)...")
    result = {
        "source": "Indian Railways",
        "originating_freight_mt": None,
        "freight_revenue_cr": None,
        "cement_clinker_mt": None,
        "iron_ore_mt": None,
        "url": None
    }
    
    # MinId=26 is Ministry of Railways
    title, link = fetch_pib_rss_links(session, min_id=26, keywords=["freight", "revenue freight", "loading"])
    
    if link:
        result["url"] = link
        try:
            resp = session.get(link, headers=COMMON_HEADERS, timeout=25, verify=False)
            if resp.status_code == 200:
                txt = resp.text
                
                # Total freight volume
                m_tot = re.search(r'([\d\.,]+)\s*MT\s*(?:freight|originating)', txt, re.IGNORECASE)
                if not m_tot:
                    m_tot = re.search(r'(?:freight loading of|originating freight of)\s*([\d\.,]+)\s*MT', txt, re.IGNORECASE)
                if m_tot:
                    result["originating_freight_mt"] = clean_num(m_tot.group(1))

                # Freight Revenue
                m_rev = re.search(r'(?:revenue of|revenue reached)\s*(?:Rs\.?)?\s*([\d\.,]+)\s*crore', txt, re.IGNORECASE)
                if m_rev:
                    result["freight_revenue_cr"] = clean_num(m_rev.group(1))

                # Cement loading
                m_cem = re.search(r'([\d\.,]+)\s*MT\s*of\s*Cement', txt, re.IGNORECASE)
                if m_cem:
                    result["cement_clinker_mt"] = clean_num(m_cem.group(1))

                # Iron ore loading
                m_iron = re.search(r'([\d\.,]+)\s*MT\s*of\s*Iron\s*Ore', txt, re.IGNORECASE)
                if m_iron:
                    result["iron_ore_mt"] = clean_num(m_iron.group(1))

        except Exception as e:
            print(f"   ❌ Railways Parse Error: {e}")

    print(f"   ✅ Railways: Total: {result['originating_freight_mt']} MT | Revenue: ₹{result['freight_revenue_cr']} Cr | Cement: {result['cement_clinker_mt']} MT | Iron Ore: {result['iron_ore_mt']} MT")
    return result

# ============================================================
# 4. IPA (PORTS TRAFFIC VIA PIB RSS - MINID 54)
# ============================================================

def scrape_ipa_ports(session):
    print("⚓ [4/5] Scraping Indian Ports Association (Cargo Traffic)...")
    result = {
        "source": "IPA / Ports Ministry",
        "cargo_traffic_mt": None,
        "container_teus": None,
        "url": None
    }
    
    # MinId=54 is Ministry of Ports, Shipping and Waterways
    title, link = fetch_pib_rss_links(session, min_id=54, keywords=["traffic", "cargo", "major ports", "performance"])
    
    if link:
        result["url"] = link
        try:
            resp = session.get(link, headers=COMMON_HEADERS, timeout=25, verify=False)
            if resp.status_code == 200:
                txt = resp.text
                m_cargo = re.search(r'([\d\.,]+)\s*(?:Million\s*Tonnes|MT).*?(?:cargo|traffic)', txt, re.IGNORECASE)
                if m_cargo:
                    result["cargo_traffic_mt"] = clean_num(m_cargo.group(1))

                m_teu = re.search(r'([\d\.,]+)\s*(?:million|lakh)?\s*TEUs', txt, re.IGNORECASE)
                if m_teu:
                    result["container_teus"] = clean_num(m_teu.group(1))
        except Exception as e:
            print(f"   ❌ Ports Parse Error: {e}")

    print(f"   ✅ Ports: Cargo Traffic: {result['cargo_traffic_mt']} MT | Containers: {result['container_teus']} TEUs")
    return result

# ============================================================
# 5. FASTAG (MULTI-ENDPOINT TELEMETRY)
# ============================================================

def scrape_npci_fastag(session):
    print("🛣️ [5/5] Scraping NPCI / NETC FASTag Statistics...")
    result = {
        "source": "NETC FASTag",
        "toll_volume_crores": None,
        "toll_value_inr_crores": None,
        "freight_intensity_ratio": None
    }
    
    endpoints = [
        "https://www.npci.org.in/what-we-do/netc-fastag/product-statistics",
        "https://ihmcl.co.in/fastag-statistics/"
    ]
    
    for url in endpoints:
        try:
            resp = session.get(url, headers=COMMON_HEADERS, timeout=20, verify=False)
            if resp.status_code == 200 and len(resp.text) > 500:
                soup = BeautifulSoup(resp.text, "html.parser")
                
                # Scan table cells
                for row in soup.find_all("tr"):
                    cells = [c.get_text().strip() for c in row.find_all(["td", "th"])]
                    nums = [clean_num(c) for c in cells if clean_num(c) is not None]
                    
                    # Volume is typically 25 to 50 Crores, Value is 4,000 to 7,000 Crores
                    v_vol = next((n for n in nums if 20.0 <= n <= 55.0), None)
                    v_val = next((n for n in nums if 3000.0 <= n <= 10000.0), None)
                    
                    if v_vol and not result["toll_volume_crores"]:
                        result["toll_volume_crores"] = v_vol
                    if v_val and not result["toll_value_inr_crores"]:
                        result["toll_value_inr_crores"] = v_val
                    
                    if result["toll_volume_crores"] and result["toll_value_inr_crores"]:
                        break

                # Regex fallback
                if not result["toll_volume_crores"]:
                    all_nums = [clean_num(n) for n in re.findall(r'[\d,]+\.?\d*', resp.text) if clean_num(n)]
                    v_vol = next((n for n in all_nums if 20.0 <= n <= 55.0), None)
                    v_val = next((n for n in all_nums if 3500.0 <= n <= 9000.0), None)
                    if v_vol:
                        result["toll_volume_crores"] = v_vol
                    if v_val:
                        result["toll_value_inr_crores"] = v_val

            if result["toll_volume_crores"] and result["toll_value_inr_crores"]:
                break
        except Exception:
            continue

    if result["toll_value_inr_crores"] and result["toll_volume_crores"]:
        result["freight_intensity_ratio"] = round(
            result["toll_value_inr_crores"] / result["toll_volume_crores"], 2
        )

    print(f"   ✅ FASTag: Volume: {result['toll_volume_crores']} Cr | Value: ₹{result['toll_value_inr_crores']} Cr | Freight Ratio: {result['freight_intensity_ratio']}")
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
