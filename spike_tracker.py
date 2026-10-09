import json
import re
from datetime import datetime
import requests

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept-Language": "en-IN,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

def get_realtime_trending_searches():
    """
    Google Trends ke HTML landing page se embedded hydration state 
    extract karta hai jahan pure real-time trending queries stored hoti hain.
    """
    # India Realtime Trends URL
    url = "https://trends.google.com/trending?geo=IN&hl=en-IN"
    
    try:
        session = requests.Session()
        res = session.get(url, headers=HEADERS, timeout=15)
        
        if res.status_code != 200 or not res.text:
            return {"status": "error", "message": f"HTTP status {res.status_code}"}
        
        # Google trends ke UI page par data ek JavaScript window variable ya tag mein hota hai
        # Regex se pure search keywords extract karna:
        matches = re.findall(r'"query":\s*"([^"]+)"', res.text)
        traffic_matches = re.findall(r'"formattedTraffic":\s*"([^"]+)"', res.text)
        
        if not matches:
            # Alternate pattern for newer Google Trends frontend layout
            matches = re.findall(r'\["([A-Za-z0-9\s\.\-]{3,40})",\s*\[\],', res.text)
        
        # Unique keywords preserve order
        seen = set()
        unique_spikes = []
        for kw in matches:
            kw_clean = kw.strip()
            # Generic UI words filter out
            if kw_clean.lower() not in seen and len(kw_clean) > 2 and not kw_clean.startswith("http"):
                seen.add(kw_clean.lower())
                unique_spikes.append(kw_clean)
                
        # Business/Finance intent matching dynamically via category context
        results = []
        for idx, keyword in enumerate(unique_spikes[:20]):
            traffic = traffic_matches[idx] if idx < len(traffic_matches) else "Volume Spike"
            results.append({
                "trending_search_query": keyword,
                "surge_volume": traffic,
                "source": "Google Real-Time Search Trends"
            })
            
        return {
            "status": "success",
            "timestamp": datetime.now().isoformat(),
            "total_spikes": len(results),
            "data": results
        }
        
    except Exception as e:
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    result = get_realtime_trending_searches()
    
    output_json = json.dumps(result, indent=2, ensure_ascii=False)
    print(output_json)
    
    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(output_json)
