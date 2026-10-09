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

OUTPUT_DIR = "downloaded_macro_pdfs"
METADATA_FILE = "macro_reports_manifest.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

os.makedirs(OUTPUT_DIR, exist_ok=True)

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
# 4. MoSPI IIP (100% PURE DYNAMIC - NO HARDCODED URLS)
# ============================================================

async def scrape_mospi_iip(page):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    result = {"title": "Index of Industrial Production Press Release", "pdf_url": None, "local_path": None, "preview_text": ""}

    pdf_url = None

    # Step 1: Direct MoSPI Product Backend API
    try:
        api_url = "https://www.mospi.gov.in/api/theme-details/54"
        resp = await page.request.get(api_url, timeout=15000)
        if resp.status == 200:
            text_body = await resp.text()
            matches = re.findall(r'(https?://[^\s"\'\\]+latestreleasesfiles[^\s"\'\\]*IIP[^\s"\'\\]*\.pdf)', text_body, re.I)
            if not matches:
                rel = re.findall(r'(/uploads/latestreleasesfiles/[^\s"\'\\]*IIP[^\s"\'\\]*\.pdf)', text_body, re.I)
                matches = [urljoin("https://www.mospi.gov.in", m) for m in rel]
            if matches:
                pdf_url = matches[0]
                print(f"   ⚡ Resolved Dynamically via MoSPI Backend API: {pdf_url}")
    except Exception:
        pass

    # Step 2: Live DOM Crawl (agar API me delay ho)
    if not pdf_url:
        try:
            await page.goto(target_url, wait_until="networkidle", timeout=45000)
            links = await page.eval_on_selector_all(
                "a[href*='.pdf']",
                "elements => elements.map(e => e.href).filter(h => /iip/i.test(h) || /latestreleasesfiles/i.test(h))"
            )
            if links:
                pdf_url = links[0]
                print(f"   ⚡ Resolved Dynamically via Live DOM: {pdf_url}")
        except Exception:
            pass

    # Strictly dynamic download: koi purana hardcoded link nahi
    if pdf_url:
        result["pdf_url"] = pdf_url
        print(f"   🔗 Found: {result['title']}")
        print(f"   🌐 Dynamic Link: {result['pdf_url']}")
        path = await download_binary_file(page, result["pdf_url"], "MoSPI_IIP_Latest.pdf")
        result["local_path"] = path
        result["preview_text"] = extract_pdf_preview(path)
    else:
        print("   ❌ MoSPI: Latest dynamic PDF link not found.")

    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

async def main():
    print("=" * 80)
    print("🚀 PURE DYNAMIC MACRO DOCUMENT CRAWLER (ZERO HARDCODING)")
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
                "mospi_iip": await scrape_mospi_iip(page)
            }
        }

        await browser.close()

    with open(METADATA_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("✅ EXECUTION SUMMARY:")
    for key, val in manifest["reports"].items():
        status = "✅ Downloaded" if val["local_path"] else "❌ Not Released / Failed"
        link_str = val.get("pdf_url") or val.get("file_url")
        print(f"   • {key.upper():<20} : {status} | Link: {link_str}")
    print(f"📁 Manifest Metadata saved to: '{METADATA_FILE}'")
    print(f"📂 Downloaded Directory        : '{OUTPUT_DIR}/'")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
