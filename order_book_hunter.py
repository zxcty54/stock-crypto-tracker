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

# Universal Max Debt/MCap ratio across all categories
MAX_DEBT_TO_MCAP_RATIO = 1.2

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

# Non-order sectors jahan order book nahi hota
NON_ORDER_SECTORS = [
    "bank", "financial services", "finance", "nbfc", "housing finance",
    "information technology", "it services", "software", "consulting",
    "fast moving consumer goods", "fmcg", "consumer goods", "retail",
    "healthcare", "pharmaceuticals", "pharma", "diagnostic", "hospital",
    "media", "entertainment", "broadcasting", "publishing",
    "hotel", "restaurant", "travel", "tourism"
]

WATCHLIST_SYMBOLS = [
    "20MICRONS", "5PAISA", "AAATECH", "AAREYDRUGS", "AARON", "AARTIDRUGS", "AARVI", "ABCOTS", "ABLBL",
    "ABMKNO", "ACI", "ADDIND", "ADFFOODS", "ADL", "ADSL", "ADVANCE", "ADVENZYMES", "ADVENTHTL", "AEROENTER",
    "AERONEU", "AEROPLANE", "AFCONS", "AFFORDABLE", "AFSL", "AGARIND", "AGIIL", "AGRITECH", "AHLEAST",
    "AIROLAM", "AJMERA", "AKSHARCHEM", "ALEMBICLTD", "ALGOQUANT", "ALKALI", "ALLTIME", "ALPA", "AMARJOTHI",
    "AMNPLST", "ANDHRAPAP", "ANDHRSUGAR", "ANNAPURNA", "ANSALBU", "ANUHPHR", "AONESTEELS", "APCL", "APEX",
    "APTECHT", "ARCHIDPLY", "ARCIL", "ARCL", "ARFIN", "ARIHANTCAP", "ARIHANTSUP", "ARIS", "ARKADE",
    "ARMEE", "ARTEMISMED", "ARVEE", "ARVINDFASN", "ASAHISONG", "ASAL", "ASHIANA", "ASHOKA", "ASIANENE",
    "ASIANHOTNR", "ASPINWALL", "ATAM", "ATLASCYCLE", "ATULAUTO", "AURUM", "AUSOMENT", "AUSTENG", "AUTOIND",
    "AVANTEL", "AVTNPL", "AWFIS", "AWHCL", "AXTEL", "AYE", "AYMSYNTEX", "AZADIND", "BAJAJCON", "BAJAJELEC",
    "BAJAJHCARE", "BAJAJINDEF", "BAJAJST", "BAJEL", "BALAJITELE", "BALMLAWRIE", "BALPHARMA", "BANARBEADS",
    "BANKA", "BANSALWIRE", "BANSWRAS", "BATLIBOI", "BBTCL", "BCONCEPTS", "BCPL", "BECTORFOOD", "BEDMUTHA",
    "BEEKAY", "BELLACASA", "BEPL", "BFINVEST", "BFUTILITIE", "BHAGCHEM", "BHAGERIA", "BHAGYANGR", "BHARATGEAR",
    "BHARATSE", "BHARATWIRE", "BIRLACABLE", "BIRLAMONEY", "BLACKROSE", "BLAL", "BLKASHYAP", "BLIL", "BLS",
    "BLSE", "BLUSPRING", "BMWVENTLTD", "BNAGROCHEM", "BODALCHEM", "BOMDYEING", "BORANA", "BOROLTD", "BORORENEW",
    "BOROSCI", "BRAHMINFRA", "BRIGHOTEL", "BRIGHTBR", "BROOKS", "BSHSL", "BSL", "BSOFT", "CAMLINFINE",
    "CAMPUS", "CANTABIL", "CAPACITE", "CAPITALSFB", "CEIGALL", "CELLO", "CEWATER", "CGVAK", "CHEMBOND",
    "CHEMCON", "CHEMCRUX", "CHEMFAB", "CHEMPLASTS", "CINELINE", "CLEDUCATE", "CLSEL", "CMRGREEN", "CMSINFO",
    "COMPEAU", "COMSYN", "CONFIPET", "CONSOFINVT", "CORDELIA", "CORDSCABLE", "CPCAP", "CPEDU", "CPL",
    "CRAMC", "CRAVATEX", "CREST", "CRIZAC", "CROWN", "CSBBANK", "CSLFINANCE", "CSM", "CYBERTECH", "DALMIASUG",
    "DAMCAPITAL", "DBCORP", "DBL", "DBOL", "DBREALTY", "DCAL", "DCBBANK", "DCI", "DCM", "DCMNVL", "DCMSIL",
    "DCXINDIA", "DDEVPLSTIK", "DECNGOLD", "DEEPA", "DELTACORP", "DELTAMAGNT", "DENTA", "DHAMPURSUG", "DHARMAJ",
    "DIAMINESQ", "DIFFNKG", "DIGITIDE", "DJML", "DLINKINDIA", "DMCC", "DOLATALGO", "DOLLAR", "DONEAR",
    "DPWIRES", "DREAMFOLKS", "DTIL", "DVL", "DYCL", "DYNPRO", "ECORECO", "ECOSMOBLTY", "EFCIL", "EIEL",
    "EIFFL", "EIHAHOTELS", "EKC", "ELECON", "ELECTCAST", "ELEVATE", "ELGIRUBCO", "ELIN", "ELLEN", "ELPROINTL",
    "EMAMIPAP", "EMAMIREAL", "EMBDL", "EMIL", "EMKAY", "EMMBI", "EMSLIMITED", "ENIL", "ENKEIWHEL", "EPACK",
    "EPACKPEB", "EPL", "EQUITASBNK", "ESTER", "EUREKAFORB", "EUROBOND", "EUROPRATIK", "EVEREADY", "EXCELSOFT",
    "EXICOM", "FABTECH", "FAZE3Q", "FCL", "FDC", "FEDDERSHOL", "FEDFINA", "FILATEX", "FINKURVE", "FINOPB",
    "FINPIPE", "FIRSTCRY", "FLAIR", "FMGOETZE", "FOCUS", "FUSION", "GAEL", "GAJA", "GANDHAR", "GANESHCP",
    "GANESHBE", "GANGESSECU", "GARUDA", "GATEWAY", "GAUDIUMIVF", "GEECEE", "GEMAROMA", "GENESYS", "GENUSPOWER",
    "GEOJITFSL", "GFLLIMITED", "GHCL", "GHCLTEXTIL", "GICHSGFIN", "GILLANDERS", "GIPCL", "GKB", "GKENERGY",
    "GKSL", "GLASSWALL", "GLOBAL", "GLOBALVECT", "GLOTTIS", "GMRP&UI", "GNRL", "GOACARBON", "GOCLCORP",
    "GOCOLORS", "GODAVARIB", "GOKULAGRO", "GOLDIAM", "GOODLUCK", "GOPAL", "GPPL", "GPTHEALTH", "GPTINFRA",
    "GRANDOAK", "GRAUWEIL", "GREAVESCOT", "GREENLAM", "GREENPANEL", "GREENPLY", "GRMOVER", "GSFC", "GSPCROP",
    "GTPL", "GUFICBIO", "GUJAPOLLO", "GUJTHEM", "GULPOLY", "GYFTR", "HALDER", "HALDYNGL", "HAPPSTMNDS",
    "HARIOMPIPE", "HARRMALAYA", "HARSHA", "HBESD", "HBPOR", "HBSL", "HEALTHX", "HECPROJECT", "HEGAM",
    "HEIDELBERG", "HEMIPROP", "HERANBA", "HERITGFOOD", "HEROMOTORS", "HEXATRADEX", "HGINFRA", "HGS", "HIKAL",
    "HIMATSEIDE", "HINDADH", "HINDALUMI", "HINDCOMPOS", "HINDOILEXP", "HINDWAREAP", "HISARMETAL", "HITECH",
    "HITECHCORP", "HLEGLAS", "HMVL", "HPIL", "HPL", "HRYNSHP", "HTEL", "HUBTOWN", "HUHTAMAKI", "ICIL",
    "IEX", "IFGLEXPOR", "IGARASHI", "IGCL", "IITL", "IKIO", "INA", "INDIACEM", "INDIAGLYCO", "INDIANCARD",
    "INDIANHUME", "INDIQUBE", "INDOAMIN", "INDOBORAX", "INDOCO", "INDOFARM", "INDORAMA", "INDOSTAR", "INDRAMEDCO",
    "INDSWFTLAB", "INDOUS", "INFOBEAN", "INNOVANA", "INNOVISION", "INOXGREEN", "INSPIRISYS", "INTENTECH",
    "INTLCONV", "IOLCP", "IONEXCHANG", "IPL", "IPRINGLTD", "IRIS", "IRISDOREME", "IRMENERGY", "ISFT",
    "ITL", "IVALUE", "IVP", "IXIGO", "JAGRAN", "JAGSNPHARM", "JAIBALAJI", "JAICORPLTD", "JAMNAAUTO",
    "JARO", "JAYAGROGN", "JAYBARMARU", "JAYKAY", "JAYNECOIND", "JAYSREETEA", "JITFINFRA", "JKIL", "JKIPL",
    "JKLAKSHMI", "JKPAPER", "JKTYRE", "JLHL", "JMA", "JNKINDIA", "JOCIL", "JSLL", "JTEKTINDIA", "JTLIND",
    "JUNIPER", "JWL", "JYOTHYLAB", "KAKATCEM", "KALAMANDIR", "KALPATARU", "KAMATHOTEL", "KANCHI", "KANCOTEA",
    "KANORICHEM", "KANPRPLA", "KAYA", "KCP", "KECL", "KEYFINSERV", "KHADIM", "KHAITANLTD", "KILITCH",
    "KIRANVYPAR", "KIRLFER", "KISSHT", "KITEX", "KJMCFIN", "KKCL", "KMCSHIL", "KNACK", "KNAGRI", "KNRCON",
    "KOKUYOCMLN", "KOLTEPATIL", "KOPRAN", "KOTHARIPET", "KOTHARIPRO", "KOTIC", "KPEL", "KPIGREEN", "KRBL",
    "KREBSBIO", "KRISHANA", "KRISHIVAL", "KRITI", "KRITINUT", "KRONOX", "KROSS", "KSE", "KSOLVES", "KUANTUM",
    "LAGNAM", "LAMBODHARA", "LANDMARK", "LAOPALA", "LASERPOWER", "LATENTVIEW", "LAXMIDENTL", "LAXMIINDIA",
    "LCCPROJECT", "LEAPIND", "LEMONTREE", "LFIC", "LGHL", "LIBERTSHOE", "LIKHITHA", "LINC", "LOKESHMACH",
    "LORDSCHLO", "LOTUSEYE", "LOVABLE", "LOYALTEX", "LUMINO", "LXCHEM", "LYKALABS", "MAANALU", "MADRASFERT",
    "MAFATIND", "MAHAPEXLTD", "MAHEPC", "MAHESHWARI", "MAHLIFE", "MAHLOG", "MAKERSL", "MAMATA", "MANAKCOAT",
    "MANAKSIA", "MANAKSTEEL", "MANALIPETC", "MANBA", "MANCREDIT", "MANINFRA", "MANOMAY", "MANORG", "MARALOVER",
    "MARATHON", "MARINE", "MARKOLINES", "MARSONS", "MASFIN", "MASKINVEST", "MASTERTR", "MAWANASUG", "MAXIND",
    "MBAPL", "MBEL", "MCL", "MEDIASSIST", "MEDICAMEQ", "MEGASTAR", "MEIL", "MENONBE", "METROGLOBL", "MHRIL",
    "MIDHANI", "MINDTECK", "MITCON", "MKEXIM", "MLKFOOD", "MMP", "MMTC", "MOBIKWIK", "MODINATUR", "MODIRUBBER",
    "MODIS", "MODISONLTD", "MOHITE", "MOIL", "MOL", "MOLDTECH", "MOMSBELIEF", "MONARCH", "MOREPENLAB",
    "MOSCHIP", "MPIMANIPAL", "MSL", "MUFIN", "MUFTI", "MUKANDLTD", "MUKESHB", "MUKTAARTS", "MUNJALAU",
    "MUNJALSHOW", "MUTHOOTCAP", "MUTHOOTMF", "MVGJL", "NACLIND", "NAHARCAP", "NAHARINDUS", "NAHARPOLY",
    "NAHARSPING", "NATCAPSUQ", "NATHBIOGEN", "NATIONSTD", "NAVKARCORP", "NAVNETEDUL", "NCC", "NCLIND",
    "NDLVENTURE", "NDTV", "NELCAST", "NEWGEN", "NFL", "NICCOPAR", "NIITLTD", "NIITMTS", "NIMBSPROJ",
    "NIPPOBATRY", "NIRAJISPAT", "NITCO", "NITIRAJ", "NKIND", "NOCIL", "NORBTEAEXP", "NORTHARC", "NRL",
    "NTCIND", "OBCL", "OCCLLTD", "OILCOUNTUB", "OMAXAUTO", "OMAXE", "OMINFRAL", "OMPOWER", "ONEPOINT",
    "ONIXSOLAR", "ONWARDTEC", "ORBTEXP", "ORICONENT", "ORIENTBELL", "ORIENTCEM", "ORIENTELEC", "ORIENTHOT",
    "ORIENTTECH", "ORIRAIL", "OSWALPUMPS", "PACEDIGITK", "PACIFICI", "PAISALO", "PAKKA", "PALASHSECU",
    "PANACEABIO", "PANCHMAHQ", "PANORAMA", "PANSARI", "PARACABLES", "PARAGMILK", "PARKHOTELS", "PARNAXLAB",
    "PASHUPATI", "PASUPTAC", "PATELRMART", "PBMPOLY", "PDMJEPAPER", "PDSL", "PENIND", "PIGL", "PLASTIBLEN",
    "PLATIND", "PLAZACABLE", "PML", "PNBGILTS", "PNCINFRA", "POCL", "PODDARMENT", "POEL", "PONNIERODE",
    "PPAP", "PPL", "PRABHA", "PRAJIND", "PRAKASH", "PRANAV", "PRAVEG", "PRECAM", "PREMCO", "PREMIERPOL",
    "PRIMESECU", "PRINCEPIPE", "PRIORITY", "PRSMJOHNSN", "PROSTARM", "PROZONER", "PTC", "PURVA", "PVP",
    "PVSL", "PYRAMID", "QUESS", "QUICKHEAL", "RACE", "RADHIKAJWE", "RAILTEL", "RAIN", "RAJESHEXPO",
    "RAJRATAN", "RALLIS", "RAMAPHO", "RAMBHAJO", "RAMCOIND", "RAMKY", "RATNAVEER", "RBA", "RBZJEWEL",
    "RCF", "REDTAPE", "REFEX", "REGAAL", "RELAXO", "RELCHEMQ", "RELIABLE", "RELIGARE", "RELINFRA", "RELTD",
    "REMSONSIND", "REPCOHOME", "REPL", "REPRO", "RESPONIND", "RGL", "RHIM", "RHL", "RICOAUTO", "RIR",
    "RITCO", "RITES", "RKSWAMY", "RMC", "ROHLTD", "ROLEXRINGS", "ROSSELLIND", "ROSSARI", "ROTO", "ROUTE",
    "RPPINFRA", "RRECL", "RSL", "RTSPOWR", "RSWM", "RSYSTEMS", "RUBFILA", "RUBYMILLS", "RUCHIRA", "RUPA",
    "RUSTOMJEE", "S&SPOWER", "SAATVIKGL", "SAB", "SAGCEM", "SAHLIBHFI", "SAHYADRI", "SAICAPI", "SAKSOFT",
    "SALONA", "SALSTEEL", "SAMBANDAM", "SAMBHV", "SAMHI", "SANDUMA", "SANGHVIMOV", "SANSTAR", "SAPPHIRE",
    "SAPPL", "SARLAPOLY", "SATIA", "SATIN", "SAURASHCEM", "SAYAJIHOTL", "SAYAJIIND", "SBC", "SBFC",
    "SCHAND", "SCODATUBES", "SDBL", "SECMARK", "SEIL", "SEKURITIND", "SEMAC", "SENCO", "SERVOTECH",
    "SESHAPAPER", "SETL", "SHAHALLOYS", "SHAKTIPUMP", "SHALBY", "SHALPAINTS", "SHANKARA", "SHANKESH",
    "SHANTIGOLD", "SHAREINDIA", "SHBAJRG", "SHEMAROO", "SHERVANI", "SHILGRAVQ", "SHINDL", "SHIPROCKET",
    "SHIVALIK", "SHIVAMILLS", "SHIVATEX", "SHK", "SHOPERSTOP", "SHRADDHA", "SHREDIGCEM", "SHREEPUSHK",
    "SHREYANIND", "SHRINGARMS", "SHRIRAMPPS", "SHUKRAPHAR", "SICAGEN", "SIGNPOST", "SIGIND", "SILGO",
    "SILINV", "SIMPLEXINF", "SIMPLXREA", "SINCLAIR", "SINGERIND", "SINTERCOM", "SIRCA", "SIS", "SKMEGGPROD",
    "SKYWAYS", "SMCGLOBAL", "SMLT", "SMSPHARMA", "SOFTTECH", "SOLARWORLD", "SOMATEX", "SOMICONVEY", "SONAL",
    "SONATSOFTW", "SOUTHWEST", "SPANDANA", "SPARC", "SPECIALITY", "SPIC", "SPMLINFRA", "SPORTKING", "SREEL",
    "SRGHFL", "SRM", "SSDL", "SSWL", "STALLION", "STANLEY", "STARCEMENT", "STARPAPER", "STARTECK", "STCINDIA",
    "STEAMHOUSE", "STEELCAS", "STEELCITY", "STERTOOLS", "STUDDS", "STYL", "STYLEBAAZA", "SUDARCOLOR",
    "SUKHJITS", "SULA", "SUMIT", "SUNFLAG", "SUNLOC", "SUNRAKSHAK", "SUNSHINE", "SUNTECK", "SUPERHOUSE",
    "SUPRAJIT", "SUPREMEINF", "SURAJEST", "SURAJLTD", "SURAKSHA", "SURYALA", "SURYALAXMI", "SURYAROSNI",
    "SURYODAY", "SUVEN", "SVGLOBAL", "SWANCORP", "SWSOLAR", "TAINWALCHM", "TAJGVK", "TALBROAUTO", "TANAA",
    "TANLA", "TARC", "TARIL", "TARMAT", "TARSONS", "TCIEXP", "TEAMGTY", "TECHNOCRAF", "TEJASNET", "TEMBO",
    "TEMPSENS", "TERAI", "TERASOFT", "TEXINFRA", "TEXMOPIPES", "TEXRAIL", "TFCILTD", "TGVSL", "THAKDEV",
    "THEINVEST", "THEMISMED", "THOMASCOOK", "THOMASCOTT", "TIL", "TIMETECHNO", "TIPSFILMS", "TIRUMALCHM",
    "TNPETRO", "TNPL", "TOKYOPLAST", "TOLINS", "TOTAL", "TOUCHWOOD", "TPLPLASTEH", "TRANSRAILL", "TRANSWORLD",
    "TREJHARA", "TRF", "TRIGYN", "TRIVENI", "TRUALT", "TSFINV", "TURTLEMINT", "TUTIALKA", "TVSELECT",
    "TVSSCS", "TVTODAY", "UDAYJEW", "UDS", "UEL", "UFO", "UGROCAP", "ULTRAMAR", "UMIYA-MRO", "UNIDT",
    "UNIECOM", "UNIENTER", "UNITEDTEA", "URAVIDEF", "UTTAMSUGAR", "V2RETAIL", "VAIBHAVGBL", "VALIANTLAB",
    "VALIANTORG", "VASUPRADA", "VESUVIUS", "VETO", "VGL", "VIDHIING", "VIDYAWIRES", "VIKRAMSOLR", "VIKRAN",
    "VINCOFE", "VINYLINDIA", "VIPIND", "VIRAT", "VISAKAIND", "VITAL", "VLSFINANCE", "VRAJ", "VRLLOG",
    "VSSL", "VSTIND", "VSTL", "WAAREEINDO", "WAKEFIT", "WALCHANNAG", "WANBURY", "WCIL", "WEBELSOLAR",
    "WEIZMANIND", "WEL", "WELSPLSOL", "WEWIN", "WHBRADY", "WINDMACHIN", "WIPL", "WORTHPERI", "WPIL",
    "WSI", "XCHANGING", "XELPMOC", "XTRANET", "YOGI", "YATRA", "ZAGGLE", "ZEEL", "ZENITHEXPO", "ZIMLAB",
    "ZODIAC", "ZODIACLOTH", "ZUARI", "ZUARIIND"
]

