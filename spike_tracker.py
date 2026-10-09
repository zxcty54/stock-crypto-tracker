import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime
import requests

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

def extract_realtime_spikes():
    # Google Trends official real-time daily feed for India
    url = "https://trends.google.com/trends/trendingsearches/daily/rss?geo=IN"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=15)
        if response.status_code != 200 or not response.content:
            return {"status": "error", "message": f"HTTP Error {response.status_code}"}

        # Parse XML
        root = ET.fromstring(response.content)
        
        # Namespace Google Trends tags ke liye
        ns = {'ht': 'https://trends.google.com/trends/trendingsearches/daily'}
        
        spikes = []
        for item in root.findall('.//item'):
            title_elem = item.find('title')
            traffic_elem = item.find('ht:approx_traffic', ns)
            pub_date_elem = item.find('pubDate')
            
            # Related queries aur entities jo breakout hui hain
            related_queries = []
            for q in item.findall('ht:news_item/ht:news_item_title', ns):
                if q.text:
                    related_queries.append(re.sub(r'<.*?>', '', q.text).strip())
            
            if title_elem is not None and title_elem.text:
                keyword = title_elem.text.strip()
                traffic = traffic_elem.text.strip() if traffic_elem is not None and traffic_elem.text else "Spike"
                pub_date = pub_date_elem.text.strip() if pub_date_elem is not None else ""
                
                spikes.append({
                    "keyword": keyword,
                    "search_volume_spike": traffic,
                    "surge_time": pub_date,
                    "breakout_context": related_queries[:2]
                })

        return {
            "status": "success",
            "timestamp": datetime.now().isoformat(),
            "total_spikes": len(spikes),
            "data": spikes
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    result = extract_realtime_spikes()
    
    output_json = json.dumps(result, indent=2, ensure_ascii=False)
    print(output_json)
    
    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(output_json)
