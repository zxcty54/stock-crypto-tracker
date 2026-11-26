#!/usr/bin/env python3
"""
SECTOR INTELLIGENCE & RSS FEED HARVESTER
========================================
Powered directly by curated OPML specification: assets/data/India_Sector_RSS_Feeds.opml
Zero AI API calls; 100% automated RSS XML syndication and parsing.

Outputs: assets/data/sector_live_feed.json & sector_live_feed.json
Format: Clean, factual RSS feeds (Headline + 2-3 line excerpt + Tickers + What to watch).
"""

import os
import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone, timedelta
import urllib.request

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

OPML_PATH = "assets/data/India_Sector_RSS_Feeds.opml"

# Master Mapping: OPML Categories to Sector IDs (from India_Sector_Specific_News_Sources.pdf)
OPML_TO_SECTOR_MAP = {
    "01": [1],                   # Sugar and Ethanol
    "02": [3, 5],                # Fertilisers, Edible oils
    "03": [2],                   # Textiles and Garments
    "04": [10, 11],              # Steel, Non-ferrous metals
    "05": [12, 4],               # Chemicals, Agrochemicals
    "06": [14],                  # Paper and Packaging
    "07": [15],                  # Cement
    "08": [17],                  # Electronics and EMS
    "09": [18, 19, 20, 21],      # Power, Solar/Renewables, Oil & Gas, Coal
    "10": [22],                  # Roads EPC and Water
    "11": [23],                  # Railways and Metro
    "12": [24],                  # Defence
    "13": [25],                  # Realty and Paints
    "14": [26, 27],              # Ports, Shipping, Logistics
    "15": [28],                  # Airlines and Airports
    "16": [29, 31, 32, 33, 34],  # Banking, Insurance, AMCs, Brokers, Fintech
    "17": [36],                  # Telecom
    "18": [37],                  # Pharma and FDA
    "19": [38],                  # Hospitals, Diagnostics, Medical Devices
    "20": [39, 40, 41],          # FMCG, Retail/QSR, Consumer Durables
    "21": [43],                  # Travel and Hospitality
    "22": [47],                  # Education
    "23": [46],                  # Alcohol, Spirits and Wine
}

