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
# 1. DPIIT — EIGHT CORE INDUSTRIES
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
        "release_url": None
    }

    # PIB Search Endpoint for Eight Core Industries
    query_url = "https://pib.gov.in/AllRelease.aspx"
    target_link = None

    try:
        # Fetch the press release directory
        resp = session.get(query_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            for a in soup.find_all("a", href=True):
                txt = a.get_text().strip().lower()
                if "eight core" in txt or "index of eight" in txt:
                    target_link = urljoin("https://pib.gov.in/", a['href'])
                    break

        # Fallback to direct latest announcement page
        if not target_link:
            target_link = "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"

        result["release_url"] = target_link

        # Scrape and parse content
        pr_resp = session.get(target_link, headers=COMMON_HEADERS, timeout=25, verify=False)
        content_text = ""
        
        if target_link.endswith(".pdf") and pdfplumber:
            with pdfplumber.open(io.BytesIO(pr_resp.content)) as pdf:
                content_text = "\n".join([p.extract_text() or "" for p in pdf.pages[:5]])
        else:
            content_text = pr_resp.text

        # 1. Overall Growth
        m_core = re.search(r'(?:Eight Core Industries|combined Index)[^\d\n%]+(?:increased|growth of|by)\s+([\d\.\-]+)\s*%', content_text, re.IGNORECASE)
        if m_core:
            result["overall_core_growth_pct"] = clean_num(m_core.group(1))

        # 2. Cement Metrics
        m_cem_growth = re.search(r'Cement\s+production[^\d\n%]+(?:increased|declined|growth|by)\s+([\d\.\-]+)\s*%', content_text, re.IGNORECASE)
        if m_cem_growth:
            result["cement_growth_pct"] = clean_num(m_cem_growth.group(1))
        
        m_cem_vol = re.search(r'Cement[^\d\n]+([\d,\.]+)\s*(?:million|MT)', content_text, re.IGNORECASE)
        if m_cem_vol:
            result["cement_production_mt"] = clean_num(m_cem_vol.group(1))

        # 3. Steel Metrics
        m_stl_growth = re.search(r'Steel\s+production[^\d\n%]+(?:increased|declined|growth|by)\s+([\d\.\-]+)\s*%', content_text, re.IGNORECASE)
        if m_stl_growth:
            result["steel_growth_pct"] = clean_num(m_stl_growth.group(1))

        m_stl_vol = re.search(r'Steel[^\d\n]+([\d,\.]+)\s*(?:million|MT)', content_text, re.IGNORECASE)
        if m_stl_vol:
            result["steel_production_mt"] = clean_num(m_stl_vol.group(1))

        print(f"   ✅ DPIIT: Core: {result['overall_core_growth_pct']}% | Cement: {result['cement_growth_pct']}% (Vol: {result['cement_production_mt']}) | Steel: {result['steel_growth_pct']}% (Vol: {result['steel_production_mt']})")
    except Exception as e:
        print(f"   ❌ DPIIT Error: {e}")

    return result

# ============================================================
# 2. PPAC — DIESEL, BITUMEN & PETCOKE
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
                    for page in pdf.pages[:8]:
                        text = page.extract_text(layout=True) or ""
                        lines = text.split("\n")
                        for line in lines:
                            l_lower = line.lower()
                            # Tokenize floats/ints with commas
                            tokens = re.findall(r'[\d,]+\.?\d*', line)
                            nums = [clean_num(t) for t in tokens if clean_num(t) is not None]

                            if ("hsd" in l_lower or "high speed diesel" in l_lower) and not result["hsd_diesel_tmt"]:
                                # Typical Indian monthly HSD consumption is 5,000 to 10,000 TMT
                                c = [n for n in nums if 4000 <= n <= 12000]
                                if c:
                                    result["hsd_diesel_tmt"] = c[0]

                            if "bitumen" in l_lower and not result["bitumen_tmt"]:
                                # Typical monthly Bitumen consumption is 250 to 1,500 TMT
                                c = [n for n in nums if 150 <= n <= 2000]
                                if c:
                                    result["bitumen_tmt"] = c[0]

                            if ("petcoke" in l_lower or "petroleum coke" in l_lower) and not result["petcoke_tmt"]:
                                # Typical monthly Petcoke is 300 to 2,500 TMT
                                c = [n for n in nums if 200 <= n <= 3000]
                                if c:
                                    result["petcoke_tmt"] = c[0]

        print(f"   ✅ PPAC Extracted: HSD: {result['hsd_diesel_tmt']} TMT | Bitumen: {result['bitumen_tmt']} TMT | Petcoke: {result['petcoke_tmt']} TMT")
    except Exception as e:
        print(f"   ❌ PPAC Error: {e}")

    return result

# ============================================================
# 3. RAILWAYS — FREIGHT TRAFFIC & COMMODITIES
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

    pib_url = "https://pib.gov.in/AllRelease.aspx"
    target_link = None
    try:
        resp = session.get(pib_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            for a in soup.find_all("a", href=True):
                txt = a.get_text().strip().lower()
                if "railway" in txt and ("freight" in txt or "revenue" in txt or "loading" in txt):
                    target_link = urljoin("https://pib.gov.in/", a['href'])
                    break

        if target_link:
            result["url"] = target_link
            rel_resp = session.get(target_link, headers=COMMON_HEADERS, timeout=25, verify=False)
            txt = rel_resp.text

            # 1. Originating Freight Total
            m_tot = re.search(r'(?:freight loading of|originating freight of|originating freight reached)\s*([\d\.,]+)\s*MT', txt, re.IGNORECASE)
            if not m_tot:
                m_tot = re.search(r'([\d\.,]+)\s*MT\s*(?:freight|originating)', txt, re.IGNORECASE)
            if m_tot:
                result["originating_freight_mt"] = clean_num(m_tot.group(1))

            # 2. Freight Revenue
            m_rev = re.search(r'(?:freight revenue of|revenue of|reached)\s*(?:Rs\.?)?\s*([\d\.,]+)\s*crore', txt, re.IGNORECASE)
            if m_rev:
                result["freight_revenue_cr"] = clean_num(m_rev.group(1))

            # 3. Cement & Clinker
            m_cem = re.search(r'([\d\.,]+)\s*MT\s*of\s*Cement', txt, re.IGNORECASE)
            if not m_cem:
                m_cem = re.search(r'Cement\s*(?:&|\+)?
