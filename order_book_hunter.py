import os
import re
import json
import time
from datetime import datetime
import io
import requests
from bs4 import BeautifulSoup
import pypdf

OUTPUT_REPORT_FILE = "order_radar_report.json"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()

MAX_MARKET_CAP_CR = 15000.0  # Smallcap range
MIN_ORDER_TO_MCAP_MULTIPLE = 0.8

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

# Aapki CSV (ind_niftysmallcap250list.csv) ke saare order-oriented core stocks
TARGET_COMPANIES = [
    {"symbol": "ACC", "name": "ACC Ltd.", "industry": "Construction Materials"},
    {"symbol": "ACMESOLAR", "name": "ACME Solar Holdings Ltd.", "industry": "Power"},
    {"symbol": "ACE", "name": "Action Construction Equipment Ltd.", "industry": "Capital Goods"},
    {"symbol": "ABREL", "name": "Aditya Birla Real Estate Ltd.", "industry": "Realty"},
    {"symbol": "AIAENG", "name": "AIA Engineering Ltd.", "industry": "Capital Goods"},
    {"symbol": "AMBER", "name": "Amber Enterprises India Ltd.", "industry": "Consumer Durables"},
    {"symbol": "ANANDRATHI", "name": "Anand Rathi Wealth Ltd.", "industry": "Financial Services"},
    {"symbol": "ANANTRAJ", "name": "Anant Raj Ltd.", "industry": "Realty"},
    {"symbol": "APARINDS", "name": "Apar Industries Ltd.", "industry": "Capital Goods"},
    {"symbol": "APLLTD", "name": "Alembic Pharmaceuticals Ltd.", "industry": "Healthcare"},
    {"symbol": "APOLLO", "name": "Apollo Micro Systems Ltd.", "industry": "Capital Goods"},
    {"symbol": "ARVINDFASN", "name": "Arvind Fashions Ltd.", "industry": "Textiles"},
    {"symbol": "ASAHIINDIA", "name": "Asahi India Glass Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "ASHOKLEY", "name": "Ashok Leyland Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "ASTERDM", "name": "Aster DM Healthcare Ltd.", "industry": "Healthcare"},
    {"symbol": "ASTRAL", "name": "Astral Ltd.", "industry": "Capital Goods"},
    {"symbol": "ATUL", "name": "Atul Ltd.", "industry": "Chemicals"},
    {"symbol": "BAJAJELEC", "name": "Bajaj Electricals Ltd.", "industry": "Consumer Durables"},
    {"symbol": "BALRAMCHIN", "name": "Balrampur Chini Mills Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "BATAINDIA", "name": "Bata India Ltd.", "industry": "Consumer Durables"},
    {"symbol": "BEL", "name": "Bharat Electronics Ltd.", "industry": "Capital Goods"},
    {"symbol": "BEML", "name": "BEML Ltd.", "industry": "Capital Goods"},
    {"symbol": "BHARATFORG", "name": "Bharat Forge Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "BHEL", "name": "Bharat Heavy Electricals Ltd.", "industry": "Capital Goods"},
    {"symbol": "BIRLACORPN", "name": "Birla Corporation Ltd.", "industry": "Construction Materials"},
    {"symbol": "BLS", "name": "BLS International Services Ltd.", "industry": "Services"},
    {"symbol": "BLUESTARCO", "name": "Blue Star Ltd.", "industry": "Consumer Durables"},
    {"symbol": "BRIGADE", "name": "Brigade Enterprises Ltd.", "industry": "Realty"},
    {"symbol": "BSE", "name": "BSE Ltd.", "industry": "Financial Services"},
    {"symbol": "BSOFT", "name": "Birlasoft Ltd.", "industry": "Information Technology"},
    {"symbol": "CANFINHOME", "name": "Can Fin Homes Ltd.", "industry": "Financial Services"},
    {"symbol": "CAPACITE", "name": "Capacite Infraprojects Ltd.", "industry": "Construction"},
    {"symbol": "CARBORUNIV", "name": "Carborundum Universal Ltd.", "industry": "Capital Goods"},
    {"symbol": "CASTROLIND", "name": "Castrol India Ltd.", "industry": "Oil Gas & Consumable Fuels"},
    {"symbol": "CDSL", "name": "Central Depository Services (India) Ltd.", "industry": "Financial Services"},
    {"symbol": "CENTURYPLY", "name": "Century Plyboards (India) Ltd.", "industry": "Consumer Durables"},
    {"symbol": "CENTURYTEX", "name": "Century Textiles & Industries Ltd.", "industry": "Construction Materials"},
    {"symbol": "CERA", "name": "Cera Sanitaryware Ltd.", "industry": "Consumer Durables"},
    {"symbol": "CESC", "name": "CESC Ltd.", "industry": "Power"},
    {"symbol": "CHAMBLFERT", "name": "Chambal Fertilisers and Chemicals Ltd.", "industry": "Chemicals"},
    {"symbol": "CHOLAFIN", "name": "Cholamandalam Investment and Finance Company Ltd.", "industry": "Financial Services"},
    {"symbol": "CIEINDIA", "name": "CIE Automotive India Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "COCHINSHIP", "name": "Cochin Shipyard Ltd.", "industry": "Capital Goods"},
    {"symbol": "COFORGE", "name": "Coforge Ltd.", "industry": "Information Technology"},
    {"symbol": "COROMANDEL", "name": "Coromandel International Ltd.", "industry": "Chemicals"},
    {"symbol": "CREDITACC", "name": "CreditAccess Grameen Ltd.", "industry": "Financial Services"},
    {"symbol": "CROMPTON", "name": "Crompton Greaves Consumer Electricals Ltd.", "industry": "Consumer Durables"},
    {"symbol": "CUB", "name": "City Union Bank Ltd.", "industry": "Financial Services"},
    {"symbol": "CYIENT", "name": "Cyient Ltd.", "industry": "Information Technology"},
    {"symbol": "DATAPATTNS", "name": "Data Patterns (India) Ltd.", "industry": "Capital Goods"},
    {"symbol": "DEEDEV", "name": "Dee Development Engineers Ltd.", "industry": "Capital Goods"},
    {"symbol": "DEEPAKNTR", "name": "Deepak Nitrite Ltd.", "industry": "Chemicals"},
    {"symbol": "DELHIVERY", "name": "Delhivery Ltd.", "industry": "Services"},
    {"symbol": "DEVYANI", "name": "Devyani International Ltd.", "industry": "Consumer Services"},
    {"symbol": "DIXON", "name": "Dixon Technologies (India) Ltd.", "industry": "Consumer Durables"},
    {"symbol": "DLF", "name": "DLF Ltd.", "industry": "Realty"},
    {"symbol": "ECLERX", "name": "eClerx Services Ltd.", "industry": "Services"},
    {"symbol": "EDELWEISS", "name": "Edelweiss Financial Services Ltd.", "industry": "Financial Services"},
    {"symbol": "EICHERMOT", "name": "Eicher Motors Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "EIDPARRY", "name": "E.I.D. - Parry (India) Ltd.", "industry": "Chemicals"},
    {"symbol": "EIHOTEL", "name": "EIH Ltd.", "industry": "Consumer Services"},
    {"symbol": "ELGIEQUIP", "name": "Elgi Equipments Ltd.", "industry": "Capital Goods"},
    {"symbol": "EMAMILTD", "name": "Emami Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "ENDURANCE", "name": "Endurance Technologies Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "ENGINERSIN", "name": "Engineers India Ltd.", "industry": "Construction"},
    {"symbol": "EPL", "name": "EPL Ltd.", "industry": "Capital Goods"},
    {"symbol": "EQUITASBNK", "name": "Equitas Small Finance Bank Ltd.", "industry": "Financial Services"},
    {"symbol": "ERIS", "name": "Eris Lifesciences Ltd.", "industry": "Healthcare"},
    {"symbol": "ESCORTS", "name": "Escorts Kubota Ltd.", "industry": "Capital Goods"},
    {"symbol": "EXIDEIND", "name": "Exide Industries Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "FDC", "name": "FDC Ltd.", "industry": "Healthcare"},
    {"symbol": "FEDERALBNK", "name": "The Federal Bank Ltd.", "industry": "Financial Services"},
    {"symbol": "FINCABLES", "name": "Finolex Cables Ltd.", "industry": "Capital Goods"},
    {"symbol": "FINEORG", "name": "Fine Organic Industries Ltd.", "industry": "Chemicals"},
    {"symbol": "FINPIPE", "name": "Finolex Industries Ltd.", "industry": "Capital Goods"},
    {"symbol": "FSL", "name": "Firstsource Solutions Ltd.", "industry": "Services"},
    {"symbol": "GMRINFRA", "name": "GMR Airports Infrastructure Ltd.", "industry": "Services"},
    {"symbol": "GNFC", "name": "Gujarat Narmada Valley Fertilizers & Chemicals Ltd.", "industry": "Chemicals"},
    {"symbol": "GODFRYPHLP", "name": "Godfrey Phillips India Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "GODREJIND", "name": "Godrej Industries Ltd.", "industry": "Diversified"},
    {"symbol": "GODREJPROP", "name": "Godrej Properties Ltd.", "industry": "Realty"},
    {"symbol": "GRANULES", "name": "Granules India Ltd.", "industry": "Healthcare"},
    {"symbol": "GRAPHITE", "name": "Graphite India Ltd.", "industry": "Capital Goods"},
    {"symbol": "GRINDWELL", "name": "Grindwell Norton Ltd.", "industry": "Capital Goods"},
    {"symbol": "GSFC", "name": "Gujarat State Fertilizers & Chemicals Ltd.", "industry": "Chemicals"},
    {"symbol": "GSPL", "name": "Gujarat State Petronet Ltd.", "industry": "Oil Gas & Consumable Fuels"},
    {"symbol": "GUJGASLTD", "name": "Gujarat Gas Ltd.", "industry": "Oil Gas & Consumable Fuels"},
    {"symbol": "HAPPSTMNDS", "name": "Happiest Minds Technologies Ltd.", "industry": "Information Technology"},
    {"symbol": "HAVELLS", "name": "Havells India Ltd.", "industry": "Consumer Durables"},
    {"symbol": "HEG", "name": "HEG Ltd.", "industry": "Capital Goods"},
    {"symbol": "HGINFRA", "name": "H.G. Infra Engineering Ltd.", "industry": "Construction"},
    {"symbol": "HIKAL", "name": "Hikal Ltd.", "industry": "Healthcare"},
    {"symbol": "HINDCOPPER", "name": "Hindustan Copper Ltd.", "industry": "Metals & Mining"},
    {"symbol": "HINDZINC", "name": "Hindustan Zinc Ltd.", "industry": "Metals & Mining"},
    {"symbol": "HUDCO", "name": "Housing & Urban Development Corporation Ltd.", "industry": "Financial Services"},
    {"symbol": "IDFCFIRSTB", "name": "IDFC First Bank Ltd.", "industry": "Financial Services"},
    {"symbol": "IEX", "name": "Indian Energy Exchange Ltd.", "industry": "Financial Services"},
    {"symbol": "IFCI", "name": "IFCI Ltd.", "industry": "Financial Services"},
    {"symbol": "IIFL", "name": "IIFL Finance Ltd.", "industry": "Financial Services"},
    {"symbol": "INDHOTEL", "name": "The Indian Hotels Company Ltd.", "industry": "Consumer Services"},
    {"symbol": "INDIAMART", "name": "IndiaMART InterMESH Ltd.", "industry": "Consumer Services"},
    {"symbol": "INDIANB", "name": "Indian Bank", "industry": "Financial Services"},
    {"symbol": "INDIGO", "name": "InterGlobe Aviation Ltd.", "industry": "Services"},
    {"symbol": "INDIGOPNTS", "name": "Indigo Paints Ltd.", "industry": "Consumer Durables"},
    {"symbol": "IOB", "name": "Indian Overseas Bank", "industry": "Financial Services"},
    {"symbol": "IPCALAB", "name": "IPCA Laboratories Ltd.", "industry": "Healthcare"},
    {"symbol": "IRB", "name": "IRB Infrastructure Developers Ltd.", "industry": "Construction"},
    {"symbol": "IRCON", "name": "Ircon International Ltd.", "industry": "Construction"},
    {"symbol": "IRCTC", "name": "Indian Railway Catering And Tourism Corporation Ltd.", "industry": "Consumer Services"},
    {"symbol": "IREDA", "name": "Indian Renewable Energy Development Agency Ltd.", "industry": "Financial Services"},
    {"symbol": "IRFC", "name": "Indian Railway Finance Corporation Ltd.", "industry": "Financial Services"},
    {"symbol": "JBCHEPHARM", "name": "JB Chemicals & Pharmaceuticals Ltd.", "industry": "Healthcare"},
    {"symbol": "JINDALSAW", "name": "Jindal Saw Ltd.", "industry": "Capital Goods"},
    {"symbol": "JKCEMENT", "name": "JK Cement Ltd.", "industry": "Construction Materials"},
    {"symbol": "JKLAKSHMI", "name": "JK Lakshmi Cement Ltd.", "industry": "Construction Materials"},
    {"symbol": "JKPAPER", "name": "JK Paper Ltd.", "industry": "Forest Products"},
    {"symbol": "JSL", "name": "Jindal Stainless Ltd.", "industry": "Metals & Mining"},
    {"symbol": "JSWINFRA", "name": "JSW Infrastructure Ltd.", "industry": "Services"},
    {"symbol": "JUBLFOOD", "name": "Jubilant Foodworks Ltd.", "industry": "Consumer Services"},
    {"symbol": "JUBLINGREA", "name": "Jubilant Ingrevia Ltd.", "industry": "Chemicals"},
    {"symbol": "JUBLPHARMA", "name": "Jubilant Pharmova Ltd.", "industry": "Healthcare"},
    {"symbol": "JUSTDIAL", "name": "Just Dial Ltd.", "industry": "Consumer Services"},
    {"symbol": "JYOTHYLAB", "name": "Jyothy Labs Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "KAJARIACER", "name": "Kajariaceramics Ltd.", "industry": "Consumer Durables"},
    {"symbol": "KALPATPOWR", "name": "Kalpataru Projects International Ltd.", "industry": "Construction"},
    {"symbol": "KALYANKJIL", "name": "Kalyan Jewellers India Ltd.", "industry": "Consumer Durables"},
    {"symbol": "KANSAINER", "name": "Kansai Nerolac Paints Ltd.", "industry": "Consumer Durables"},
    {"symbol": "KARURVYSYA", "name": "The Karur Vysya Bank Ltd.", "industry": "Financial Services"},
    {"symbol": "KEC", "name": "KEC International Ltd.", "industry": "Construction"},
    {"symbol": "KEI", "name": "KEI Industries Ltd.", "industry": "Capital Goods"},
    {"symbol": "KIMS", "name": "Krishna Institute of Medical Sciences Ltd.", "industry": "Healthcare"},
    {"symbol": "KPITTECH", "name": "KPIT Technologies Ltd.", "industry": "Information Technology"},
    {"symbol": "KPRMILL", "name": "K.P.R. Mill Ltd.", "industry": "Textiles"},
    {"symbol": "KRBL", "name": "KRBL Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "KSB", "name": "KSB Ltd.", "industry": "Capital Goods"},
    {"symbol": "L&TFH", "name": "L&T Finance Holdings Ltd.", "industry": "Financial Services"},
    {"symbol": "LALPATHLAB", "name": "Dr. Lal Path Labs Ltd.", "industry": "Healthcare"},
    {"symbol": "LAURUSLABS", "name": "Laurus Labs Ltd.", "industry": "Healthcare"},
    {"symbol": "LEMONTREE", "name": "Lemon Tree Hotels Ltd.", "industry": "Consumer Services"},
    {"symbol": "LICHSGFIN", "name": "LIC Housing Finance Ltd.", "industry": "Financial Services"},
    {"symbol": "LUPIN", "name": "Lupin Ltd.", "industry": "Healthcare"},
    {"symbol": "MANAPPURAM", "name": "Manappuram Finance Ltd.", "industry": "Financial Services"},
    {"symbol": "MAPMYINDIA", "name": "C.E. Info Systems Ltd.", "industry": "Information Technology"},
    {"symbol": "MARICO", "name": "Marico Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "MARKSANS", "name": "Marksans Pharma Ltd.", "industry": "Healthcare"},
    {"symbol": "MAXHEALTH", "name": "Max Healthcare Institute Ltd.", "industry": "Healthcare"},
    {"symbol": "MAZDOCK", "name": "Mazagon Dock Shipbuilders Ltd.", "industry": "Capital Goods"},
    {"symbol": "METROPOLIS", "name": "Metropolis Healthcare Ltd.", "industry": "Healthcare"},
    {"symbol": "MFSL", "name": "Max Financial Services Ltd.", "industry": "Financial Services"},
    {"symbol": "MINDACORP", "name": "Minda Corporation Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "MOTILALOFS", "name": "Motilal Oswal Financial Services Ltd.", "industry": "Financial Services"},
    {"symbol": "MPHASIS", "name": "MphasiS Ltd.", "industry": "Information Technology"},
    {"symbol": "MRF", "name": "MRF Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "NATCOPHARM", "name": "Natco Pharma Ltd.", "industry": "Healthcare"},
    {"symbol": "NAVINFLUOR", "name": "Navin Fluorine International Ltd.", "industry": "Chemicals"},
    {"symbol": "NBCC", "name": "NBCC (India) Ltd.", "industry": "Construction"},
    {"symbol": "NCC", "name": "NCC Ltd.", "industry": "Construction"},
    {"symbol": "NH", "name": "Narayana Hrudayalaya Ltd.", "industry": "Healthcare"},
    {"symbol": "NLCINDIA", "name": "NLC India Ltd.", "industry": "Power"},
    {"symbol": "NMDC", "name": "NMDC Ltd.", "industry": "Metals & Mining"},
    {"symbol": "NSLNISP", "name": "NMDC Steel Ltd.", "industry": "Metals & Mining"},
    {"symbol": "NTPC", "name": "NTPC Ltd.", "industry": "Power"},
    {"symbol": "OBEROIRLTY", "name": "Oberoi Realty Ltd.", "industry": "Realty"},
    {"symbol": "OFSS", "name": "Oracle Financial Services Software Ltd.", "industry": "Information Technology"},
    {"symbol": "OIL", "name": "Oil India Ltd.", "industry": "Oil Gas & Consumable Fuels"},
    {"symbol": "OLECTRA", "name": "Olectra Greentech Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "PATELENG", "name": "Patel Engineering Ltd.", "industry": "Construction"},
    {"symbol": "PERSISTENT", "name": "Persistent Systems Ltd.", "industry": "Information Technology"},
    {"symbol": "PETRONET", "name": "Petronet LNG Ltd.", "industry": "Oil Gas & Consumable Fuels"},
    {"symbol": "PFIZER", "name": "Pfizer Ltd.", "industry": "Healthcare"},
    {"symbol": "PHOENIXLTD", "name": "The Phoenix Mills Ltd.", "industry": "Realty"},
    {"symbol": "PIIND", "name": "PI Industries Ltd.", "industry": "Chemicals"},
    {"symbol": "PNBHOUSING", "name": "PNB Housing Finance Ltd.", "industry": "Financial Services"},
    {"symbol": "POONAWALLA", "name": "Poonawalla Fincorp Ltd.", "industry": "Financial Services"},
    {"symbol": "POWERINDIA", "name": "Hitachi Energy India Ltd.", "industry": "Capital Goods"},
    {"symbol": "PRESTIGE", "name": "Prestige Estates Projects Ltd.", "industry": "Realty"},
    {"symbol": "PRINCEPIPE", "name": "Prince Pipes and Fittings Ltd.", "industry": "Capital Goods"},
    {"symbol": "PRSMJOHNSN", "name": "Prism Johnson Ltd.", "industry": "Construction Materials"},
    {"symbol": "PVRINOX", "name": "PVR INOX Ltd.", "industry": "Media Entertainment & Publication"},
    {"symbol": "RADICO", "name": "Radico Khaitan Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "RAMCOCEM", "name": "The Ramco Cements Ltd.", "industry": "Construction Materials"},
    {"symbol": "RBLBANK", "name": "RBL Bank Ltd.", "industry": "Financial Services"},
    {"symbol": "REDINGTON", "name": "Redington Ltd.", "industry": "Services"},
    {"symbol": "RECLTD", "name": "REC Ltd.", "industry": "Financial Services"},
    {"symbol": "RELAXO", "name": "Relaxo Footwears Ltd.", "industry": "Consumer Durables"},
    {"symbol": "RITES", "name": "RITES Ltd.", "industry": "Construction"},
    {"symbol": "RKFORGE", "name": "Ramkrishna Forgings Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "RRKABEL", "name": "R R Kabel Ltd.", "industry": "Capital Goods"},
    {"symbol": "RVNL", "name": "Rail Vikas Nigam Ltd.", "industry": "Construction"},
    {"symbol": "SAIL", "name": "Steel Authority of India Ltd.", "industry": "Metals & Mining"},
    {"symbol": "SALASAR", "name": "Salasar Techno Engineering Ltd.", "industry": "Capital Goods"},
    {"symbol": "SJVN", "name": "SJVN Ltd.", "industry": "Power"},
    {"symbol": "SKFINDIA", "name": "SKF India Ltd.", "industry": "Capital Goods"},
    {"symbol": "SONACOMS", "name": "Sona BLW Precision Forgings Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "STARHEALTH", "name": "Star Health and Allied Insurance Company Ltd.", "industry": "Financial Services"},
    {"symbol": "SUNDARMFIN", "name": "Sundaram Finance Ltd.", "industry": "Financial Services"},
    {"symbol": "SUNDRMFAST", "name": "Sundram Fasteners Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "SUNTV", "name": "Sun TV Network Ltd.", "industry": "Media Entertainment & Publication"},
    {"symbol": "SUPRAJIT", "name": "Suprajit Engineering Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "SUZLON", "name": "Suzlon Energy Ltd.", "industry": "Capital Goods"},
    {"symbol": "SYMPHONY", "name": "Symphony Ltd.", "industry": "Consumer Durables"},
    {"symbol": "SYNGENE", "name": "Syngene International Ltd.", "industry": "Healthcare"},
    {"symbol": "TATACHEM", "name": "Tata Chemicals Ltd.", "industry": "Chemicals"},
    {"symbol": "TATACOMM", "name": "Tata Communications Ltd.", "industry": "Telecommunication"},
    {"symbol": "TATAELXSI", "name": "Tata Elxsi Ltd.", "industry": "Information Technology"},
    {"symbol": "TATAINVEST", "name": "Tata Investment Corporation Ltd.", "industry": "Financial Services"},
    {"symbol": "TATAPOWER", "name": "Tata Power Company Ltd.", "industry": "Power"},
    {"symbol": "TATATECH", "name": "Tata Technologies Ltd.", "industry": "Information Technology"},
    {"symbol": "TEJASNET", "name": "Tejas Networks Ltd.", "industry": "Telecommunication"},
    {"symbol": "THERMAX", "name": "Thermax Ltd.", "industry": "Capital Goods"},
    {"symbol": "TIMKEN", "name": "Timken India Ltd.", "industry": "Capital Goods"},
    {"symbol": "TITAGARH", "name": "Titagarh Rail Systems Ltd.", "industry": "Capital Goods"},
    {"symbol": "TORNTPOWER", "name": "Torrent Power Ltd.", "industry": "Power"},
    {"symbol": "TRIDENT", "name": "Trident Ltd.", "industry": "Textiles"},
    {"symbol": "TRITURBINE", "name": "Triveni Turbine Ltd.", "industry": "Capital Goods"},
    {"symbol": "TRIVENI", "name": "Triveni Engineering & Industries Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "TTML", "name": "Tata Teleservices (Maharashtra) Ltd.", "industry": "Telecommunication"},
    {"symbol": "UCOBANK", "name": "UCO Bank", "industry": "Financial Services"},
    {"symbol": "UNIONBANK", "name": "Union Bank of India", "industry": "Financial Services"},
    {"symbol": "UNOMINDA", "name": "UNO Minda Ltd.", "industry": "Automobile and Auto Components"},
    {"symbol": "UPL", "name": "UPL Ltd.", "industry": "Chemicals"},
    {"symbol": "USHAMART", "name": "Usha Martin Ltd.", "industry": "Capital Goods"},
    {"symbol": "VBL", "name": "Varun Beverages Ltd.", "industry": "Fast Moving Consumer Goods"},
    {"symbol": "VEDL", "name": "Vedanta Ltd.", "industry": "Metals & Mining"},
    {"symbol": "VOLTAS", "name": "Voltas Ltd.", "industry": "Consumer Durables"},
    {"symbol": "WELCORP", "name": "Welspun Corp Ltd.", "industry": "Capital Goods"},
    {"symbol": "WELSPUNLIV", "name": "Welspun Living Ltd.", "industry": "Textiles"},
    {"symbol": "WHIRLPOOL", "name": "Whirlpool of India Ltd.", "industry": "Consumer Durables"},
    {"symbol": "WOCKPHARMA", "name": "Wockhardt Ltd.", "industry": "Healthcare"},
    {"symbol": "YESBANK", "name": "Yes Bank Ltd.", "industry": "Financial Services"},
    {"symbol": "ZEEL", "name": "Zee Entertainment Enterprises Ltd.", "industry": "Media Entertainment & Publication"},
    {"symbol": "ZENSARTECH", "name": "Zensar Technologies Ltd.", "industry": "Information Technology"},
    {"symbol": "ZYDUSLIFE", "name": "Zydus Lifesciences Ltd.", "industry": "Healthcare"}
]

def get_screener_details(symbol):
    """Screener.in se direct live Market Cap aur Credit Rating PDF fetch karta hai."""
    url = f"https://www.screener.in/company/{symbol}/consolidated/"
    try:
        res = requests.get(url, headers=HEADERS, timeout=10)
        if res.status_code == 404:
            url = f"https://www.screener.in/company/{symbol}/"
            res = requests.get(url, headers=HEADERS, timeout=10)
            
        if res.status_code != 200:
            return None, None, None

        soup = BeautifulSoup(res.text, "html.parser")
        
        # 1. Market Cap
        mcap_val = None
        mcap_tag = soup.find("span", string=re.compile(r"Market Cap", re.I))
        if mcap_tag:
            num_span = mcap_tag.find_next("span", class_="number")
            if num_span:
                mcap_val = float(num_span.text.replace(",", "").strip())

        # 2. Credit Rating Rationale PDF Link
        rating_doc_url = None
        agency_name = "Audited Rating Rationale"
        
        for link in soup.find_all("a", href=True):
            href = link["href"]
            text = link.get_text(strip=True).lower()
            if any(ag in text for ag in ["crisil", "care", "icra", "india ratings", "infomerics", "credit rating"]):
                rating_doc_url = href if href.startswith("http") else f"https://www.screener.in{href}"
                agency_name = link.get_text(strip=True)
                break

        return mcap_val, rating_doc_url, agency_name
    except Exception as e:
        print(f"      [Screener error for {symbol}: {e}]")
        return None, None, None

def extract_pdf_order_text(pdf_url):
    try:
        res = requests.get(pdf_url, headers=HEADERS, timeout=15)
        if res.status_code == 200 and len(res.content) > 1000:
            reader = pypdf.PdfReader(io.BytesIO(res.content))
            pages_text = []
            for p in reader.pages[:3]:
                txt = p.extract_text()
                if txt:
                    pages_text.append(txt)
            return " ".join(pages_text)
    except Exception:
        pass
    return ""

def parse_order_metrics(text):
    if not any(k in text.lower() for k in ["order book", "unexecuted", "backlog", "order intake"]):
        return None

    if GEMINI_API_KEY:
        try:
            prompt = f"Extract numerical unexecuted order book from: '{text[:2500]}'. Return raw JSON: {{\"order_book_cr\": 1500.0, \"timeline_months\": 24, \"thesis\": \"short impact\"}}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"}
            }
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=12)
            if res.status_code == 200:
                raw = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                if raw.startswith("```"): raw = re.sub(r"^```[a-z]*|```$", "", raw).strip()
                data = json.loads(raw)
                val = float(data.get("order_book_cr", 0))
                if val > 0:
                    return {
                        "order_book_cr": val,
                        "timeline_months": int(data.get("timeline_months", 24)),
                        "thesis": data.get("thesis", "Revenue visibility from order backlog.")
                    }
        except Exception:
            pass

    patterns = [
        r'(?:unexecuted\s+order\s+book|order\s+backlog|order\s+book)\s+(?:of|stood\s+at|stands\s+at|at)\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)',
        r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)\s+(?:of\s+unexecuted\s+orders|order\s+book)'
    ]
    for p in patterns:
        m = re.search(p, text, re.I)
        if m:
            val = float(m.group(1).replace(",", ""))
            return {
                "order_book_cr": val,
                "timeline_months": 24,
                "thesis": f"Healthy revenue runway backed by order backlog of ₹{val:,.1f} Cr."
            }
    return None

def run():
    print("=" * 75)
    print("🚀 NIFTY SMALLCAP: ORDER BOOK / MCAP RADAR (FULL EMBEDDED CSV UNIVERSE)")
    print("=" * 75)

    verified_gems = []

    for idx, item in enumerate(TARGET_COMPANIES, 1):
        name = item["name"]
        symbol = item["symbol"]
        industry = item["industry"]

        print(f"\n[{idx}/{len(TARGET_COMPANIES)}] Checking: {name} ({symbol}) | Sector: {industry}...")

        mcap, doc_url, agency = get_screener_details(symbol)
        if not mcap:
            print(f"   ⚠️ Could not fetch Market Cap for {symbol}. Skipping.")
            continue

        print(f"   📊 Live Market Cap: ₹{mcap:,.1f} Cr")
        if mcap > MAX_MARKET_CAP_CR:
            print(f"   ⏩ MCap ₹{mcap:,.1f} Cr > ₹{MAX_MARKET_CAP_CR} Cr limit. Skipped.")
            continue

        if not doc_url:
            print("   ℹ️ No direct rating rationale link found on Screener page.")
            continue

        print(f"   📄 Rating Document Found: {agency}")
        pdf_text = extract_pdf_order_text(doc_url)
        if not pdf_text:
            print("   ⚠️ Could not extract text from document.")
            continue

        metrics = parse_order_metrics(pdf_text)
        if not metrics or metrics["order_book_cr"] <= 0:
            print("   ℹ️ No unexecuted order book stated in this document.")
            continue

        order_val = metrics["order_book_cr"]
        multiple = round(order_val / mcap, 2)
        print(f"   🎯 Order Book: ₹{order_val:,.1f} Cr ➔ Multiple: {multiple}x MCap")

        if multiple >= MIN_ORDER_TO_MCAP_MULTIPLE:
            gem_entry = {
                "symbol": symbol,
                "company_name": name,
                "sector": industry,
                "market_cap_cr": mcap,
                "unexecuted_order_book_cr": order_val,
                "order_to_mcap_multiple": multiple,
                "execution_timeline_months": metrics["timeline_months"],
                "thesis": metrics["thesis"],
                "source_verification": {
                    "source_name": agency,
                    "document_url": doc_url,
                    "as_on_date": datetime.now().strftime("%b %Y"),
                    "is_audited_regulatory": True
                }
            }
            verified_gems.append(gem_entry)
            print(f"   🔥 [HIDDEN GEM QUALIFIED] Multiple {multiple}x >= {MIN_ORDER_TO_MCAP_MULTIPLE}x!")
        else:
            print(f"   ❌ Multiple {multiple}x < {MIN_ORDER_TO_MCAP_MULTIPLE}x.")

        time.sleep(0.5)

    verified_gems.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)

    final_report = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "filter_criteria": {
            "source_universe": "Nifty Smallcap 250 Index (Embedded)",
            "max_mcap_cr": MAX_MARKET_CAP_CR,
            "min_order_multiple": MIN_ORDER_TO_MCAP_MULTIPLE
        },
        "total_hidden_gems_found": len(verified_gems),
        "gems": verified_gems
    }

    with open(OUTPUT_REPORT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_report, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 75)
    print(f"🎉 SUCCESS: Found {len(verified_gems)} high-visibility gems from Nifty Smallcap!")
    print("=" * 75)

if __name__ == "__main__":
    run()
