import os
import json
import re
import asyncio
import pandas as pd
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
from playwright.async_api import async_playwright

OUTPUT_DIR = "downloaded_macro_pdfs"
MANIFEST_FILE = "macro_reports_manifest.json"
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
# 1. IPA PORTS (Excel Downloader)
# ============================================================

async def download_ipa(page):
    print("\n⚓ [1/5] Crawling & Downloading IPA Ports Traffic Report...")
    target_url = "https://ipa.org.in/reports-statistics"
    res = {"title": None, "file_url": None, "local_path": None}

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
    except Exception as e:
        print(f"   ❌ IPA Error: {e}")

    return res

# ============================================================
# 2. DPIIT EIGHT CORE (PDF Downloader)
# ============================================================

async def download_eight_core(page):
    print("\n🏭 [2/5] Crawling & Downloading DPIIT Eight Core PDF...")
    target_url = "https://eaindustry.nic.in/"
    res = {"title": None, "pdf_url": None, "local_path": None}

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
    except Exception as e:
        print(f"   ❌ Eight Core Error: {e}")

    return res

# ============================================================
# 3. DPIIT WPI (PDF Downloader)
# ============================================================

async def download_wpi(page):
    print("\n📈 [3/5] Crawling & Downloading DPIIT WPI PDF...")
    target_url = "https://eaindustry.nic.in/"
    res = {"title": None, "pdf_url": None, "local_path": None}

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
    except Exception as e:
        print(f"   ❌ WPI Error: {e}")

    return res

# ============================================================
# 4. PPAC INDUSTRY CONSUMPTION REPORT (Petroleum ICR PDF)
# ============================================================

async def download_ppac_icr(page):
    print("\n🛢️ [4/5] Crawling & Downloading PPAC Petroleum Consumption Report (ICR)...")
    target_url = "https://ppac.gov.in/consumption/reports"
    res = {"title": "PPAC Industry Consumption Report", "pdf_url": None, "local_path": None}

    try:
        await page.goto(target_url, wait_until="domcontentloaded", timeout=45000)
        await page.wait_for_timeout(3000)

        pdf_url = None
        for a in await page.query_selector_all("a"):
            href = await a.get_attribute("href") or ""
            title = (await a.get_attribute("title") or "").lower()
            text = (await a.inner_text()).strip().lower()

            if ("industry consumption report" in title or "industry consumption report" in text or "_icr_" in href.lower()) and "download.php" in href.lower():
                pdf_url = urljoin(target_url, href)
                res["title"] = (await a.inner_text()).strip() or (await a.get_attribute("title")) or "PPAC Industry Consumption Report"
                break

        if not pdf_url:
            await page.goto("https://ppac.gov.in/", wait_until="domcontentloaded", timeout=45000)
            await page.wait_for_timeout(2000)
            for a in await page.query_selector_all("a"):
                href = await a.get_attribute("href") or ""
                text = (await a.inner_text()).strip().lower()
                if "industry consumption report" in text and "download.php" in href:
                    pdf_url = urljoin("https://ppac.gov.in/", href)
                    break

        if pdf_url:
            res["pdf_url"] = pdf_url
            path = await download_binary_file(page, res["pdf_url"], "PPAC_Petroleum_Consumption_Latest.pdf")
            res["local_path"] = path
        else:
            print("   ❌ PPAC: Industry Consumption Report link not found on portal.")

    except Exception as e:
        print(f"   ❌ PPAC Error: {e}")

    return res

# ============================================================
# 5. NETC FASTAG (Your Proven Working Logic - Latest Period)
# ============================================================

