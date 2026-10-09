import os
import io
import json
import re
import asyncio
import pandas as pd
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
from playwright.async_api import async_playwright

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

OUTPUT_DIR = "downloaded_macro_pdfs"
TELEMETRY_MASTER_FILE = "macro_telemetry_master.json"
MANIFEST_FILE = "macro_reports_manifest.json"
FASTAG_CSV_FILE = "netc_fastag_monthly_3years.csv"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

os.makedirs(OUTPUT_DIR, exist_ok=True)

# ============================================================
# HELPER FUNCTIONS
# ============================================================

def clean_num(val):
    if val is None:
        return None
    val = str(val).replace(",", "").replace("%", "").strip()
    match = re.search(r"[-+]?\d*\.?\d+", val)
    return float(match.group(0)) if match else None

async def download_binary_file(page, url, filename):
    filepath = os.path.join(OUTPUT_DIR, filename)
    try:
        response = await page.request.get(
            url,
            timeout=45000,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                "Accept": "*/*"
            }
        )
        if response.status == 200:
            content = await response.body()
            with open(filepath, "wb") as f:
                f.write(content)
            size_kb = len(content) // 1024
            print(f"   💾 Downloaded: {filepath} ({size_kb} KB)")
            return filepath
        else:
            print(f"   ⚠️ Download failed for {url} with HTTP status {response.status}")
    except Exception as e:
        print(f"   ❌ Download error: {e}")
    return None

# ============================================================
# 1. PARSER: DPIIT EIGHT CORE PDF
# ============================================================

def parse_eight_core_pdf(pdf_path):
    metrics = {
        "overall_growth_pct": None,
        "cement_production_mt": None,
        "cement_growth_pct": None,
        "steel_production_mt": None,
        "steel_growth_pct": None,
        "coal_production_mt": None
    }
    if not pdfplumber or not os.path.exists(pdf_path):
        return metrics

    try:
        with pdfplumber.open(pdf_path) as pdf:
            page_text = "\n".join([page.extract_text() or "" for page in pdf.pages[:3]])

            m_core = re.search(r'(?:Eight Core Industries|combined Index)[^\d\n%]+(?:increased|growth of|by)\s+([-\+]?\d+\.\d+)\s*%', page_text, re.I)
            if m_core:
                metrics["overall_growth_pct"] = clean_num(m_core.group(1))

            m_cem_p = re.search(r'Cement\s+production[^\d\n%]+(?:increased|declined|growth|by)\s+([-\+]?\d+\.\d+)\s*(?:%|per\s+cent)', page_text, re.I)
            if m_cem_p:
                metrics["cement_growth_pct"] = clean_num(m_cem_p.group(1))

            m_stl_p = re.search(r'Steel\s+production[^\d\n%]+(?:increased|declined|growth|by)\s+([-\+]?\d+\.\d+)\s*(?:%|per\s+cent)', page_text, re.I)
            if m_stl_p:
                metrics["steel_growth_pct"] = clean_num(m_stl_p.group(1))

            for page in pdf.pages:
                txt = page.extract_text() or ""
                if "Statement II" in txt or "Production" in txt:
                    for line in txt.split("\n"):
                        l_clean = line.strip().lower()
                        tokens = re.findall(r'[\d,]+\.?\d*', line)
                        nums = [clean_num(t) for t in tokens if clean_num(t) is not None]
                        nums = [n for n in nums if n not in [2023.0, 2024.0, 2025.0, 2026.0, 2027.0]]

                        if l_clean.startswith("cement") and not metrics["cement_production_mt"]:
                            cands = [n for n in nums if 20.0 <= n <= 55.0 and n != 5.37]
                            if cands:
                                metrics["cement_production_mt"] = cands[0]

                        if l_clean.startswith("steel") and not metrics["steel_production_mt"]:
                            cands = [n for n in nums if 7.0 <= n <= 25.0 and n != 17.92]
                            if cands:
                                metrics["steel_production_mt"] = cands[0]

                        if l_clean.startswith("coal") and not metrics["coal_production_mt"]:
                            cands = [n for n in nums if 40.0 <= n <= 130.0 and n != 10.33]
                            if cands:
                                metrics["coal_production_mt"] = cands[0]
    except Exception as e:
        print(f"   ⚠️ Eight Core parsing error: {e}")

    return metrics

# ============================================================
# 2. PARSER: DPIIT WPI PDF
# ============================================================

