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

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

# 🚫 Non-Order Sectors: Inhe direct skip karenge
EXCLUDED_SECTORS = [
    "bank", "financial services", "finance", "nbfc", "housing finance",
    "information technology", "it services", "software", "consulting",
    "fast moving consumer goods", "fmcg", "consumer goods", "retail",
    "healthcare", "pharmaceuticals", "pharma", "diagnostic", "hospital",
    "media", "entertainment", "broadcasting", "publishing",
    "hotel", "restaurant", "travel", "tourism"
]

# Aapke 1,392 watchlist symbols
WATCHLIST_SYMBOLS = [
    "20MICRONS", "21STCENMGM", "3PLAND", "5PAISA", "A2ZINFRA", "AAATECH", "AAKASH", "AAREYDRUGS",
    "AARON", "AARTIDRUGS", "AARTISURF", "AARVI", "AASTHA", "ABANSENT", "ABCOTS", "ABFRL", "ABINFRA",
    "ABLBL", "ABMINTLLTD", "ABMKNO", "ACE", "ACEINTEG", "ACI", "ACL", "ACMESOLAR", "ADFFOODS",
    "ADDIND", "ADL", "ADSL", "ADVANCE", "ADVANIHOTR", "ADVENZYMES", "ADVENTHTL", "ADVIKCA", "AEPL",
    "AEROENTER", "AERONEU", "AEROPLANE", "AFCONS", "AFFORDABLE", "AFIL", "AFSL", "AGARIND", "AGIIL",
    "AGRITECH", "AGROPHOS", "AHCL", "AHLADA", "AHLEAST", "AIRAN", "AIROLAM", "AJMERA", "AJOONI",
    "AKASH", "AKG", "AKSHAR", "AKSHARCHEM", "ALANKIT", "ALEMBICLTD", "ALGOQUANT", "ALKALI", "ALLCARGO",
    "ALLTIME", "ALOKINDS", "ALPA", "ALPINETEX", "AMARJOTHI", "AMBICAAGAR", "AMJLAND", "AMNPLST",
    "ANDHRAPAP", "ANDHRSUGAR", "ANDREWYU", "ANIKINDS", "ANNAPURNA", "ANNU", "ANSALBU", "ANTGRAPHIC",
    "ANUHPHR", "AONESTEELS", "APARINDS", "APCL", "APEX", "APOLLO", "APTECHT", "AQYLON", "ARCHIDPLY",
    "ARCHIES", "ARCIL", "ARCL", "ARDEE", "ARENTERP", "ARFIN", "ARIHANTCAP", "ARIHANTSUP", "ARIS",
    "ARKADE", "ARMEE", "AROGRANITE", "ARTEMISMED", "ARTNIRMAN", "ARVEE", "ARVINDFASN", "ASAHIINDIA",
    "ASAHISONG", "ASAL", "ASHIANA", "ASHIMASYN", "ASHOKA", "ASHOKAMET", "ASIANENE", "ASIANHOTNR",
    "ASIANTILES", "ASIANTNE", "ASMS", "ASPINWALL", "ATALREAL", "ATAM", "ATL", "ATLANTAA", "ATLASCYCLE",
    "ATULAUTO", "AURUM", "AURUS", "AUSOMENT", "AUSTENG", "AUTOIND", "AVANCE", "AVANTEL", "AVONMORE",
    "AVROIND", "AVTNPL", "AWFIS", "AWHCL", "AXITA", "AXTEL", "AYE", "AYMSYNTEX", "AZADIND", "BAGFILMS",
    "BAIDFIN", "BAJAJCON", "BAJAJELEC", "BAJAJHCARE", "BAJAJHIND", "BAJAJINDEF", "BAJAJST", "BAJEL",
    "BALAJEE", "BALAJITELE", "BALAXI", "BALKRISHNA", "BALMLAWRIE", "BALPHARMA", "BANARBEADS", "BANG",
    "BANKA", "BANSALWIRE", "BANSWRAS", "BATLIBOI", "BBTCL", "BCG", "BCLIND", "BCONCEPTS", "BCPL",
    "BEARDSELL", "BECTORFOOD", "BEDMUTHA", "BEEKAY", "BELLACASA", "BEML", "BEPL", "BESTAGRO", "BFINVEST",
    "BFUTILITIE", "BHAGCHEM", "BHAGERIA", "BHAGYANGR", "BHANDARI", "BHARATGEAR", "BHARATSE", "BHARATWIRE",
    "BIGBLOC", "BIOFILCHEM", "BIRLACABLE", "BIRLAMONEY", "BLACKROSE", "BLAL", "BLBLIMITED", "BLIL",
    "BLKASHYAP", "BLS", "BLSE", "BLUECLOUDS", "BLUECOAST", "BLUSPRING", "BMWVENTLTD", "BNAGROCHEM",
    "BODALCHEM", "BOHRAIND", "BOMDYEING", "BONLON", "BORANA", "BOROLTD", "BORORENEW", "BOROSCI",
    "BPL", "BRAHMINFRA", "BRIGHOTEL", "BRIGHTBR", "BRNL", "BROOKS", "BSHSL", "BSL", "BSOFT", "BTML",
    "BVCL", "BYKE", "CAMLINFINE", "CAMPUS", "CANTABIL", "CAPACITE", "CAPITALSFB", "CAPTRUST", "CCAVENUE",
    "CCCL", "CCHHL", "CEIGALL", "CELEBRITY", "CELLO", "CENTEXT", "CENTRUM", "CEWATER", "CGVAK",
    "CHEMBOND", "CHEMCON", "CHEMCRUX", "CHEMFAB", "CHEMPLASTS", "CIFL", "CINELINE", "CINEVISTA",
    "CLEDUCATE", "CLSEL", "CMRGREEN", "CMSINFO", "COASTCORP", "COFFEEDAY", "COMFINTE", "COMPEAU",
    "COMPUSOFT", "COMSYN", "CONFIPET", "CONSOFINVT", "CORALFINAC", "CORDELIA", "CORDSCABLE", "CPCAP",
    "CPEDU", "CPL", "CRAMC", "CRAVATEX", "CREATIVEYE", "CREST", "CRIZAC", "CROWN", "CSBBANK", "CSLFINANCE",
    "CSM", "CYBERTECH", "DALMIASUG", "DAMCAPITAL", "DANGEE", "DAVANGERE", "DBCORP", "DBEIL", "DBL",
    "DBOL", "DBREALTY", "DCAL", "DCBBANK", "DCI", "DCM", "DCMFINSERV", "DCMNVL", "DCMSIL", "DCMSRIND",
    "DCW", "DCXINDIA", "DDEVPLSTIK", "DECNGOLD", "DEEDEV", "DEEPA", "DELTACORP", "DELTAMAGNT", "DEN",
    "DENTA", "DEVIT", "DEVX", "DGCONTENT", "DHAMPURSUG", "DHANBANK", "DHARMAJ", "DHATRE", "DHRUV",
    "DIAMINESQ", "DIFFNKG", "DIGIDRIVE", "DIGISPICE", "DIGITIDE", "DISHTV", "DJML", "DLINKINDIA", "DMCC",
    "DNAMEDIA", "DOLATALGO", "DOLLAR", "DOLLEX", "DONEAR", "DPWIRES", "DRCSYSTEMS", "DREAMFOLKS", "DTIL",
    "DUCON", "DVL", "DWARKESH", "DYCL", "DYNPRO", "EASEMYTRIP", "EASTWEST", "ECORECO", "ECOSMOBLTY",
    "EFCIL", "EIEL", "EIFFL", "EIHAHOTELS", "EKC", "ELECON", "ELECTCAST", "ELEVATE", "ELGIRUBCO", "ELIN",
    "ELITECON", "ELLEN", "ELPROINTL", "EMAMIPAP", "EMAMIREAL", "EMBDL", "EMIL", "EMKAY", "EMMBI",
    "EMPOWER", "EMSLIMITED", "ENERGYDEV", "ENIL", "ENKEIWHEL", "EPACK", "EPACKPEB", "EPL", "EQUITASBNK",
    "ESSARSHPNG", "ESSENTIA", "ESTER", "EUREKAFORB", "EUROBOND", "EUROPRATIK", "EUROTEXIND", "EVEREADY",
    "EXCELSOFT", "EXICOM", "EXXARO", "FABTECH", "FAZE3Q", "FCL", "FCSSOFT", "FDC", "FEDDERSHOL", "FEDFINA",
    "FIBERWEB", "FILATEX", "FILATFASH", "FINKURVE", "FINOPB", "FINPIPE", "FIRSTCRY", "FISCHER", "FLAIR",
    "FMGOETZE", "FMNL", "FOCUS", "FOODSIN", "FUSION", "GAEL", "GAJA", "GANDHAR", "GANESHCP", "GANESHBE",
    "GANGAFORGE", "GANGESSECU", "GARUDA", "GATEWAY", "GAUDIUMIVF", "GAYAHWS", "GAYAPROJ", "GEECEE",
    "GEEKAYWIRE", "GEMAROMA", "GENCON", "GENESYS", "GENSOL", "GENUSPAPER", "GENUSPOWER", "GEOJITFSL",
    "GFLLIMITED", "GHCL", "GHCLTEXTIL", "GICHSGFIN", "GILLANDERS", "GIPCL", "GKB", "GKENERGY", "GKSL",
    "GLASSWALL", "GLFL", "GLOBAL", "GLOBALE", "GLOBALVECT", "GLOBE", "GLOBECIVIL", "GLOTTIS", "GMRP&UI",
    "GNRL", "GOACARBON", "GOCLCORP", "GOCOLORS", "GODAVARIB", "GOKUL", "GOKULAGRO", "GOLDIAM", "GOLDTECH",
    "GOODLUCK", "GOPAL", "GOYALALUM", "GPPL", "GPTHEALTH", "GPTINFRA", "GRANDOAK", "GRAUWEIL", "GREAVESCOT",
    "GREENLAM", "GREENPANEL", "GREENPLY", "GREENPOWER", "GRMOVER", "GSFC", "GSLSU", "GSPCROP", "GSS",
    "GTECJAINX", "GTL", "GTLINFRA", "GTPL", "GUFICBIO", "GUJAPOLLO", "GUJRAFFIA", "GUJTHEM", "GULPOLY",
    "GYFTR", "HALDER", "HALDYNGL", "HAMPTON", "HAPPSTMNDS", "HARDWYN", "HARIOMPIPE", "HARRMALAYA",
    "HARSHA", "HATHWAY", "HAVISHA", "HAZOOR", "HBESD", "HBPOR", "HBSL", "HCC", "HCL-INSYS", "HEADSUP",
    "HEALTHX", "HECPROJECT", "HEGAM", "HEIDELBERG", "HEMIPROP", "HERANBA", "HERITGFOOD", "HEROMOTORS",
    "HEXATRADEX", "HGINFRA", "HGM", "HGS", "HIKAL", "HILINFRA", "HILTON", "HIMATSEIDE", "HINDADH",
    "HINDALUMI", "HINDCOMPOS", "HINDCON", "HINDOILEXP", "HINDWAREAP", "HISARMETAL", "HITECH", "HITECHCORP",
    "HLEGLAS", "HLVLTD", "HMAAGRO", "HMVL", "HPAL", "HPIL", "HPL", "HRYNSHP", "HTEL", "HTMEDIA", "HUBTOWN",
    "HUHTAMAKI", "HYBRIDFIN", "IBULLSLTD", "ICIL", "IEX", "IFGLEXPOR", "IGARASHI", "IGCL", "IITL", "IKIO",
    "IMAGICAA", "INA", "INCREDIBLE", "INDBANK", "INDIACEM", "INDIAGLYCO", "INDIANCARD", "INDIANHUME",
    "INDIQUBE", "INDOAMIN", "INDOBORAX", "INDOCO", "INDOFARM", "INDORAMA", "INDOSTAR", "INDOTHAI", "INDOUS",
    "INDOWIND", "INDRAMEDCO", "INDSWFTLAB", "INDTERRAIN", "INFOBEAN", "INFOMEDIA", "INNOVANA", "INNOVISION",
    "INOXGREEN", "INSPIRISYS", "INTENTECH", "INTLCONV", "INVENTURE", "IOLCP", "IONEXCHANG", "IPL",
    "IPRINGLTD", "IRIS", "IRISDOREME", "IRMENERGY", "ISFT", "ISHANCH", "ITL", "IVALUE", "IVC", "IVP",
    "IWP", "IXIGO", "JAGRAN", "JAGSNPHARM", "JAIBALAJI", "JAICORPLTD", "JAIPURKURT", "JAMNAAUTO", "JARO",
    "JAYAGROGN", "JAYBARMARU", "JAYKAY", "JAYNECOIND", "JAYSREETEA", "JETFREIGHT", "JHS", "JINDWORLD",
    "JISLDVREQS", "JISLJALEQS", "JITFINFRA", "JKIL", "JKIPL", "JKLAKSHMI", "JKPAPER", "JKTYRE", "JLHL",
    "JMA", "JNKINDIA", "JOCIL", "JSLL", "JTEKTINDIA", "JTLIND", "JUNIPER", "JWL", "JYOTHYLAB", "JYOTISTRUC",
    "KAKATCEM", "KALAMANDIR", "KALPATARU", "KAMATHOTEL", "KAMANWALA", "KAMDHENU", "KAMOPAINTS", "KANANIIND",
    "KANCHI", "KANCOTEA", "KANORICHEM", "KANPRPLA", "KARMAENG", "KAYA", "KCP", "KDGREEN", "KEC", "KECL",
    "KEEPLEARN", "KELLTONTEC", "KESORAMIND", "KEYFINSERV", "KHADIM", "KHAICHEM", "KHAITANLTD", "KHANDSE",
    "KILITCH", "KIRANVYPAR", "KIRLFER", "KISSHT", "KITEX", "KJMCFIN", "KKCL", "KMCSHIL", "KNACK",
    "KNAGRI", "KNRCON", "KOHINOOR", "KOKUYOCMLN", "KOLTEPATIL", "KOPRAN", "KOTHARIPET", "KOTHARIPRO",
    "KOTIC", "KOTYARK", "KPEL", "KPIGREEN", "KRBL", "KREBSBIO", "KRIDHANINF", "KRISHANA", "KRISHIVAL",
    "KRITI", "KRITIKA", "KRITINUT", "KRONOX", "KROSS", "KSE", "KSOLVES", "KUANTUM", "KWIL", "LAGNAM",
    "LAHOTIOV", "LAL", "LAMBODHARA", "LANCER", "LANDMARK", "LANDSMILL", "LAOPALA", "LASERPOWER", "LATENTVIEW",
    "LATTEYS", "LAXMICOT", "LAXMIDENTL", "LAXMIINDIA", "LCCPROJECT", "LEAPIND", "LEMERITE", "LEMONTREE",
    "LEXUS", "LFIC", "LGHL", "LIBAS", "LIBERTSHOE", "LIKHITHA", "LINC", "LKPSEC", "LOKESHMACH", "LORDSCHLO",
    "LOTUSEYE", "LOVABLE", "LOYALTEX", "LPDC", "LUMINO", "LXCHEM", "LYKALABS", "MAANALU", "MADHAV",
    "MADHAVIPL", "MADHUCON", "MADRASFERT", "MAFATIND", "MAGNUM", "MAHAPEXLTD", "MAHEPC", "MAHESHWARI",
    "MAHLIFE", "MAHLOG", "MAKERSL", "MALUPAPER", "MAMATA", "MANAKALUCO", "MANAKCOAT", "MANAKSIA", "MANAKSTEEL",
    "MANALIPETC", "MANBA", "MANCREDIT", "MANGALAM", "MANINFRA", "MANOMAY", "MANORG", "MARALOVER", "MARATHON",
    "MARINE", "MARKOLINES", "MARSONS", "MASFIN", "MASKINVEST", "MASTERTR", "MAWANASUG", "MAXIND", "MBAPL",
    "MBEL", "MBLINFRA", "MCL", "MCLOUD", "MCLEODRUSS", "MEDIASSIST", "MEDICAMEQ", "MEDICO", "MEGASTAR",
    "MEIL", "MENONBE", "MERCANTILE", "MERCURYEV", "METROGLOBL", "MFML", "MGEL", "MHRIL", "MICEL", "MIDHANI",
    "MINDTECK", "MIRZAINT", "MITCON", "MITTAL", "MKEXIM", "MKPL", "MLKFOOD", "MMP", "MMTC", "MMWL",
    "MOBIKWIK", "MODINATUR", "MODIRUBBER", "MODIS", "MODISONLTD", "MODTHREAD", "MOHITE", "MOHITIND",
    "MOIL", "MOKSH", "MOL", "MOLDTECH", "MOMSBELIEF", "MONARCH", "MOREPENLAB", "MOSCHIP", "MOTISONS",
    "MOTOGENFIN", "MPIMANIPAL", "MSL", "MSPL", "MTNL", "MUFIN", "MUFTI", "MUKANDLTD", "MUKESHB", "MUKTAARTS",
    "MUNJALAU", "MUNJALSHOW", "MURUDCERA", "MUTHOOTCAP", "MUTHOOTMF", "MVGJL", "MWL", "NACLIND", "NAGREEKCAP",
    "NAGREEKEXP", "NAHARCAP", "NAHARINDUS", "NAHARPOLY", "NAHARSPING", "NARMADA", "NATCAPSUQ", "NATHBIOGEN",
    "NATIONSTD", "NAVKARCORP", "NAVKARURB", "NAVNETEDUL", "NCC", "NCLIND", "NDL", "NDLVENTURE", "NDTV",
    "NECLIFE", "NELCAST", "NETWORK18", "NEWGEN", "NEXTMEDIA", "NFL", "NGIL", "NIBL", "NICCOPAR", "NIITLTD",
    "NIITMTS", "NILAINFRA", "NILASPACES", "NIMBSPROJ", "NIPPOBATRY", "NIRAJ", "NIRAJISPAT", "NITCO",
    "NITIRAJ", "NKIND", "NOCIL", "NOIDATOLL", "NORBTEAEXP", "NORTHARC", "NOVAAGRI", "NRL", "NTCIND", "OBCL",
    "OCCLLTD", "ODIGMA", "ODYCORP", "OILCOUNTUB", "OMAXAUTO", "OMAXE", "OMINFRAL", "OMPOWER", "ONEPOINT",
    "ONIDA", "ONIXSOLAR", "ONMOBILE", "ONWARDTEC", "OPTIFIN", "ORBTEXP", "ORCHASP", "ORICONENT", "ORIENTALTL",
    "ORIENTBELL", "ORIENTCEM", "ORIENTCER", "ORIENTELEC", "ORIENTHOT", "ORIENTPPR", "ORIENTTECH", "ORIRAIL",
    "ORTINGLOBE", "OSWALAGRO", "OSWALGREEN", "OSWALPUMPS", "OSWALSEEDS", "PACEDIGITK", "PACIFICI", "PAISALO",
    "PAKKA", "PALASHSECU", "PALREDTEC", "PANACEABIO", "PANAMAPET", "PANCHMAHQ", "PANORAMA", "PANSARI",
    "PARACABLES", "PARAGMILK", "PARASPETRO", "PARKHOTELS", "PARNAXLAB", "PASHUPATI", "PASUPTAC", "PATELENG",
    "PATELRMART", "PATINTLOG", "PAVNAIND", "PBMPOLY", "PDMJEPAPER", "PDSL", "PEARLPOLY", "PENIND", "PENINLAND",
    "PFS", "PHOENXINTL", "PIGL", "PILITA", "PIONEEREMB", "PLASTIBLEN", "PLATIND", "PLAZACABLE", "PML", "PNC",
    "PNCINFRA", "PNBGILTS", "POCL", "PODDARMENT", "POEL", "POLYSPIN", "PONNIERODE", "PPAP", "PPL", "PRABHA",
    "PRAENG", "PRAJIND", "PRAKASH", "PRAKASHSTL", "PRANAV", "PRAVEG", "PRAXIS", "PRECAM", "PREMCO",
    "PREMIERPOL", "PRIMESECU", "PRIMO", "PRINCEPIPE", "PRIORITY", "PRITI", "PRISMX", "PRITIKAUTO", "PROSTARM",
    "PROZONER", "PRUDMOULI", "PRSMJOHNSN", "PTC", "PTL", "PURVA", "PVP", "PVSL", "PYRAMID", "QUESS",
    "QUICKHEAL", "QUINTEGRA", "RACE", "RADAAN", "RADHIKAJWE", "RADIANTCMS", "RADIOCITY", "RAILTEL", "RAIN",
    "RAJESHEXPO", "RAJMET", "RAJRATAN", "RAJSREESUG", "RALLIS", "RAMANEWS", "RAMAPHO", "RAMBHAJO", "RAMCOIND",
    "RAMKY", "RANASUG", "RATNAVEER", "RBA", "RBZJEWEL", "RCF", "REDTAPE", "REFEX", "REGAAL", "REGENCERAM",
    "RELAXO", "RELCHEMQ", "RELIABLE", "RELIGARE", "RELINFRA", "RELTD", "REMSONSIND", "RENUKA", "REPCOHOME",
    "REPL", "REPRO", "RESPONIND", "RETAIL", "RGL", "RHETAN", "RHIM", "RHL", "RICOAUTO", "RIR", "RITCO",
    "RITES", "RKDL", "RKEC", "RKSWAMY", "RMC", "ROHLTD", "ROLEXRINGS", "ROML", "ROSSELLIND", "ROSSARI",
    "ROTO", "ROUTE", "RPOWER", "RPPINFRA", "RRECL", "RRIL", "RSL", "RSSOFTWARE", "RSWM", "RSYSTEMS",
    "RTNINDIA", "RTNPOWER", "RTSPOWR", "RUBFILA", "RUBYMILLS", "RUCHINFRA", "RUCHIRA", "RUDRA", "RUPA",
    "RUSHIL", "RUSTOMJEE", "RVHL", "S&SPOWER", "SAATVIKGL", "SAB", "SADBHAV", "SADBHIN", "SAGARDEEP",
    "SAGCEM", "SAHLIBHFI", "SAHYADRI", "SAICAPI", "SAKHTISUG", "SAKSOFT", "SAKUMA", "SALASAR", "SALONA",
    "SALSTEEL", "SAMBANDAM", "SAMBHAAV", "SAMBHV", "SAMHI", "SAMPANN", "SANDUMA", "SANGHVIMOV", "SANSTAR",
    "SAPPHIRE", "SAPPL", "SAREGAMA", "SARLAPOLY", "SARVESHWAR", "SATIA", "SATIN", "SAURASHCEM", "SAYAJIHOTL",
    "SAYAJIIND", "SBC", "SBFC", "SBGLP", "SCHAND", "SCILAL", "SCODATUBES", "SDBL", "SECMARK", "SECURKLOUD",
    "SEIL", "SEKURITIND", "SEMAC", "SENCO", "SEPC", "SERVOTECH", "SESHAPAPER", "SETL", "SGL", "SGLRES",
    "SHAH", "SHAHALLOYS", "SHAKTIPUMP", "SHALBY", "SHALPAINTS", "SHANKARA", "SHANKESH", "SHANTI", "SHANTIGOLD",
    "SHAREINDIA", "SHBAJRG", "SHEMAROO", "SHERVANI", "SHILGRAVQ", "SHINDL", "SHIPROCKET", "SHIVAAGRO",
    "SHIVACEM", "SHIVALIK", "SHIVAMAUTO", "SHIVAMILLS", "SHIVATEX", "SHK", "SHOPERSTOP", "SHRADDHA",
    "SHRADHA", "SHREDIGCEM", "SHREEPUSHK", "SHREERAMA", "SHREYANIND", "SHRIKRISH", "SHRINGARMS", "SHRIRAMPPS",
    "SHUKRAPHAR", "SHYAMTEL", "SICAGEN", "SIEL", "SIGACHI", "SIGIND", "SIGMA", "SIGNPOST", "SIKKO", "SIL",
    "SILGO", "SILINV", "SILVERTUC", "SIMPLEXINF", "SIMPLXREA", "SINCLAIR", "SINDHUTRAD", "SINGERIND",
    "SINTERCOM", "SIRCA", "SIS", "SKMEGGPROD", "SKYWAYS", "SMCGLOBAL", "SMLT", "SMSPHARMA", "SNOWMAN",
    "SOFTTECH", "SOLARWORLD", "SOMATEX", "SOMICONVEY", "SONAL", "SONATSOFTW", "SOUTHWEST", "SPANDANA",
    "SPARC", "SPCENET", "SPECIALITY", "SPENCERS", "SPIC", "SPLIL", "SPMLINFRA", "SPORTKING", "SRD",
    "SREEL", "SRGHFL", "SRM", "SRTL", "SSDL", "SSWL", "STALLION", "STANLEY", "STARCEMENT", "STARPAPER",
    "STARTECK", "STCINDIA", "STEAMHOUSE", "STEELCAS", "STEELCITY", "STEELXIND", "STERTOOLS", "STLNETWORK",
    "STLSTRINF", "STUDDS", "STYL", "STYLEBAAZA", "SUBEXLTD", "SUDARCOLOR", "SUKHJITS", "SULA", "SUMEDHA",
    "SUMEETINDS", "SUMIT", "SUNDARAM", "SUNFLAG", "SUNLOC", "SUNRAKSHAK", "SUNSHINE", "SUNTECK", "SUPERHOUSE",
    "SUPRAJIT", "SUPREME", "SUPREMEINF", "SURAJEST", "SURAJLTD", "SURAKSHA", "SURANASOL", "SURANAT&P",
    "SURYALA", "SURYALAXMI", "SURYAROSNI", "SURYODAY", "SUVEN", "SUVIDHAA", "SVGLOBAL", "SVPGLOB",
    "SWANCORP", "SWARNSAR", "SWSOLAR", "SYNCOMF", "TAINWALCHM", "TAJGVK", "TAKE", "TALBROAUTO", "TANAA",
    "TANLA", "TARACHAND", "TARAPUR", "TARC", "TARIL", "TARMAT", "TARSONS", "TCC", "TCIEXP", "TCIFINANCE",
    "TEAMGTY", "TECHNOCRAF", "TECILCHEM", "TEJASNET", "TEMBO", "TEMPSENS", "TERAI", "TERASOFT", "TEXINFRA",
    "TEXMOPIPES", "TEXRAIL", "TFCILTD", "TFL", "TGBHOTELS", "TGVSL", "THAKDEV", "THEINVEST", "THEMISMED",
    "THOMASCOOK", "THOMASCOTT", "TIGERLOGS", "TIL", "TIMETECHNO", "TIPSFILMS", "TIRUMALCHM", "TNPETRO",
    "TNPL", "TNTELE", "TOKYOPLAST", "TOLINS", "TOTAL", "TOUCHWOOD", "TOYAMSL", "TPLPLASTEH", "TRACXN",
    "TRANSCOR", "TRANSRAILL", "TRANSWORLD", "TREEHOUSE", "TREJHARA", "TREL", "TRF", "TRIGYN", "TRIVENI",
    "TRU", "TRUALT", "TSFINV", "TTL", "TTML", "TURTLEMINT", "TUTIALKA", "TVSELECT", "TVSSCS", "TVTODAY",
    "UDAYJEW", "UDS", "UEL", "UFO", "UGROCAP", "ULTRAMAR", "UMAEXPORTS", "UMESLTD", "UMIYA-MRO", "UNIDT",
    "UNIECOM", "UNIENTER", "UNIINFO", "UNITECH", "UNITEDPOLY", "UNITEDTEA", "URAVIDEF", "URJA", "USK",
    "UTKARSHBNK", "UTTAMSUGAR", "V2RETAIL", "VAIBHAVGBL", "VAISHALI", "VAKRANGEE", "VALIANTLAB", "VALIANTORG",
    "VARDMNPOLY", "VASCONEQ", "VASUPRADA", "VASWANI", "VEDAVAAG", "VERANDA", "VERTOZ", "VESUVIUS", "VETO",
    "VGCL", "VGL", "VIDHIING", "VIDYAWIRES", "VIKASECO", "VIKASLIFE", "VIKRAMSOLR", "VIKRAN", "VINCOFE",
    "VINEETLAB", "VINNY", "VINYLINDIA", "VIPCLOTHNG", "VIPIND", "VIRAT", "VIRINCHI", "VISACHROME", "VISAKAIND",
    "VISHAL", "VISHWARAJ", "VITAL", "VIVIDHA", "VIVOBIOT", "VLEGOV", "VLSFINANCE", "VMSTMT", "VPRPL",
    "VRAJ", "VRLLOG", "VSSL", "VSTIND", "VSTL", "VTMLTD", "WAAREEINDO", "WAKEFIT", "WALCHANNAG", "WANBURY",
    "WARDINMOBI", "WATERBASE", "WCIL", "WEBELSOLAR", "WEIZMANIND", "WEL", "WELSPLSOL", "WEWIN", "WHBRADY",
    "WILLAMAGOR", "WINDMACHIN", "WIPL", "WORTHPERI", "WPIL", "WSI", "XCHANGING", "XELPMOC", "XTGLOBAL",
    "XTRANET", "YOGI", "ZAGGLE", "ZEEL", "ZEELEARN", "ZEEMEDIA", "ZENITHEXPO", "ZENITHSTL", "ZIMLAB",
    "ZODIAC", "ZODIACLOTH", "ZUARI", "ZUARIIND"
]

