#!/usr/bin/env python3
"""
SECTOR INTELLIGENCE & TELEMETRY NEWS CRAWLER
============================================
Fetches public RSS and structured press feeds from verified Indian sector sources:
- Economic Times Industry Verticals (Auto, Energy, Infra, BFSI, Telecom, Health, Retail, Realty, Education)
- ChiniMandi (Sugar & Ethanol)
- Mercom India (Renewable Energy & Solar)
- Indian Chemical News & Paper Mart
- ITLN (Logistics) & Rail Analysis India
- Curated Topic Feeds across Regulators (RBI, SEBI, DGCA, IRDAI, APEDA, GJEPC, ISWAI)

Outputs: assets/data/sector_live_feed.json & sector_live_feed.json
NO AI API required: runs 100% on free public RSS & web endpoints.
"""

import os
import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone, timedelta
import urllib.request

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

FEED_SOURCES = [
    # ------------------ THEME 1: Agriculture, Sugar & Inputs (Sectors 1-7) ------------------
    {
        "sector_id": 1,
        "sector_name": "Sugar / ethanol",
        "theme_name": "Agriculture, Sugar & Inputs",
        "theme_icon": "🌾",
        "source_name": "ChiniMandi",
        "source_type": "NEWS",
        "url": "https://www.chinimandi.com/feed/",
        "kya_dekhna_hai": "Ethanol blending allocation, crushing updates, MSP & ex-mill prices.",
        "tickers": ["BALRAMCHIN", "EIDPARRY", "SHREERAMA", "PRAJMAC"]
    },
    {
        "sector_id": 2,
        "sector_name": "Cotton / textiles / garments",
        "theme_name": "Agriculture, Sugar & Inputs",
        "theme_icon": "🌾",
        "source_name": "Indian Textile Magazine",
        "source_type": "NEWS",
        "url": "https://www.indiantextilemagazine.in/feed/",
        "kya_dekhna_hai": "CAI crop estimates, Shankar-6 raw cotton spot prices, spinning mill spreads.",
        "tickers": ["PAGEIND", "KPRMILL", "GOKEX", "TRIDENT", "VTL"]
    },
    {
        "sector_id": 3,
        "sector_name": "Fertilisers",
        "theme_name": "Agriculture, Sugar & Inputs",
        "theme_icon": "🌾",
        "source_name": "FAI / Fertilisers Bureau",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=Fertiliser+Association+India+urea+DAP+subsidy&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Cabinet NBS subsidy rates, gas pooling tariffs, international DAP prices.",
        "tickers": ["COROMANDEL", "CHAMBLFERT", "GNFC", "FACT", "GSFC"]
    },
    {
        "sector_id": 4,
        "sector_name": "Agrochemicals / pesticides",
        "theme_name": "Agriculture, Sugar & Inputs",
        "theme_icon": "🌾",
        "source_name": "Indian Chemical News",
        "source_type": "NEWS",
        "url": "https://www.indianchemicalnews.com/rss",
        "kya_dekhna_hai": "CIB&RC approvals, Chinese active ingredient price spreads, export CSM demand.",
        "tickers": ["PIIND", "UPL", "DHANUKA", "RALLIS", "ASTEC"]
    },
    {
        "sector_id": 5,
        "sector_name": "Edible oils / oilseeds",
        "theme_name": "Agriculture, Sugar & Inputs",
        "theme_icon": "🌾",
        "source_name": "SEA India Feed",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=Solvent+Extractors+Association+edible+oil+import+mustard&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Crude Palm Oil vs RBD import duties, port inventories at Kandla, mustard sowing.",
        "tickers": ["ADANIENT", "PATANJALI", "AWL", "MARICO", "GOKULAGRO"]
    },
    {
        "sector_id": 6,
        "sector_name": "Tea / coffee / rubber",
        "theme_name": "Agriculture, Sugar & Inputs",
        "theme_icon": "🌾",
        "source_name": "Plantation Board Monitor",
        "source_type": "ORIGINAL",
        "url": "https://news.google.com/rss/search?q=Rubber+Board+Kottayam+Tea+Board+Kolkata+auction&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Kottayam RSS-4 spot rubber rates vs SICOM, tea auction realisations, coffee exports.",
        "tickers": ["APOLLOTYRE", "MRF", "CEATLTD", "MCLEODRUSS", "CCL"]
    },
    {
        "sector_id": 7,
        "sector_name": "Agri exports / seafood-shrimp",
        "theme_name": "Agriculture, Sugar & Inputs",
        "theme_icon": "🌾",
        "source_name": "APEDA / MPEDA Monitor",
        "source_type": "ORIGINAL",
        "url": "https://news.google.com/rss/search?q=APEDA+basmati+rice+export+MPEDA+shrimp&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Basmati rice FOB realisations post-MEP removal, US countervailing duty updates.",
        "tickers": ["KRBL", "LTFOODS", "AVANTIFEED", "APEX", "WATERBASE"]
    },

    # ------------------ THEME 2: Manufacturing, Metals & Materials (Sectors 8-17) ------------------
    {
        "sector_id": 8,
        "sector_name": "Auto: 2W / PV / CV / 3W",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "ETAuto",
        "source_type": "NEWS",
        "url": "https://auto.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "SIAM wholesales vs FADA retail registrations, dealer inventory days.",
        "tickers": ["MARUTI", "TATAMOTORS", "M&M", "BAJAJ-AUTO", "HEROMOTOCO"]
    },
    {
        "sector_id": 9,
        "sector_name": "Auto ancillaries",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "ETAuto Components",
        "source_type": "NEWS",
        "url": "https://auto.economictimes.indiatimes.com/rss/auto-components",
        "kya_dekhna_hai": "Content per vehicle expansion, EV powertrain orders, component exports.",
        "tickers": ["BHARATFORG", "SONACOMS", "MOTHERSON", "ENDURANCE", "CRAFTSMAN"]
    },
    {
        "sector_id": 10,
        "sector_name": "Steel",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "Steel Industry Monitor",
        "source_type": "NEWS_PRICING",
        "url": "https://news.google.com/rss/search?q=Indian+Steel+Association+HRC+steel+prices+coking+coal&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Hot-rolled coil spot prices, Australian coking coal index, blast furnace spreads.",
        "tickers": ["TATASTEEL", "JSWSTEEL", "JINDALSTEL", "SAIL", "APLAPOLLO"]
    },
    {
        "sector_id": 11,
        "sector_name": "Non-ferrous metals / mining",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "Mining & Metals Monitor",
        "source_type": "ORIGINAL",
        "url": "https://news.google.com/rss/search?q=Indian+Bureau+Mines+aluminium+copper+zinc+LME&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "LME cash settlement prices for Aluminium, Copper, Zinc; captive coal tariffs.",
        "tickers": ["HINDALCO", "VEDL", "HINDZINC", "NATIONALUM", "HINDCOPPER"]
    },
    {
        "sector_id": 12,
        "sector_name": "Chemicals / petrochemicals",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "Indian Chemical News",
        "source_type": "NEWS",
        "url": "https://www.indianchemicalnews.com/rss",
        "kya_dekhna_hai": "BIS Quality Control Orders, crude feedstock spreads, specialty chemical recovery.",
        "tickers": ["DEEPAKNTR", "AARTIIND", "SRF", "NAVINFLUOR", "TATACHEM"]
    },
    {
        "sector_id": 13,
        "sector_name": "Plastics / polymers / pipes",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "Polymer & Pipes Wire",
        "source_type": "NEWS_PRICING",
        "url": "https://news.google.com/rss/search?q=Polymerupdate+PVC+resin+prices+plastic+pipes&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Domestic PVC resin prices, anti-dumping investigations, Jal Jeevan pipe off-take.",
        "tickers": ["ASTRAL", "FINPIPE", "SUPREMEIND", "PRINCEPIPE"]
    },
    {
        "sector_id": 14,
        "sector_name": "Paper / paperboard / packaging",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "Paper Mart",
        "source_type": "NEWS",
        "url": "https://www.papermart.in/feed/",
        "kya_dekhna_hai": "ASEAN FTA paper imports, virgin fiber paperboard demand, waste paper recovery rates.",
        "tickers": ["JKPAPER", "WESTCOAST", "ANDHRAPAP", "TNPL"]
    },
    {
        "sector_id": 15,
        "sector_name": "Cement",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "Cement Review Wire",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=Cement+Manufacturers+Association+India+cement+prices+petcoke&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Regional 50kg bag prices (East/South/North/West), delivered petcoke fuel costs.",
        "tickers": ["ULTRACEMCO", "AMBUJACEM", "SHREECEM", "ACC", "DALBHARAT"]
    },
    {
        "sector_id": 16,
        "sector_name": "Electrical equipment / cables / transformers",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "IEEMA Grid Equipment",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=IEEMA+transformer+switchgear+cables+powergrid&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "765kV transformer lead times, CRGO electrical steel imports, PGCIL tenders.",
        "tickers": ["VOLTAMP", "ABB", "SIEMENS", "SCHNEIDER", "POLYCAB", "KEI"]
    },
    {
        "sector_id": 17,
        "sector_name": "Electronics / EMS / semiconductors",
        "theme_name": "Manufacturing, Metals & Materials",
        "theme_icon": "🏭",
        "source_name": "Electronics & Semi Dispatch",
        "source_type": "POLICY",
        "url": "https://news.google.com/rss/search?q=India+Semiconductor+Mission+MeitY+PLI+electronics+EMS&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Semiconductor OSAT packaging clearances, domestic PCBA value addition %.",
        "tickers": ["DIXON", "KAYNES", "PGEL", "SYRMA", "AMBER"]
    },

    # ------------------ THEME 3: Energy, Infrastructure & Transport (Sectors 18-28) ------------------
    {
        "sector_id": 18,
        "sector_name": "Power generation / utilities",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ETEnergyworld Power",
        "source_type": "NEWS",
        "url": "https://energy.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "Daily CEA peak demand prints, Day-Ahead Market (DAM) clearing prices on IEX.",
        "tickers": ["NTPC", "TATAPOWER", "POWERGRID", "JSWENERGY", "IEX"]
    },
    {
        "sector_id": 19,
        "sector_name": "Solar / wind / renewable / BESS",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "Mercom India",
        "source_type": "NEWS",
        "url": "https://mercomindia.com/feed/",
        "kya_dekhna_hai": "SECI auction tariffs, ALMM domestic module orders, BESS viability storage tenders.",
        "tickers": ["TATAPOWER", "ADANIGREEN", "SWSOLAR", "SUZLON", "INOXWIND"]
    },
    {
        "sector_id": 20,
        "sector_name": "Oil / refining / gas / CGD",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ETEnergyworld Oil & Gas",
        "source_type": "NEWS",
        "url": "https://energy.economictimes.indiatimes.com/rss/oil-and-gas",
        "kya_dekhna_hai": "Gross Refining Margin (GRM) benchmarks, domestic APM natural gas price revisions.",
        "tickers": ["RELIANCE", "ONGC", "IOC", "BPCL", "GAIL", "MGL", "IGL"]
    },
    {
        "sector_id": 21,
        "sector_name": "Coal",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ETEnergyworld Coal",
        "source_type": "NEWS",
        "url": "https://energy.economictimes.indiatimes.com/rss/coal",
        "kya_dekhna_hai": "Monthly Coal India production/off-take, non-power e-auction premiums.",
        "tickers": ["COALINDIA", "GMDC", "NLCINDIA"]
    },
    {
        "sector_id": 22,
        "sector_name": "Roads / highways / EPC",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ETInfra Roads",
        "source_type": "NEWS",
        "url": "https://infra.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "MoRTH construction km/day, FASTag daily toll revenue, HAM project pipeline.",
        "tickers": ["L&T", "IRB", "KNRCON", "PNCINFRA", "GRINFRA"]
    },
    {
        "sector_id": 23,
        "sector_name": "Railways / wagons / metro",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "Rail Analysis India",
        "source_type": "NEWS",
        "url": "https://railanalysis.in/feed/",
        "kya_dekhna_hai": "Wagon procurement tenders on IREPS, Kavach 4.0 track deployment, Vande Bharat rakes.",
        "tickers": ["TITAGARH", "JWL", "TEXRAIL", "BEML", "RAILTEL"]
    },
    {
        "sector_id": 24,
        "sector_name": "Defence",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "Defence Capital Monitor",
        "source_type": "ORIGINAL",
        "url": "https://news.google.com/rss/search?q=PIB+Defence+Acquisition+Council+AoN+make+in+India&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "AoN sanctions to commercial contract conversions, DPSU order book execution.",
        "tickers": ["BEL", "HAL", "MAZDOCK", "BDL", "DATAPATTNS", "COCHINSHIP"]
    },
    {
        "sector_id": 25,
        "sector_name": "Real estate / housing",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ETRealty",
        "source_type": "NEWS",
        "url": "https://realty.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "Top-7 city housing pre-sales, unsold inventory overhang months, commercial office GCC leasing.",
        "tickers": ["DLF", "GODREJPROP", "LODHA", "OBEROIRLTY", "BRIGADE", "PRESTIGE"]
    },
    {
        "sector_id": 26,
        "sector_name": "Ports / shipping",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ETInfra Ports",
        "source_type": "NEWS",
        "url": "https://infra.economictimes.indiatimes.com/rss/ports-shipping",
        "kya_dekhna_hai": "Major port cargo throughput, container TEU volumes, turnaround times.",
        "tickers": ["ADANIPORTS", "JSWINFRA", "SCI", "GPPL"]
    },
    {
        "sector_id": 27,
        "sector_name": "Logistics / warehousing / air cargo",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ITLN Logistics News",
        "source_type": "NEWS",
        "url": "https://www.itln.in/rss",
        "kya_dekhna_hai": "Grade-A warehousing absorption, express parcel shipments, DFC transit time reductions.",
        "tickers": ["CONCOR", "DELHIVERY", "TCIEXP", "BLUEDART", "MAHLOG"]
    },
    {
        "sector_id": 28,
        "sector_name": "Airlines / airports",
        "theme_name": "Energy, Infrastructure & Transport",
        "theme_icon": "⚡",
        "source_name": "ETInfra Aviation",
        "source_type": "NEWS",
        "url": "https://infra.economictimes.indiatimes.com/rss/aviation",
        "kya_dekhna_hai": "DGCA monthly passenger load factors, ATF pricing, non-aeronautical airport revenue.",
        "tickers": ["INDIGO", "SPICEJET", "GMRINFRA"]
    },

    # ------------------ THEME 4: Banking & Financial Services (Sectors 29-34) ------------------
    {
        "sector_id": 29,
        "sector_name": "Banks / NBFC / housing finance",
        "theme_name": "Banking & Financial Services",
        "theme_icon": "🏦",
        "source_name": "ETBFSI Banking",
        "source_type": "REGULATOR",
        "url": "https://bfsi.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "System credit-to-deposit ratio, Net Interest Margins, Gross NPA trajectories.",
        "tickers": ["HDFCBANK", "ICICIBANK", "SBIN", "AXISBANK", "KOTAKBANK", "BAJFINANCE"]
    },
    {
        "sector_id": 30,
        "sector_name": "Microfinance",
        "theme_name": "Banking & Financial Services",
        "theme_icon": "🏦",
        "source_name": "MFIN Micrometer Feed",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=MFIN+microfinance+institutions+network+India&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "PAR 30 and PAR 90 delinquency buckets, rural collection efficiency %.",
        "tickers": ["CREDITACC", "FUSION", "SPANDANA", "BANDHANBNK"]
    },
    {
        "sector_id": 31,
        "sector_name": "Life / general / health insurance",
        "theme_name": "Banking & Financial Services",
        "theme_icon": "🏦",
        "source_name": "ETBFSI Insurance",
        "source_type": "NEWS",
        "url": "https://bfsi.economictimes.indiatimes.com/rss/insurance",
        "kya_dekhna_hai": "Individual Retail APE growth, VNB margins, combined ratio for general insurers.",
        "tickers": ["HDFCLIFE", "SBILIFE", "ICICIPRULI", "STARHEALTH", "ICICIGI"]
    },
    {
        "sector_id": 32,
        "sector_name": "AMCs / mutual funds",
        "theme_name": "Banking & Financial Services",
        "theme_icon": "🏦",
        "source_name": "AMFI Mutual Funds Wire",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=AMFI+monthly+data+mutual+fund+SIP+inflow&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Monthly gross SIP contribution, net equity mutual fund inflows, B-30 penetration.",
        "tickers": ["HDFCAMC", "NAM-INDIA", "UTIAMC", "BSE", "CDSL", "CAMS"]
    },
    {
        "sector_id": 33,
        "sector_name": "Brokers / exchanges / depositories",
        "theme_name": "Banking & Financial Services",
        "theme_icon": "🏦",
        "source_name": "Capital Markets Regulator Wire",
        "source_type": "REGULATOR",
        "url": "https://news.google.com/rss/search?q=SEBI+circulars+NSE+BSE+demat+accounts&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Daily average cash turnover, monthly active demat additions on CDSL/NSDL.",
        "tickers": ["BSE", "MCX", "CDSL", "ANGELONE", "ISEC"]
    },
    {
        "sector_id": 34,
        "sector_name": "Payments / fintech",
        "theme_name": "Banking & Financial Services",
        "theme_icon": "🏦",
        "source_name": "ETBFSI Fintech",
        "source_type": "NEWS",
        "url": "https://bfsi.economictimes.indiatimes.com/rss/fintech",
        "kya_dekhna_hai": "Monthly NPCI UPI transaction volume & value, merchant soundbox rentals.",
        "tickers": ["PAYTM", "PBFINTECH", "INFIBEAM"]
    },

    # ------------------ THEME 5: IT, Telecom & Healthcare (Sectors 35-38) ------------------
    {
        "sector_id": 35,
        "sector_name": "IT services / BPM / technology",
        "theme_name": "IT, Telecom & Healthcare",
        "theme_icon": "💻",
        "source_name": "Enterprise Tech Wire",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=Nasscom+Indian+IT+services+TCS+Infosys+deal+wins&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Total Contract Value (TCV) deal wins, employee utilization, GCC expansions.",
        "tickers": ["TCS", "INFY", "HCLTECH", "WIPRO", "TECHM", "LTIM"]
    },
    {
        "sector_id": 36,
        "sector_name": "Telecom",
        "theme_name": "IT, Telecom & Healthcare",
        "theme_icon": "💻",
        "source_name": "ETTelecom",
        "source_type": "NEWS",
        "url": "https://telecom.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "TRAI active VLR subscribers, industry blended ARPU, 5G FWA monetization.",
        "tickers": ["BHARTIARTL", "IDEA", "TATACOMM", "INDUSTOWER"]
    },
    {
        "sector_id": 37,
        "sector_name": "Pharma / APIs / CDMO",
        "theme_name": "IT, Telecom & Healthcare",
        "theme_icon": "💻",
        "source_name": "ETHealthworld Pharma",
        "source_type": "NEWS",
        "url": "https://health.economictimes.indiatimes.com/rss/pharma",
        "kya_dekhna_hai": "USFDA inspection EIR issuance vs Form 483s, base portfolio pricing erosion.",
        "tickers": ["SUNPHARMA", "CIPLA", "DRREDDY", "DIVISLAB", "ZYDUSLIFE", "TORNTPHARM"]
    },
    {
        "sector_id": 38,
        "sector_name": "Hospitals / diagnostics / devices",
        "theme_name": "IT, Telecom & Healthcare",
        "theme_icon": "💻",
        "source_name": "ETHealthworld Hospitals",
        "source_type": "NEWS",
        "url": "https://health.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "Average ARPOB per occupied bed, bed additions, medical tourism volume.",
        "tickers": ["APOLLOHOSP", "MAXHEALTH", "FORTIS", "MEDANTA", "LALPATHLAB", "METROPOLIS"]
    },

    # ------------------ THEME 6: Consumption, Retail & Other Services (Sectors 39-47) ------------------
    {
        "sector_id": 39,
        "sector_name": "FMCG",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "ETRetail Food",
        "source_type": "NEWS",
        "url": "https://retail.economictimes.indiatimes.com/rss/food-entertainment",
        "kya_dekhna_hai": "Rural vs urban FMCG volume growth, crude derivative and palm oil input costs.",
        "tickers": ["HINDUNILVR", "ITC", "DABUR", "MARICO", "BRITANNIA", "NESTLEIND"]
    },
    {
        "sector_id": 40,
        "sector_name": "Retail / e-commerce / QSR",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "ETRetail Wire",
        "source_type": "NEWS",
        "url": "https://retail.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "RAI retail business survey, Same-Store Sales Growth (SSSG), QSR delivery.",
        "tickers": ["TRENT", "DMART", "JUBLFOOD", "DEVYANI", "WESTLIFE", "VBL"]
    },
    {
        "sector_id": 41,
        "sector_name": "Consumer durables / AC / appliances",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "ETRetail Durables",
        "source_type": "NEWS",
        "url": "https://retail.economictimes.indiatimes.com/rss/consumer-durables-and-information-technology",
        "kya_dekhna_hai": "Dealer channel inventory, copper & compressor raw material costs, summer pre-stocking.",
        "tickers": ["VOLTAS", "HAVEELLS", "BLUESTARCO", "WHIRLPOOL", "CROMPTON"]
    },
    {
        "sector_id": 42,
        "sector_name": "Gems / jewellery / diamonds",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "GJEPC Jewellery Monitor",
        "source_type": "ORIGINAL",
        "url": "https://news.google.com/rss/search?q=GJEPC+gems+jewellery+gold+diamond+exports+India&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Domestic gold spot prices, customs duty cut impact, Lab-Grown Diamond exports.",
        "tickers": ["TITAN", "KALYANKJIL", "SENCO", "RAJESHEXPO"]
    },
    {
        "sector_id": 43,
        "sector_name": "Hotels / hospitality / travel",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "Hospitality & Travel Wire",
        "source_type": "RESEARCH",
        "url": "https://news.google.com/rss/search?q=HVS+ANAROCK+hotel+RevPAR+ARR+occupancy+India&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Monthly RevPAR and Average Room Rates (ARR), spiritual & wedding tourism occupancy.",
        "tickers": ["INDHOTEL", "EIHOTEL", "LEMONTREE", "CHALET"]
    },
    {
        "sector_id": 44,
        "sector_name": "Media / broadcasting / advertising",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "ETBrandEquity",
        "source_type": "NEWS",
        "url": "https://brandequity.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "Festive AdEx growth, digital video spends, multiplex net box office and food spends.",
        "tickers": ["ZEEL", "SUNTV", "NETWORK18", "PVRINOX"]
    },
    {
        "sector_id": 45,
        "sector_name": "Staffing / HR services",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "Staffing Federation Wire",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=Indian+Staffing+Federation+flexi+staffing+headcount+EPFO&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "Quarterly flexi-staffing associate headcount additions, EPFO payroll metrics.",
        "tickers": ["QUESS", "TEAMLEASE", "SIS"]
    },
    {
        "sector_id": 46,
        "sector_name": "Alcohol / spirits / wine",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "Spirits & Alcobev Wire",
        "source_type": "ASSOCIATION",
        "url": "https://news.google.com/rss/search?q=ISWAI+spirits+liquor+alcohol+excise+policy+India&hl=en-IN&gl=IN&ceid=IN:en",
        "kya_dekhna_hai": "State excise policy revisions, Extra Neutral Alcohol (ENA) costs, premiumisation %.",
        "tickers": ["MCDOWELL-N", "RADICO", "SULA", "TIIL"]
    },
    {
        "sector_id": 47,
        "sector_name": "Education / training services",
        "theme_name": "Consumption, Retail & Other Services",
        "theme_icon": "🛒",
        "source_name": "ETEducation",
        "source_type": "NEWS",
        "url": "https://education.economictimes.indiatimes.com/rss/topstories",
        "kya_dekhna_hai": "Vocational skilling grants under NEP, offline test-prep coaching enrollments.",
        "tickers": ["CLEDUCATE", "APTECHT", "NAVNETEDUL"]
    }
]

