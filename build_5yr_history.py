import os
import json
import time
import base64
from datetime import datetime
import requests

OUTPUT_FILE = "historical_5yr_ohlc.json"

TARGET_REPO = "zxcty54/stock-crypto-tracker"
TARGET_FILE_PATH = "historical_5yr_ohlc.json"
TARGET_BRANCH = "main"

# Nifty Smallcap 250 Stocks List
STOCKS_LIST = [
    {"symbol": "ACC", "name": "ACC Ltd.", "sector": "Construction Materials"},
    {"symbol": "ACMESOLAR", "name": "ACME Solar Holdings Ltd.", "sector": "Power"},
    {"symbol": "AWL", "name": "AWL Agri Business Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "AADHARHFC", "name": "Aadhar Housing Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "AARTIIND", "name": "Aarti Industries Ltd.", "sector": "Chemicals"},
    {"symbol": "AAVAS", "name": "Aavas Financiers Ltd.", "sector": "Financial Services"},
    {"symbol": "ACE", "name": "Action Construction Equipment Ltd.", "sector": "Capital Goods"},
    {"symbol": "ACUTAAS", "name": "Acutaas Chemicals Ltd.", "sector": "Chemicals"},
    {"symbol": "ABREL", "name": "Aditya Birla Real Estate Ltd.", "sector": "Realty"},
    {"symbol": "ABSLAMC", "name": "Aditya Birla Sun Life AMC Ltd.", "sector": "Financial Services"},
    {"symbol": "AEGISLOG", "name": "Aegis Logistics Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "AFFLE", "name": "Affle (India) Ltd.", "sector": "Information Technology"},
    {"symbol": "AJANTPHARM", "name": "Ajanta Pharma Ltd.", "sector": "Healthcare"},
    {"symbol": "AKUMS", "name": "Akums Drugs and Pharmaceuticals Ltd.", "sector": "Healthcare"},
    {"symbol": "ALOKINDS", "name": "Alok Industries Ltd.", "sector": "Textiles"},
    {"symbol": "AMBER", "name": "Amber Enterprises India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "ANANDRATHI", "name": "Anand Rathi Wealth Ltd.", "sector": "Financial Services"},
    {"symbol": "ANANTRAJ", "name": "Anant Raj Ltd.", "sector": "Realty"},
    {"symbol": "ANGELONE", "name": "Angel One Ltd.", "sector": "Financial Services"},
    {"symbol": "APARINDS", "name": "Apar Industries Ltd.", "sector": "Capital Goods"},
    {"symbol": "APLLTD", "name": "Alembic Pharmaceuticals Ltd.", "sector": "Healthcare"},
    {"symbol": "APPUS", "name": "Appus Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "APTUS", "name": "Aptus Value Housing Finance India Ltd.", "sector": "Financial Services"},
    {"symbol": "ARE&M", "name": "Amara Raja Energy & Mobility Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "ASAHIINDIA", "name": "Asahi India Glass Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "ASHOKLEY", "name": "Ashok Leyland Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "ASTERDM", "name": "Aster DM Healthcare Ltd.", "sector": "Healthcare"},
    {"symbol": "ASTRAL", "name": "Astral Ltd.", "sector": "Capital Goods"},
    {"symbol": "ASTRAZEN", "name": "AstraZeneca Pharma India Ltd.", "sector": "Healthcare"},
    {"symbol": "ATUL", "name": "Atul Ltd.", "sector": "Chemicals"},
    {"symbol": "AUBANK", "name": "AU Small Finance Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "AUROPHARMA", "name": "Aurobindo Pharma Ltd.", "sector": "Healthcare"},
    {"symbol": "AVANTIFEED", "name": "Avanti Feeds Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "BAJAJELEC", "name": "Bajaj Electricals Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BALAMINES", "name": "Balaji Amines Ltd.", "sector": "Chemicals"},
    {"symbol": "BALKRISIND", "name": "Balkrishna Industries Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "BALRAMCHIN", "name": "Balrampur Chini Mills Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "BANDHANBNK", "name": "Bandhan Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "BANKINDIA", "name": "Bank of India", "sector": "Financial Services"},
    {"symbol": "BATAINDIA", "name": "Bata India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BAYERCROP", "name": "Bayer Cropscience Ltd.", "sector": "Chemicals"},
    {"symbol": "BDL", "name": "Bharat Dynamics Ltd.", "sector": "Capital Goods"},
    {"symbol": "BERGEPAINT", "name": "Berger Paints India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BHARATFORG", "name": "Bharat Forge Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "BBL", "name": "Bharat Bijlee Ltd.", "sector": "Capital Goods"},
    {"symbol": "BIOCON", "name": "Biocon Ltd.", "sector": "Healthcare"},
    {"symbol": "BIRLACORPN", "name": "Birla Corporation Ltd.", "sector": "Construction Materials"},
    {"symbol": "BLS", "name": "BLS International Services Ltd.", "sector": "Consumer Services"},
    {"symbol": "BLUEDART", "name": "Blue Dart Express Ltd.", "sector": "Services"},
    {"symbol": "BLUESTARCO", "name": "Blue Star Ltd.", "sector": "Consumer Durables"},
    {"symbol": "BSOFT", "name": "Birlasoft Ltd.", "sector": "Information Technology"},
    {"symbol": "CAMPUS", "name": "Campus Activewear Ltd.", "sector": "Consumer Durables"},
    {"symbol": "CAMS", "name": "Computer Age Management Services Ltd.", "sector": "Financial Services"},
    {"symbol": "CANFINHOME", "name": "Can Fin Homes Ltd.", "sector": "Financial Services"},
    {"symbol": "CAPL", "name": "Caplin Point Laboratories Ltd.", "sector": "Healthcare"},
    {"symbol": "CARBORUNIV", "name": "Carborundum Universal Ltd.", "sector": "Capital Goods"},
    {"symbol": "CASTROLIND", "name": "Castrol India Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "CEATLTD", "name": "CEAT Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "CENTRALBK", "name": "Central Bank of India", "sector": "Financial Services"},
    {"symbol": "CENTURYPLY", "name": "Century Plyboards (India) Ltd.", "sector": "Consumer Durables"},
    {"symbol": "CENTURYTEX", "name": "Century Textiles & Industries Ltd.", "sector": "Realty"},
    {"symbol": "CERA", "name": "Cera Sanitaryware Ltd.", "sector": "Consumer Durables"},
    {"symbol": "CESC", "name": "CESC Ltd.", "sector": "Power"},
    {"symbol": "CGCL", "name": "Capri Global Capital Ltd.", "sector": "Financial Services"},
    {"symbol": "CHAMBLFERT", "name": "Chambal Fertilisers and Chemicals Ltd.", "sector": "Chemicals"},
    {"symbol": "CHEMPLASTS", "name": "Chemplast Sanmar Ltd.", "sector": "Chemicals"},
    {"symbol": "CHOLAHLDNG", "name": "Cholamandalam Financial Holdings Ltd.", "sector": "Financial Services"},
    {"symbol": "CLEAN", "name": "Clean Science and Technology Ltd.", "sector": "Chemicals"},
    {"symbol": "COCHINSHIP", "name": "Cochin Shipyard Ltd.", "sector": "Capital Goods"},
    {"symbol": "CONCOR", "name": "Container Corporation of India Ltd.", "sector": "Services"},
    {"symbol": "COROMANDEL", "name": "Coromandel International Ltd.", "sector": "Chemicals"},
    {"symbol": "CREDITACC", "name": "CreditAccess Grameen Ltd.", "sector": "Financial Services"},
    {"symbol": "CROMPTON", "name": "Crompton Greaves Consumer Electricals Ltd.", "sector": "Consumer Durables"},
    {"symbol": "CUB", "name": "City Union Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "CYIENT", "name": "Cyient Ltd.", "sector": "Information Technology"},
    {"symbol": "DATAPATTNS", "name": "Data Patterns (India) Ltd.", "sector": "Capital Goods"},
    {"symbol": "DCMSHRIRAM", "name": "DCM Shriram Ltd.", "sector": "Diversified"},
    {"symbol": "DEEPAKFERT", "name": "Deepak Fertilisers and Petrochemicals Corp. Ltd.", "sector": "Chemicals"},
    {"symbol": "DEEPAKNTR", "name": "Deepak Nitrite Ltd.", "sector": "Chemicals"},
    {"symbol": "DELHIVERY", "name": "Delhivery Ltd.", "sector": "Services"},
    {"symbol": "DEVYANI", "name": "Devyani International Ltd.", "sector": "Consumer Services"},
    {"symbol": "DHANI", "name": "Dhani Services Ltd.", "sector": "Financial Services"},
    {"symbol": "EIDPARRY", "name": "E.I.D. Parry (India) Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "EIHOTEL", "name": "EIH Ltd.", "sector": "Consumer Services"},
    {"symbol": "ELECON", "name": "Elecon Engineering Co. Ltd.", "sector": "Capital Goods"},
    {"symbol": "ELGIEQUIP", "name": "Elgi Equipments Ltd.", "sector": "Capital Goods"},
    {"symbol": "EMAMILTD", "name": "Emami Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "ENDURANCE", "name": "Endurance Technologies Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "ENGINERSIN", "name": "Engineers India Ltd.", "sector": "Construction"},
    {"symbol": "EPL", "name": "EPL Ltd.", "sector": "Capital Goods"},
    {"symbol": "EQUITASBNK", "name": "Equitas Small Finance Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "ERIS", "name": "Eris Lifesciences Ltd.", "sector": "Healthcare"},
    {"symbol": "ESCORTS", "name": "Escorts Kubota Ltd.", "sector": "Capital Goods"},
    {"symbol": "EXIDEIND", "name": "Exide Industries Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "FDC", "name": "FDC Ltd.", "sector": "Healthcare"},
    {"symbol": "FEDERALBNK", "name": "The Federal Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "FINCABLES", "name": "Finolex Cables Ltd.", "sector": "Capital Goods"},
    {"symbol": "FINEORG", "name": "Fine Organic Industries Ltd.", "sector": "Chemicals"},
    {"symbol": "FINPIPE", "name": "Finolex Industries Ltd.", "sector": "Capital Goods"},
    {"symbol": "FSL", "name": "Firstsource Solutions Ltd.", "sector": "Information Technology"},
    {"symbol": "GICRE", "name": "General Insurance Corporation of India", "sector": "Financial Services"},
    {"symbol": "GLAXO", "name": "GlaxoSmithKline Pharmaceuticals Ltd.", "sector": "Healthcare"},
    {"symbol": "GLENMARK", "name": "Glenmark Pharmaceuticals Ltd.", "sector": "Healthcare"},
    {"symbol": "GNFC", "name": "Gujarat Narmada Valley Fertilizers and Chemicals Ltd.", "sector": "Chemicals"},
    {"symbol": "GODFRYPHLP", "name": "Godfrey Phillips India Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "GODREJIND", "name": "Godrej Industries Ltd.", "sector": "Diversified"},
    {"symbol": "GODREJPROP", "name": "Godrej Properties Ltd.", "sector": "Realty"},
    {"symbol": "GPIL", "name": "Godawari Power and Ispat Ltd.", "sector": "Metals & Mining"},
    {"symbol": "GRAVITA", "name": "Gravita India Ltd.", "sector": "Metals & Mining"},
    {"symbol": "GRINDWELL", "name": "Grindwell Norton Ltd.", "sector": "Capital Goods"},
    {"symbol": "GSFC", "name": "Gujarat State Fertilizers & Chemicals Ltd.", "sector": "Chemicals"},
    {"symbol": "GSPL", "name": "Gujarat State Petronet Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "GUJGASLTD", "name": "Gujarat Gas Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "HAPPSTMNDS", "name": "Happiest Minds Technologies Ltd.", "sector": "Information Technology"},
    {"symbol": "HEG", "name": "HEG Ltd.", "sector": "Capital Goods"},
    {"symbol": "HFCL", "name": "HFCL Ltd.", "sector": "Telecommunication"},
    {"symbol": "HGS", "name": "Hinduja Global Solutions Ltd.", "sector": "Information Technology"},
    {"symbol": "HONAUT", "name": "Honeywell Automation India Ltd.", "sector": "Capital Goods"},
    {"symbol": "HUDCO", "name": "Housing & Urban Development Corporation Ltd.", "sector": "Financial Services"},
    {"symbol": "IDBI", "name": "IDBI Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "IDFCFIRSTB", "name": "IDFC First Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "IEX", "name": "Indian Energy Exchange Ltd.", "sector": "Financial Services"},
    {"symbol": "IFCI", "name": "IFCI Ltd.", "sector": "Financial Services"},
    {"symbol": "IIFL", "name": "IIFL Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "INDGN", "name": "Indegene Ltd.", "sector": "Healthcare"},
    {"symbol": "INDIACEM", "name": "The India Cements Ltd.", "sector": "Construction Materials"},
    {"symbol": "INDIAMART", "name": "IndiaMART InterMESH Ltd.", "sector": "Consumer Services"},
    {"symbol": "INDIANB", "name": "Indian Bank", "sector": "Financial Services"},
    {"symbol": "INDIGO", "name": "InterGlobe Aviation Ltd.", "sector": "Services"},
    {"symbol": "INDOCO", "name": "Indoco Remedies Ltd.", "sector": "Healthcare"},
    {"symbol": "IOB", "name": "Indian Overseas Bank", "sector": "Financial Services"},
    {"symbol": "IPCALAB", "name": "IPCA Laboratories Ltd.", "sector": "Healthcare"},
    {"symbol": "IRB", "name": "IRB Infrastructure Developers Ltd.", "sector": "Construction"},
    {"symbol": "IRCON", "name": "Ircon International Ltd.", "sector": "Construction"},
    {"symbol": "ISEC", "name": "ICICI Securities Ltd.", "sector": "Financial Services"},
    {"symbol": "ITI", "name": "ITI Ltd.", "sector": "Telecommunication"},
    {"symbol": "JBCHEPHARM", "name": "JB Chemicals & Pharmaceuticals Ltd.", "sector": "Healthcare"},
    {"symbol": "JKCEMENT", "name": "JK Cement Ltd.", "sector": "Construction Materials"},
    {"symbol": "JKPAPER", "name": "JK Paper Ltd.", "sector": "Forest Materials"},
    {"symbol": "JSL", "name": "Jindal Stainless Ltd.", "sector": "Metals & Mining"},
    {"symbol": "JUBLFOOD", "name": "Jubilant FoodWorks Ltd.", "sector": "Consumer Services"},
    {"symbol": "JUBLINGREA", "name": "Jubilant Ingrevia Ltd.", "sector": "Chemicals"},
    {"symbol": "JUBLPHARMA", "name": "Jubilant Pharmova Ltd.", "sector": "Healthcare"},
    {"symbol": "JUSTDIAL", "name": "Just Dial Ltd.", "sector": "Consumer Services"},
    {"symbol": "JYOTHYLAB", "name": "Jyothy Labs Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "KAJARIACER", "name": "Kajariacera Ltd.", "sector": "Consumer Durables"},
    {"symbol": "KALPATPOWR", "name": "Kalpataru Projects International Ltd.", "sector": "Construction"},
    {"symbol": "KALYANKJIL", "name": "Kalyan Jewellers India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "KANSAINER", "name": "Kansai Nerolac Paints Ltd.", "sector": "Consumer Durables"},
    {"symbol": "KARURVYSYA", "name": "Karur Vysya Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "KEC", "name": "KEC International Ltd.", "sector": "Construction"},
    {"symbol": "KEI", "name": "KEI Industries Ltd.", "sector": "Capital Goods"},
    {"symbol": "KIMS", "name": "Krishna Institute of Medical Sciences Ltd.", "sector": "Healthcare"},
    {"symbol": "KPITTECH", "name": "KPIT Technologies Ltd.", "sector": "Information Technology"},
    {"symbol": "KRBL", "name": "KRBL Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "KSB", "name": "KSB Ltd.", "sector": "Capital Goods"},
    {"symbol": "LALPATHLAB", "name": "Dr. Lal Path Labs Ltd.", "sector": "Healthcare"},
    {"symbol": "LAURUSLABS", "name": "Laurus Labs Ltd.", "sector": "Healthcare"},
    {"symbol": "LEMONTREE", "name": "Lemon Tree Hotels Ltd.", "sector": "Consumer Services"},
    {"symbol": "LICHSGFIN", "name": "LIC Housing Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "LINDEINDIA", "name": "Linde India Ltd.", "sector": "Chemicals"},
    {"symbol": "LLOYDSME", "name": "Lloyds Metals and Energy Ltd.", "sector": "Metals & Mining"},
    {"symbol": "LTF", "name": "L&T Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "LTIM", "name": "LTIMindtree Ltd.", "sector": "Information Technology"},
    {"symbol": "LTTS", "name": "L&T Technology Services Ltd.", "sector": "Information Technology"},
    {"symbol": "MANAPPURAM", "name": "Manappuram Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "MAPMYINDIA", "name": "C.E. Info Systems Ltd.", "sector": "Information Technology"},
    {"symbol": "MARICO", "name": "Marico Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "MASTEK", "name": "Mastek Ltd.", "sector": "Information Technology"},
    {"symbol": "MEDANTA", "name": "Global Health Ltd.", "sector": "Healthcare"},
    {"symbol": "METROPOLIS", "name": "Metropolis Healthcare Ltd.", "sector": "Healthcare"},
    {"symbol": "MFSL", "name": "Max Financial Services Ltd.", "sector": "Financial Services"},
    {"symbol": "MGL", "name": "Mahanagar Gas Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "MINDACORP", "name": "Minda Corporation Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "MOTILALOFS", "name": "Motilal Oswal Financial Services Ltd.", "sector": "Financial Services"},
    {"symbol": "MPHASIS", "name": "MphasiS Ltd.", "sector": "Information Technology"},
    {"symbol": "MRF", "name": "MRF Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "MRPL", "name": "Mangalore Refinery & Petrochemicals Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "MSUMI", "name": "Motherson Sumi Wiring India Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "MUTHOOTFIN", "name": "Muthoot Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "NATCOPHARM", "name": "Natco Pharma Ltd.", "sector": "Healthcare"},
    {"symbol": "NATIONALUM", "name": "National Aluminium Co. Ltd.", "sector": "Metals & Mining"},
    {"symbol": "NAVINFLUOR", "name": "Navin Fluorine International Ltd.", "sector": "Chemicals"},
    {"symbol": "NBCC", "name": "NBCC (India) Ltd.", "sector": "Construction"},
    {"symbol": "NCC", "name": "NCC Ltd.", "sector": "Construction"},
    {"symbol": "NH", "name": "Narayana Hrudayalaya Ltd.", "sector": "Healthcare"},
    {"symbol": "NHPC", "name": "NHPC Ltd.", "sector": "Power"},
    {"symbol": "NLCINDIA", "name": "NLC India Ltd.", "sector": "Power"},
    {"symbol": "NMDC", "name": "NMDC Ltd.", "sector": "Metals & Mining"},
    {"symbol": "NSLNISP", "name": "NMDC Steel Ltd.", "sector": "Metals & Mining"},
    {"symbol": "NUVAMA", "name": "Nuvama Wealth Management Ltd.", "sector": "Financial Services"},
    {"symbol": "NYKAA", "name": "FSN E-Commerce Ventures Ltd.", "sector": "Consumer Services"},
    {"symbol": "OBEROIRLTY", "name": "Oberoi Realty Ltd.", "sector": "Realty"},
    {"symbol": "OFSS", "name": "Oracle Financial Services Software Ltd.", "sector": "Information Technology"},
    {"symbol": "OIL", "name": "Oil India Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "OLECTRA", "name": "Olectra Greentech Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "PATANJALI", "name": "Patanjali Foods Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "PAYTM", "name": "One 97 Communications Ltd.", "sector": "Financial Services"},
    {"symbol": "PEL", "name": "Piramal Enterprises Ltd.", "sector": "Financial Services"},
    {"symbol": "PERSISTENT", "name": "Persistent Systems Ltd.", "sector": "Information Technology"},
    {"symbol": "PETRONET", "name": "Petronet LNG Ltd.", "sector": "Oil Gas & Consumable Fuels"},
    {"symbol": "PFIZER", "name": "Pfizer Ltd.", "sector": "Healthcare"},
    {"symbol": "PHOENIXLTD", "name": "The Phoenix Mills Ltd.", "sector": "Realty"},
    {"symbol": "PIIND", "name": "PI Industries Ltd.", "sector": "Chemicals"},
    {"symbol": "PNBHOUSING", "name": "PNB Housing Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "POONAWALLA", "name": "Poonawalla Fincorp Ltd.", "sector": "Financial Services"},
    {"symbol": "PRESTIGE", "name": "Prestige Estates Projects Ltd.", "sector": "Realty"},
    {"symbol": "PRINCEPIPE", "name": "Prince Pipes and Fittings Ltd.", "sector": "Capital Goods"},
    {"symbol": "PVRINOX", "name": "PVR INOX Ltd.", "sector": "Media Entertainment & Publication"},
    {"symbol": "RADICO", "name": "Radico Khaitan Ltd.", "sector": "Fast Moving Consumer Goods"},
    {"symbol": "RAJESHEXPO", "name": "Rajesh Exports Ltd.", "sector": "Consumer Durables"},
    {"symbol": "RAMCOCEM", "name": "The Ramco Cements Ltd.", "sector": "Construction Materials"},
    {"symbol": "RBLBANK", "name": "RBL Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "REDINGTON", "name": "Redington Ltd.", "sector": "Services"},
    {"symbol": "RELAXO", "name": "Relaxo Footwears Ltd.", "sector": "Consumer Durables"},
    {"symbol": "RITES", "name": "RITES Ltd.", "sector": "Construction"},
    {"symbol": "ROUTE", "name": "Route Mobile Ltd.", "sector": "Telecommunication"},
    {"symbol": "RPOWER", "name": "Reliance Power Ltd.", "sector": "Power"},
    {"symbol": "RRKABEL", "name": "R R Kabel Ltd.", "sector": "Capital Goods"},
    {"symbol": "RVNL", "name": "Rail Vikas Nigam Ltd.", "sector": "Construction"},
    {"symbol": "SAFARI", "name": "Safari Industries (India) Ltd.", "sector": "Consumer Durables"},
    {"symbol": "SAIL", "name": "Steel Authority of India Ltd.", "sector": "Metals & Mining"},
    {"symbol": "SANOFI", "name": "Sanofi India Ltd.", "sector": "Healthcare"},
    {"symbol": "SAPPHIRE", "name": "Sapphire Foods India Ltd.", "sector": "Consumer Services"},
    {"symbol": "SCHAEFFLER", "name": "Schaeffler India Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "SHOPERSTOP", "name": "Shoppers Stop Ltd.", "sector": "Consumer Services"},
    {"symbol": "SHREERAMA", "name": "Shree Rama Newsprint Ltd.", "sector": "Forest Materials"},
    {"symbol": "SJVN", "name": "SJVN Ltd.", "sector": "Power"},
    {"symbol": "SKFINDIA", "name": "SKF India Ltd.", "sector": "Capital Goods"},
    {"symbol": "SONACOMS", "name": "Sona BLW Precision Forgings Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "STARHEALTH", "name": "Star Health and Allied Insurance Co. Ltd.", "sector": "Financial Services"},
    {"symbol": "SUMICHEM", "name": "Sumitomo Chemical India Ltd.", "sector": "Chemicals"},
    {"symbol": "SUNDARMFIN", "name": "Sundaram Finance Ltd.", "sector": "Financial Services"},
    {"symbol": "SUNDRMFAST", "name": "Sundram Fasteners Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "SUNTV", "name": "Sun TV Network Ltd.", "sector": "Media Entertainment & Publication"},
    {"symbol": "SUPRAJIT", "name": "Suprajit Engineering Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "SUZLON", "name": "Suzlon Energy Ltd.", "sector": "Capital Goods"},
    {"symbol": "SWANENERGY", "name": "Swan Energy Ltd.", "sector": "Diversified"},
    {"symbol": "SYMPHONY", "name": "Symphony Ltd.", "sector": "Consumer Durables"},
    {"symbol": "SYNGENE", "name": "Syngene International Ltd.", "sector": "Healthcare"},
    {"symbol": "TANLA", "name": "Tanla Platforms Ltd.", "sector": "Information Technology"},
    {"symbol": "TATACHEM", "name": "Tata Chemicals Ltd.", "sector": "Chemicals"},
    {"symbol": "TATACOMM", "name": "Tata Communications Ltd.", "sector": "Telecommunication"},
    {"symbol": "TATAELXSI", "name": "Tata Elxsi Ltd.", "sector": "Information Technology"},
    {"symbol": "TATAINVEST", "name": "Tata Investment Corporation Ltd.", "sector": "Financial Services"},
    {"symbol": "TATATECH", "name": "Tata Technologies Ltd.", "sector": "Information Technology"},
    {"symbol": "TEJASNET", "name": "Tejas Networks Ltd.", "sector": "Telecommunication"},
    {"symbol": "THERMAX", "name": "Thermax Ltd.", "sector": "Capital Goods"},
    {"symbol": "TIMKEN", "name": "Timken India Ltd.", "sector": "Capital Goods"},
    {"symbol": "TRIDENT", "name": "Trident Ltd.", "sector": "Textiles"},
    {"symbol": "TRITURBINE", "name": "Triveni Turbine Ltd.", "sector": "Capital Goods"},
    {"symbol": "TIINDIA", "name": "Tube Investments of India Ltd.", "sector": "Automobile and Auto Components"},
    {"symbol": "UCOBANK", "name": "UCO Bank", "sector": "Financial Services"},
    {"symbol": "UNIONBANK", "name": "Union Bank of India", "sector": "Financial Services"},
    {"symbol": "UPL", "name": "UPL Ltd.", "sector": "Chemicals"},
    {"symbol": "UTIAMC", "name": "UTI Asset Management Company Ltd.", "sector": "Financial Services"},
    {"symbol": "VGUARD", "name": "V-Guard Industries Ltd.", "sector": "Consumer Durables"},
    {"symbol": "VINATIORGA", "name": "Vinati Organics Ltd.", "sector": "Chemicals"},
    {"symbol": "VOLTAS", "name": "Voltas Ltd.", "sector": "Consumer Durables"},
    {"symbol": "WELCORP", "name": "Welspun Corp Ltd.", "sector": "Metals & Mining"},
    {"symbol": "WELSPUNLIV", "name": "Welspun Living Ltd.", "sector": "Textiles"},
    {"symbol": "WHIRLPOOL", "name": "Whirlpool of India Ltd.", "sector": "Consumer Durables"},
    {"symbol": "YESBANK", "name": "Yes Bank Ltd.", "sector": "Financial Services"},
    {"symbol": "ZEEL", "name": "Zee Entertainment Enterprises Ltd.", "sector": "Media Entertainment & Publication"},
    {"symbol": "ZENSARTECH", "name": "Zensar Technologies Ltd.", "sector": "Information Technology"}
]

# Extract ticker symbols directly
SYMBOLS = [item["symbol"] for item in STOCKS_LIST]

def fetch_5year_ohlc():
    master_store = {}
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    print("=" * 70)
    print(f"⏳ Fetching 5-Year Daily OHLCV Data for {len(SYMBOLS)} Stocks...")
    print("=" * 70)

    for idx, symbol in enumerate(SYMBOLS, 1):
        ticker = f"{symbol}.NS"
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=5y&interval=1d"

        try:
            res = requests.get(url, headers=headers, timeout=15)
            if res.status_code != 200:
                print(f"⚠️ [{idx}/{len(SYMBOLS)}] Failed for {symbol} (HTTP {res.status_code})")
                continue

            data = res.json()
            result = data.get("chart", {}).get("result", [])[0]

            timestamps = result.get("timestamp", [])
            indicators = result.get("indicators", {}).get("quote", [])[0]

            opens = indicators.get("open", [])
            highs = indicators.get("high", [])
            lows = indicators.get("low", [])
            closes = indicators.get("close", [])
            volumes = indicators.get("volume", [])

            stock_candles = []
            for i in range(len(timestamps)):
                if None in (opens[i], highs[i], lows[i], closes[i]):
                    continue

                date_str = datetime.fromtimestamp(timestamps[i]).strftime("%Y-%m-%d")
                stock_candles.append([
                    date_str,
                    round(opens[i], 2),
                    round(highs[i], 2),
                    round(lows[i], 2),
                    round(closes[i], 2),
                    int(volumes[i] or 0)
                ])

            master_store[symbol] = stock_candles
            print(f"✅ [{idx}/{len(SYMBOLS)}] {symbol}: {len(stock_candles)} sessions fetched")
            time.sleep(0.3)

        except Exception as e:
            print(f"❌ [{idx}/{len(SYMBOLS)}] Error fetching {symbol}: {e}")

    # Local Save with clean indentation
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_store, f, ensure_ascii=False, indent=2)

    print("=" * 70)
    print(f"💾 File Saved Locally: '{OUTPUT_FILE}' ({len(master_store)} stocks stored)")
    print("=" * 70)

    push_to_target_repo()


def push_to_target_repo():
    token = os.environ.get("GH_PAT_TOKEN", "").strip()
    if not token:
        print("⚠️ GH_PAT_TOKEN not found. Skipping remote push.")
        return

    if not os.path.exists(OUTPUT_FILE):
        print(f"⚠️ {OUTPUT_FILE} not found. Nothing to push.")
        return

    print(f"\n🚀 Direct-Pushing '{OUTPUT_FILE}' to '{TARGET_REPO}'...")

    with open(OUTPUT_FILE, "rb") as f:
        file_bytes = f.read()

    b64_content = base64.b64encode(file_bytes).decode("utf-8")
    api_url = f"https://api.github.com/repos/{TARGET_REPO}/contents/{TARGET_FILE_PATH}"

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "Multi-Stock-Sync-Engine"
    }

    sha = None
    try:
        check_res = requests.get(api_url, headers=headers, params={"ref": TARGET_BRANCH}, timeout=15)
        if check_res.status_code == 200:
            sha = check_res.json().get("sha")
    except Exception as e:
        print(f"⚠️ Notice while fetching SHA: {e}")

    payload = {
        "message": f"📊 Auto-Update: 5Y OHLCV for {len(SYMBOLS)} Stocks [{datetime.now().strftime('%d-%b-%Y')}]",
        "content": b64_content,
        "branch": TARGET_BRANCH
    }
    if sha:
        payload["sha"] = sha

    try:
        put_res = requests.put(api_url, headers=headers, json=payload, timeout=45)
        if put_res.status_code in [200, 201]:
            print(f"✅ Target repo updated: https://github.com/{TARGET_REPO}/blob/{TARGET_BRANCH}/{TARGET_FILE_PATH}")
        else:
            print(f"❌ Target repo push failed ({put_res.status_code}): {put_res.text}")
    except Exception as e:
        print(f"❌ Error during remote sync: {e}")


if __name__ == "__main__":
    fetch_5year_ohlc()
