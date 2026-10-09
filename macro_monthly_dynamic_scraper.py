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
METADATA_FILE = "macro_reports_manifest.json"
FASTAG_CSV_FILE = "netc_fastag_monthly_3years.csv"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

os.makedirs(OUTPUT_DIR, exist_ok=True)

def clean_num(val):
    if not val:
        return None
    val = str(val).replace(",", "").replace("%", "").strip()
    match = re.search(r"[-+]?\d*\.?\d+", val)
    return float(match.group(0)) if match else None

def extract_pdf_preview(filepath):
    if not pdfplumber or not os.path.exists(filepath) or not filepath.endswith(".pdf"):
        return ""
    try:
        with pdfplumber.open(filepath) as pdf:
            pages = [p.extract_text() or "" for p in pdf.pages[:2]]
            return " ".join(" ".join(pages).split())[:1200]
    except Exception:
        return ""

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
# 1. IPA PORTS (Pure Dynamic .xlsx Crawl)
# ============================================================

async def scrape_ipa(page):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    target_url = "https://ipa.org.in/reports-statistics"
    result = {"title": None, "file_url": None, "local_path": None, "preview_text": ""}

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
                result["title"] = (await a.inner_text()).strip() or "IPA Traffic Report"
                break

        if detail_link:
            print(f"   🔗 Latest Detail Page: {detail_link}")
            await page.goto(detail_link, wait_until="domcontentloaded", timeout=45000)
            await page.wait_for_timeout(2000)

            for a in await page.query_selector_all("a"):
                href = await a.get_attribute("href") or ""
                text = (await a.inner_text()).strip()
                if ".xlsx" in href.lower() or ".xls" in href.lower() or "/upload/media/" in href.lower():
                    result["file_url"] = urljoin(detail_link, href)
                    result["title"] = text or "Major Ports Traffic Excel"
                    break

            if result["file_url"]:
                print(f"   🌐 Dynamic File Link: {result['file_url']}")
                ext = ".xlsx" if ".xlsx" in result["file_url"].lower() else ".xls"
                path = await download_binary_file(page, result["file_url"], f"IPA_Traffic_Latest{ext}")
                result["local_path"] = path
                result["preview_text"] = "Excel report downloaded successfully."
            else:
                print("   ❌ IPA: Dynamic file link not found on detail page.")
        else:
            print("   ❌ IPA: Latest detail page link not found.")
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")

    return result

# ============================================================
# 2. DPIIT EIGHT CORE (Pure Dynamic PDF Crawl)
# ============================================================

async def scrape_eight_core(page):
    print("\n🏭 [2/4] Scraping DPIIT Eight Core Industries PDF...")
    target_url = "https://eaindustry.nic.in/"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        pdf_url = None
        for a in await page.query_selector_all("a"):
            href = await a.get_attribute("href") or ""
            if "press_release_ici_" in href.lower() and href.lower().endswith(".pdf"):
                pdf_url = href
                result["title"] = (await a.inner_text()).strip() or "Eight Core Monthly Press Release"
                break

        if not pdf_url:
            box_cell = page.locator("td.my-box1-text:has-text('INDEX OF CORE')").first
            if await box_cell.count() > 0:
                parent_a = box_cell.locator("xpath=ancestor::a[1]").first
                if await parent_a.count() > 0:
                    pdf_url = await parent_a.get_attribute("href")
                    result["title"] = "Index of Eight Core Industries Press Release"

        if pdf_url:
            result["pdf_url"] = urljoin(target_url, pdf_url)
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Dynamic Link: {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "DPIIT_Eight_Core_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ DPIIT Eight Core: Dynamic link not found on homepage.")
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return result

# ============================================================
# 3. DPIIT WPI (Pure Dynamic PDF Crawl)
# ============================================================

async def scrape_wpi(page):
    print("\n📈 [3/4] Scraping DPIIT WPI (Wholesale Price Index) PDF...")
    target_url = "https://eaindustry.nic.in/"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        for a in await page.query_selector_all("a"):
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).strip()

            if "press_release_" in href.lower() and not "ici" in href.lower() and href.lower().endswith(".pdf"):
                result["title"] = text or "WPI Press Release"
                result["pdf_url"] = urljoin(target_url, href)
                break

        if result["pdf_url"]:
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Dynamic Link: {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "DPIIT_WPI_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ DPIIT WPI: Dynamic link not found.")
    except Exception as e:
        print(f"   ❌ WPI Error: {e}")

    return result

# ============================================================
# 4. NETC FASTAG (3-YEAR HISTORICAL & LIVE EXTRACTION)
# ============================================================

async def scrape_netc_fastag(page):
    print("\n🛣️ [4/4] Scraping NETC FASTag Monthly Statistics (3-Year History)...")
    target_url = "https://www.npci.org.in/product/netc/product-statistics"
    years_to_scrape = ["2026", "2025", "2024"]
    all_data = []

    result = {
        "title": "NETC FASTag Monthly Product Statistics",
        "csv_path": None,
        "total_records_extracted": 0,
        "latest_metrics": {}
    }

    try:
        print(f"   🌐 Opening: {target_url}")
        await page.goto(target_url, wait_until="networkidle", timeout=60000)

        try:
            monthly_tab = page.locator("text='Monthly Statistics'").first
            if await monthly_tab.is_visible():
                await monthly_tab.click()
                await page.wait_for_timeout(2000)
        except Exception:
            pass

        for year in years_to_scrape:
            print(f"   📅 Fetching FASTag Year: {year}...")
            year_selected = False

            # Select option if dropdown exists
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
            count = 0
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
                        count += 1

            print(f"   ✅ {count} records extracted for {year}")

        if all_data:
            df = pd.DataFrame(all_data)
            df.to_csv(FASTAG_CSV_FILE, index=False)
            result["csv_path"] = FASTAG_CSV_FILE
            result["total_records_extracted"] = len(all_data)
            result["latest_metrics"] = all_data[0] if len(all_data) > 0 else {}
            print(f"   🎉 Saved successfully to '{FASTAG_CSV_FILE}'!")
        else:
            print("   ❌ FASTag table parse nahi ho paya.")

    except Exception as e:
        print(f"   ❌ FASTag Error: {e}")

    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

async def main():
    print("=" * 80)
    print("🚀 UNIFIED DYNAMIC MACRO & FASTAG DATA CRAWLER")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            ignore_https_errors=True
        )
        page = await context.new_page()

        manifest = {
            "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            "reports": {
                "ipa_ports_traffic": await scrape_ipa(page),
                "dpiit_eight_core": await scrape_eight_core(page),
                "dpiit_wpi": await scrape_wpi(page),
                "netc_fastag": await scrape_netc_fastag(page)
            }
        }

        await browser.close()

    with open(METADATA_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("✅ EXECUTION SUMMARY:")
    for key, val in manifest["reports"].items():
        if key == "netc_fastag":
            status = f"✅ Extracted ({val['total_records_extracted']} rows)" if val.get("csv_path") else "❌ Failed"
            link_str = val.get("csv_path")
        else:
            status = "✅ Downloaded" if val.get("local_path") else "❌ Not Released / Failed"
            link_str = val.get("pdf_url") or val.get("file_url")
        print(f"   • {key.upper():<20} : {status} | Destination: {link_str}")
    print(f"📁 Manifest Metadata saved to: '{METADATA_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