def get_screener_details(symbol):
    """Screener se Live Market Cap, Sector, aur Rating Doc fetch karta hai."""
    url = f"https://www.screener.in/company/{symbol}/consolidated/"
    try:
        res = requests.get(url, headers=HEADERS, timeout=8)
        if res.status_code == 404:
            url = f"https://www.screener.in/company/{symbol}/"
            res = requests.get(url, headers=HEADERS, timeout=8)
            
        if res.status_code != 200:
            return None, None, None, symbol, ""

        soup = BeautifulSoup(res.text, "html.parser")
        
        # 1. Company Name
        h1 = soup.find("h1")
        company_name = h1.get_text(strip=True) if h1 else symbol

        # 2. Sector Check & Filter
        sector_text = ""
        crumbs = soup.find("div", class_="breadcrumbs") or soup.find("ul", class_="breadcrumbs")
        if crumbs:
            sector_text = crumbs.get_text(separator=" ", strip=True).lower()
            if any(bad in sector_text for bad in EXCLUDED_SECTORS):
                return None, None, None, symbol, "EXCLUDED_SECTOR"

        # 3. Market Cap Extraction
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

        # 4. Rating Document Discovery
        doc_url = None
        agency_name = "Audited Disclosures"
        for a in soup.find_all("a", href=True):
            href = a["href"]
            t = a.get_text(strip=True).lower()
            if any(ag in t for ag in ["crisil", "care", "icra", "india ratings", "infomerics"]) or "rating update" in t:
                doc_url = href if href.startswith("http") else f"https://www.screener.in{href}"
                agency_name = a.get_text(strip=True)
                break

        return mcap_val, doc_url, agency_name, company_name, sector_text
    except Exception:
        return None, None, None, symbol, ""