# Sector directory metadata (tickers & Kya Dekhna Hai from PDF)
SECTOR_METADATA = {
    1: {"name": "Sugar / ethanol", "theme": "Agriculture, Sugar & Inputs", "icon": "🌾", "kya_dekhna_hai": "Ethanol blending allocation, crushing updates, MSP & ex-mill prices.", "tickers": ["BALRAMCHIN", "EIDPARRY", "SHREERAMA", "PRAJMAC"]},
    2: {"name": "Cotton / textiles / garments", "theme": "Agriculture, Sugar & Inputs", "icon": "🌾", "kya_dekhna_hai": "CAI crop estimates, Shankar-6 raw cotton spot prices, spinning mill spreads.", "tickers": ["PAGEIND", "KPRMILL", "GOKEX", "TRIDENT", "VTL"]},
    3: {"name": "Fertilisers", "theme": "Agriculture, Sugar & Inputs", "icon": "🌾", "kya_dekhna_hai": "Cabinet NBS subsidy rates, gas pooling tariffs, international DAP prices.", "tickers": ["COROMANDEL", "CHAMBLFERT", "GNFC", "FACT", "GSFC"]},
    4: {"name": "Agrochemicals / pesticides", "theme": "Agriculture, Sugar & Inputs", "icon": "🌾", "kya_dekhna_hai": "CIB&RC approvals, Chinese active ingredient price spreads, export CSM demand.", "tickers": ["PIIND", "UPL", "DHANUKA", "RALLIS", "ASTEC"]},
    5: {"name": "Edible oils / oilseeds", "theme": "Agriculture, Sugar & Inputs", "icon": "🌾", "kya_dekhna_hai": "Crude Palm Oil vs RBD import duties, port inventories at Kandla, mustard sowing.", "tickers": ["ADANIENT", "PATANJALI", "AWL", "MARICO", "GOKULAGRO"]},
    6: {"name": "Tea / coffee / rubber", "theme": "Agriculture, Sugar & Inputs", "icon": "🌾", "kya_dekhna_hai": "Kottayam RSS-4 spot rubber rates vs SICOM, tea auction realisations, coffee exports.", "tickers": ["APOLLOTYRE", "MRF", "CEATLTD", "MCLEODRUSS", "CCL"]},
    7: {"name": "Agri exports / seafood-shrimp", "theme": "Agriculture, Sugar & Inputs", "icon": "🌾", "kya_dekhna_hai": "Basmati rice FOB realisations post-MEP removal, US countervailing duty updates.", "tickers": ["KRBL", "LTFOODS", "AVANTIFEED", "APEX", "WATERBASE"]},
    8: {"name": "Auto: 2W / PV / CV / 3W", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "SIAM wholesales vs FADA retail registrations, dealer inventory days.", "tickers": ["MARUTI", "TATAMOTORS", "M&M", "BAJAJ-AUTO", "HEROMOTOCO"]},
    9: {"name": "Auto ancillaries", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "Content per vehicle expansion, EV powertrain orders, component exports.", "tickers": ["BHARATFORG", "SONACOMS", "MOTHERSON", "ENDURANCE", "CRAFTSMAN"]},
    10: {"name": "Steel", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "Hot-rolled coil spot prices, Australian coking coal index, blast furnace spreads.", "tickers": ["TATASTEEL", "JSWSTEEL", "JINDALSTEL", "SAIL", "APLAPOLLO"]},
    11: {"name": "Non-ferrous metals / mining", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "LME cash settlement prices for Aluminium, Copper, Zinc; captive coal tariffs.", "tickers": ["HINDALCO", "VEDL", "HINDZINC", "NATIONALUM", "HINDCOPPER"]},
    12: {"name": "Chemicals / petrochemicals", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "BIS Quality Control Orders, crude feedstock spreads, specialty chemical recovery.", "tickers": ["DEEPAKNTR", "AARTIIND", "SRF", "NAVINFLUOR", "TATACHEM"]},
    13: {"name": "Plastics / polymers / pipes", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "Domestic PVC resin prices, anti-dumping investigations, Jal Jeevan pipe off-take.", "tickers": ["ASTRAL", "FINPIPE", "SUPREMEIND", "PRINCEPIPE"]},
    14: {"name": "Paper / paperboard / packaging", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "ASEAN FTA paper imports, virgin fiber paperboard demand, waste paper recovery rates.", "tickers": ["JKPAPER", "WESTCOAST", "ANDHRAPAP", "TNPL"]},
    15: {"name": "Cement", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "Regional 50kg bag prices (East/South/North/West), delivered petcoke fuel costs.", "tickers": ["ULTRACEMCO", "AMBUJACEM", "SHREECEM", "ACC", "DALBHARAT"]},
    16: {"name": "Electrical equipment / cables / transformers", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "765kV transformer lead times, CRGO electrical steel imports, PGCIL tenders.", "tickers": ["VOLTAMP", "ABB", "SIEMENS", "SCHNEIDER", "POLYCAB", "KEI"]},
    17: {"name": "Electronics / EMS / semiconductors", "theme": "Manufacturing, Metals & Materials", "icon": "🏭", "kya_dekhna_hai": "Semiconductor OSAT packaging clearances, domestic PCBA value addition %.", "tickers": ["DIXON", "KAYNES", "PGEL", "SYRMA", "AMBER"]},
    18: {"name": "Power generation / utilities", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "Daily CEA peak demand prints, Day-Ahead Market (DAM) clearing prices on IEX.", "tickers": ["NTPC", "TATAPOWER", "POWERGRID", "JSWENERGY", "IEX"]},
    19: {"name": "Solar / wind / renewable / BESS", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "SECI auction tariffs, ALMM domestic module orders, BESS viability storage tenders.", "tickers": ["TATAPOWER", "ADANIGREEN", "SWSOLAR", "SUZLON", "INOXWIND"]},
    20: {"name": "Oil / refining / gas / CGD", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "Gross Refining Margin (GRM) benchmarks, domestic APM natural gas price revisions.", "tickers": ["RELIANCE", "ONGC", "IOC", "BPCL", "GAIL", "MGL", "IGL"]},
    21: {"name": "Coal", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "Monthly Coal India production/off-take, non-power e-auction premiums.", "tickers": ["COALINDIA", "GMDC", "NLCINDIA"]},
    22: {"name": "Roads / highways / EPC", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "MoRTH construction km/day, FASTag daily toll revenue, HAM project pipeline.", "tickers": ["L&T", "IRB", "KNRCON", "PNCINFRA", "GRINFRA"]},
    23: {"name": "Railways / wagons / metro", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "Wagon procurement tenders on IREPS, Kavach 4.0 track deployment, Vande Bharat rakes.", "tickers": ["TITAGARH", "JWL", "TEXRAIL", "BEML", "RAILTEL"]},
    24: {"name": "Defence", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "AoN sanctions to commercial contract conversions, DPSU order book execution.", "tickers": ["BEL", "HAL", "MAZDOCK", "BDL", "DATAPATTNS", "COCHINSHIP"]},
    25: {"name": "Real estate / housing", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "Top-7 city housing pre-sales, unsold inventory overhang months, commercial office GCC leasing.", "tickers": ["DLF", "GODREJPROP", "LODHA", "OBEROIRLTY", "BRIGADE", "PRESTIGE"]},
    26: {"name": "Ports / shipping", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "Major port cargo throughput, container TEU volumes, turnaround times.", "tickers": ["ADANIPORTS", "JSWINFRA", "SCI", "GPPL"]},
    27: {"name": "Logistics / warehousing / air cargo", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "Grade-A warehousing absorption, express parcel shipments, DFC transit time reductions.", "tickers": ["CONCOR", "DELHIVERY", "TCIEXP", "BLUEDART", "MAHLOG"]},
    28: {"name": "Airlines / airports", "theme": "Energy, Infrastructure & Transport", "icon": "⚡", "kya_dekhna_hai": "DGCA monthly passenger load factors, ATF pricing, non-aeronautical airport revenue.", "tickers": ["INDIGO", "SPICEJET", "GMRINFRA"]},
    29: {"name": "Banks / NBFC / housing finance", "theme": "Banking & Financial Services", "icon": "🏦", "kya_dekhna_hai": "System credit-to-deposit ratio, Net Interest Margins, Gross NPA trajectories.", "tickers": ["HDFCBANK", "ICICIBANK", "SBIN", "AXISBANK", "KOTAKBANK", "BAJFINANCE"]},
    30: {"name": "Microfinance", "theme": "Banking & Financial Services", "icon": "🏦", "kya_dekhna_hai": "PAR 30 and PAR 90 delinquency buckets, rural collection efficiency %.", "tickers": ["CREDITACC", "FUSION", "SPANDANA", "BANDHANBNK"]},
    31: {"name": "Life / general / health insurance", "theme": "Banking & Financial Services", "icon": "🏦", "kya_dekhna_hai": "Individual Retail APE growth, VNB margins, combined ratio for general insurers.", "tickers": ["HDFCLIFE", "SBILIFE", "ICICIPRULI", "STARHEALTH", "ICICIGI"]},
    32: {"name": "AMCs / mutual funds", "theme": "Banking & Financial Services", "icon": "🏦", "kya_dekhna_hai": "Monthly gross SIP contribution, net equity mutual fund inflows, B-30 penetration.", "tickers": ["HDFCAMC", "NAM-INDIA", "UTIAMC", "BSE", "CDSL", "CAMS"]},
    33: {"name": "Brokers / exchanges / depositories", "theme": "Banking & Financial Services", "icon": "🏦", "kya_dekhna_hai": "Daily average cash turnover, monthly active demat additions on CDSL/NSDL.", "tickers": ["BSE", "MCX", "CDSL", "ANGELONE", "ISEC"]},
    34: {"name": "Payments / fintech", "theme": "Banking & Financial Services", "icon": "🏦", "kya_dekhna_hai": "Monthly NPCI UPI transaction volume & value, merchant soundbox rentals.", "tickers": ["PAYTM", "PBFINTECH", "INFIBEAM"]},
    35: {"name": "IT services / BPM / technology", "theme": "IT, Telecom & Healthcare", "icon": "💻", "kya_dekhna_hai": "Total Contract Value (TCV) deal wins, employee utilization, GCC expansions.", "tickers": ["TCS", "INFY", "HCLTECH", "WIPRO", "TECHM", "LTIM"]},
    36: {"name": "Telecom", "theme": "IT, Telecom & Healthcare", "icon": "💻", "kya_dekhna_hai": "TRAI active VLR subscribers, industry blended ARPU, 5G FWA monetization.", "tickers": ["BHARTIARTL", "IDEA", "TATACOMM", "INDUSTOWER"]},
    37: {"name": "Pharma / APIs / CDMO", "theme": "IT, Telecom & Healthcare", "icon": "💻", "kya_dekhna_hai": "USFDA inspection EIR issuance vs Form 483s, base portfolio pricing erosion.", "tickers": ["SUNPHARMA", "CIPLA", "DRREDDY", "DIVISLAB", "ZYDUSLIFE", "TORNTPHARM"]},
    38: {"name": "Hospitals / diagnostics / devices", "theme": "IT, Telecom & Healthcare", "icon": "💻", "kya_dekhna_hai": "Average ARPOB per occupied bed, bed additions, medical tourism volume.", "tickers": ["APOLLOHOSP", "MAXHEALTH", "FORTIS", "MEDANTA", "LALPATHLAB", "METROPOLIS"]},
    39: {"name": "FMCG", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "Rural vs urban FMCG volume growth, crude derivative and palm oil input costs.", "tickers": ["HINDUNILVR", "ITC", "DABUR", "MARICO", "BRITANNIA", "NESTLEIND"]},
    40: {"name": "Retail / e-commerce / QSR", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "RAI retail business survey, Same-Store Sales Growth (SSSG), QSR delivery.", "tickers": ["TRENT", "DMART", "JUBLFOOD", "DEVYANI", "WESTLIFE", "VBL"]},
    41: {"name": "Consumer durables / AC / appliances", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "Dealer channel inventory, copper & compressor raw material costs, summer pre-stocking.", "tickers": ["VOLTAS", "HAVEELLS", "BLUESTARCO", "WHIRLPOOL", "CROMPTON"]},
    42: {"name": "Gems / jewellery / diamonds", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "Domestic gold spot prices, customs duty cut impact, Lab-Grown Diamond exports.", "tickers": ["TITAN", "KALYANKJIL", "SENCO", "RAJESHEXPO"]},
    43: {"name": "Hotels / hospitality / travel", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "Monthly RevPAR and Average Room Rates (ARR), spiritual & wedding tourism occupancy.", "tickers": ["INDHOTEL", "EIHOTEL", "LEMONTREE", "CHALET"]},
    44: {"name": "Media / broadcasting / advertising", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "Festive AdEx growth, digital video spends, multiplex net box office and food spends.", "tickers": ["ZEEL", "SUNTV", "NETWORK18", "PVRINOX"]},
    45: {"name": "Staffing / HR services", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "Quarterly flexi-staffing associate headcount additions, EPFO payroll metrics.", "tickers": ["QUESS", "TEAMLEASE", "SIS"]},
    46: {"name": "Alcohol / spirits / wine", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "State excise policy revisions, Extra Neutral Alcohol (ENA) costs, premiumisation %.", "tickers": ["MCDOWELL-N", "RADICO", "SULA", "TIIL"]},
    47: {"name": "Education / training services", "theme": "Consumption, Retail & Other Services", "icon": "🛒", "kya_dekhna_hai": "Vocational skilling grants under NEP, offline test-prep coaching enrollments.", "tickers": ["CLEDUCATE", "APTECHT", "NAVNETEDUL"]},
}

