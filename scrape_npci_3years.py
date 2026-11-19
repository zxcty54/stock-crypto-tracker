import asyncio
import json
import re
import pandas as pd
from playwright.async_api import async_playwright

# Naya updated working URL
TARGET_URL = "https://www.npci.org.in/product/netc/product-statistics"
YEARS_TO_SCRAPE = ["2026", "2025", "2024"]

def clean_num(val):
    if not val:
        return None
    val = str(val).replace(",", "").replace("%", "").strip()
    match = re.search(r"[-+]?\d*\.?\d+", val)
    return float(match.group(0)) if match else None

async def scrape_netc_3years():
    print(f"🚀 Scraping NETC FASTag Monthly Data for {', '.join(YEARS_TO_SCRAPE)}...")
    all_data = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        )
        page = await context.new_page()

        print(f"🌐 Opening: {TARGET_URL}")
        await page.goto(TARGET_URL, wait_until="networkidle", timeout=60000)

        # "Monthly Statistics" tab par click karein agar default selected na ho
        try:
            monthly_tab = page.locator("text='Monthly Statistics'").first
            if await monthly_tab.is_visible():
                await monthly_tab.click()
                await page.wait_for_timeout(2000)
        except Exception:
            pass

        for year in YEARS_TO_SCRAPE:
            print(f"\n📅 Fetching Year: {year}...")

            # Dropdown se year select karein
            year_selected = False
            
            # 1. Standard HTML Select
            selects = await page.query_selector_all("select")
            for sel in selects:
                options = await sel.inner_text()
                if year in options:
                    await sel.select_option(label=year)
                    year_selected = True
                    break

            # 2. Custom UI Dropdown Button
            if not year_selected:
                try:
                    btn = page.locator(f"button:has-text('{year}'), div:has-text('{year}')").first
                    if await btn.is_visible():
                        await btn.click()
                        year_selected = True
                except Exception:
                    pass

            await page.wait_for_timeout(3000)

            # Table rows read karein
            rows = await page.query_selector_all("table tr")
            count = 0
            for row in rows:
                cells = await row.query_selector_all("td")
                if len(cells) >= 3:
                    cell_texts = [ (await c.inner_text()).strip() for c in cells ]
                    month_name = cell_texts[0]

                    if month_name.lower() in ["month", "particulars", "total", "sl no", "sr no"]:
                        continue

                    # Column structure: Month | Live Banks | Tag Issuance | Volume (Mn) | Amount (Cr)
                    # Numbers extract karein
                    nums = [clean_num(t) for t in cell_texts[1:] if clean_num(t) is not None]
                    
                    if len(nums) >= 2:
                        vol_mn = nums[-2]   # Volume in Million
                        val_cr = nums[-1]   # Amount in Cr
                        
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

        await browser.close()

    if all_data:
        df = pd.DataFrame(all_data)
        csv_file = "netc_fastag_monthly_3years.csv"
        df.to_csv(csv_file, index=False)
        print(f"\n🎉 Saved successfully to '{csv_file}'!")
        print(df.to_string(index=False))
    else:
        print("❌ Data parse nahi ho paya. URL live check karein.")

if __name__ == "__main__":
    asyncio.run(scrape_netc_3years())
