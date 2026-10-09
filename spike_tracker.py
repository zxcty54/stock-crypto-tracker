import json
import urllib.parse
from datetime import datetime
import requests

def get_google_breakout_searches():
    # Google Trends ka naya unified explore endpoint (geo=IN)
    # Yeh un keywords ko return karta hai jinke volume me achanak spike (Breakout) aaya hai
    base_url = "https://trends.google.com/trends/api/explore"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Referer": "https://trends.google.com/trends/explore?geo=IN"
    }

    session = requests.Session()
    
    # Step 1: Token request for Realtime Rising Searches in India (geo: IN)
    req_payload = {
        "comparisonItem": [{"geo": {"country": "IN"}, "time": "now 1-d"}],
        "category": 0,  # All live rising categories
        "property": ""
    }
    
    params = {
        "hl": "en-US",
        "tz": "-330",
        "req": json.dumps(req_payload)
    }

    try:
        res = session.get(base_url, headers=headers, params=params, timeout=12)
        clean_text = res.text
        if clean_text.startswith(")]}',"):
            clean_text = clean_text.replace(")]}',", "", 1).strip()
            
        data = json.loads(clean_text)
        
        # RELATED_QUERIES widget ka token nikalna
        widgets = data.get("widgets", [])
        related_widget = None
        for w in widgets:
            if w.get("id") == "RELATED_QUERIES":
                related_widget = w
                break
                
        if not related_widget:
            return []

        # Step 2: Widget se exact Rising/Breakout search queries fetch karna
        widget_url = "https://trends.google.com/trends/api/widgetdata/relatedsearches"
        widget_params = {
            "hl": "en-US",
            "tz": "-330",
            "req": json.dumps(related_widget.get("request", {})),
            "token": related_widget.get("token", "")
        }

        w_res = session.get(widget_url, headers=headers, params=widget_params, timeout=12)
        w_text = w_res.text
        if w_text.startswith(")]}',"):
            w_text = w_text.replace(")]}',", "", 1).strip()
            
        w_data = json.loads(w_text)
        
        # rankedList[1] me Google "RISING / BREAKOUT" queries deta hai (jinka volume achanak bada hai)
        ranked_lists = w_data.get("default", {}).get("rankedList", [])
        rising_queries = []
        
        if len(ranked_lists) > 1:
            rising_items = ranked_lists[1].get("rankedKeyword", [])
            for item in rising_items:
                query = item.get("query", "")
                # Google metric: "Breakout" ya percentage surge jaise "+4,500%"
                value = item.get("formattedValue", "Breakout Volume Spike")
                
                if query:
                    rising_queries.append({
                        "keyword": query,
                        "search_volume_spike": value,
                        "source": "Google Realtime Breakout Engine"
                    })
                    
        return rising_queries

    except Exception as e:
        print(f"Error: {e}")
        return []

if __name__ == "__main__":
    spikes = get_google_breakout_searches()
    
    output = {
        "status": "success" if spikes else "empty",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(spikes),
        "data": spikes
    }
    
    json_data = json.dumps(output, indent=2, ensure_ascii=False)
    print(json_data)
    
    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(json_data)
