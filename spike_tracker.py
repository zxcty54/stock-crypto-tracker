import json
from datetime import datetime
from playwright.sync_api import sync_playwright

def scrape_pure_business_trends():
    spikes = []
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage"]
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            locale="en-IN"
        )
        page = context.new_page()
        
        try:
            print("Loading Google Trends...")
            page.goto("https://trends.google.com/trending?geo=IN&hl=en-IN", timeout=60000)
            page.wait_for_selector('tr, [role="row"]', state="attached", timeout=30000)

            # --- UI PAR DIRECT 'BUSINESS' CATEGORY SELECT KARNA ---
            try:
                print("Switching category to Business...")
                # Category Dropdown par click karein
                # Google Trends dropdown selector ya button target karna
                category_btn = page.locator('button:has-text("All categories"), [aria-label*="category"], [aria-label*="Category"]').first
                if category_btn.is_visible(timeout=5000):
                    category_btn.click()
                    page.wait_for_timeout(1000)
                    # Dropdown menu se "Business" select karein
                    business_option = page.locator('[role="menuitem"]:has-text("Business"), [role="option"]:has-text("Business"), li:has-text("Business")').first
                    business_option.click()
                    print("Business category selected successfully.")
                    # Naye filtered data ke reload hone ka wait
                    page.wait_for_timeout(3000)
            except Exception as e:
                print(f"Dropdown click note: {e}")

            # Filter hone ke baad updated rows extract karein
            raw_data = page.evaluate('''() => {
                const rows = Array.from(document.querySelectorAll('tr, [role="row"]'));
                return rows.map(r => r.innerText.trim()).filter(Boolean);
            }''')

            for item in raw_data:
                lines = [line.strip() for line in item.split("\n") if line.strip()]
                if len(lines) >= 2:
                    kw = lines[0]
                    kw_lower = kw.lower()

                    # System headers skip
                    if kw_lower in ["search", "search term", "trend", "trends", "query", "title", "explore"]:
                        continue

                    # Volume (+, K, L, M)
                    traffic = "Volume Surge"
                    for line in lines[1:]:
                        if any(char.isdigit() for char in line) and ("+" in line or "K" in line or "L" in line or "M" in line or "%" in line):
                            traffic = line
                            break

                    spikes.append({
                        "keyword": kw,
                        "search_volume_spike": traffic,
                        "category": "Business & Economy",
                        "source": "Google Real-Time Search Trends"
                    })
                    
        except Exception as e:
            print(f"Extraction error: {e}")
        finally:
            browser.close()

    # Deduplicate
    unique_spikes = []
    seen = set()
    for s in spikes:
        clean_name = s["keyword"].strip().lower()
        if clean_name not in seen and len(clean_name) > 2:
            seen.add(clean_name)
            unique_spikes.append(s)

    return unique_spikes

if __name__ == "__main__":
    data = scrape_pure_business_trends()
    output = {
        "status": "success" if data else "empty",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(data),
        "data": data
    }
    
    output_json = json.dumps(output, indent=2, ensure_ascii=False)
    print(output_json)

    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(output_json)
