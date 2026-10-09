import json
from datetime import datetime
from playwright.sync_api import sync_playwright

def scrape_google_trends():
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
            print("Navigating to Google Trends...")
            page.goto("https://trends.google.com/trending?geo=IN&hl=en-IN", timeout=60000)
            
            # Visibility ka wait nahi karna, sirf DOM me attach hone ka wait karna hai
            page.wait_for_selector('tr, [role="row"]', state="attached", timeout=30000)
            
            # Browser ke andar se hi sara text ek sath extract kar lo (Fast & Safe)
            raw_data = page.evaluate('''() => {
                const rows = Array.from(document.querySelectorAll('tr, [role="row"]'));
                const results = [];
                for (const row of rows) {
                    const text = row.innerText.trim();
                    if (text) {
                        results.push(text);
                    }
                }
                return results;
            }''')
            
            for item in raw_data:
                lines = [line.strip() for line in item.split("\n") if line.strip()]
                if len(lines) >= 2:
                    kw = lines[0]
                    # Table headers aur pagination filter out karein
                    if kw.lower() in ["search term", "trend", "trends", "query", "title", "explore"]:
                        continue
                        
                    # Volume find karein (e.g. 50K+, 100K+, 10K+)
                    traffic = "Volume Surge"
                    for line in lines[1:]:
                        if any(char.isdigit() for char in line) and ("+" in line or "K" in line or "M" in line or "%" in line):
                            traffic = line
                            break
                            
                    spikes.append({
                        "keyword": kw,
                        "search_volume_spike": traffic,
                        "source": "Google Real-Time Search Trends"
                    })
                    
        except Exception as e:
            print(f"Extraction error: {e}")
        finally:
            browser.close()
            
    # Duplicates remove karein
    unique_spikes = []
    seen = set()
    for s in spikes:
        if s["keyword"].lower() not in seen and len(s["keyword"]) > 2:
            seen.add(s["keyword"].lower())
            unique_spikes.append(s)
            
    return unique_spikes

if __name__ == "__main__":
    data = scrape_google_trends()
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