def check_insolvency_and_warnings(soup):
    text_blob = soup.get_text().lower()
    red_keywords = [
        "insolvency", "cirp", "nclt", "resolution professional",
        "corporate insolvency", "interim resolution professional", "going concern issue"
    ]
    if any(k in text_blob for k in red_keywords):
        return True

    alerts = soup.find_all(["div", "p", "span"], class_=lambda c: c and any(x in str(c).lower() for x in ["warning", "danger", "alert", "caution"]))
    for alert in alerts:
        a_text = alert.get_text().lower()
        if any(k in a_text for k in ["default", "insolvency", "nclt", "going concern", "suspended"]):
            return True

    return False

def get_screener_data(symbol):
    url = f"https://www.screener.in/company/{symbol}/consolidated/"
    try:
        res = requests.get(url, headers=HEADERS, timeout=8)
        if res.status_code == 404:
            url = f"https://www.screener.in/company/{symbol}/"
            res = requests.get(url, headers=HEADERS, timeout=8)
            
        if res.status_code != 200:
            return None

        soup = BeautifulSoup(res.text, "html.parser")
        
        h1 = soup.find("h1")
        name = h1.get_text(strip=True) if h1 else symbol

        sector_text = ""
        crumbs = soup.find("div", class_="breadcrumbs") or soup.find("ul", class_="breadcrumbs")
        if crumbs:
            sector_text = crumbs.get_text(separator=" ", strip=True).lower()

        mcap_val = None
        for span in soup.find_all("span", string=re.compile(r"Market Cap", re.I)):
            parent = span.find_parent("li")
            if parent:
                num = parent.find("span", class_="number")
                if num:
                    val_str = num.text.replace(",", "").strip()
                    m = re.search(r"[\d.]+", val_str)
                    if m:
                        mcap_val = float(m.group(0))
                        break

        total_debt_cr = 0.0
        bs_section = soup.find("section", id="balance-sheet")
        if bs_section:
            for tr in bs_section.find_all("tr"):
                first_col = tr.find(["td", "th"])
                if first_col and "borrowings" in first_col.get_text().lower():
                    tds = tr.find_all("td")
                    if len(tds) > 1:
                        last_val = tds[-1].get_text(strip=True).replace(",", "")
                        m = re.search(r"[\d.]+", last_val)
                        if m:
                            total_debt_cr = float(m.group(0))
                            break

        if total_debt_cr == 0.0:
            for span in soup.find_all("span", string=re.compile(r"^\s*Debt\s*$", re.I)):
                parent = span.find_parent("li")
                if parent:
                    num = parent.find("span", class_="number")
                    if num:
                        val_str = num.text.replace(",", "").strip()
                        m = re.search(r"[\d.]+", val_str)
                        if m:
                            total_debt_cr = float(m.group(0))
                            break

        doc_url = None
        agency_name = "Audited Disclosures"
        for a in soup.find_all("a", href=True):
            href = a["href"]
            t = a.get_text(strip=True).lower()
            if any(ag in t for ag in ["crisil", "care", "icra", "india ratings", "infomerics"]) or "rating update" in t:
                doc_url = href if href.startswith("http") else f"https://www.screener.in{href}"
                agency_name = a.get_text(strip=True)
                break

        annual_sales = None
        ebitda_positive = False
        profit_table = soup.find("section", id="profit-loss")
        if profit_table:
            for tr in profit_table.find_all("tr"):
                first_col = tr.find(["td", "th"])
                if first_col and "sales" in first_col.get_text().lower():
                    tds = tr.find_all("td")
                    if len(tds) > 1:
                        last_val = tds[-1].get_text(strip=True).replace(",", "")
                        m = re.search(r"[\d.]+", last_val)
                        if m:
                            annual_sales = float(m.group(0))
                            break

            for tr in profit_table.find_all("tr"):
                first_col = tr.find(["td", "th"])
                if first_col and "operating profit" in first_col.get_text().lower():
                    tds = tr.find_all("td")
                    if len(tds) > 1:
                        last_op = tds[-1].get_text(strip=True).replace(",", "")
                        if last_op and not last_op.startswith("-"):
                            ebitda_positive = True
                            break

        is_stressed = check_insolvency_and_warnings(soup)

        return {
            "symbol": symbol,
            "company_name": name,
            "mcap": mcap_val,
            "total_debt": total_debt_cr,
            "sector": sector_text,
            "doc_url": doc_url,
            "agency": agency_name,
            "annual_sales": annual_sales,
            "ebitda_positive": ebitda_positive,
            "is_stressed": is_stressed
        }
    except Exception:
        return None

