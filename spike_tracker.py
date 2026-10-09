import json
import xml.etree.ElementTree as ET
from datetime import datetime
import requests

# Target finance & market filters
FINANCE_KEYWORDS = [
    "rbi", "nifty", "sensex", "stock", "share", "market", "sebi", 
    "bank", "ipo", "gold", "silver", "repo", "inflation", "gdp", 
    "adani", "tata", "rupee", "dollar", "fed", "budget", "finance"
]

def get_autocomplete_queries(keyword):
    """Google Autocomplete API se user intent queries nikalta hai"""
    url = f"https://suggestqueries.google.com/complete/search?client=firefox&q={keyword}"
    try:
        res = requests.get(url, timeout=5)
        data = res.json()
        return data[1][:4] if len(data) > 1 else []
    except Exception:
        return []

def extract_search_spikes():
    url = "https://trends.google.com/trends/trending/rss?geo=IN"
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        root = ET.fromstring(response.content)
    except Exception as e:
        return {"error": f"Failed to fetch trends: {str(e)}"}

    namespaces = {'ht': 'https://trends.google.com/trends/trending/rss'}
    spikes = []

    for item in root.findall('.//item'):
        title = item.find('title').text or ""
        
        approx_traffic = item.find('ht:approx_traffic', namespaces)
        traffic_vol = approx_traffic.text if approx_traffic is not None else "Sudden Surge"
        
        news_title = ""
        news_url = ""
        news_item = item.find('ht:news_item', namespaces)
        if news_item is not None:
            nt = news_item.find('ht:news_item_title', namespaces)
            nu = news_item.find('ht:news_item_url', namespaces)
            if nt is not None:
                news_title = nt.text
            if nu is not None:
                news_url = nu.text

        # Filter strictly for finance and economy
        full_context = f"{title} {news_title}".lower()
        if any(kw in full_context for k in FINANCE_KEYWORDS for kw in [k]):
            queries = get_autocomplete_queries(title)
            
            spikes.append({
                "keyword": title,
                "search_volume_spike": traffic_vol,
                "user_intent_queries": queries,
                "trigger_news": {
                    "headline": news_title,
                    "source_url": news_url
                }
            })

    output = {
        "status": "success",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(spikes),
        "data": spikes
    }

    return output

if __name__ == "__main__":
    result = extract_search_spikes()
    
    # Terminal par pretty JSON print karega
    json_output = json.dumps(result, indent=2, ensure_ascii=False)
    print(json_output)

    # Local file me save karega
    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(json_output)
    
    print("\nSaved to trending_spikes.json")
