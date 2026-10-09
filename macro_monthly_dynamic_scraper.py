import os
import io
import json
import re
import asyncio
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
from playwright.async_api import async_playwright

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

OUTPUT_FILE = "macro_telemetry_master.json"
MANIFEST_FILE = "macro_reports_manifest.json"
PDF_DIR = "downloaded_macro_pdfs"

os.makedirs(PDF_DIR, exist_ok=True)

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

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

async def scrape_dpiit(page):
    print("🏭 [1/5] Extracting DPIIT Eight Core Industries via Playwright...")
    res = {
        "source": "DPIIT",
        "cement_growth_pct": None,
        "steel_growth_pct": None,
        "overall_core_growth_pct": None,
        "cement_production_mt": None,
        "steel_production_mt": None,
        "url": None
    }
    try:
        await page.goto("https://pib.gov.in/AllRelease.aspx", timeout=45000, wait_until="domcontentloaded")
        await page.wait_for_timeout(3000)

        # Evaluate all links matching Eight Core in DOM
        links = await page.eval_on_selector_all(
            "a", 
            "elements => elements.map(e => ({ text: e.innerText, href: e.href })).filter(e => /eight core|core industries/i.test(e.text))"
        )
        
        target_url = links[0]["href"] if links else "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"
        res["url"] = target_url

        if target_url.endswith(".pdf"):
            resp = await page.request.get(target_url)
            content = await resp.body()
            text = ""
            if pdfplumber:
                with pdfplumber.open(io.BytesIO(content)) as pdf:
                    text = "\n".join([p.extract_text() or "" for p in pdf.pages[:5]])
        else:
            await page.goto(target_url, timeout=30000, wait_until="domcontentloaded")
            text = await page.inner_text("body")

        # Parsing
        m_core = re.search(r'(?:Eight Core Industries|combined Index)[^\d\n%]+(?:increased|growth of|by)\s+([\d\.\-]+)\s*%', text, re.IGNORECASE)
        if m_core:
            res["overall_core_growth_pct"] = clean_num(m_core.group(1))

        m_cem = re.search(r'Cement\s+production[^\d\n%]+(?:increased|declined|growth|by)?\s*([\d\.\-]+)\s*%', text, re.IGNORECASE)
        if m_cem:
            res["cement_growth_pct"] = clean_num(m_cem.group(1))

        m_cem_v = re.search(r'Cement[^\d\n]+([\d,\.]+)\s*(?:million|MT)', text, re.IGNORECASE)
        if m_cem_v:
            res["cement_production_mt"] = clean_num(m_cem_v.group(1))

        m_stl = re.search(r'Steel\s+production[^\d\n%]+(?:increased|declined|growth|by)?\s*([\d\.\-]+)\s*%', text, re.IGNORECASE)
        if m_stl:
            res["steel_growth_pct"] = clean_num(m_stl.group(1))

        m_stl_v = re.search(r'Steel[^\d\n]+([\d,\.]+)\s*(?:million|MT)', text, re.IGNORECASE)
        if m_stl_v:
            res["steel_production_mt"] = clean_num(m_stl_v.group(1))

    except Exception as e:
        print(f"   ⚠️ DPIIT Playwright Error: {e}")

    print(f"   ✅ DPIIT: Core: {res['overall_core_growth_pct']}% | Cement: {res['cement_growth_pct']}% | Steel: {res['steel_growth_pct']}%")
    return res

# ============================================================
# 2. PPAC — DIESEL, BITUMEN & PETCOKE (DIRECT URL EXTRACTION)
# ============================================================