def extract_document_text(doc_url):
    try:
        res = requests.get(doc_url, headers=HEADERS, timeout=12)
        if res.status_code != 200 or len(res.content) < 500:
            return ""

        content_type = res.headers.get("Content-Type", "").lower()
        if "pdf" in content_type or doc_url.lower().endswith(".pdf") or res.content.startswith(b"%PDF"):
            reader = pypdf.PdfReader(io.BytesIO(res.content))
            pages = []
            for p in reader.pages[:5]:
                txt = p.extract_text()
                if txt:
                    pages.append(txt)
            return " ".join(pages)
        else:
            soup = BeautifulSoup(res.text, "html.parser")
            for t in soup(["script", "style", "nav", "footer"]):
                t.decompose()
            return soup.get_text(separator=" ", strip=True)
    except Exception:
        return ""

def batch_process_gemini(batch_candidates):
    """
    3 stocks ke PDF text ko ek saath Gemini AI ko bhejta hai.
    Returns: Dict of {SYMBOL: {order_book_cr, pdf_debt_cr, timeline_months, thesis}}
    """
    if not GEMINI_API_KEY or not batch_candidates:
        return {}

    stocks_text_bundle = ""
    for item in batch_candidates:
        stocks_text_bundle += f"\n\n=== STOCK: {item['symbol']} ===\n{item['text'][:3200]}\n"

    prompt = f"""
You are a senior equity research analyst. Analyze the following batch of credit rating rationale documents for up to 3 companies.
For EACH company marked with '=== STOCK: SYMBOL ===', extract:
1. "order_book_cr": Float unexecuted order backlog in Crores INR (0.0 if not found).
2. "total_debt_cr": Float Total Debt/Borrowings from 'Key Financial Indicators' table or text in Crores INR (0.0 if not found).
3. "timeline_months": Execution tenure in months (integer, default 24).
4. "thesis": 1-line crisp summary highlighting backlog and debt health.

Return a JSON array of objects. Exactly follow this structure:
[
  {{
    "symbol": "SYMBOL",
    "order_book_cr": 0.0,
    "total_debt_cr": 0.0,
    "timeline_months": 24,
    "thesis": "..."
  }}
]
"""

    payload = {
        "contents": [{"parts": [{"text": prompt + stocks_text_bundle}]}],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json"
        }
    }
    
    # Gemini 3.5 Lite endpoint
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-lite:generateContent?key={GEMINI_API_KEY}"
    
    try:
        res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=20)
        
        # Fallback to flash-lite if specific alias varies
        if res.status_code == 404:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={GEMINI_API_KEY}"
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=20)

        if res.status_code == 200:
            raw = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
            if raw.startswith("```"):
                raw = re.sub(r"^```[a-z]*|```$", "", raw).strip()
            data = json.loads(raw)
            result = {}
            for row in data:
                sym = row.get("symbol", "").upper()
                result[sym] = {
                    "order_book_cr": float(row.get("order_book_cr", 0.0)),
                    "pdf_debt_cr": float(row.get("total_debt_cr", 0.0)),
                    "timeline_months": int(row.get("timeline_months", 24)),
                    "thesis": row.get("thesis", "Order backlog verified via AI.")
                }
            return result
    except Exception as e:
        print(f"   ⚠️ Gemini Batch Error: {e}")

    # Fallback to regex if AI call fails
    fallback_res = {}
    for item in batch_candidates:
        txt = item["text"]
        pats = [
            r'(?:unexecuted\s+order\s+book|order\s+backlog|order\s+book|under-construction\s+portfolio)\s+(?:has\s+grown|stood\s+at|stands\s+at|at|of)?\s*(?:around|~)?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)',
            r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)\s+(?:of\s+unexecuted\s+orders|order\s+book)'
        ]
        val = 0.0
        for pat in pats:
            m = re.search(pat, txt, re.I)
            if m:
                val = float(m.group(1).replace(",", ""))
                break
        fallback_res[item["symbol"]] = {
            "order_book_cr": val,
            "pdf_debt_cr": 0.0,
            "timeline_months": 24,
            "thesis": f"Order backlog of ₹{val:,.1f} Cr."
        }
    return fallback_res