def extract_document_text(doc_url):
    """PDF aur HTML dono document types se readable text extract karta hai."""
    try:
        res = requests.get(doc_url, headers=HEADERS, timeout=12)
        if res.status_code != 200 or len(res.content) < 500:
            return ""

        content_type = res.headers.get("Content-Type", "").lower()
        if "pdf" in content_type or doc_url.lower().endswith(".pdf") or res.content.startswith(b"%PDF"):
            reader = pypdf.PdfReader(io.BytesIO(res.content))
            pages = []
            for p in reader.pages[:4]:
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

def parse_order_metrics(text):
    """Keywords check karke unexecuted order book extract karta hai."""
    if not any(k in text.lower() for k in ["order book", "unexecuted", "backlog", "order intake", "under-construction"]):
        return None

    # AI Extraction
    if GEMINI_API_KEY:
        try:
            prompt = f"Analyze text: '{text[:2500]}'. Extract unexecuted order numbers into JSON: {{\"order_book_cr\": 1500.0, \"timeline_months\": 24, \"thesis\": \"short impact summary\"}}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"}
            }
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
            res = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=10)
            if res.status_code == 200:
                raw = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                if raw.startswith("```"):
                    raw = re.sub(r"^```[a-z]*|```$", "", raw).strip()
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

    # Regex Fallback
    patterns = [
        r'(?:unexecuted\s+order\s+book|order\s+backlog|order\s+book|under-construction\s+portfolio)\s+(?:has\s+grown|stood\s+at|stands\s+at|at|of)?\s*(?:around|~)?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore)',
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
    print(f"🚀 ORDER BOOK RADAR: SCANNING {len(WATCHLIST_SYMBOLS)} STOCKS WITH AUTO-FILTER")
    print("=" * 75)

    all_tracked_orders = []
    hidden_gems = []

    for idx, symbol in enumerate(WATCHLIST_SYMBOLS, 1):
        mcap, doc_url, agency, company_name, sector_info = get_screener_details(symbol)
        
        # Non-Order Sector Skip
        if sector_info == "EXCLUDED_SECTOR":
            print(f"[{idx}/{len(WATCHLIST_SYMBOLS)}] ⏩ Skipping {symbol} (Non-Order Sector: Bank/IT/Pharma/FMCG)")
            continue

        if not mcap:
            continue

        print(f"\n[{idx}/{len(WATCHLIST_SYMBOLS)}] 🔍 Scanning: {company_name} ({symbol}) | MCap: ₹{mcap:,.1f} Cr")
        if not doc_url:
            print("   ℹ️ No direct rating document found.")
            continue

        doc_text = extract_document_text(doc_url)
        if not doc_text:
            continue

        metrics = parse_order_metrics(doc_text)
        if not metrics or metrics["order_book_cr"] <= 0:
            print("   ℹ️ No unexecuted order book disclosed.")
            continue

        order_val = metrics["order_book_cr"]
        multiple = round(order_val / mcap, 2)
        print(f"   🎯 Order Book: ₹{order_val:,.1f} Cr ➔ Multiple: {multiple}x MCap")

        record = {
            "symbol": symbol,
            "company_name": company_name,
            "market_cap_cr": mcap,
            "pending_order_book_cr": order_val,
            "order_to_mcap_multiple": multiple,
            "execution_timeline_months": metrics["timeline_months"],
            "thesis": metrics["thesis"],
            "source_doc": doc_url
        }

        all_tracked_orders.append(record)

        if multiple >= 1.0:
            hidden_gems.append(record)
            print(f"   🔥 [HIDDEN GEM CONFIRMED] Multiple {multiple}x >= 1.0x!")

        time.sleep(0.3)

    all_tracked_orders.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)
    hidden_gems.sort(key=lambda x: x["order_to_mcap_multiple"], reverse=True)

    final_output = {
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_scanned": len(WATCHLIST_SYMBOLS),
        "total_companies_with_order_book": len(all_tracked_orders),
        "total_hidden_gems_multiple_gt_1": len(hidden_gems),
        "hidden_gems": hidden_gems,
        "all_tracked_orders": all_tracked_orders
    }

    with open(OUTPUT_REPORT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 75)
    print(f"✅ COMPLETED: Found {len(hidden_gems)} Hidden Gems (>=1.0x) and {len(all_tracked_orders)} Total Orders.")
    print("=" * 75)

if __name__ == "__main__":
    run()
