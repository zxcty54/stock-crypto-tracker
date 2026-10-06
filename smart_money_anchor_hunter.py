import requests
import json
import re
from datetime import datetime, timedelta

BSE_API_URL = "https://api.bseindia.com/BseIndiaAPI/api/AnnSubCategoryGetData/w"

BSE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36",
    "Origin": "https://www.bseindia.com",
    "Referer": "https://www.bseindia.com/",
    "Accept": "application/json, text/plain, */*"
}

def fetch_bse_allotments(days_back=30):
    """BSE se pichle 30 dino ke saare QIP aur Allotment corporate filings direct extract karta hai."""
    to_date = datetime.now().strftime("%Y%m%d")
    from_date = (datetime.now() - timedelta(days=days_back)).strftime("%Y%m%d")

    params = {
        "pageno": 1,
        "strCat": "Company Update",
        "strPrevDate": from_date,
        "strScrip": "",
        "strSearch": "P", # Preferential / Allotment / QIP
        "strToDate": to_date,
        "strType": "C",
        "subcategory": "Allotment of Securities"
    }

    try:
        response = requests.get(BSE_API_URL, headers=BSE_HEADERS, params=params, timeout=10)
        if response.status_code != 200:
            return []

        data = response.json()
        filings = data.get("Table", [])
        
        extracted_anchors = []

        for item in filings:
            head = item.get("NEWSSUB", "")
            details = item.get("HEADLINE", "") + " " + item.get("MORE", "")
            symbol = item.get("scrip_cd", "")
            company_name = item.get("SLONGNAME", "")
            pdf_name = item.get("ATTACHMENTNAME", "")
            pdf_url = f"https://www.bseindia.com/xml-data/corpfiling/AttachLive/{pdf_name}" if pdf_name else ""

            # Detect Issue Price via regex
            price_match = re.search(r'(?:issue\s+price|price\s+of|at\s+a\s+price\s+of)\s*(?:of|at|is)?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)', details, re.I)
            
            if price_match:
                floor_price = float(price_match.group(1).replace(",", ""))
                extracted_anchors.append({
                    "bse_code": symbol,
                    "company_name": company_name,
                    "headline": head,
                    "institutional_floor_price": floor_price,
                    "filing_pdf": pdf_url,
                    "date": item.get("NEWS_DT", "")
                })

        return extracted_anchors
    except Exception as e:
        print(f"Error fetching from BSE: {e}")
        return []

if __name__ == "__main__":
    anchors = fetch_bse_allotments()
    print(f"✅ Found {len(anchors)} fresh institutional allotments directly from BSE India!")
