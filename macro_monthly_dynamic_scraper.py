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

# ============================================================
# 1. IPA (Indian Ports Association)
# ============================================================

async def scrape_ipa(page):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    target_url = "https://ipa.org.in/reports-statistics"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="networkidle", timeout=60000)
        await page.wait_for_timeout(3000)

        # Saare anchor tags inspect karte hain jinka href .pdf ho ya text me traffic/month ho
        anchors = await page.query_selector_all("a")
        for a in anchors:
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).strip()
            combined = f"{text.lower()} {href.lower()}"

            if ".pdf" in href.lower() and ("traffic" in combined or "month" in combined or "cargo" in combined):
                result["title"] = text or "IPA Monthly Traffic Report"
                result["pdf_url"] = urljoin(target_url, href)
                break

        if result["pdf_url"]:
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            
            # Browser session se direct download
            filepath = os.path.join(OUTPUT_DIR, "IPA_Traffic_Latest.pdf")
            response = await page.request.get(result["pdf_url"], timeout=45000)
            if response.status == 200:
                with open(filepath, "wb") as f:
                    f.write(await response.body())
                result["local_path"] = filepath
                result["preview_text"] = extract_pdf_preview(filepath)
                print(f"   💾 Downloaded: {filepath}")
        else:
            print("   ❌ IPA: Link not found in DOM.")
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")

    return result

# ============================================================
# 2. DPIIT — Eight Core Industries Press Note
# ============================================================

async def scrape_eight_core(page):
    print("\n🏭 [2/4] Scraping DPIIT Eight Core Industries PDF...")
    target_url = "https://eaindustry.nic.in/eight_core_infra/"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(2000)

        # Links collect karein (WPI press_release_ se conflict na ho)
        anchors = await page.query_selector_all("a")
        candidate_url = None
        candidate_title = None

        for a in anchors:
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).strip()

            if href.lower().endswith(".pdf") and not href.lower().startswith("press_release_"):
                candidate_url = urljoin(target_url, href)
                candidate_title = text or "Eight Core Industries Press Note"
                break

        # Fallback to direct static PDF if directory has no raw anchors
        if not candidate_url:
            candidate_url = "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"
            candidate_title = "Index of Eight Core Industries"

        result["pdf_url"] = candidate_url
        result["title"] = candidate_title

        print(f"   🔗 Found: {result['title']}")
        print(f"   🌐 Link : {result['pdf_url']}")

        filepath = os.path.join(OUTPUT_DIR, "DPIIT_Eight_Core_Latest.pdf")
        response = await page.request.get(result["pdf_url"], timeout=45000)
        if response.status == 200:
            with open(filepath, "wb") as f:
                f.write(await response.body())
            result["local_path"] = filepath
            result["preview_text"] = extract_pdf_preview(filepath)
            print(f"   💾 Downloaded: {filepath}")
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return result

# ============================================================
# 3. DPIIT — WPI Press Release PDF
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

            filepath = os.path.join(OUTPUT_DIR, "DPIIT_WPI_Latest.pdf")
            response = await page.request.get(result["pdf_url"], timeout=45000)
            if response.status == 200:
                with open(filepath, "wb") as f:
                    f.write(await response.body())
                result["local_path"] = filepath
                result["preview_text"] = extract_pdf_preview(filepath)
                print(f"   💾 Downloaded: {filepath}")
    except Exception as e:
        print(f"   ❌ WPI Error: {e}")

    return result

# ============================================================
# 4. MoSPI — Index of Industrial Production (IIP) Release
# ============================================================

async def scrape_mospi_iip(page):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}

    try:
        await page.goto(target_url, wait_until="networkidle", timeout=60000)
        await page.wait_for_timeout(3000)

        # MoSPI ke rendered DOM me check karte hain
        anchors = await page.query_selector_all("a")
        for a in anchors:
            href = await a.get_attribute("href") or ""
            text = (await a.inner_text()).strip().lower()

            is_iip = (
                "iip" in href.lower()
                or "quick estimate" in text
                or "industrial production" in text
                or "latestreleasesfiles" in href.lower()
            )

            if is_iip and (".pdf" in href.lower() or "latestreleasesfiles" in href.lower()):
                result["title"] = (await a.inner_text()).strip() or "MoSPI IIP Press Release"
                result["pdf_url"] = urljoin(target_url, href)
                break

        if result["pdf_url"]:
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")

            filepath = os.path.join(OUTPUT_DIR, "MoSPI_IIP_Latest.pdf")
            response = await page.request.get(result["pdf_url"], timeout=45000)
            if response.status == 200:
                with open(filepath, "wb") as f:
                    f.write(await response.body())
                result["local_path"] = filepath
                result["preview_text"] = extract_pdf_preview(filepath)
                print(f"   💾 Downloaded: {filepath}")
        else:
            print("   ❌ MoSPI: No matching IIP PDF link found in DOM.")
    except Exception as e:
        print(f"   ❌ MoSPI Error: {e}")

    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

async def main():
    print("=" * 80)
    print("🚀 PLAYWRIGHT MACRO DOCUMENT CRAWLER (HEADLESS CHROMIUM)")
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