def parse_wpi_pdf(pdf_path):
    metrics = {
        "headline_inflation_pct": None,
        "all_commodities_index": None,
        "primary_articles_inflation_pct": None,
        "fuel_power_inflation_pct": None,
        "manufactured_products_inflation_pct": None
    }
    if not pdfplumber or not os.path.exists(pdf_path):
        return metrics

    try:
        with pdfplumber.open(pdf_path) as pdf:
            text = "\n".join([page.extract_text() or "" for page in pdf.pages[:3]])

            m_rate = re.search(r'annual\s+rate\s+of\s+inflation[^\d\n%]+(?:is|stands\s+at)?\s*\(?([-\+]?\d+\.\d+)\)?\s*%', text, re.I)
            if not m_rate:
                m_rate = re.search(r'WPI[^\n%]+inflation[^\d\n%]+(?:stands\s+at|is)?\s*\(?([-\+]?\d+\.\d+)\)?\s*%', text, re.I)
            if m_rate:
                metrics["headline_inflation_pct"] = clean_num(m_rate.group(1))

            m_idx = re.search(r'index[^\n\d]+All\s+Commodities[^\d\n]+(\d{3}\.\d+)', text, re.I)
            if not m_idx:
                m_idx = re.search(r'All\s+Commodities[^\n\d]+(?:index[^\d\n]+)?(\d{3}\.\d+)', text, re.I)
            if m_idx:
                metrics["all_commodities_index"] = clean_num(m_idx.group(1))

            m_primary = re.search(r'Primary\s+Articles[^\d\n%]+(?:to|is|stands\s+at)?\s*\(?([-\+]?\d+\.\d+)\)?\s*%', text, re.I)
            if m_primary:
                metrics["primary_articles_inflation_pct"] = clean_num(m_primary.group(1))

            m_fuel = re.search(r'Fuel\s*&\s*Power[^\d\n%]+(?:to|is|stands\s+at)?\s*\(?([-\+]?\d+\.\d+)\)?\s*%', text, re.I)
            if m_fuel:
                metrics["fuel_power_inflation_pct"] = clean_num(m_fuel.group(1))

            m_manuf = re.search(r'Manufactured\s+Products[^\d\n%]+(?:to|is|stands\s+at)?\s*\(?([-\+]?\d+\.\d+)\)?\s*%', text, re.I)
            if m_manuf:
                metrics["manufactured_products_inflation_pct"] = clean_num(m_manuf.group(1))
    except Exception as e:
        print(f"   ⚠️ WPI parsing error: {e}")

    return metrics

# ============================================================
# 3. PARSER: IPA PORTS EXCEL
# ============================================================

def parse_ipa_excel(file_path):
    metrics = {
        "total_traffic_mt": None,
        "container_teus": None,
        "coking_coal_mt": None
    }
    if not file_path or not os.path.exists(file_path):
        return metrics

    try:
        xl = pd.ExcelFile(file_path)
        for sheet in xl.sheet_names:
            df = xl.parse(sheet, header=None).fillna("").astype(str)

            for _, row in df.iterrows():
                row_str = " ".join(row.values).lower()

                if "total" in row_str and ("traffic" in row_str or "cargo" in row_str or "all ports" in row_str):
                    nums = [clean_num(x) for x in row.values if clean_num(x) is not None]
                    for n in nums:
                        if 55.0 <= n <= 95.0 and not metrics["total_traffic_mt"]:
                            metrics["total_traffic_mt"] = n
                        elif 55000.0 <= n <= 95000.0 and not metrics["total_traffic_mt"]:
                            metrics["total_traffic_mt"] = round(n / 1000.0, 2)

                if "container" in row_str and "teu" in row_str:
                    nums = [clean_num(x) for x in row.values if clean_num(x) is not None]
                    for n in nums:
                        if 500000 <= n <= 2500000 and not metrics["container_teus"]:
                            metrics["container_teus"] = n
                        elif 500 <= n <= 2500 and not metrics["container_teus"]:
                            metrics["container_teus"] = int(n * 1000)

                if "coking coal" in row_str and not metrics["coking_coal_mt"]:
                    nums = [clean_num(x) for x in row.values if clean_num(x) is not None]
                    for n in nums:
                        if 3.0 <= n <= 10.0:
                            metrics["coking_coal_mt"] = n
                        elif 3000 <= n <= 10000:
                            metrics["coking_coal_mt"] = round(n / 1000.0, 2)

            if metrics["total_traffic_mt"] and metrics["container_teus"]:
                break
    except Exception as e:
        print(f"   ⚠️ IPA Excel parsing error: {e}")

    return metrics