async def scrape_ppac(page):
    print("🛢️ [2/5] Extracting PPAC (Diesel, Bitumen, Petcoke) via Playwright...")
    res = {
        "source": "PPAC",
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None,
        "downloaded_pdf": None
    }
    try:
        await page.goto("https://ppac.gov.in/consumption", timeout=45000, wait_until="domcontentloaded")
        await page.wait_for_timeout(3000)

        # Directly grab the href without relying on Playwright UI clicks
        pdf_urls = await page.eval_on_selector_all(
            "a[href*='.pdf']",
            "elements => elements.map(e => e.href)"
        )

        target_pdf_url = pdf_urls[0] if pdf_urls else None

        if target_pdf_url:
            pdf_path = os.path.join(PDF_DIR, "ppac_latest.pdf")
            response = await page.request.get(target_pdf_url)
            pdf_bytes = await response.body()

            with open(pdf_path, "wb") as f:
                f.write(pdf_bytes)
            res["downloaded_pdf"] = pdf_path

            if pdfplumber:
                with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
                    for p in pdf.pages[:8]:
                        txt = p.extract_text() or ""
                        for line in txt.split("\n"):
                            l_lower = line.lower()
                            raw_nums = [clean_num(n) for n in re.findall(r'[\d,]+\.?\d*', line) if clean_num(n)]
                            valid_nums = [n for n in raw_nums if n not in [2023.0, 2024.0, 2025.0, 2026.0, 2027.0]]

                            if ("hsd" in l_lower or "diesel" in l_lower) and not res["hsd_diesel_tmt"]:
                                candidates = [n for n in valid_nums if 4000.0 <= n <= 12000.0]
                                if candidates:
                                    res["hsd_diesel_tmt"] = candidates[0]

                            if "bitumen" in l_lower and not res["bitumen_tmt"]:
                                candidates = [n for n in valid_nums if 150.0 <= n <= 2000.0]
                                if candidates:
                                    res["bitumen_tmt"] = candidates[0]

                            if ("petcoke" in l_lower or "petroleum coke" in l_lower) and not res["petcoke_tmt"]:
                                candidates = [n for n in valid_nums if 200.0 <= n <= 3000.0]
                                if candidates:
                                    res["petcoke_tmt"] = candidates[0]

    except Exception as e:
        print(f"   ⚠️ PPAC Playwright Error: {e}")

    print(f"   ✅ PPAC: HSD: {res['hsd_diesel_tmt']} TMT | Bitumen: {res['bitumen_tmt']} TMT | Petcoke: {res['petcoke_tmt']} TMT")
    return res

# ============================================================
# 3. RAILWAYS — FREIGHT TRAFFIC & REVENUE
# ============================================================

async def scrape_railways(page):
    print("🚂 [3/5] Extracting Ministry of Railways via Playwright...")
    res = {
        "source": "Indian Railways",
        "originating_freight_mt": None,
        "freight_revenue_cr": None,
        "cement_clinker_mt": None,
        "iron_ore_mt": None,
        "url": None
    }
    try:
        await page.goto("https://pib.gov.in/AllRelease.aspx", timeout=45000, wait_until="domcontentloaded")
        await page.wait_for_timeout(3000)

        links = await page.eval_on_selector_all(
            "a", 
            "elements => elements.map(e => ({ text: e.innerText, href: e.href })).filter(e => /railway/i.test(e.text) && /freight|loading|revenue/i.test(e.text))"
        )

        if links:
            target_url = links[0]["href"]
            res["url"] = target_url
            await page.goto(target_url, timeout=30000, wait_until="domcontentloaded")
            txt = await page.inner_text("body")

            m_tot = re.search(r'(?:freight loading of|originating freight of|loading of)\s*([\d\.,]+)\s*MT', txt, re.IGNORECASE)
            if not m_tot:
                m_tot = re.search(r'([\d\.,]+)\s*MT\s*(?:freight|originating)', txt, re.IGNORECASE)
            if m_tot:
                res["originating_freight_mt"] = clean_num(m_tot.group(1))

            m_rev = re.search(r'(?:revenue of|revenue reached|freight revenue)\s*(?:Rs\.?)?\s*([\d\.,]+)\s*crore', txt, re.IGNORECASE)
            if m_rev:
                res["freight_revenue_cr"] = clean_num(m_rev.group(1))

            m_cem = re.search(r'([\d\.,]+)\s*MT\s*of\s*Cement', txt, re.IGNORECASE)
            if not m_cem:
                m_cem = re.search(r'Cement\s*(?:&|\+)?\s*Clinker[^\d\n]+([\d\.,]+)\s*MT', txt, re.IGNORECASE)
            if m_cem:
                res["cement_clinker_mt"] = clean_num(m_cem.group(1))

            m_iron = re.search(r'([\d\.,]+)\s*MT\s*of\s*Iron\s*Ore', txt, re.IGNORECASE)
            if not m_iron:
                m_iron = re.search(r'Iron\s*Ore[^\d\n]+([\d\.,]+)\s*MT', txt, re.IGNORECASE)
            if m_iron:
                res["iron_ore_mt"] = clean_num(m_iron.group(1))

    except Exception as e:
        print(f"   ⚠️ Railways Playwright Error: {e}")

    print(f"   ✅ Railways: Total: {res['originating_freight_mt']} MT | Revenue: ₹{res['freight_revenue_cr']} Cr | Cement: {res['cement_clinker_mt']} MT | Iron Ore: {res['iron_ore_mt']} MT")
    return res

