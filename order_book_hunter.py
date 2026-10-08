import os
import re
import json
import time
import threading
from urllib.parse import urlsplit
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import io
import requests
from bs4 import BeautifulSoup
import pypdf
from concurrent.futures import ThreadPoolExecutor, as_completed

OUTPUT_REPORT_FILE = "order_radar_report.json"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()

# Universal Guards Parameters
MAX_DEBT_TO_MCAP_RATIO = 1.2
MAX_BOOK_TO_BILL_RATIO = 6.0  # > 6x = Paper backlog trap
MIN_BOOK_TO_BILL_RATIO = 1.0  # < 1x = Insufficient runway
SCRAPE_WORKERS = 2  # Parallelism is for Screener/PDF fetching only; Gemini stays sequential.
SCRAPE_REQUEST_INTERVAL_SECONDS = 5.0  # Minimum gap between requests to the same host.

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}


_host_rate_lock = threading.Lock()
_host_locks = {}
_last_request_at = {}
_host_cooldown_until = {}


def _host_for_url(url):
    return urlsplit(url).netloc.lower()


def _pace_host_request(url):
    """Space requests to each host and honor any active rate-limit cooldown."""
    host = _host_for_url(url)
    with _host_rate_lock:
        host_lock = _host_locks.setdefault(host, threading.Lock())

    with host_lock:
        while True:
            with _host_rate_lock:
                now = time.monotonic()
                last_request_at = _last_request_at.get(host, 0.0)
                cooldown_until = _host_cooldown_until.get(host, 0.0)
                interval_wait = SCRAPE_REQUEST_INTERVAL_SECONDS - (now - last_request_at)
                cooldown_wait = cooldown_until - now
                wait_seconds = max(interval_wait, cooldown_wait, 0.0)
                if wait_seconds <= 0:
                    _last_request_at[host] = now
                    return
            # Recheck after sleeping: another worker may extend the cooldown meanwhile.
            time.sleep(wait_seconds)


def _cooldown_host(url, seconds):
    """Pause all workers targeting the same host after a 429 response."""
    host = _host_for_url(url)
    cooldown_until = time.monotonic() + max(0.0, seconds)
    with _host_rate_lock:
        _host_cooldown_until[host] = max(
            _host_cooldown_until.get(host, 0.0), cooldown_until
        )


def _retry_after_seconds(response, attempt):
    """Use the server's Retry-After header, or the configured host request interval."""
    retry_after = (response.headers.get("Retry-After") or "").strip()
    if retry_after:
        try:
            return max(0.0, float(retry_after))
        except ValueError:
            try:
                retry_at = parsedate_to_datetime(retry_after)
                if retry_at.tzinfo is None:
                    retry_at = retry_at.replace(tzinfo=timezone.utc)
                return max(0.0, (retry_at - datetime.now(timezone.utc)).total_seconds())
            except (TypeError, ValueError, OverflowError):
                pass
    return SCRAPE_REQUEST_INTERVAL_SECONDS


def _get_with_retries(session, url, *, timeout, context, attempts=3):
    """Retry transient network/server errors without changing the selected URL."""
    retryable_statuses = {408, 425, 429, 500, 502, 503, 504}
    for attempt in range(1, attempts + 1):
        try:
            _pace_host_request(url)
            response = session.get(url, headers=HEADERS, timeout=timeout)
        except requests.RequestException as exc:
            # Errno 101 means there is no route to the host; repeating every stock request is futile.
            if "network is unreachable" in str(exc).lower() or attempt == attempts:
                raise
            delay = min(2 ** (attempt - 1), 4)
            print(f"   ↻ {context} request failed ({exc}); retry {attempt + 1}/{attempts} in {delay}s")
            time.sleep(delay)
            continue

        if response.status_code == 429:
            delay = _retry_after_seconds(response, attempt)
            _cooldown_host(url, delay)
            if attempt == attempts:
                print(
                    f"   ⚠️ {context} is still HTTP 429 after {attempts} attempts; "
                    f"pausing this host for {delay:.0f}s before continuing with other symbols"
                )
                return response
            print(
                f"   ↻ {context} returned HTTP 429; pausing this host for "
                f"{delay:.0f}s, then retry {attempt + 1}/{attempts}"
            )
            continue

        if response.status_code in retryable_statuses and attempt < attempts:
            delay = min(2 ** (attempt - 1), 4)
            print(f"   ↻ {context} returned HTTP {response.status_code}; retry {attempt + 1}/{attempts} in {delay}s")
            time.sleep(delay)
            continue
        return response

    raise RuntimeError(f"{context} request failed after {attempts} attempts")


