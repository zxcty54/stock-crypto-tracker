import json
from datetime import datetime
from playwright.sync_api import sync_playwright

def scrape_google_trends():
    spikes = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Real mobile/desktop browser context
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            locale="en-IN"
        )
        page = context.new_page()
        
        try:
            # India ke real-time daily trends page par direct navigation
            page.goto("https://trends.google.com/trending?geo=IN&hl=en-IN", timeout=45000, wait_until="networkidle")
            
            # Table/List items load hone ka wait
            page.wait_for_selector('tbody tr, [role="row"]', timeout=15000)
            
            rows = page.query_selector_all('tbody tr, [role="row"]')
            for row in rows:
                text = row.inner_text()
                lines = [line.strip() for line in text.split("\n") if line.strip()]
                # Format parsing: Title aur search count
                if len(lines) >= 2:
                    keyword = lines[0]
                    # Filter out header rows
                    if keyword.lower() in ["search term", "trend", "query", "title"]:
                        continue
                    traffic = lines[1] if any(char.isdigit() for char in lines[1]) else "Spike"
                    spikes.append({
                        "keyword": keyword,
                        "search_volume_spike": traffic,
                        "source": "Google Realtime Trends (Headless)"
                    })
        except Exception as e:
            print(f"Playwright error: {e}")
        finally:
            browser.close()
            
    return spikes

if __name__ == "__main__":
    data = scrape_google_trends()
    output = {
        "status": "success" if data else "empty",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(data),
        "data": data
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))
    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(json.dumps(output, indent=2, ensure_ascii=False))
