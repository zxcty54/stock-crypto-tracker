import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime
import requests

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

def clean_text(text):
    """HTML tags aur special characters hatata hai"""
    clean = re.sub(r'<.*?>', '', text)
    clean = re.sub(r'[^a-zA-Z0-9\s]', ' ', clean)
    return " ".join(clean.split())

def fetch_dynamic_breaking_finance_topics():
    """
    Google News Business/Economy (India) ke live RSS feed se
    breakout topics dynamically uthata hai - ZERO hardcoding.
    """
    # Google News Business Topic Feed (India - English)
    url = "https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=en-IN&gl=IN&ceid=IN:en"
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=10)
        root = ET.fromstring(res.content)
        
        candidates = []
        for item in root.findall('.//item')[:15]:
            title = item.find('title').text or ""
            link = item.find('link').text or ""
            
            # Source name (e.g. " - Economic Times") ko alag karna
            main_headline = title.split(" - ")[0].strip()
            
            # Headline se main meaningful entities nikalna
            clean_title = clean_text(main_headline)
            words = [w for w in clean_title.split() if len(w) > 3]
            
            candidates.append({
                "headline": main_headline,
                "url": link,
                "tokens": words[:4] # Core topic phrase
            })
            
        return candidates
    except Exception as e:
        print(f"Error fetching live feed: {e}")
        return []

def get_live_search_intent(query_phrase):
    """Google live autocomplete se volume aur actual user queries verify karta hai"""
    url = f"https://suggestqueries.google.com/complete/search?client=chrome&hl=en-IN&gl=in&q={query_phrase}"
    try:
        res = requests.get(url, headers=HEADERS, timeout=5)
        if res.status_code == 200:
            data = res.json()
            # data[1] -> Real-time suggested search queries
            return data[1] if len(data) > 1 else []
    except Exception:
        pass
    return []

def extract_dynamic_spikes():
    breaking_events = fetch_dynamic_breaking_finance_topics()
    
    results = []
    
    for event in breaking_events:
        phrase = " ".join(event["tokens"][:3]) # First 3 strong words
        if not phrase:
            continue
            
        # Check actual search surge on Google
        live_queries = get_live_search_intent(phrase)
        
        # Agar Google is topic par suggestions de raha hai, iska matlab search volume active hai
        if live_queries:
            results.append({
                "hot_keyword": live_queries[0],
                "search_volume_velocity": f"{len(live_queries)} active variations expanding",
                "trending_queries_by_users": live_queries[:4],
                "trigger_event": {
                    "headline": event["headline"],
                    "source": event["url"]
                }
            })

    return {
        "status": "success",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(results),
        "data": results
    }

if __name__ == "__main__":
    output = extract_dynamic_spikes()
    
    json_data = json.dumps(output, indent=2, ensure_ascii=False)
    print(json_data)
    
    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(json_data)