# ============================================================
# CRAWLERS
# ============================================================

async def scrape_ipa(page):
    print("\n⚓ [1/4] Crawling & Extracting IPA Ports Traffic...")
    target_url = "https://ipa.org.in/reports-statistics"
    res = {"title": None, "file_url": None, "local_path": None, "extracted_metrics": {}}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        detail_link = None
        for a in await page.query_selector_all("a"):
            aria = (await a.get_attribute("aria-label") or "").lower()
            href = (await a.get_attribute("href") or "")
            text = (await a.inner_text()).lower()

            if "traffic" in aria or "traffic" in text or "traffic-month" in href:
                detail_link = urljoin(target_url, href)
                res["title"] = (await a.inner_text()).strip() or "IPA Traffic Report"
                break

        if detail_link:
            await page.goto(detail_link, wait_until="domcontentloaded", timeout=45000)
            await page.wait_for_timeout(2000)

            for a in await page.query_selector_all("a"):
                href = await a.get_attribute("href") or ""
                text = (await a.inner_text()).strip()
                if ".xlsx" in href.lower() or ".xls" in href.lower() or "/upload/media/" in href.lower():
                    res["file_url"] = urljoin(detail_link, href)
                    res["title"] = text or "Major Ports Traffic Excel"
                    break

            if res["file_url"]:
                ext = ".xlsx" if ".xlsx" in res["file_url"].lower() else ".xls"
                path = await download_binary_file(page, res["file_url"], f"IPA_Traffic_Latest{ext}")
                res["local_path"] = path
                res["extracted_metrics"] = parse_ipa_excel(path)
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")

    return res

async def scrape_eight_core(page):
    print("\n🏭 [2/4] Crawling & Extracting DPIIT Eight Core Industries...")
    target_url = "https://eaindustry.nic.in/"
    res = {"title": None, "pdf_url": None, "local_path": None, "extracted_metrics": {}}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        pdf_url = None
        for a in await page.query_selector_all("a"):
            href = await a.get_attribute("href") or ""
            if "press_release_ici_" in href.lower() and href.lower().endswith(".pdf"):
                pdf_url = href
                res["title"] = (await a.inner_text()).strip() or "Eight Core Monthly Press Release"
                break

        if not pdf_url:
            box_cell = page.locator("td.my-box1-text:has-text('INDEX OF CORE')").first
            if await box_cell.count() > 0:
                parent_a = box_cell.locator("xpath=ancestor::a[1]").first
                if await parent_a.count() > 0:
                    pdf_url = await parent_a.get_attribute("href")
                    res["title"] = "Index of Eight Core Industries Press Release"

        if pdf_url:
            res["pdf_url"] = urljoin(target_url, pdf_url)
            path = await download_binary_file(page, res["pdf_url"], "DPIIT_Eight_Core_Latest.pdf")
            res["local_path"] = path
            res["extracted_metrics"] = parse_eight_core_pdf(path)
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return res

async def scrape_wpi(page):
    print("\n📈 [3/4] Crawling & Extracting DPIIT WPI...")
    target_url = "https://eaindustry.nic.in/"
    res = {"title": None, "pdf_url": None, "local_path": None, "extracted_metrics": {}}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        for a in await page.query_selector_all("a"):
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).strip()
            if "press_release_" in href.lower() and not "ici" in href.lower() and href.lower().endswith(".pdf"):
                res["title"] = text or "WPI Press Release"
                res["pdf_url"] = urljoin(target_url, href)
                break

        if res["pdf_url"]:
            path = await download_binary_file(page, res["pdf_url"], "DPIIT_WPI_Latest.pdf")
            res["local_path"] = path
            res["extracted_metrics"] = parse_wpi_pdf(path)
    except Exception as e:
        print(f"   ❌ WPI Error: {e}")

    return res