def clean_html(raw_html: str) -> str:
    if not raw_html:
        return ""
    clean = re.sub(r'<[^>]+>', ' ', raw_html)
    clean = re.sub(r'\s+', ' ', clean).strip()
    return clean

def fetch_rss_feed(source: dict) -> list:
    url = source["url"]
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

                for item in channel.findall("item")[:3]:
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
                            "sector_id": source["sector_id"],
                            "sector_name": source["sector_name"],
                            "theme_name": source["theme_name"],
                            "theme_icon": source["theme_icon"],
                            "source_name": source["source_name"],
                            "source_type": source["source_type"],
                            "title": title[:140],
                            "summary": summary[:320] if summary else f"Sector regulatory and market update from {source['source_name']}.",
                            "deep_analysis": f"Live automated RSS intelligence harvested from {source['source_name']}.\n\nMonitoring Key Focus:\n{source['kya_dekhna_hai']}",
                            "published_at": pub_date[:25] if pub_date else NOW.strftime("%d %b %Y"),
                            "kya_dekhna_hai": source["kya_dekhna_hai"],
                            "source_url": link or source["url"],
                            "key_tickers": source.get("tickers", [])
                        })
    except Exception:
        # Graceful fallback on network timeout/block to retain calibrated baseline
        pass
    return items