async def scrape_netc_fastag(browser):
    print("\n🛣️ [5/5] Scraping NETC FASTag Latest Monthly Data...")
    target_url = "https://www.npci.org.in/product/netc/product-statistics"
    all_data = []

    res = {
        "title": "NETC FASTag Monthly Product Statistics",
        "csv_path": None,
        "total_records": 0,
        "latest_monthly_metrics": {}
    }

    context = await browser.new_context(
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    )
    page = await context.new_page()

    try:
        print(f"   🌐 Opening: {target_url}")
        await page.goto(target_url, wait_until="networkidle", timeout=60000)

        # "Monthly Statistics" tab par click karein agar default selected na ho
        try:
            monthly_tab = page.locator("text='Monthly Statistics'").first
            if await monthly_tab.is_visible():
                await monthly_tab.click()
                await page.wait_for_timeout(2000)
        except Exception:
            pass

        # Table rows read karein
        rows = await page.query_selector_all("table tr")
        count = 0
        for row in rows:
            cells = await row.query_selector_all("td")
            if len(cells) >= 3:
                cell_texts = [(await c.inner_text()).strip() for c in cells]
                month_name = cell_texts[0]

                if month_name.lower() in ["month", "particulars", "total", "sl no", "sr no"]:
                    continue

                # Column structure: Month | Live Banks | Tag Issuance | Volume (Mn) | Amount (Cr)
                nums = [clean_num(t) for t in cell_texts[1:] if clean_num(t) is not None]

                if len(nums) >= 2:
                    vol_mn = nums[-2]   # Volume in Million
                    val_cr = nums[-1]   # Amount in Cr

                    record = {
                        "month": month_name,
                        "volume_million": vol_mn,
                        "volume_crore": round(vol_mn / 10.0, 2) if vol_mn else None,
                        "amount_inr_crore": val_cr,
                        "ticket_size_inr": round((val_cr * 10000000) / (vol_mn * 1000000), 2) if (val_cr and vol_mn) else None
                    }
                    all_data.append(record)
                    count += 1

        print(f"   ✅ Extracted {count} latest monthly records.")

        if all_data:
            df = pd.DataFrame(all_data)
            df.to_csv(FASTAG_CSV_FILE, index=False)
            res["csv_path"] = FASTAG_CSV_FILE
            res["total_records"] = len(df)
            res["latest_monthly_metrics"] = df.iloc[0].to_dict()
            print(f"   🎉 Saved successfully to '{FASTAG_CSV_FILE}'!")
        else:
            print("   ⚠️ No FASTag table records were parsed.")

    except Exception as e:
        print(f"   ❌ FASTag Error: {e}")
    finally:
        await context.close()

    return res

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

async def main():
    print("=" * 80)
    print("🚀 TARGETED MACRO REPORTS DOWNLOADER (PURE FETCH & STORE)")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)

    ipa_res, core_res, wpi_res, ppac_res, fastag_res = {}, {}, {}, {}, {}

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        download_context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            ignore_https_errors=True
        )
        download_page = await download_context.new_page()

        ipa_res = await download_ipa(download_page)
        core_res = await download_eight_core(download_page)
        wpi_res = await download_wpi(download_page)
        ppac_res = await download_ppac_icr(download_page)

        await download_context.close()

        # Dedicated context execution for FASTag
        fastag_res = await scrape_netc_fastag(browser)

        await browser.close()

    manifest = {
        "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "reports": {
            "ipa_ports_traffic": ipa_res,
            "dpiit_eight_core": core_res,
            "dpiit_wpi": wpi_res,
            "ppac_petroleum_icr": ppac_res,
            "netc_fastag": fastag_res
        }
    }

    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("✅ DOWNLOAD & MANIFEST SUMMARY:")
    for key, val in manifest["reports"].items():
        if key == "netc_fastag":
            status = f"✅ Extracted ({val['total_records']} rows)" if val.get("csv_path") else "❌ Failed"
            target = val.get("csv_path")
        else:
            status = "✅ Downloaded" if val.get("local_path") else "❌ Failed"
            target = val.get("local_path")
        print(f"   • {key.upper():<22} : {status} | Saved to: {target}")

    print(f"\n📁 Manifest Saved To : '{MANIFEST_FILE}'")
    print(f"📂 Files Saved To    : '{OUTPUT_DIR}/'")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
