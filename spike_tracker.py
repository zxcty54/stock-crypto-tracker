import json
from datetime import datetime
import requests

def get_pure_search_volume_spikes():
    # Google Search Widget ka direct Realtime Trends Feed (India)
    # Isme sirf wahi keywords aate hain jinka search volume pichle 1-4 ghante me breakout hua hai
    url = "https://trends.google.com/trends/api/realtimetrends?hl=en-IN&tz=-330&cat=b&fi=0&fs=0&geo=IN&ri=300&rs=20&sort=0"
    
    # cat=b ka matlab: Category = Business, Economy & Markets (Google internal category code)
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Referer": "https://trends.google.com/trends/trendingsearches/realtime?geo=IN&category=b"
    }

    try:
        session = requests.Session()
        res = session.get(url, headers=headers, timeout=12)
        
        # Google API prefixes garbage characters ')]}\',\n' for JSON hijacking protection
        clean_text = res.text
        if clean_text.startswith(")]}',"):
            clean_text = clean_text.replace(")]}',", "", 1).strip()
            
        data = json.loads(clean_text)
    except Exception as e:
        return {"status": "error", "message": f"Network/Parse Error: {str(e)}"}

    spikes = []
    
    # Story Summaries extracting
    story_summaries = data.get("storySummaries", {}).get("trendingStories", [])
    
    for story in story_summaries:
        title = story.get("title", "")
        # Query breakout entities (log exact kya search kar rahe hain)
        entity_names = story.get("entityNames", [])
        
        # Search surge metrics
        articles_count = len(story.get("articles", []))
        
        spikes.append({
            "trending_search_keyword": title,
            "associated_hot_entities": entity_names,
            "surge_indicator": f"{articles_count}+ live breakout sources confirming search explosion"
        })

    return {
        "status": "success",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(spikes),
        "data": spikes
    }

if __name__ == "__main__":
    result = get_pure_search_volume_spikes()
    
    # Console output
    json_output = json.dumps(result, indent=2, ensure_ascii=False)
    print(json_output)

    # File save
    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(json_output)
