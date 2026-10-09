import os
import io
import json
import re
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

# ============================================================
# 1 & 3 & 4. PIB BACKEND DIRECT API RESOLVER
# ============================================================

def fetch_latest_pib_release_text(session, ministry_keywords, title_keywords):
    """
    Directly queries PIB's raw release lists and extracts full HTML release body
    without dealing with ASP.NET forms or pagination.
    """
    api_url = "https://pib.gov.in/AllRelease.aspx"
    try:
        # Standard release listing
        resp = session.get(api_url, headers=COMMON_HEADERS, timeout=20, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            for a in soup.find_all("a", href=True):
                txt = a.get_text().strip().lower()
                href = a['href']
                if any(k.lower() in txt for k in title_keywords) and "pressrelease" in href.lower():
                    full_link = urljoin("https://pib.gov.in/", href)
                    rel_page = session.get(full_link, headers=COMMON_HEADERS, timeout=20, verify=False)
                    if rel_page.status_code == 200:
                        psoup = BeautifulSoup(rel_page.text, "html.parser")
                        return psoup.get_text(), full_link
    except Exception:
        pass
    return "", ""

# ============================================================
# 1. DPIIT — EIGHT CORE INDUSTRIES
# ============================================================

def scrape_dpiit_core_industries(session):
    print("🏭 [1/5] Extracting DPIIT Eight Core Industries...")
    result = {
        "source": "DPIIT",
        "cement_growth_pct": None,
        "steel_growth_pct": None,
        "overall_core_growth_pct": None,
        "cement_production_mt": None,
        "steel_production_mt": None
    }

    text, link = fetch_latest_pib_release_text(session, ["commerce"], ["eight core", "core industries"])
    
    # Fallback to direct economic advisory monthly index
    if not text:
        try:
            fallback_url = "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"
            f_resp = session.get(fallback_url, headers=COMMON_HEADERS, timeout=20, verify=False)
            if f_resp.status_code == 200 and pdfplumber:
                with pdfplumber.open(io.BytesIO(f_resp.content)) as pdf:
                    text = "\n".join([p.extract_text() or "" for p in pdf.pages[:5]])
        except Exception:
            pass

    if text:
        # Core overall
        m_core = re.search(r'(?:Eight Core Industries|combined Index)[^\d\n%]+(?:increased|growth of|by)\s+([\d\.\-]+)\s*%', text, re.IGNORECASE)
        if m_core:
            result["overall_core_growth_pct"] = clean_num(m_core.group(1))

        # Cement
        m_cem = re.search(r'Cement\s+production[^\d\n%]+(?:increased|declined|growth|by)?\s*([\d\.\-]+)\s*%', text, re.IGNORECASE)
        if m_cem:
            result["cement_growth_pct"] = clean_num(m_cem.group(1))
        
        m_cem_v = re.search(r'Cement[^\d\n]+([\d,\.]+)\s*(?:million|MT)', text, re.IGNORECASE)
        if m_cem_v:
            result["cement_production_mt"] = clean_num(m_cem_v.group(1))

        # Steel
        m_stl = re.search(r'Steel\s+production[^\d\n%]+(?:increased|declined|growth|by)?\s*([\d\.\-]+)\s*%', text, re.IGNORECASE)
        if m_stl:
            result["steel_growth_pct"] = clean_num(m_stl.group(1))

        m_stl_v = re.search(r'Steel[^\d\n]+([\d,\.]+)\s*(?:million|MT)', text, re.IGNORECASE)
        if m_stl_v:
            result["steel_production_mt"] = clean_num(m_stl_v.group(1))

    print(f"   ✅ DPIIT: Core: {result['overall_core_growth_pct']}% | Cement: {result['cement_growth_pct']}% | Steel: {result['steel_growth_pct']}%")
    return result

# ============================================================
# 2. PPAC — DIESEL, BITUMEN & PETCOKE (EXCLUDING CALENDAR YEARS)
# ============================================================

def scrape_ppac_consumption(session):
    print("🛢️ [2/5] Extracting PPAC (Diesel, Bitumen, Petcoke)...")
    result = {
        "source": "PPAC",
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None
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
            p_resp = session.get(pdf_link, headers=COMMON_HEADERS, timeout=35, verify=False)
            if p_resp.status_code == 200 and pdfplumber:
                with pdfplumber.open(io.BytesIO(p_resp.content)) as pdf:
                    for page in pdf.pages[:8]:
                        tables = page.extract_tables()
                        for table in tables:
                            for row in table:
                                if not row:
                                    continue
                                line = " ".join([str(c) for c in row if c]).lower()
                                
                                # Year filter: Strictly exclude 2024, 2025, 2026, 2027
                                raw_nums = [clean_num(c) for c in row if clean_num(c) is not None]
                                valid_nums = [n for n in raw_nums if n not in [2024.0, 2025.0, 2026.0, 2027.0]]

                                if ("hsd" in line or "high speed diesel" in line) and not result["hsd_diesel_tmt"]:
                                    hsd_c = [n for n in valid_nums if 4000.0 <= n <= 11000.0]
                                    if hsd_c:
                                        result["hsd_diesel_tmt"] = hsd_c[0]

                                if "bitumen" in line and not result["bitumen_tmt"]:
                                    bit_c = [n for n in valid_nums if 150.0 <= n <= 1500.0]
                                    if bit_c:
                                        result["bitumen_tmt"] = bit_c[0]

                                if ("petcoke" in line or "petroleum coke" in line) and not result["petcoke_tmt"]:
                                    pet_c = [n for n in valid_nums if 200.0 <= n <= 2500.0]
                                    if pet_c:
                                        result["petcoke_tmt"] = pet_c[0]

        print(f"   ✅ PPAC: HSD: {result['hsd_diesel_tmt']} TMT | Bitumen: {result['bitumen_tmt']} TMT | Petcoke: {result['petcoke_tmt']} TMT")
    except Exception as e:
        print(f"   ❌ PPAC Error: {e}")

    return result

# ============================================================
# 3. RAILWAYS — FREIGHT TRAFFIC & REVENUE
# ============================================================

def scrape_railways_freight(session):
    print("🚂 [3/5] Extracting Ministry of Railways (Freight Traffic)...")
    result = {
        "source": "Indian Railways",
        "originating_freight_mt": None,
        "freight_revenue_cr": None,
        "cement_clinker_mt": None,
        "iron_ore_mt": None
    }

    text, link = fetch_latest_pib_release_text(session, ["railways"], ["freight", "revenue freight", "loading"])
    
    if text:
        # Total freight volume
        m_tot = re.search(r'(?:freight loading of|originating freight of|loading of)\s*([\d\.,]+)\s*MT', text, re.IGNORECASE)
        if not m_tot:
            m_tot = re.search(r'([\d\.,]+)\s*MT\s*(?:freight|originating)', text, re.IGNORECASE)
        if m_tot:
            result["originating_freight_mt"] = clean_num(m_tot.group(1))

        # Revenue
        m_rev = re.search(r'(?:revenue of|revenue reached|freight revenue)\s*(?:Rs\.?)?\s*([\d\.,]+)\s*crore', text, re.IGNORECASE)
        if m_rev:
            result["freight_revenue_cr"] = clean_num(m_rev.group(1))

        # Cement
        m_cem = re.search(r'([\d\.,]+)\s*MT\s*of\s*Cement', text, re.IGNORECASE)
        if not m_cem:
            m_cem = re.search(r'Cement\s*(?:&|\+)?\s*Clinker[^\d\n]+([\d\.,]+)\s*MT', text, re.IGNORECASE)
        if m_cem:
            result["cement_clinker_mt"] = clean_num(m_cem.group(1))

        # Iron Ore
        m_iron = re.search(r'([\d\.,]+)\s*MT\s*of\s*Iron\s*Ore', text, re.IGNORECASE)
        if not m_iron:
            m_iron = re.search(r'Iron\s*Ore[^\d\n]+([\d\.,]+)\s*MT', text, re.IGNORECASE)
        if m_iron:
            result["iron_ore_mt"] = clean_num(m_iron.group(1))

    print(f"   ✅ Railways: Total: {result['originating_freight_mt']} MT | Revenue: ₹{result['freight_revenue_cr']} Cr | Cement: {result['cement_clinker_mt']} MT | Iron Ore: {result['iron_ore_mt']} MT")
    return result

# ============================================================
# 4. IPA — MAJOR PORTS TRAFFIC
# ============================================================

def scrape_ipa_ports(session):
    print("⚓ [4/5] Extracting Indian Ports Association (Cargo Traffic)...")
    result = {
        "source": "IPA",
        "cargo_traffic_mt": None,
        "container_teus": None
    }

    text, link = fetch_latest_pib_release_text(session, ["ports", "shipping"], ["cargo", "traffic", "major ports"])

    if text:
        m_cargo = re.search(r'([\d\.,]+)\s*(?:Million\s*Tonnes|MT).*?(?:cargo|traffic)', text, re.IGNORECASE)
        if m_cargo:
            result["cargo_traffic_mt"] = clean_num(m_cargo.group(1))

        m_teu = re.search(r'([\d\.,]+)\s*(?:million|lakh)?\s*TEUs', text, re.IGNORECASE)
        if m_teu:
            result["container_teus"] = clean_num(m_teu.group(1))

    print(f"   ✅ Ports: Cargo: {result['cargo_traffic_mt']} MT | Containers: {result['container_teus']} TEUs")
    return result

# ============================================================
# 5. FASTAG — HIGHWAY TOLL METRICS (WORKING)
# ============================================================

def scrape_npci_fastag(session):
    print("🛣️ [5/5] Extracting NPCI / NETC FASTag Statistics...")
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
                for row in soup.find_all("tr"):
                    cells = [c.get_text().strip() for c in row.find_all(["td", "th"])]
                    nums = [clean_num(c) for c in cells if clean_num(c) is not None]

                    v_vol = next((n for n in nums if 15.0 <= n <= 55.0), None)
                    v_val = next((n for n in nums if 3000.0 <= n <= 10000.0), None)

                    if v_vol and not result["toll_volume_crores"]:
                        result["toll_volume_crores"] = v_vol
                    if v_val and not result["toll_value_inr_crores"]:
                        result["toll_value_inr_crores"] = v_val

                    if result["toll_volume_crores"] and result["toll_value_inr_crores"]:
                        break

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
