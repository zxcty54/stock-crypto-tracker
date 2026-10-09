import json
import re
from datetime import datetime
import requests
from pytrends.request import TrendReq

FINANCE_KEYWORDS = [
    "rbi", "nifty", "sensex", "stock", "share", "market", "sebi", 
    "bank", "ipo", "gold", "silver", "repo", "inflation", "gdp", 
    "adani", "tata", "rupee", "dollar", "fed", "budget", "finance"
]

def get_autocomplete_queries(keyword):
    url = f"https://suggestqueries.google.com/complete/search?client=firefox&q={keyword}"
    try:
        res = requests.get(url, timeout=5)
        data = res.json()
        return data[1][:4] if len(data) > 1 else []
    except Exception:
        return []

def extract_search_spikes():
    spikes = []
    try:
        # Pytrends session initialize (India timezone)
        pytrends = TrendReq(hl='en-US', tz=330, timeout=(10, 25))
        
        # Realtime trending searches for India
        df = pytrends.trending_searches(pn='india')
        trending_list = df[0].tolist()
        
    except Exception as e:
        return {
            "status": "error",
            "error": f"Failed to fetch trends via pytrends: {str(e)}",
            "data": []
        }

    for item in trending_list:
        keyword = str(item).strip()
        kw_lower = keyword.lower()
        
        # Check against finance filters
        if any(fk in kw_lower for fk in FINANCE_KEYWORDS):
            queries = get_autocomplete_queries(keyword)
            spikes.append({
                "keyword": keyword,
                "spike_status": "Trending Now (Top Breakout)",
                "live_intent_queries": queries
            })

    return {
        "status": "success",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(spikes),
        "data": spikes
    }

if __name__ == "__main__":
    result = extract_search_spikes()
    json_output = json.dumps(result, indent=2, ensure_ascii=False)
    print(json_output)

    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(json_output)