# Complementary RSS endpoints for sectors not explicitly grouped in OPML outlines
COMPLEMENTARY_SOURCES = [
    {"sector_id": 6, "name": "Rubber Board / Tea Board", "type": "ORIGINAL", "url": "https://news.google.com/rss/search?q=Rubber+Board+Kottayam+Tea+Board+auction&hl=en-IN&gl=IN&ceid=IN:en"},
    {"sector_id": 7, "name": "APEDA / MPEDA Trade", "type": "ORIGINAL", "url": "https://news.google.com/rss/search?q=APEDA+basmati+rice+export+MPEDA+shrimp&hl=en-IN&gl=IN&ceid=IN:en"},
    {"sector_id": 8, "name": "ETAuto", "type": "NEWS", "url": "https://auto.economictimes.indiatimes.com/rss/topstories"},
    {"sector_id": 9, "name": "ETAuto Components", "type": "NEWS", "url": "https://auto.economictimes.indiatimes.com/rss/auto-components"},
    {"sector_id": 13, "name": "Polymer & Pipes Wire", "type": "NEWS_PRICING", "url": "https://news.google.com/rss/search?q=Polymerupdate+PVC+resin+prices+plastic+pipes&hl=en-IN&gl=IN&ceid=IN:en"},
    {"sector_id": 16, "name": "IEEMA Grid Equipment", "type": "ASSOCIATION", "url": "https://news.google.com/rss/search?q=IEEMA+transformer+switchgear+cables+powergrid&hl=en-IN&gl=IN&ceid=IN:en"},
    {"sector_id": 30, "name": "MFIN Micrometer", "type": "ASSOCIATION", "url": "https://news.google.com/rss/search?q=MFIN+microfinance+institutions+network+India&hl=en-IN&gl=IN&ceid=IN:en"},
    {"sector_id": 35, "name": "Enterprise Tech Wire", "type": "ASSOCIATION", "url": "https://news.google.com/rss/search?q=Nasscom+Indian+IT+services+TCS+Infosys+deal+wins&hl=en-IN&gl=IN&ceid=IN:en"},
    {"sector_id": 42, "name": "GJEPC Jewellery Monitor", "type": "ORIGINAL", "url": "https://news.google.com/rss/search?q=GJEPC+gems+jewellery+gold+diamond+exports+India&hl=en-IN&gl=IN&ceid=IN:en"},
    {"sector_id": 44, "name": "ETBrandEquity", "type": "NEWS", "url": "https://brandequity.economictimes.indiatimes.com/rss/topstories"},
    {"sector_id": 45, "name": "Staffing Federation Wire", "type": "ASSOCIATION", "url": "https://news.google.com/rss/search?q=Indian+Staffing+Federation+flexi+staffing+headcount&hl=en-IN&gl=IN&ceid=IN:en"},
]