# Sectors jahan order backlog model physically exist nahi karta
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


def parse_market_cap(soup):
    """Extract Screener's Market Cap despite minor changes to the page markup."""
    top_ratios = soup.find(id="top-ratios")
    candidate_items = list(top_ratios.find_all("li")) if top_ratios else []

    # The label may be in data-field or nested inside the name span; avoid relying on span.string.
    for item in candidate_items:
        label = item.get("data-field", "")
        if not label:
            name_node = item.find(class_="name")
            label = name_node.get_text(" ", strip=True) if name_node else ""
        if re.search(r"\bmarket\s*cap(?:italization)?\b", label, re.I):
            value_node = item.find(class_="number") or item.find(class_="value")
            value_text = value_node.get_text(" ", strip=True) if value_node else item.get_text(" ", strip=True)
            match = re.search(r"[\d,]+(?:\.\d+)?", value_text)
            if match:
                return float(match.group(0).replace(",", ""))

    # Fallback: locate the exact label even if it is nested in other inline elements.
    label_nodes = soup.find_all(string=re.compile(r"^\s*market\s*cap(?:italization)?\s*$", re.I))
    for label_node in label_nodes:
        container = label_node.parent
        for _ in range(5):
            if not container:
                break
            value_node = container.find(class_="number") or container.find(class_="value")
            if value_node:
                match = re.search(r"[\d,]+(?:\.\d+)?", value_node.get_text(" ", strip=True))
                if match:
                    return float(match.group(0).replace(",", ""))
            container = container.parent

    # Last fallback for pages where Screener renders the ratio as plain text.
    page_text = soup.get_text(" ", strip=True)
    match = re.search(
        r"\bmarket\s*cap(?:italization)?\b\s*[:\-]?\s*(?:₹\s*)?([\d,]+(?:\.\d+)?)\s*(?:cr\b|crore\b)",
        page_text,
        re.I,
    )
    if match:
        return float(match.group(1).replace(",", ""))

    return None


def get_screener_data(symbol):
    """Fetch and parse a Screener company page."""
    consolidated_url = f"https://www.screener.in/company/{symbol}/consolidated/"
    standalone_url = f"https://www.screener.in/company/{symbol}/"
    url = consolidated_url
    session = requests.Session()
    try:
        res = _get_with_retries(session, url, timeout=7, context=f"Screener {symbol}")

        if res.status_code == 404:
            # Some symbols do not have a consolidated page at all.
            url = standalone_url
            res = _get_with_retries(session, url, timeout=7, context=f"Screener standalone {symbol}")
        elif res.status_code == 200:
            # Screener may return HTTP 200 for a consolidated page whose ratios and tables are blank.
            # Check for Market Cap data, not only the HTTP status, before accepting that page.
            consolidated_soup = BeautifulSoup(res.text, "html.parser")
            if parse_market_cap(consolidated_soup) is None:
                print(
                    f"   ↪ Screener consolidated page has no Market Cap for {symbol}; "
                    "trying the standalone company page."
                )
                standalone_res = _get_with_retries(
                    session,
                    standalone_url,
                    timeout=7,
                    context=f"Screener standalone fallback {symbol}",
                )
                if standalone_res.status_code == 200:
                    res = standalone_res
                    url = standalone_url
                elif standalone_res.status_code == 429:
                    print(
                        f"   ⚠️ Screener standalone fallback remained HTTP 429 for {symbol}; "
                        "marking this symbol failed and continuing."
                    )
                    return None
                elif standalone_res.status_code != 404:
                    print(
                        f"   ⚠️ Screener standalone fallback returned HTTP "
                        f"{standalone_res.status_code} for {symbol}; keeping the consolidated page."
                    )

        if res.status_code == 429:
            print(f"   ⚠️ Screener still returned HTTP 429 for {symbol}; marking this symbol failed and continuing.")
            return None
        if res.status_code != 200:
            print(f"   ⚠️ Screener returned HTTP {res.status_code} for {symbol}")
            return None

        soup = BeautifulSoup(res.text, "html.parser")
        
        h1 = soup.find("h1")
        name = h1.get_text(strip=True) if h1 else symbol

        sector_text = ""
        crumbs = soup.find("div", class_="breadcrumbs") or soup.find("ul", class_="breadcrumbs")
        if crumbs:
            sector_text = crumbs.get_text(separator=" ", strip=True).lower()

        mcap_val = parse_market_cap(soup)
        if mcap_val is None:
            page_title = soup.title.get_text(" ", strip=True) if soup.title else "(no title)"
            page_text = soup.get_text(" ", strip=True)
            label_match = re.search(r"\bmarket\s*cap(?:italization)?\b", page_text, re.I)
            if label_match:
                context_start = max(0, label_match.start() - 80)
                context_end = min(len(page_text), label_match.end() + 180)
                market_cap_context = page_text[context_start:context_end]
            else:
                market_cap_context = page_text[:260]
            top_ratios_present = soup.find(id="top-ratios") is not None
            print(
                f"   ⚠️ Market Cap not extracted for {symbol}; "
                f"top-ratios={'present' if top_ratios_present else 'missing'}; "
                f"title={page_title!r}; market-cap context={market_cap_context!r}"
            )

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
            "annual_sales": annual_sales or 0.0,
            "ebitda_positive": ebitda_positive,
            "is_stressed": is_stressed
        }
    except Exception as e:
        print(f"   ⚠️ Screener fetch/parse failed for {symbol}: {type(e).__name__}: {e}")
        error_text = str(e).lower()
        if "network is unreachable" in error_text:
            raise RuntimeError(
                "Runner cannot reach Screener (network route unavailable); stopping scan to preserve the last report."
            ) from e
        return None


