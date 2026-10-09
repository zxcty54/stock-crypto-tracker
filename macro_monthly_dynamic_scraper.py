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
    if not pdfplumber or not os.path.exists(filepath):
        return ""
    try:
        with pdfplumber.open(filepath) as pdf:
            pages = [p.extract_text() or "" for p in pdf.pages[:2]]
            return " ".join(" ".join(pages).split())[:1200]
    except Exception:
        return ""

async def download_file(page, url, filename):
    filepath = os.path.join(OUTPUT_DIR, filename)
    try:
        response = await page.request.get(url, timeout=45000)
        if response.status == 200:
            with open(filepath, "wb") as f:
                f.write(await response.body())
            print(f"   💾 Downloaded: {filepath} ({os.path.getsize(filepath) // 1024} KB)")
            return filepath
        else:
            print(f"   ⚠️ Download failed for {url} with status {response.status}")
    except Exception as e:
        print(f"   ❌ Download exception: {e}")
    return None

# ============================================================
# 1. IPA PORTS (Targeting detail page -> direct PDF)
# ============================================================

async def scrape_ipa(page):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    target_url = "https://ipa.org.in/reports-statistics"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        # Load reports listing
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(3000)

        # Snippet Match: <a aria-label="View details of Traffic Month...">
        detail_link = None
        anchors = await page.query_selector_all("a")
        for a in anchors:
            aria = (await a.get_attribute("aria-label") or "").lower()
            href = (await a.get_attribute("href") or "")
            text = (await a.inner_text()).lower()

            if "traffic" in aria or "traffic" in text or "traffic-month" in href:
                detail_link = urljoin(target_url, href)
                result["title"] = (await a.inner_text()).strip() or "IPA Traffic Report"
                break

        if detail_link:
            print(f"   🔗 Found Detail Page: {detail_link}")
            # Navigate to detail page to fetch actual PDF
            await page.goto(detail_link, wait_until="domcontentloaded", timeout=45000)
            await page.wait_for_timeout(2000)

            # Search PDF inside detail page
            pdf_anchors = await page.query_selector_all("a")
            for pa in pdf_anchors:
                phref = await pa.get_attribute("href") or ""
                if ".pdf" in phref.lower() or "download" in phref.lower():
                    result["pdf_url"] = urljoin(detail_link, phref)
                    break

            if not result["pdf_url"]:
                # If page itself redirects or has iframe
                iframe = await page.query_selector("iframe")
                if iframe:
                    src = await iframe.get_attribute("src") or ""
                    if ".pdf" in src.lower():
                        result["pdf_url"] = urljoin(detail_link, src)

            if result["pdf_url"]:
                print(f"   🌐 PDF Direct Link : {result['pdf_url']}")
                path = await download_file(page, result["pdf_url"], "IPA_Traffic_Latest.pdf")
                result["local_path"] = path
                result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ IPA: Detail page link not matched in DOM.")
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")

    return result

# ============================================================
# 2. DPIIT EIGHT CORE (Targeting td.my-box1-text)
# ============================================================

async def scrape_eight_core(page):
    print("\n🏭 [2/4] Scraping DPIIT Eight Core Industries PDF...")
    target_url = "https://eaindustry.nic.in/eight_core_infra/"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        # Snippet Match: <td class="my-box1-text">INDEX OF CORE...</td>
        # Find cell and navigate to its row anchor
        target_cell = page.locator("td.my-box1-text:has-text('INDEX OF CORE')").first
        pdf_url = None

        if await target_cell.count() > 0:
            # Check anchor inside or in sibling columns of this row
            row = target_cell.locator("xpath=..")
            anchor = row.locator("a[href$='.pdf']").first
            if await anchor.count() > 0:
                pdf_url = await anchor.get_attribute("href")
            else:
                # Any anchor in that row
                any_a = row.locator("a").first
                if await any_a.count() > 0:
                    pdf_url = await any_a.get_attribute("href")

        # Fallback to scanning all anchors for core index
        if not pdf_url:
            all_a = await page.query_selector_all("a")
            for a in all_a:
                t = (await a.inner_text()).lower()
                h = (await a.get_attribute("href") or "").lower()
                if ("core" in t or "press" in t) and h.endswith(".pdf") and not h.startswith("press_release_"):
                    pdf_url = h
                    break

        if pdf_url:
            result["title"] = "Index of Eight Core Industries Press Release"
            result["pdf_url"] = urljoin(target_url, pdf_url)
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_file(page, result["pdf_url"], "DPIIT_Eight_Core_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ DPIIT Eight Core: Row anchor not matched.")
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return result

# ============================================================
# 3. DPIIT WPI (Already working)
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
            path = await download_file(page, result["pdf_url"], "DPIIT_WPI_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
    except Exception as e:
        print(f"   ❌ WPI Error: {e}")

    return result

# ============================================================
# 4. MoSPI IIP (Targeting <h3>Press Release on Quick Estimates...)
# ============================================================

async def scrape_mospi_iip(page):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        # Changed from networkidle to domcontentloaded to avoid timeout
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(3000)

        # Snippet Match: <h3>Press Release on Quick Estimates...</h3>
        heading = page.locator("h3:has-text('Quick Estimates of all India Index of Industrial Production')").first
        pdf_url = None

        if await heading.count() > 0:
            result["title"] = (await heading.inner_text()).strip()
            # 1. Check if heading itself is inside an anchor or parent has a link
            parent_link = heading.locator("xpath=ancestor::a").first
            if await parent_link.count() > 0:
                pdf_url = await parent_link.get_attribute("href")

            # 2. Check nearest sibling or container for download link
            if not pdf_url:
                container = heading.locator("xpath=ancestor::div[1]")
                anchor = container.locator("a[href*='.pdf'], a[href*='latestreleasesfiles']").first
                if await anchor.count() > 0:
                    pdf_url = await anchor.get_attribute("href")

        # Fallback: scan all links for uploads/latestreleasesfiles
        if not pdf_url:
            anchors = await page.query_selector_all("a")
            for a in anchors:
                href = (await a.get_attribute("href") or "").lower()
                text = (await a.inner_text()).lower()
                if ("iip" in href or "iip" in text) and (".pdf" in href or "latestreleasesfiles" in href):
                    pdf_url = await a.get_attribute("href")
                    result["title"] = (await a.inner_text()).strip() or "MoSPI IIP Press Release"
                    break

        if pdf_url:
            result["pdf_url"] = urljoin(target_url, pdf_url)
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_file(page, result["pdf_url"], "MoSPI_IIP_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ MoSPI: IIP Heading container link not found.")
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
        print(f"   • {key.upper():<20} : {status} | Link: {val['pdf_url']}")
    print(f"📁 Manifest Metadata saved to: '{METADATA_FILE}'")
    print(f"📂 PDFs Directory             : '{OUTPUT_DIR}/'")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