def main():
    print("=" * 70)
    print("📡 SECTOR INTELLIGENCE FEED HARVESTER (ALL 47 SECTORS)")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 70)

    # 1. Ingest existing baseline feeds
    baseline_file = "assets/data/sector_live_feed.json"
    existing_feeds = []
    if os.path.exists(baseline_file):
        try:
            with open(baseline_file, "r", encoding="utf-8") as f:
                d = json.load(f)
                existing_feeds = d.get("live_feeds", [])
        except Exception:
            pass

    live_harvested = []
    for src in FEED_SOURCES:
        items = fetch_rss_feed(src)
        if items:
            print(f"  • {src['source_name']} ({src['sector_name']}): Harvested {len(items)} items")
            live_harvested.extend(items)
        else:
            print(f"  • {src['source_name']} ({src['sector_name']}): Retaining calibrated baseline")

    # Group by sector_id to guarantee all 47 sectors remain fully populated
    sector_feeds_map = {}
    for item in existing_feeds:
        sid = item.get("sector_id")
        if sid:
            sector_feeds_map[sid] = item

    for item in live_harvested:
        sid = item.get("sector_id")
        if sid:
            # When fresh live RSS arrives, update sector item while preserving deep_analysis if RSS summary is brief
            old_item = sector_feeds_map.get(sid, {})
            if "deep_analysis" in old_item and len(old_item["deep_analysis"]) > len(item.get("deep_analysis", "")):
                item["deep_analysis"] = old_item["deep_analysis"]
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
        print(f"✅ Generated {path} with {len(payload['live_feeds'])} sector intelligence dispatches.")

if __name__ == "__main__":
    main()
