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
# 1. IPA PORTS (Targeting First Available Month .xlsx Report)
# ============================================================

async def scrape_ipa(page):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    target_url = "https://ipa.org.in/reports-statistics"
    result = {"title": None, "file_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        # First card on the page is always the latest published month
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

            # Match any dynamic timestamp Excel upload: /upload/media/*.xlsx
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

        # 1. Target direct dynamic link pattern (Press_Release_ICI_<timestamp>.pdf)
        for a in await page.query_selector_all("a"):
            href = await a.get_attribute("href") or ""
            if "press_release_ici_" in href.lower() and href.lower().endswith(".pdf"):
                pdf_url = href
                result["title"] = (await a.inner_text()).strip() or "Eight Core Monthly Press Release"
                break

        # 2. Target anchor wrapping the 'INDEX OF CORE INDUSTRIES' table box
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

        # Dynamic pattern: press_release_<YYYYMM>.pdf (excluding ICI)
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
# 4. MoSPI IIP (Fully Dynamic: Tab Click + Rendered Pattern + Network Intercept)
# ============================================================

async def scrape_mospi_iip(page):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    detected_urls = []

    # Dynamic background response listener for any monthly IIP PDF link
    async def capture_network(response):
        try:
            url = response.url
            if ".pdf" in url.lower() and ("latestreleasesfiles" in url.lower() or "iip" in url.lower()):
                if url not in detected_urls:
                    detected_urls.append(url)
            
            ct = response.headers.get("content-type", "")
            if "json" in ct or "javascript" in ct:
                text_content = await response.text()
                matches = re.findall(
                    r'(https?://[^\s"\'\\]+latestreleasesfiles[^\s"\'\\]*IIP[^\s"\'\\]*\.pdf)', 
                    text_content, 
                    re.IGNORECASE
                )
                if not matches:
                    rel_matches = re.findall(
                        r'(/uploads/latestreleasesfiles/[^\s"\'\\]*IIP[^\s"\'\\]*\.pdf)', 
                        text_content, 
                        re.IGNORECASE
                    )
                    matches = [urljoin("https://www.mospi.gov.in", m) for m in rel_matches]
                for m in matches:
                    if m not in detected_urls:
                        detected_urls.append(m)
        except Exception:
            pass

    page.on("response", capture_network)

    try:
        await page.goto(target_url, wait_until="load", timeout=60000)
        await page.wait_for_timeout(3000)

        # Trigger "Latest Release" tab button so React mounts the release card
        tab_buttons = page.locator("button, a").filter(has_text=re.compile(r"latest release", re.I))
        if await tab_buttons.count() > 0:
            try:
                await tab_buttons.first.click()
                await page.wait_for_timeout(2500)
            except Exception:
                pass

        pdf_url = None

        # 1. Search rendered anchors in DOM
        for a in await page.query_selector_all("a"):
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).lower()
            h_lower = href.lower()

            if h_lower.endswith(".pdf") and ("latestreleasesfiles" in h_lower or "iip" in h_lower or "quick" in text):
                pdf_url = urljoin(target_url, href)
                result["title"] = (await a.inner_text()).strip() or "MoSPI IIP Press Release"
                break

        # 2. Search raw page content for dynamic uploads pattern
        if not pdf_url:
            page_html = await page.content()
            dom_matches = re.findall(
                r'(https?://[^\s"\'<>]+latestreleasesfiles[^\s"\'<>]*IIP[^\s"\'<>]*\.pdf)',
                page_html,
                re.IGNORECASE
            )
            if not dom_matches:
                rel_dom_matches = re.findall(
                    r'(/uploads/latestreleasesfiles/[^\s"\'<>]*IIP[^\s"\'<>]*\.pdf)',
                    page_html,
                    re.IGNORECASE
                )
                dom_matches = [urljoin("https://www.mospi.gov.in", m) for m in rel_dom_matches]
            if dom_matches:
                pdf_url = dom_matches[0]

        # 3. Use captured URL from background network payload
        if not pdf_url and detected_urls:
            pdf_url = detected_urls[0]
            result["title"] = "MoSPI IIP Press Release"

        # 4. Trigger download near the Quick Estimates heading if not resolved as plain link
        if not pdf_url:
            heading = page.locator("xpath=//h3[contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'quick estimates')]").first
            if await heading.count() > 0:
                result["title"] = (await heading.inner_text()).strip()
                card = heading.locator("xpath=./ancestor::div[position() <= 3]")
                clickable = card.locator("a, button, [role='button']").first
                if await clickable.count() > 0:
                    try:
                        async with page.expect_download(timeout=8000) as dl_info:
                            await clickable.click()
                        dl = await dl_info.value
                        filepath = os.path.join(OUTPUT_DIR, "MoSPI_IIP_Latest.pdf")
                        await dl.save_as(filepath)
                        result["local_path"] = filepath
                        result["pdf_url"] = dl.url
                        result["preview_text"] = extract_pdf_preview(filepath)
                        print(f"   💾 Downloaded via click: {filepath}")
                    except Exception:
                        pass

        if pdf_url and not result["local_path"]:
            result["pdf_url"] = pdf_url
            result["title"] = result["title"] or "MoSPI IIP Press Release"
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_binary_file(page, result["pdf_url"], "MoSPI_IIP_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        elif not result["local_path"]:
            print("   ❌ MoSPI: Dynamic PDF link could not be captured.")

    except Exception as e:
        print(f"   ❌ MoSPI Error: {e}")
    finally:
        page.remove_listener("response", handle_response)

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
