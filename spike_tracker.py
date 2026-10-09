import json
import urllib.parse
from datetime import datetime
from playwright.sync_api import sync_playwright
import requests

def get_entity_classification(keyword):
    """
    Google ke entity database se bina kisi hardcoded list ke 
    pata karta hai ki keyword Film/Actor hai ya Company/Finance/Market.
    """
    try:
        enc = urllib.parse.quote(keyword)
        # Google Knowledge Graph lightweight query
        url = f"https://suggestqueries.google.com/complete/search?client=chrome&hl=en&gl=in&q={enc}"
        res = requests.get(url, timeout=4)
        if res.status_code == 200:
            data = res.json()
            # data[2] me Google topic label return karta hai (e.g. "Indian actor", "Bank", "Stock", "Company")
            if len(data) > 2 and data[2]:
                labels = " ".join([str(x).lower() for x in data[2]])
                return labels
    except Exception:
        pass
    return ""

def scrape_pure_finance_spikes():
    raw_spikes = []
    
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
            print("Fetching Google Trends...")
            page.goto("https://trends.google.com/trending?geo=IN&hl=en-IN", timeout=60000)
            page.wait_for_selector('tr, [role="row"]', state="attached", timeout=30000)

            # Switch to Business
            try:
                category_btn = page.locator('button:has-text("All categories"), [aria-label*="category"], [aria-label*="Category"]').first
                if category_btn.is_visible(timeout=4000):
                    category_btn.click()
                    page.wait_for_timeout(1000)
                    business_option = page.locator('[role="menuitem"]:has-text("Business"), [role="option"]:has-text("Business"), li:has-text("Business")').first
                    business_option.click()
                    page.wait_for_timeout(2500)
            except Exception:
                pass

            raw_data = page.evaluate('''() => {
                const rows = Array.from(document.querySelectorAll('tr, [role="row"]'));
                return rows.map(r => r.innerText.trim()).filter(Boolean);
            }''')

            for item in raw_data:
                lines = [line.strip() for line in item.split("\n") if line.strip()]
                if len(lines) >= 2:
                    kw = lines[0]
                    kw_lower = kw.lower()

                    if kw_lower in ["search", "search term", "trend", "trends", "query", "title", "explore"]:
                        continue

                    traffic = "Volume Surge"
                    for line in lines[1:]:
                        if any(char.isdigit() for char in line) and ("+" in line or "K" in line or "L" in line or "M" in line or "%" in line):
                            traffic = line
                            break

                    raw_spikes.append({"keyword": kw, "volume": traffic})

        except Exception as e:
            print(f"Browser error: {e}")
        finally:
            browser.close()

    # --- ENTITY TYPE FILTERING (Bina hardcoding ke Entertainment/Cricket filter karna) ---
    clean_spikes = []
    seen = set()

    # Google Knowledge Graph me jo topics entertainment/cricket hote hain unka classification:
    DISALLOWED_ENTITIES = ["film", "movie", "actor", "actress", "cricketer", "politician", "singer", "director", "song", "tv series"]

    for s in raw_spikes:
        kw = s["keyword"]
        if kw.lower() in seen or len(kw) < 3:
            continue
        seen.add(kw.lower())

        # Dynamic query type verification
        entity_info = get_entity_classification(kw)

        # Agar Google khud ise Film/Actor/Cricketer bol raha hai, to discard karein
        is_entertainment = any(ent in entity_info for ent in DISALLOWED_ENTITIES)

        if not is_entertainment:
            clean_spikes.append({
                "keyword": kw,
                "search_volume_spike": s["volume"],
                "source": "Google Real-Time Search Trends"
            })

    return clean_spikes

if __name__ == "__main__":
    data = scrape_pure_finance_spikes()
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
