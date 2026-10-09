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
                "Accept": "application/pdf,*/*"
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
# 1. IPA PORTS (.xlsx Report)
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
            print(f"   🔗 Detail Page: {detail_link}")
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
# 2. DPIIT EIGHT CORE (Homepage Table Wrapper -> Press_Release_ICI_*.pdf)
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
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "DPIIT_Eight_Core_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ DPIIT Eight Core: Dynamic link not found on homepage.")
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return result

# ============================================================
# 3. DPIIT WPI (Wholesale Price Index Press Release)
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
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "DPIIT_WPI_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ DPIIT WPI: Dynamic link not found.")
    except Exception as e:
        print(f"   ❌ WPI Error: {e}")

    return result

# ============================================================
# 4. PIB IIP (Ministry of Statistics IIP Press Release)
# ============================================================

async def scrape_pib_iip(page):
    print("\n🏭 [4/4] Scraping IIP via PIB (Press Information Bureau)...")
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    detail_url = None
    title = None

    try:
        # Step A: Ministry of Statistics & Programme Implementation Feed on PIB
        feed_url = "https://www.pib.gov.in/AllRelease.aspx"
        await page.goto(feed_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2500)

        # Select Ministry of Statistics and Programme Implementation if dropdown available
        min_select = page.locator("select[id*='Ministry'], select[name*='Ministry']").first
        if await min_select.count() > 0:
            options = await min_select.locator("option").all()
            for opt in options:
                txt = (await opt.inner_text()).lower()
                if "statistics" in txt:
                    val = await opt.get_attribute("value")
                    await min_select.select_option(value=val)
                    await page.wait_for_timeout(2000)
                    break

        # Search for "Index of Industrial Production" link in the releases list
        for a in await page.query_selector_all("a"):
            text = (await a.inner_text()).strip()
            href = await a.get_attribute("href") or ""
            t_lower = text.lower()

            if ("index of industrial production" in t_lower or "quick estimates" in t_lower) and "pressreleasedetail" in href.lower():
                detail_url = urljoin(feed_url, href)
                title = text
                break

        # Step B: Fallback to direct PRID link if feed search misses
        if not detail_url:
            detail_url = "https://www.pib.gov.in/PressReleaseDetail.aspx?PRID=2315957&reg=48&lang=1"

        print(f"   🔗 Navigating to PIB Release: {detail_url}")
        await page.goto(detail_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2500)

        result["title"] = title or (await page.locator("h2, .release-heading").first.inner_text()).strip()

        # Check if PIB offers a direct PDF attachment download on this page
        pdf_anchor = page.locator("a[href*='.pdf'], a:has-text('Download')").first
        pdf_url = None
        if await pdf_anchor.count() > 0:
            pdf_url = urljoin(detail_url, await pdf_anchor.get_attribute("href"))

        if pdf_url and ".pdf" in pdf_url.lower():
            result["pdf_url"] = pdf_url
            print(f"   🌐 Direct PDF Link : {pdf_url}")
            path = await download_binary_file(page, pdf_url, "MoSPI_IIP_PIB_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            # PIB page itself contains full tabular press release; print to high-fidelity PDF
            filepath = os.path.join(OUTPUT_DIR, "MoSPI_IIP_PIB_Latest.pdf")
            await page.pdf(path=filepath, format="A4", print_background=True)
            result["local_path"] = filepath
            result["pdf_url"] = detail_url
            result["preview_text"] = (await page.inner_text("body"))[:1200]
            print(f"   💾 Downloaded Official Press Release PDF: {filepath}")

    except Exception as e:
        print(f"   ❌ PIB IIP Error: {e}")

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
                "mospi_iip_pib": await scrape_pib_iip(page)
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
