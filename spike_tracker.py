import json
import re
from datetime import datetime
import requests

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
    # Google Trends ka internal daily trends JSON endpoint
    url = "https://trends.google.com/trends/api/dailytrends?hl=en-US&tz=-330&geo=IN&ns=15"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Referer": "https://trends.google.com/trends/trendingsearches/daily?geo=IN"
    }

    try:
        session = requests.Session()
        # Homepage hit karke zaroori cookies collect karta hai
        session.get("https://trends.google.com/trends/trendingsearches/daily?geo=IN", headers=headers, timeout=10)
        
        response = session.get(url, headers=headers, timeout=10)
        
        # Google API response ke shuru me security prefix ')]}\',\n' bhejta hai
        raw_text = response.text
        if raw_text.startswith(")]}',"):
            raw_text = raw_text.replace(")]}',", "", 1).strip()
            
        data = json.loads(raw_text)
    except Exception as e:
        return {"error": f"Failed to fetch trends: {str(e)}"}

    spikes = []
    
    try:
        days = data.get("default", {}).get("trendingSearchesDays", [])
        if days:
            searches = days[0].get("trendingSearches", [])
            for item in searches:
                title = item.get("title", {}).get("query", "")
                traffic = item.get("formattedTraffic", "High Spike")
                
                # Context check: related queries aur news articles
                articles = item.get("articles", [])
                news_title = articles[0].get("title", "") if articles else ""
                news_url = articles[0].get("url", "") if articles else ""
                
                full_context = f"{title} {news_title}".lower()
                
                # Filter finance topics
                if any(kw in full_context for kw in FINANCE_KEYWORDS):
                    queries = get_autocomplete_queries(title)
                    spikes.append({
                        "keyword": title,
                        "search_volume_spike": traffic,
                        "user_intent_queries": queries,
                        "trigger_news": {
                            "headline": re.sub(r'<.*?>', '', news_title),  # HTML tags clean karta hai
                            "source_url": news_url
                        }
                    })
    except Exception as e:
        return {"error": f"JSON parsing error: {str(e)}"}

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