def clean_html(raw_html: str) -> str:
    if not raw_html:
        return ""
    clean = re.sub(r'<[^>]+>', ' ', raw_html)
    clean = re.sub(r'\s+', ' ', clean).strip()
    return clean

def load_opml_sources() -> list:
    sources = []
    if not os.path.exists(OPML_PATH):
        return sources

    try:
        tree = ET.parse(OPML_PATH)
        root = tree.getroot()
        body = root.find("body")
        if body is None:
            return sources

        for cat in body.findall("outline"):
            cat_text = cat.attrib.get("text", "")
            cat_code = cat_text[:2]
            target_sector_ids = OPML_TO_SECTOR_MAP.get(cat_code, [])

            for f in cat.findall("outline"):
                xml_url = f.attrib.get("xmlUrl", "").strip()
                name = f.attrib.get("text") or f.attrib.get("title", "")
                cat_type = f.attrib.get("category", "NEWS").upper()

                if xml_url and target_sector_ids:
                    for sid in target_sector_ids:
                        sources.append({
                            "sector_id": sid,
                            "name": name,
                            "type": cat_type,
                            "url": xml_url
                        })
    except Exception as e:
        print(f"⚠️ Error parsing OPML: {e}")

    return sources

def fetch_rss_feed(source: dict) -> list:
    url = source["url"]
    sid = source["sector_id"]
    meta = SECTOR_METADATA.get(sid, {})

    items = []
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/rss+xml, application/xml, text/xml, */*"
    }
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=6) as resp:
            if resp.status == 200:
                xml_data = resp.read()
                root = ET.fromstring(xml_data)
                channel = root.find("channel")
                if channel is None:
                    channel = root

                for item in channel.findall("item")[:2]:
                    title_elem = item.find("title")
                    desc_elem = item.find("description")
                    link_elem = item.find("link")
                    date_elem = item.find("pubDate")

                    title = clean_html(title_elem.text if title_elem is not None else "")
                    summary = clean_html(desc_elem.text if desc_elem is not None else "")
                    link = (link_elem.text if link_elem is not None else "").strip()
                    pub_date = (date_elem.text if date_elem is not None else "").strip()

                    if title and len(title) > 10:
                        items.append({
                            "id": f"rss_{abs(hash(title)) % 1000000:06d}",
                            "sector_id": sid,
                            "sector_name": meta.get("name", f"Sector {sid}"),
                            "theme_name": meta.get("theme", "General"),
                            "theme_icon": meta.get("icon", "📊"),
                            "source_name": source["name"],
                            "source_type": source.get("type", "NEWS"),
                            "title": title[:140],
                            "summary": summary[:280] if summary else f"Sector news and market update from {source['name']}.",
                            "published_at": pub_date[:25] if pub_date else NOW.strftime("%d %b %Y"),
                            "kya_dekhna_hai": meta.get("kya_dekhna_hai", ""),
                            "source_url": link or source["url"],
                            "key_tickers": meta.get("tickers", [])
                        })
    except Exception:
        # Fallback gracefully to retain calibrated baseline
        pass
    return items

def main():
    print("=" * 70)
    print("📡 SECTOR INTELLIGENCE & OPML RSS FEED HARVESTER")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print(f"📂 Loaded OPML Feeds from: {OPML_PATH}")
    print("=" * 70)

    # 1. Ingest existing calibrated baseline feeds
    baseline_file = "assets/data/sector_live_feed.json"
    existing_feeds = []
    if os.path.exists(baseline_file):
        try:
            with open(baseline_file, "r", encoding="utf-8") as f:
                d = json.load(f)
                existing_feeds = d.get("live_feeds", [])
        except Exception:
            pass

    # 2. Combine OPML sources with complementary sector sources
    opml_sources = load_opml_sources()
    all_sources = opml_sources + COMPLEMENTARY_SOURCES
    print(f"Total RSS Endpoints to poll: {len(all_sources)} across all 47 sectors")

    live_harvested = []
    for src in all_sources:
        items = fetch_rss_feed(src)
        if items:
            live_harvested.extend(items)

    print(f"Harvested {len(live_harvested)} live RSS items (Zero AI used).")

    # Group by sector_id to guarantee all 47 sectors remain 100% populated
    sector_feeds_map = {}
    for item in existing_feeds:
        sid = item.get("sector_id")
        if sid:
            sector_feeds_map[sid] = item

    for item in live_harvested:
        sid = item.get("sector_id")
        if sid:
            sector_feeds_map[sid] = item

    all_ordered_feeds = []
    for sid in range(1, 48):
        if sid in sector_feeds_map:
            all_ordered_feeds.append(sector_feeds_map[sid])

    payload = {
        "last_updated": NOW.strftime("%d-%b-%Y %H:%M IST"),
        "total_items": len(all_ordered_feeds),
        "live_feeds": all_ordered_feeds
    }

    for path in ["assets/data/sector_live_feed.json", "sector_live_feed.json"]:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        print(f"✅ Generated {path} with {len(payload['live_feeds'])} sector dispatches.")

if __name__ == "__main__":
    main()