def run():
    print("=" * 75)
    print(f"🚀 UNIFIED RADAR: SCANNING {len(WATCHLIST_SYMBOLS)} STOCKS")
    print(f"   🤖 Batched AI Processing (3 Stocks/Call) with 15s Cooldown")
    print(f"   🛡️ Universal Guards: Debt/MCap <= {MAX_DEBT_TO_MCAP_RATIO}x & CIRP/NCLT Blocked")
    print("=" * 75)

    hidden_gems = []
    all_tracked_orders = []
    turnaround_sales_gems = []
    order_doc_queue = []

    for idx, symbol in enumerate(WATCHLIST_SYMBOLS, 1):
        info = get_screener_data(symbol)
        if not info or not info["mcap"]:
            continue

        sym = info["symbol"]
        name = info["company_name"]
        mcap = info["mcap"]
        debt = info["total_debt"]
        sector = info["sector"]
        doc_url = info["doc_url"]
        sales = info["annual_sales"]
        ebitda_ok = info["ebitda_positive"]
        is_stressed = info["is_stressed"]

        if is_stressed:
            print(f"[{idx}/{len(WATCHLIST_SYMBOLS)}] ⛔ Disqualified {sym}: Under Insolvency / CIRP.")
            continue

        # Check for order-book eligible stocks
        is_non_order_sector = any(bad in sector for bad in NON_ORDER_SECTORS)
        if not is_non_order_sector and doc_url:
            doc_text = extract_document_text(doc_url)
            # Local keyword prescreen
            if any(k in doc_text.lower() for k in ["order book", "unexecuted", "backlog", "order intake", "total debt"]):
                print(f"[{idx}/{len(WATCHLIST_SYMBOLS)}] 📥 Queued for AI: {name} ({sym})")
                order_doc_queue.append({
                    "symbol": sym,
                    "company_name": name,
                    "market_cap_cr": mcap,
                    "total_debt_cr": debt,
                    "doc_url": doc_url,
                    "text": doc_text
                })

        # Sales Turnaround Engine (Screener Only)
        debt_to_mcap = round(debt / mcap, 2) if mcap > 0 else 999.0
        if debt_to_mcap <= MAX_DEBT_TO_MCAP_RATIO and sales and sales > mcap and ebitda_ok:
            sales_multiple = round(sales / mcap, 2)
            ps_val = round(mcap / sales, 2)
            turnaround_sales_gems.append({
                "symbol": sym,
                "company_name": name,
                "market_cap_cr": mcap,
                "total_debt_cr": debt,
                "debt_to_mcap": debt_to_mcap,
                "annual_sales_cr": sales,
                "sales_to_mcap_multiple": sales_multiple,
                "ps_ratio": ps_val,
                "catalyst": f"P/S: {ps_val}x + Positive EBITDA + Debt/MCap: {debt_to_mcap}x (Safe)"
            })

        time.sleep(0.15)

    # =========================================================================
    # BATCHED GEMINI AI EXECUTION (3 Stocks per API call + 15 sec sleep)
    # =========================================================================
    print("\n" + "=" * 75)
    print(f"⚡ DISPATCHING {len(order_doc_queue)} CANDIDATES TO GEMINI (BATCH SIZE: 3, SLEEP: 15s)")
    print("=" * 75)

    batch_size = 3
    for i in range(0, len(order_doc_queue), batch_size):
        chunk = order_doc_queue[i:i + batch_size]
        chunk_syms = [item["symbol"] for item in chunk]
        print(f"\n📦 Processing Batch {i//batch_size + 1}: {chunk_syms}...")

        ai_results = batch_process_gemini(chunk)

        for stock in chunk:
            s_sym = stock["symbol"]
            m_cap = stock["market_cap_cr"]
            debt_val = stock["total_debt_cr"]
            metrics = ai_results.get(s_sym, {})
            
            order_val = metrics.get("order_book_cr", 0.0)
            pdf_debt = metrics.get("pdf_debt_cr", 0.0)

            # AI Debt Recovery from PDF table
            if debt_val == 0.0 and pdf_debt > 0.0:
                debt_val = pdf_debt
                print(f"   🔍 AI Debt Recovery from PDF for {s_sym}: ₹{debt_val:,.1f} Cr")

            d_to_mcap = round(debt_val / m_cap, 2) if m_cap > 0 else 999.0

            if order_val > 0:
                if d_to_mcap > MAX_DEBT_TO_MCAP_RATIO:
                    print(f"   ⛔ Disqualified {s_sym} after AI: Debt/MCap {d_to_mcap}x > {MAX_DEBT_TO_MCAP_RATIO}x")
                    continue

                multiple = round(order_val / m_cap, 2)
                record = {
                    "symbol": s_sym,
                    "company_name": stock["company_name"],
                    "market_cap_cr": m_cap,
                    "total_debt_cr": debt_val,
                    "debt_to_mcap": d_to_mcap,
                    "pending_order_book_cr": order_val,
                    "order_to_mcap_multiple": multiple,
                    "execution_timeline_months": metrics.get("timeline_months", 24),
                    "thesis": metrics.get("thesis", f"Backlog of ₹{order_val:,.1f} Cr."),
                    "source_doc": stock["doc_url"]
                }
                all_tracked_orders.append(record)
                if multiple >= 1.0:
                    hidden_gems.append(record)
                    print(f"   🔥 [HIDDEN GEM] {s_sym}: Backlog ₹{order_val:,.1f} Cr | {multiple}x MCap | Debt: {d_to_mcap}x")

        # 15 seconds break between batches
        if i + batch_size < len(order_doc_queue):
            print("⏳ 15s rate-limit cooldown before next batch...")
            time.sleep(15)

    # Sort and dump
    hidden_gems.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)
    all_tracked_orders.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)
    turnaround_sales_gems.sort(key=lambda x: x["sales_to_mcap_multiple"], reverse=True)

    final_report = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_scanned": len(WATCHLIST_SYMBOLS),
        "guards_applied": {
            "max_debt_to_mcap": MAX_DEBT_TO_MCAP_RATIO,
            "insolvency_and_cirp_filtered": True
        },
        "total_hidden_gems_multiple_gt_1": len(hidden_gems),
        "total_tracked_order_books": len(all_tracked_orders),
        "total_sales_turnaround_gems": len(turnaround_sales_gems),
        "hidden_gems": hidden_gems,
        "all_tracked_orders": all_tracked_orders,
        "turnaround_sales_gems": turnaround_sales_gems
    }

    with open(OUTPUT_REPORT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_report, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 75)
    print(f"✅ UNIFIED SCAN FINISHED!")
    print(f"   🔥 Hidden Gems (Order Book >= 1.0x): {len(hidden_gems)}")
    print(f"   📋 All Order Book Tracked: {len(all_tracked_orders)}")
    print(f"   🚀 Clean Sales Turnaround Gems (Sales > MCap): {len(turnaround_sales_gems)}")
    print(f"   💾 Saved into: {OUTPUT_REPORT_FILE}")
    print("=" * 75)

if __name__ == "__main__":
    run()