async def scrape_netc_fastag(page):
    print("\n🛣️ [4/4] Crawling NETC FASTag Statistics (3-Year History)...")
    target_url = "https://www.npci.org.in/product/netc/product-statistics"
    years_to_scrape = ["2026", "2025", "2024"]
    all_data = []

    res = {
        "title": "NETC FASTag Monthly Product Statistics",
        "csv_path": None,
        "total_records": 0,
        "latest_monthly_metrics": {}
    }

    try:
        await page.goto(target_url, wait_until="networkidle", timeout=60000)

        try:
            monthly_tab = page.locator("text='Monthly Statistics'").first
            if await monthly_tab.is_visible():
                await monthly_tab.click()
                await page.wait_for_timeout(2000)
        except Exception:
            pass

        for year in years_to_scrape:
            year_selected = False
            selects = await page.query_selector_all("select")
            for sel in selects:
                options = await sel.inner_text()
                if year in options:
                    await sel.select_option(label=year)
                    year_selected = True
                    break

            if not year_selected:
                try:
                    btn = page.locator(f"button:has-text('{year}'), div:has-text('{year}')").first
                    if await btn.is_visible():
                        await btn.click()
                        year_selected = True
                except Exception:
                    pass

            await page.wait_for_timeout(3000)
            rows = await page.query_selector_all("table tr")
            for row in rows:
                cells = await row.query_selector_all("td")
                if len(cells) >= 3:
                    cell_texts = [(await c.inner_text()).strip() for c in cells]
                    month_name = cell_texts[0]
                    if month_name.lower() in ["month", "particulars", "total", "sl no", "sr no"]:
                        continue

                    nums = [clean_num(t) for t in cell_texts[1:] if clean_num(t) is not None]
                    if len(nums) >= 2:
                        vol_mn = nums[-2]
                        val_cr = nums[-1]
                        record = {
                            "year": year,
                            "month": month_name,
                            "volume_million": vol_mn,
                            "volume_crore": round(vol_mn / 10.0, 2) if vol_mn else None,
                            "amount_inr_crore": val_cr,
                            "ticket_size_inr": round((val_cr * 10000000) / (vol_mn * 1000000), 2) if (val_cr and vol_mn) else None
                        }
                        all_data.append(record)

        if all_data:
            df = pd.DataFrame(all_data)
            df.to_csv(FASTAG_CSV_FILE, index=False)
            res["csv_path"] = FASTAG_CSV_FILE
            res["total_records"] = len(all_data)
            res["latest_monthly_metrics"] = all_data[0]
    except Exception as e:
        print(f"   ❌ FASTag Error: {e}")

    return res

# ============================================================
# MASTER ORCHESTRATOR & FAIL-SAFE JSON WRITER
# ============================================================

async def main():
    print("=" * 80)
    print("🚀 UNIFIED MACRO DATA CRAWLER & TELEMETRY JSON WRITER")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

    ipa_res, core_res, wpi_res, fastag_res = {}, {}, {}, {}

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            ignore_https_errors=True
        )
        page = await context.new_page()

        try:
            ipa_res = await scrape_ipa(page)
        except Exception as e:
            print(f"❌ Critical IPA failure: {e}")

        try:
            core_res = await scrape_eight_core(page)
        except Exception as e:
            print(f"❌ Critical Eight Core failure: {e}")

        try:
            wpi_res = await scrape_wpi(page)
        except Exception as e:
            print(f"❌ Critical WPI failure: {e}")

        try:
            fastag_res = await scrape_netc_fastag(page)
        except Exception as e:
            print(f"❌ Critical FASTag failure: {e}")

        await browser.close()

    # 1. Guaranteed Write: Manifest JSON
    manifest = {
        "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "reports": {
            "ipa_ports_traffic": ipa_res,
            "dpiit_eight_core": core_res,
            "dpiit_wpi": wpi_res,
            "netc_fastag": fastag_res
        }
    }
    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    # 2. Guaranteed Write: Master Telemetry JSON
    latest_snapshot = {
        "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "eight_core_industries": core_res.get("extracted_metrics", {}),
        "wholesale_price_index": wpi_res.get("extracted_metrics", {}),
        "ports_maritime_traffic": ipa_res.get("extracted_metrics", {}),
        "road_freight_fastag": fastag_res.get("latest_monthly_metrics", {})
    }

    history = []
    if os.path.exists(TELEMETRY_MASTER_FILE):
        try:
            with open(TELEMETRY_MASTER_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                history = loaded if isinstance(loaded, list) else [loaded]
        except Exception:
            history = []

    history.insert(0, latest_snapshot)
    history = history[:60]

    with open(TELEMETRY_MASTER_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 SUCCESS: '{TELEMETRY_MASTER_FILE}' written successfully ({len(history)} entries)")
    print(f"📁 SUCCESS: '{MANIFEST_FILE}' written successfully")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