def extract_document_text(doc_url, symbol="UNKNOWN"):
    """Fetch the selected Screener credit document and extract text from every page."""
    try:
        with requests.Session() as session:
            res = _get_with_retries(
                session,
                doc_url,
                timeout=(10, 30),
                context=f"Credit document {symbol}",
            )

        if res.status_code != 200:
            print(f"   ⚠️ Credit document fetch failed for {symbol}: HTTP {res.status_code} ({doc_url})")
            return ""
        if len(res.content) < 500:
            print(f"   ⚠️ Credit document for {symbol} is too small ({len(res.content)} bytes): {doc_url}")
            return ""

        content_type = res.headers.get("Content-Type", "").lower()
        if "pdf" in content_type or doc_url.lower().endswith(".pdf") or res.content.startswith(b"%PDF"):
            reader = pypdf.PdfReader(io.BytesIO(res.content))
            page_texts = []
            for page_number, page in enumerate(reader.pages, start=1):
                try:
                    text = page.extract_text()
                    if text:
                        page_texts.append(text)
                except Exception as e:
                    print(f"   ⚠️ PDF text extraction failed for {symbol}, page {page_number}: {e}")

            full_text = "\n".join(page_texts)
            if not full_text.strip():
                print(f"   ⚠️ Credit PDF for {symbol} has no extractable text ({len(reader.pages)} pages): {doc_url}")
            else:
                print(f"   📄 Credit PDF fetched for {symbol}: {len(reader.pages)} pages, {len(full_text):,} extracted characters")
            return full_text
        else:
            soup = BeautifulSoup(res.text, "html.parser")
            for t in soup(["script", "style", "nav", "footer"]):
                t.decompose()
            full_text = soup.get_text(separator=" ", strip=True)
            print(f"   📄 Credit document fetched for {symbol}: {len(full_text):,} extracted characters")
            return full_text
    except Exception as e:
        print(f"   ⚠️ Credit document fetch/parse failed for {symbol} ({doc_url}): {type(e).__name__}: {e}")
        return ""


def _regex_fallback_order_books(batch_candidates):
    """Best-effort extraction if Gemini is unavailable or its request fails."""
    fallback_res = {}
    for item in batch_candidates:
        txt = item["text"]
        pats = [
            r'(?:unexecuted\s+order\s+book|order\s+backlog|order\s+book|under-construction\s+portfolio)\s+(?:has\s+grown|stood\s+at|stands\s+at|at|of)?\s*(?:around|~)?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)',
            r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)\s+(?:of\s+unexecuted\s+orders|order\s+book)'
        ]
        val = 0.0
        for pat in pats:
            match = re.search(pat, txt, re.I)
            if match:
                val = float(match.group(1).replace(",", ""))
                break
        fallback_res[item["symbol"]] = {
            "order_book_cr": val,
            "pdf_debt_cr": 0.0,
            "timeline_months": 24,
            "thesis": f"Order backlog of ₹{val:,.1f} Cr."
        }
    return fallback_res