# ============================================================
# 4. IPA — MARITIME EXIM & PORTS TRAFFIC
# ============================================================

async def scrape_ipa(page):
    print("⚓ [4/5] Extracting Indian Ports Association via Playwright...")
    res = {
        "source": "IPA",
        "cargo_traffic_mt": None,
        "container_teus": None,
        "url": None
    }
    try:
        await page.goto("https://pib.gov.in/AllRelease.aspx", timeout=45000, wait_until="domcontentloaded")
        await page.wait_for_timeout(3000)

        links = await page.eval_on_selector_all(
            "a", 
            "elements => elements.map(e => ({ text: e.innerText, href: e.href })).filter(e => /major ports|ports/i.test(e.text) && /traffic|cargo|handled/i.test(e.text))"
        )

        if links:
            target_url = links[0]["href"]
            res["url"] = target_url
            await page.goto(target_url, timeout=30000, wait_until="domcontentloaded")
            txt = await page.inner_text("body")

            m_cargo = re.search(r'([\d\.,]+)\s*(?:Million\s*Tonnes|MT).*?(?:cargo|traffic)', txt, re.IGNORECASE)
            if m_cargo:
                res["cargo_traffic_mt"] = clean_num(m_cargo.group(1))

            m_teu = re.search(r'([\d\.,]+)\s*(?:million|lakh)?\s*TEUs', txt, re.IGNORECASE)
            if m_teu:
                res["container_teus"] = clean_num(m_teu.group(1))

    except Exception as e:
        print(f"   ⚠️ IPA Playwright Error: {e}")

    print(f"   ✅ Ports: Cargo: {res['cargo_traffic_mt']} MT | Containers: {res['container_teus']} TEUs")
    return res

# ============================================================
# 5. FASTAG — HIGHWAY TOLL METRICS (CONTAINER & TEXT SCAN)
# ============================================================

async def scrape_fastag(page):
    print("🛣️ [5/5] Extracting NPCI / NETC FASTag via Playwright...")
    res = {
        "source": "NETC FASTag",
        "toll_volume_crores": None,
        "toll_value_inr_crores": None,
        "freight_intensity_ratio": None
    }
    try:
        # Load NPCI page without waiting for networkidle (which causes timeouts)
        await page.goto("https://www.npci.org.in/what-we-do/netc-fastag/product-statistics", timeout=45000, wait_until="domcontentloaded")
        await page.wait_for_timeout(4000)

        # Direct text scrape of the whole body
        body_text = await page.inner_text("body")

        # Scan for numbers near Crores / Vol / Val
        all_nums = [clean_num(n) for n in re.findall(r'[\d,]+\.?\d*', body_text) if clean_num(n)]
        
        # Volume: typically 15-55 Cr, Value: 3000-10000 Cr
        v_vol = next((n for n in all_nums if 15.0 <= n <= 55.0), None)
        v_val = next((n for n in all_nums if 3000.0 <= n <= 10000.0), None)

        if v_vol:
            res["toll_volume_crores"] = v_vol
        if v_val:
            res["toll_value_inr_crores"] = v_val

    except Exception as e:
        print(f"   ⚠️ FASTag Playwright Error: {e}")

    if res["toll_value_inr_crores"] and res["toll_volume_crores"]:
        res["freight_intensity_ratio"] = round(
            res["toll_value_inr_crores"] / res["toll_volume_crores"], 2
        )

    print(f"   ✅ FASTag: Volume: {res['toll_volume_crores']} Cr | Value: ₹{res['toll_value_inr_crores']} Cr | Freight Ratio: {res['freight_intensity_ratio']}")
    return res

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

async def main():
    print("=" * 80)
    print("🚀 PLAYWRIGHT ASYNC MACRO-ECONOMIC TELEMETRY ENGINE")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
                "--disable-setuid-sandbox"
            ]
        )
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080}
        )
        page = await context.new_page()

        telemetry_payload = {
            "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            "metrics": {
                "dpiit_eight_core": await scrape_dpiit(page),
                "ppac_petroleum": await scrape_ppac(page),
                "railways_freight": await scrape_railways(page),
                "ipa_ports": await scrape_ipa(page),
                "fastag_road_logistics": await scrape_fastag(page)
            }
        }

        await browser.close()

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

    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        json.dump({"last_run": NOW.strftime("%Y-%m-%d %H:%M:%S IST"), "status": "SUCCESS"}, f, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Macro Telemetry Data successfully written to '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
