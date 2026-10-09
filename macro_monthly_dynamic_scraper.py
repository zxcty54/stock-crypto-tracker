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
# 1. IPA PORTS (Detail Page -> Deep Extraction)
# ============================================================

async def scrape_ipa(page):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    target_url = "https://ipa.org.in/reports-statistics"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

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
            await page.goto(detail_link, wait_until="domcontentloaded", timeout=45000)
            await page.wait_for_timeout(3000)

            # 1. Look for direct links / embeds / iframes
            pdf_candidates = []
            
            # Check all links
            for a in await page.query_selector_all("a"):
                h = await a.get_attribute("href") or ""
                if any(ext in h.lower() for ext in [".pdf", "download", "file", "attachment", "view"]):
                    pdf_candidates.append(urljoin(detail_link, h))

            # Check iframes / embeds
            for frame in await page.query_selector_all("iframe, embed, object"):
                src = await frame.get_attribute("src") or await frame.get_attribute("data") or ""
                if ".pdf" in src.lower() or "drive" in src.lower() or "file" in src.lower():
                    pdf_candidates.append(urljoin(detail_link, src))

            # Pick highest confidence PDF link
            for cand in pdf_candidates:
                if ".pdf" in cand.lower():
                    result["pdf_url"] = cand
                    break
            if not result["pdf_url"] and pdf_candidates:
                result["pdf_url"] = pdf_candidates[0]

            if result["pdf_url"]:
                print(f"   🌐 PDF Direct Link : {result['pdf_url']}")
                path = await download_file(page, result["pdf_url"], "IPA_Traffic_Latest.pdf")
                result["local_path"] = path
                result["preview_text"] = extract_pdf_preview(path)
            else:
                print("   ❌ IPA: No PDF/Embed element found inside detail page.")
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")

    return result

# ============================================================
# 2. DPIIT EIGHT CORE (Targeting table structure)
# ============================================================

async def scrape_eight_core(page):
    print("\n🏭 [2/4] Scraping DPIIT Eight Core Industries PDF...")
    target_url = "https://eaindustry.nic.in/eight_core_infra/"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        # 1. Try finding any anchor within the same table or row containing INDEX OF CORE
        pdf_url = None
        table_anchors = await page.query_selector_all("table a, td a")
        for a in table_anchors:
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).lower()
            h_lower = href.lower()
            
            # Must be a PDF and NOT the WPI press release
            if h_lower.endswith(".pdf") and not "press_release_" in h_lower:
                pdf_url = href
                break

        # 2. Broader DOM search excluding WPI
        if not pdf_url:
            for a in await page.query_selector_all("a"):
                href = await a.get_attribute("href") or ""
                h_lower = href.lower()
                if h_lower.endswith(".pdf") and not "press_release_" in h_lower:
                    if any(k in h_lower for k in ["core", "infra", "eight", "index"]):
                        pdf_url = href
                        break

        # 3. Direct Static Link Fallback
        if not pdf_url:
            pdf_url = "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"

        result["title"] = "Index of Eight Core Industries Press Release"
        result["pdf_url"] = urljoin(target_url, pdf_url)
        print(f"   🔗 Found: {result['title']}")
        print(f"   🌐 Link : {result['pdf_url']}")
        
        path = await download_file(page, result["pdf_url"], "DPIIT_Eight_Core_Latest.pdf")
        result["local_path"] = path
        result["preview_text"] = extract_pdf_preview(path)
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return result

# ============================================================
# 3. DPIIT WPI (Already Working)
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
# 4. MoSPI IIP (Deep Container Traversal)
# ============================================================

async def scrape_mospi_iip(page):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(3000)

        pdf_url = None
        heading = page.locator("h3:has-text('Quick Estimates of all India Index of Industrial Production')").first

        if await heading.count() > 0:
            result["title"] = (await heading.inner_text()).strip()
            
            # Check broader parent containers (up to 5 levels up)
            for level in range(1, 6):
                container = heading.locator(f"xpath=ancestor::*[{level}]")
                anchors = await container.locator("a").all()
                for a in anchors:
                    h = await a.get_attribute("href") or ""
                    if ".pdf" in h.lower() or "latestreleasesfiles" in h.lower():
                        pdf_url = h
                        break
                if pdf_url:
                    break

        # Fallback: Scan full page HTML for regex match to latest releases files
        if not pdf_url:
            html = await page.content()
            m = re.search(r'href=[\'"]([^\'"]+latestreleasesfiles[^\'"]+IIP[^\'"]*\.pdf)[\'"]', html, re.IGNORECASE)
            if not m:
                m = re.search(r'href=[\'"]([^\'"]+latestreleasesfiles[^\'"]*\.pdf)[\'"]', html, re.IGNORECASE)
            if m:
                pdf_url = m.group(1)
                result["title"] = "MoSPI IIP Press Release"

        if pdf_url:
            result["pdf_url"] = urljoin(target_url, pdf_url)
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path = await download_file(page, result["pdf_url"], "MoSPI_IIP_Latest.pdf")
            result["local_path"] = path
            result["preview_text"] = extract_pdf_preview(path)
        else:
            print("   ❌ MoSPI: Could not resolve download URL.")
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