def batch_process_gemini(batch_candidates):
    """Send the complete extracted credit-document text to Gemini."""
    if not batch_candidates:
        return {}
    if not GEMINI_API_KEY:
        print("   ⚠️ GEMINI_API_KEY is missing; using regex fallback for this batch.")
        return _regex_fallback_order_books(batch_candidates)

    stocks_text_bundle = ""
    for item in batch_candidates:
        full_text = item["text"]
        print(f"   📤 Sending full credit document for {item['symbol']} ({len(full_text):,} characters)")
        stocks_text_bundle += f"\n\n=== STOCK: {item['symbol']} ===\n{full_text}\n"

    prompt = f"""
You are an equity research analyst. Analyze these credit rating rationale documents for up to 3 companies.
For EACH company marked with '=== STOCK: SYMBOL ===', extract:
1. "order_book_cr": Float number of unexecuted/pending order backlog in Crores INR (0.0 if not found).
2. "total_debt_cr": Float number of Total Debt/Borrowings from 'Key Financial Indicators' table in Crores INR (0.0 if not found).
3. "timeline_months": Execution months (integer, default 24).
4. "thesis": Crisp 1-line summary stating order backlog and balance sheet debt health.

Return ONLY a pure JSON array of objects without markdown backticks:
[
  {{
    "symbol": "SYMBOL",
    "order_book_cr": 0.0,
    "total_debt_cr": 0.0,
    "timeline_months": 24,
    "thesis": "Crisp one line statement."
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
    
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-lite:generateContent?key={GEMINI_API_KEY}"
    
    try:
        res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=60)
        if res.status_code == 404:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={GEMINI_API_KEY}"
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=60)

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
        print(f"   ⚠️ Gemini returned HTTP {res.status_code}; using regex fallback.")
    except Exception as e:
        print(f"   ⚠️ Gemini Batch Extraction failed; using regex fallback: {type(e).__name__}: {e}")

    return _regex_fallback_order_books(batch_candidates)


def run():
    start_time = time.time()
    print("=" * 75)
    print(
        f"🚀 TURBO RADAR: PARALLEL SCRAPING {len(WATCHLIST_SYMBOLS)} STOCKS "
        f"({SCRAPE_WORKERS} workers; {SCRAPE_REQUEST_INTERVAL_SECONDS:.1f}s per host)"
    )
    print("   🤖 Gemini calls run sequentially (scraping threads are not used for AI).")
    print(f"   🛡️ Reality Filter: Book-to-Bill <= {MAX_BOOK_TO_BILL_RATIO}x & Debt/MCap <= {MAX_DEBT_TO_MCAP_RATIO}x")
    print("=" * 75)

    hidden_gems = []
    all_tracked_orders = []
    paper_backlog_traps = []
    turnaround_sales_gems = []
    order_doc_queue = []

    # 1. PARALLEL SCREENER PAGE SCRAPING. Gemini is not invoked from these threads.
    scanned_results = []
    screener_failed_symbols = []
    missing_mcap_symbols = []
    with ThreadPoolExecutor(max_workers=SCRAPE_WORKERS) as executor:
        future_to_symbol = {
            executor.submit(get_screener_data, sym): sym
            for sym in WATCHLIST_SYMBOLS
        }
        for future in as_completed(future_to_symbol):
            sym = future_to_symbol[future]
            try:
                res = future.result()
            except RuntimeError as exc:
                if "network route unavailable" in str(exc).lower():
                    for pending in future_to_symbol:
                        pending.cancel()
                    raise
                print(f"   ⚠️ Screener worker failed for {sym}: {type(exc).__name__}: {exc}")
                screener_failed_symbols.append(sym)
                continue
            except Exception as exc:
                print(f"   ⚠️ Screener worker failed for {sym}: {type(exc).__name__}: {exc}")
                screener_failed_symbols.append(sym)
                continue

            if res and res.get("mcap"):
                scanned_results.append(res)
            elif res:
                print(f"   ⚠️ Screener page parsed but Market Cap was not found for {sym}")
                missing_mcap_symbols.append(sym)
            else:
                screener_failed_symbols.append(sym)

            completed = len(scanned_results) + len(screener_failed_symbols) + len(missing_mcap_symbols)
            if completed % 50 == 0 or completed == len(WATCHLIST_SYMBOLS):
                print(
                    f"   📥 Screener progress: {completed}/{len(WATCHLIST_SYMBOLS)} symbols; "
                    f"{len(scanned_results)} pages parsed"
                )

    print(
        f"⚡ Screener scraping complete in {round((time.time() - start_time)/60, 2)} mins: "
        f"parsed {len(scanned_results)}/{len(WATCHLIST_SYMBOLS)} company pages; "
        f"request/parse failures: {len(screener_failed_symbols)}, "
        f"market-cap misses: {len(missing_mcap_symbols)}."
    )

    if not scanned_results:
        raise RuntimeError(
            f"No Screener company pages parsed out of {len(WATCHLIST_SYMBOLS)}. "
            "Check runner network access; refusing to overwrite the existing radar report."
        )

    # 2. APPLY EXISTING FILTERS AND BUILD THE CREDIT-DOCUMENT SCRAPE QUEUE.
    credit_doc_candidates = []
    for info in scanned_results:
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
            continue

        is_non_order_sector = any(bad in sector for bad in NON_ORDER_SECTORS)
        if not is_non_order_sector and doc_url:
            # doc_url remains the first qualifying Screener credit/rating document.
            credit_doc_candidates.append(info)

        # Sales Turnaround Engine (criteria unchanged)
        debt_to_mcap = round(debt / mcap, 2) if mcap > 0 else 999.0
        if debt_to_mcap <= MAX_DEBT_TO_MCAP_RATIO and sales > mcap and ebitda_ok:
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

    # 3. PARALLEL CREDIT-DOCUMENT FETCH/EXTRACTION. This ends before Gemini starts.
    print(
        f"📄 Fetching {len(credit_doc_candidates)} selected Screener credit documents "
        f"with {SCRAPE_WORKERS} scraping workers..."
    )
    with ThreadPoolExecutor(max_workers=SCRAPE_WORKERS) as executor:
        future_to_info = {
            executor.submit(extract_document_text, info["doc_url"], info["symbol"]): info
            for info in credit_doc_candidates
        }
        for future in as_completed(future_to_info):
            info = future_to_info[future]
            try:
                doc_text = future.result()
            except Exception as exc:
                print(
                    f"   ⚠️ Credit-document worker failed for {info['symbol']}: "
                    f"{type(exc).__name__}: {exc}"
                )
                continue

            if any(k in doc_text.lower() for k in ["order book", "unexecuted", "backlog", "order intake", "total debt"]):
                order_doc_queue.append({
                    "symbol": info["symbol"],
                    "company_name": info["company_name"],
                    "market_cap_cr": info["mcap"],
                    "total_debt_cr": info["total_debt"],
                    "annual_sales_cr": info["annual_sales"],
                    "doc_url": info["doc_url"],
                    "text": doc_text
                })

    # 3. BATCHED GEMINI AI EXECUTION (3 Stocks/Batch + 15s pause)
    print("\n" + "=" * 75)
    print(f"🤖 DISPATCHING {len(order_doc_queue)} CANDIDATES TO GEMINI (BATCH SIZE: 3, SLEEP: 15s)")
    print("=" * 75)

    batch_size = 3
    for i in range(0, len(order_doc_queue), batch_size):
        chunk = order_doc_queue[i:i + batch_size]
        chunk_syms = [item["symbol"] for item in chunk]
        print(f"📦 Batch {i//batch_size + 1}: {chunk_syms}...")

        ai_results = batch_process_gemini(chunk)

        for stock in chunk:
            s_sym = stock["symbol"]
            m_cap = stock["market_cap_cr"]
            debt_val = stock["total_debt_cr"]
            sales_val = stock["annual_sales_cr"]
            metrics = ai_results.get(s_sym, {})
            
            order_val = metrics.get("order_book_cr", 0.0)
            pdf_debt = metrics.get("pdf_debt_cr", 0.0)

            # AI Debt Recovery from PDF
            if debt_val == 0.0 and pdf_debt > 0.0:
                debt_val = pdf_debt

            d_to_mcap = round(debt_val / m_cap, 2) if m_cap > 0 else 999.0

            if order_val > 0:
                if d_to_mcap > MAX_DEBT_TO_MCAP_RATIO:
                    continue

                order_to_mcap = round(order_val / m_cap, 2)
                order_to_ttm = round(order_val / sales_val, 2) if sales_val > 0 else 0.0
                runway_label = f"{order_to_ttm} Years" if order_to_ttm > 0 else "N/A"

                record = {
                    "symbol": s_sym,
                    "company_name": stock["company_name"],
                    "market_cap_cr": m_cap,
                    "ttm_sales_cr": sales_val,
                    "total_debt_cr": debt_val,
                    "debt_to_mcap": d_to_mcap,
                    "pending_order_book_cr": order_val,
                    "order_to_mcap_multiple": order_to_mcap,
                    "order_to_ttm_sales": order_to_ttm,
                    "revenue_runway_years": runway_label,
                    "execution_timeline_months": metrics.get("timeline_months", 24),
                    "thesis": metrics.get("thesis", f"Backlog of ₹{order_val:,.1f} Cr."),
                    "source_doc": stock["doc_url"]
                }
                
                all_tracked_orders.append(record)

                if order_to_ttm > MAX_BOOK_TO_BILL_RATIO:
                    record["classification"] = "PAPER_BACKLOG_TRAP"
                    record["runway_badge"] = "⚠️ PAPER TRAP (>6 Yrs)"
                    paper_backlog_traps.append(record)
                    print(f"   ⚠️ [PAPER TRAP] {s_sym}: Backlog ₹{order_val:,.1f} Cr vs Sales ₹{sales_val:,.1f} Cr ({order_to_ttm} Yrs)")
                elif order_to_mcap >= 1.0 and order_to_ttm >= MIN_BOOK_TO_BILL_RATIO:
                    record["classification"] = "PRIME_HIDDEN_GEM"
                    record["runway_badge"] = f"🔥 {runway_label} Runway"
                    hidden_gems.append(record)
                    print(f"   🔥 [PRIME ALPHA] {s_sym}: Backlog ₹{order_val:,.1f} Cr | {order_to_mcap}x MCap | Runway: {runway_label} | Debt: {d_to_mcap}x")

        if i + batch_size < len(order_doc_queue):
            time.sleep(15)

    # Sort rankings
    hidden_gems.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)
    all_tracked_orders.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)
    paper_backlog_traps.sort(key=lambda x: x["order_to_ttm_sales"], reverse=True)
    turnaround_sales_gems.sort(key=lambda x: x["sales_to_mcap_multiple"], reverse=True)

    final_report = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_scanned": len(scanned_results),
        "watchlist_size": len(WATCHLIST_SYMBOLS),
        "screener_request_failures": len(screener_failed_symbols),
        "market_cap_parse_failures": len(missing_mcap_symbols),
        "credit_documents_queued": len(order_doc_queue),
        "guards_applied": {
            "max_debt_to_mcap": MAX_DEBT_TO_MCAP_RATIO,
            "max_book_to_bill_runway_years": MAX_BOOK_TO_BILL_RATIO,
            "insolvency_and_cirp_filtered": True
        },
        "total_prime_hidden_gems": len(hidden_gems),
        "total_paper_backlog_traps": len(paper_backlog_traps),
        "total_tracked_order_books": len(all_tracked_orders),
        "total_sales_turnaround_gems": len(turnaround_sales_gems),
        "prime_hidden_gems": hidden_gems,
        "paper_backlog_traps": paper_backlog_traps,
        "all_tracked_orders": all_tracked_orders,
        "turnaround_sales_gems": turnaround_sales_gems
    }

    with open(OUTPUT_REPORT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_report, f, ensure_ascii=False, indent=2)

    total_mins = round((time.time() - start_time) / 60, 2)
    print("\n" + "=" * 75)
    print(f"✅ FINISHED IN JUST {total_mins} MINUTES (Was 60 mins earlier)!")
    print(f"   🔥 Real Execution Alpha Gems: {len(hidden_gems)}")
    print(f"   ⚠️ Paper Backlog Traps Filtered: {len(paper_backlog_traps)}")
    print(f"   📋 Total Order Books Tracked: {len(all_tracked_orders)}")
    print(f"   🚀 Clean Sales Turnaround Gems: {len(turnaround_sales_gems)}")
    print(f"   💾 Saved cleanly into: {OUTPUT_REPORT_FILE}")
    print("=" * 75)


if __name__ == "__main__":
    run()
