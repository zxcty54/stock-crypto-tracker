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
        response = await page.request.get(url, timeout=45000)
        if response.status == 200:
            with open(filepath, "wb") as f:
                f.write(await response.body())
            size_kb = os.path.getsize(filepath) // 1024
            print(f"   💾 Downloaded: {filepath} ({size_kb} KB)")
            return filepath
        else:
            print(f"   ⚠️ Download failed for {url} with HTTP status {response.status}")
    except Exception as e:
        print(f"   ❌ Download error: {e}")
    return None

# ============================================================
# 1. IPA PORTS (Targeting .xlsx Excel Report)
# ============================================================

async def scrape_ipa(page):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    target_url = "https://ipa.org.in/reports-statistics"
    result = {"title": None, "file_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        # Step 1: Find detail page link
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
            print(f"   🔗 Detail Page: {detail_link}")
            await page.goto(detail_link, wait_until="domcontentloaded", timeout=45000)
            await page.wait_for_timeout(2000)

            # Step 2: Grab the .xlsx file
            for a in await page.query_selector_all("a"):
                href = await a.get_attribute("href") or ""
                text = (await a.inner_text()).strip()
                if ".xlsx" in href.lower() or ".xls" in href.lower() or "/upload/media/" in href.lower():
                    result["file_url"] = urljoin(detail_link, href)
                    result["title"] = text or "Major Ports Traffic Excel"
                    break

            if result["file_url"]:
                print(f"   🌐 File Link : {result['file_url']}")
                ext = ".xlsx" if ".xlsx" in result["file_url"].lower() else ".xls"
                path = await download_binary_file(page, result["file_url"], f"IPA_Traffic_Latest{ext}")
                result["local_path"] = path
                result["preview_text"] = "Excel report downloaded successfully."
            else:
                print("   ❌ IPA: Excel file link not found on detail page.")
        else:
            print("   ❌ IPA: Detail page link not found.")
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")

    return result

# ============================================================
# 2. DPIIT EIGHT CORE (Homepage Table Row Traversal)
# ============================================================

async def scrape_eight_core(page):
    print("\n🏭 [2/4] Scraping DPIIT Eight Core Industries PDF...")
    target_url = "https://eaindustry.nic.in/"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        # Load home page directly (blank eight_core_infra avoided)
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        pdf_url = None

        # Snippet Locator: <td class="my-box1-text">INDEX OF CORE...
        box_cell = page.locator("td.my-box1-text:has-text('INDEX OF CORE')").first

        if await box_cell.count() > 0:
            # Table row jisme ye cell hai
            row = box_cell.locator("xpath=ancestor::tr[1]")
            
            # Check anchors inside this row (adjacent td cells)
            for a in await row.locator("a").all():
                href = await a.get_attribute("href") or ""
                if href and not "press_release_" in href.lower():
                    pdf_url = href
                    result["title"] = (await a.inner_text()).strip() or "Eight Core Press Release"
                    break

            # If not in same row, check next rows within the same box table
            if not pdf_url:
                table = box_cell.locator("xpath=ancestor::table[1]")
                for a in await table.locator("a").all():
                    href = await a.get_attribute("href") or ""
                    if href and not "press_release_" in href.lower():
                        # Exclude home or non-document links
                        if any(ext in href.lower() for ext in [".pdf", ".doc", "press", "core"]):
                            pdf_url = href
                            result["title"] = (await a.inner_text()).strip() or "Eight Core Press Release"
                            break

        # Fallback search across home page anchors
        if not pdf_url:
            for a in await page.query_selector_all("a"):
                href = await a.get_attribute("href") or ""
                text = (await a.inner_text()).lower()
                h_lower = href.lower()
                if ("core" in text or "core" in h_lower) and not "press_release_" in h_lower:
                    if h_lower.endswith(".pdf"):
                        pdf_url = href
                        result["title"] = (await a.inner_text()).strip()
                        break

        if pdf_url:
            result["pdf_url"] = urljoin(target_url, pdf_url)
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "DPIIT_Eight_Core_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ DPIIT Eight Core: Download link not found beside header cell.")
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return result

# ============================================================
# 3. DPIIT WPI (Wholesale Price Index)
# ============================================================

async def scrape_wpi(page):
    print("\n📈 [3/4] Scraping DPIIT WPI (Wholesale Price Index) PDF...")
    target_url = "https://eaindustry.nic.in/"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        anchors = await page.query_selector_all("a")
        for a in anchors:
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).strip()

            if "press_release_" in href.lower() and href.lower().endswith(".pdf"):
                result["title"] = text or "WPI Press Release"
                result["pdf_url"] = urljoin(target_url, href)
                break

        if result["pdf_url"]:
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "DPIIT_WPI_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
    except Exception as e:
        print(f"   ❌ WPI Error: {e}")

    return result

# ============================================================
# 4. MoSPI IIP (Exact Heading Traversal)
# ============================================================

async def scrape_mospi_iip(page):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(3000)

        pdf_url = None
        
        # Snippet match on h3
        h3 = page.locator("h3:has-text('Quick Estimates of all India Index of Industrial Production')").first
        
        if await h3.count() > 0:
            result["title"] = (await h3.inner_text()).strip()
            
            # Container ke andar a[href] dhoondhna
            card = h3.locator("xpath=./ancestor::div[1]")
            for a in await card.locator("a").all():
                h = await a.get_attribute("href") or ""
                if any(x in h.lower() for x in [".pdf", "download", "latestreleasesfiles"]):
                    pdf_url = h
                    break
                    
            # Agar div[1] me na ho toh higher level div check karein
            if not pdf_url:
                higher_card = h3.locator("xpath=./ancestor::div[2]")
                for a in await higher_card.locator("a").all():
                    h = await a.get_attribute("href") or ""
                    if any(x in h.lower() for x in [".pdf", "download", "latestreleasesfiles"]):
                        pdf_url = h
                        break

        # Fallback: Page-wide search for IIP files
        if not pdf_url:
            for a in await page.query_selector_all("a"):
                h = await a.get_attribute("href") or ""
                t = (await a.inner_text()).lower()
                if ("iip" in h.lower() or "quick" in t or "iip" in t) and (".pdf" in h.lower() or "latestreleasesfiles" in h.lower()):
                    pdf_url = h
                    result["title"] = (await a.inner_text()).strip() or "MoSPI IIP Press Release"
                    break

        if pdf_url:
            result["pdf_url"] = urljoin(target_url, pdf_url)
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "MoSPI_IIP_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ MoSPI: Download link could not be matched.")
    except Exception as e:
        print(f"   ❌ MoSPI Error: {e}")

    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

async def main():
    print("=" * 80)
    print("🚀 TARGETED MACRO DOCUMENT CRAWLER (DOM-ALIGNED)")
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
        status = "✅ Downloaded" if val["local_path"] else "❌ Failed"
        link_str = val.get("pdf_url") or val.get("file_url")
        print(f"   • {key.upper():<20} : {status} | Link: {link_str}")
    print(f"📁 Manifest Metadata saved to: '{METADATA_FILE}'")
    print(f"📂 Downloaded Directory        : '{OUTPUT_DIR}/'")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
