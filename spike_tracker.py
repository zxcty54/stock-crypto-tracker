import json
import string
from datetime import datetime
import requests

# Base topics jinka live breakout search volume scan karna hai
BASE_SEEDS = [
    "nifty", "sensex", "rbi", "stock market", "share price", 
    "ipo", "gold rate", "silver rate", "inflation", "sebi", "repo rate"
]

# Modifiers jo tab trigger hote hain jab achanak search spike hota hai
SPIKE_MODIFIERS = ["why", "today", "news", "fall", "surge", "live", "crash"]

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

def query_google_suggest(search_term):
    """Google ke direct autocomplete engine se real-time breakout search queries fetch karta hai"""
    url = f"https://suggestqueries.google.com/complete/search?client=chrome&hl=en-IN&gl=in&q={search_term}"
    try:
        res = requests.get(url, headers=HEADERS, timeout=6)
        if res.status_code == 200:
            data = res.json()
            # data[1] -> query suggestions list
            return data[1] if len(data) > 1 else []
    except Exception:
        pass
    return []

def extract_search_spikes():
    discovered_queries = {}
    
    # 1. Base keywords + intent scan
    for seed in BASE_SEEDS:
        # Direct seed search
        direct_results = query_google_suggest(seed)
        for q in direct_results:
            q_clean = q.strip().lower()
            discovered_queries[q_clean] = discovered_queries.get(q_clean, 0) + 2

        # Breakout intent modifiers scan (e.g. "nifty why", "rbi news")
        for mod in SPIKE_MODIFIERS:
            combo = f"{seed} {mod}"
            mod_results = query_google_suggest(combo)
            for q in mod_results:
                q_clean = q.strip().lower()
                discovered_queries[q_clean] = discovered_queries.get(q_clean, 0) + 3

    # Ranking: Highest frequency in velocity predictions = highest spike
    ranked_spikes = sorted(discovered_queries.items(), key=lambda x: x[1], reverse=True)

    spikes_data = []
    # Top 15 highest volume trending breakout keywords
    for query, score in ranked_spikes[:15]:
        spikes_data.append({
            "keyword": query,
            "velocity_score": score,
            "search_status": "High Velocity Spike" if score >= 4 else "Surging Search"
        })

    return {
        "status": "success",
        "timestamp": datetime.now().isoformat(),
        "total_hot_spikes": len(spikes_data),
        "data": spikes_data
    }

if __name__ == "__main__":
    result = extract_search_spikes()
    json_output = json.dumps(result, indent=2, ensure_ascii=False)
    print(json_output)

    with open("trending_spikes.json", "w", encoding="utf-8") as f:
        f.write(json_output)
