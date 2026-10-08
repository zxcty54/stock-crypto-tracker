#!/usr/bin/env python3
"""
MACRO TELEMETRY OFFICIAL DATA HARVESTER
=======================================

Sources:
1. DPIIT / Office of Economic Adviser
   - Eight Core Industries monthly archive
2. PPAC
   - Products-wise petroleum consumption
3. Ministry of Ports, Shipping & Waterways
   - Monthly Major Ports cargo reports
4. NPCI
   - NETC FASTag monthly statistics

IMPORTANT:
- No synthetic/fallback values.
- If an official observation cannot be extracted -> value = None.
- Every observation keeps source URL/status.
- Designed for GitHub Actions.
"""

import io
import json
import os
import re
import time
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

try:
    import pdfplumber
except ImportError:
    pdfplumber = None


OUTPUT_FILE = "macro_telemetry_master.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 "
        "(KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,application/pdf;q=0.8,*/*;q=0.7"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive",
}

TIMEOUT = 30


# ============================================================
# HELPERS
# ============================================================

def clean_num(value):
    if value is None:
        return None

    s = str(value)
    s = s.replace(",", "")
    s = s.replace("%", "")
    s = s.replace("₹", "")
    s = s.strip()

    m = re.search(r"[-+]?\d+(?:\.\d+)?", s)

    if not m:
        return None

    try:
        return float(m.group(0))
    except Exception:
        return None


def get(session, url, timeout=TIMEOUT):
    try:
        r = session.get(
            url,
            headers=HEADERS,
            timeout=timeout,
            allow_redirects=True,
        )

        if r.status_code == 200:
            return r

        print(f"   HTTP {r.status_code}: {url}")

    except Exception as e:
        print(f"   Request failed: {url}")
        print(f"   {e}")

    return None


def extract_pdf_text(content):
    if not pdfplumber:
        return ""

    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            pages = []

            for page in pdf.pages:
                txt = page.extract_text() or ""
                pages.append(txt)

            return "\n".join(pages)

    except Exception as e:
        print(f"   PDF extraction error: {e}")
        return ""


def soup_text(html):
    soup = BeautifulSoup(html, "html.parser")

    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()

    return soup.get_text(" ", strip=True)


def find_pdf_links(html, base_url):
    soup = BeautifulSoup(html, "html.parser")

    links = []

    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        text = a.get_text(" ", strip=True)

        if ".pdf" in href.lower():
            links.append({
                "url": urljoin(base_url, href),
                "text": text
            })

    return links


def month_key(year, month):
    return f"{year:04d}-{month:02d}"


def empty_record(period, source, url=None):
    return {
        "period": period,
        "source": source,
        "source_url": url,
        "status": "NOT_FOUND",
        "value": None,
        "unit": None,
        "retrieved_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    }


# ============================================================
# 1. DPIIT / OEA
# ============================================================

DPIIT_ARCHIVE = (
    "https://eaindustry.nic.in/ici_press_release_archive.asp"
)


def get_dpiit_archive(session):
    print("\n" + "=" * 70)
    print("🏭 DPIIT / OEA — EIGHT CORE INDUSTRIES")
    print("=" * 70)

    r = get(session, DPIIT_ARCHIVE)

    if not r:
        return []

    soup = BeautifulSoup(r.text, "html.parser")

    documents = []

    for a in soup.find_all("a", href=True):

        text = a.get_text(" ", strip=True)
        href = a["href"]

        combined = f"{text} {href}".lower()

        if (
            ".pdf" in href.lower()
            or "press" in combined
            or "ici" in combined
            or "core" in combined
        ):
            url = urljoin(DPIIT_ARCHIVE, href)

            if url not in [x["url"] for x in documents]:
                documents.append({
                    "text": text,
                    "url": url
                })

    print(f"   Archive links discovered: {len(documents)}")

    return documents


def parse_dpiit_document(session, url, period):
    rec = empty_record(
        period,
        "DPIIT / Office of Economic Adviser",
        url
    )

    r = get(session, url)

    if not r:
        return rec

    content_type = r.headers.get("content-type", "").lower()

    if ".pdf" in url.lower() or "pdf" in content_type:
        text = extract_pdf_text(r.content)
    else:
        text = soup_text(r.text)

    if not text:
        return rec

    # --------------------------------------------------------
    # Cement
    # --------------------------------------------------------

    cement_growth = None
    steel_growth = None

    patterns_cement = [
        r"Cement.*?(?:growth|increased|declined|contraction).*?([-+]?\d+(?:\.\d+)?)\s*%",
        r"Cement\s+([-+]?\d+(?:\.\d+)?)\s*%",
    ]

    for pattern in patterns_cement:
        m = re.search(pattern, text, re.I | re.S)

        if m:
            cement_growth = clean_num(m.group(1))
            break

    patterns_steel = [
        r"Steel.*?(?:growth|increased|declined|contraction).*?([-+]?\d+(?:\.\d+)?)\s*%",
        r"Steel\s+([-+]?\d+(?:\.\d+)?)\s*%",
    ]

    for pattern in patterns_steel:
        m = re.search(pattern, text, re.I | re.S)

        if m:
            steel_growth = clean_num(m.group(1))
            break

    rec["status"] = "PARSED"

    rec["cement_growth_pct"] = cement_growth
    rec["steel_growth_pct"] = steel_growth

    return rec


def scrape_dpiit(session):
    documents = get_dpiit_archive(session)

    output = []

    for doc in documents:

        text = doc["text"].lower()

        # Try to infer month/year from link/text
        m = re.search(
            r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
            r"[^0-9]{0,5}(20\d\d)",
            text,
            re.I
        )

        if not m:
            m = re.search(
                r"(20\d\d)[-_](0?[1-9]|1[0-2])",
                text
            )

        if not m:
            continue

        if m.group(1).isdigit():
            year = int(m.group(1))
            month = int(m.group(2))
        else:
            months = {
                "jan": 1, "feb": 2, "mar": 3,
                "apr": 4, "may": 5, "jun": 6,
                "jul": 7, "aug": 8, "sep": 9,
                "oct": 10, "nov": 11, "dec": 12
            }

            month = months[m.group(1).lower()]
            year = int(m.group(2))

        period = month_key(year, month)

        parsed = parse_dpiit_document(
            session,
            doc["url"],
            period
        )

        parsed["document_text"] = doc["text"]

        output.append(parsed)

        time.sleep(0.25)

    # Deduplicate
    unique = {}

    for row in output:
        unique[row["period"]] = row

    print(f"   DPIIT records: {len(unique)}")

    return sorted(
        unique.values(),
        key=lambda x: x["period"]
    )


# ============================================================
# 2. PPAC
# ============================================================

PPAC_URL = (
    "https://ppac.gov.in/index.php/"
    "consumption/products-wise"
)


def scrape_ppac(session):
    print("\n" + "=" * 70)
    print("🛢️ PPAC — PETROLEUM PRODUCTS")
    print("=" * 70)

    result = {
        "source": "PPAC",
        "source_url": PPAC_URL,
        "status": "NOT_FOUND",
        "records": []
    }

    r = get(session, PPAC_URL)

    if not r:
        return result

    soup = BeautifulSoup(r.text, "html.parser")

    tables = soup.find_all("table")

    print(f"   Tables found: {len(tables)}")

    for table in tables:

        rows = table.find_all("tr")

        if not rows:
            continue

        headers = [
            c.get_text(" ", strip=True)
            for c in rows[0].find_all(["th", "td"])
        ]

        for row in rows[1:]:

            cells = [
                c.get_text(" ", strip=True)
                for c in row.find_all(["td", "th"])
            ]

            if not cells:
                continue

            label = cells[0].lower()

            product = None

            if "high speed diesel" in label or label == "diesel":
                product = "HSD"

            elif "bitumen" in label:
                product = "BITUMEN"

            elif "petroleum coke" in label or "petcoke" in label:
                product = "PETCOKE"

            if not product:
                continue

            result["status"] = "PARSED"

            for i, value in enumerate(cells[1:], start=1):

                if i >= len(headers):
                    break

                month_name = headers[i]

                if month_name.lower() in [
                    "total",
                    "annual",
                    ""
                ]:
                    continue

                numeric = clean_num(value)

                if numeric is None:
                    continue

                result["records"].append({
                    "product": product,
                    "month": month_name,
                    "value": numeric,
                    "raw": value,
                    "source_url": PPAC_URL
                })

    print(
        f"   PPAC records extracted: "
        f"{len(result['records'])}"
    )

    return result


# ============================================================
# 3. MINISTRY OF PORTS
# ============================================================

PORTS_URL = (
    "https://www.shipmin.gov.in/"
    "transport-reseach/"
    "monthly-cargo-traffic-handled-major-ports"
)


def scrape_ports(session):
    print("\n" + "=" * 70)
    print("🚢 MINISTRY OF PORTS — MAJOR PORTS")
    print("=" * 70)

    result = {
        "source": (
            "Ministry of Ports, Shipping "
            "& Waterways"
        ),
        "source_url": PORTS_URL,
        "status": "NOT_FOUND",
        "records": []
    }

    r = get(session, PORTS_URL)

    if not r:
        return result

    soup = BeautifulSoup(r.text, "html.parser")

    links = []

    for a in soup.find_all("a", href=True):

        txt = a.get_text(" ", strip=True)
        href = a["href"]

        combined = f"{txt} {href}".lower()

        if (
            "major port" in combined
            and (
                "2023" in combined
                or "2024" in combined
                or "2025" in combined
                or "2026" in combined
            )
        ):
            links.append({
                "text": txt,
                "url": urljoin(PORTS_URL, href)
            })

    # Also include PDF links directly
    for a in soup.find_all("a", href=True):

        href = a["href"]

        if ".pdf" in href.lower():

            links.append({
                "text": a.get_text(" ", strip=True),
                "url": urljoin(PORTS_URL, href)
            })

    # Deduplicate
    unique = {}

    for x in links:
        unique[x["url"]] = x

    links = list(unique.values())

    print(f"   Port documents discovered: {len(links)}")

    for doc in links:

        title = doc["text"]

        # Find year/month in title
        m = re.search(
            r"(January|February|March|April|May|June|July|"
            r"August|September|October|November|December)"
            r"[^0-9]{0,10}(20\d\d)",
            title,
            re.I
        )

        if not m:
            continue

        months = {
            "january": 1,
            "february": 2,
            "march": 3,
            "april": 4,
            "may": 5,
            "june": 6,
            "july": 7,
            "august": 8,
            "september": 9,
            "october": 10,
            "november": 11,
            "december": 12
        }

        month = months[m.group(1).lower()]
        year = int(m.group(2))

        period = month_key(year, month)

        page = get(session, doc["url"])

        if not page:
            continue

        pdf_links = find_pdf_links(
            page.text,
            doc["url"]
        )

        # If page itself points to PDF
        for pdf in pdf_links:

            pdf_url = pdf["url"]

            pdf_resp = get(session, pdf_url)

            if not pdf_resp:
                continue

            text = extract_pdf_text(
                pdf_resp.content
            )

            if not text:
                continue

            # Find total cargo numbers around
            # "Total Cargo handled"
            cargo = None

            patterns = [
                r"Total Cargo handled\s*"
                r"([\d,]+(?:\.\d+)?)\s*MMT",

                r"Total Cargo.*?"
                r"([\d,]+(?:\.\d+)?)\s*"
                r"million tonnes",

                r"cargo handled.*?"
                r"([\d,]+(?:\.\d+)?)\s*MMT",
            ]

            for pattern in patterns:

                cm = re.search(
                    pattern,
                    text,
                    re.I | re.S
                )

                if cm:
                    cargo = clean_num(
                        cm.group(1)
                    )
                    break

            result["records"].append({
                "period": period,
                "cargo_traffic_mmt": cargo,
                "source_url": pdf_url,
                "status": (
                    "PARSED"
                    if cargo is not None
                    else "DOCUMENT_FOUND_VALUE_NOT_PARSED"
                )
            })

            result["status"] = "PARSED"

            break

        time.sleep(0.2)

    # Deduplicate periods
    unique = {}

    for row in result["records"]:
        unique[row["period"]] = row

    result["records"] = sorted(
        unique.values(),
        key=lambda x: x["period"]
    )

    print(
        f"   Port monthly records: "
        f"{len(result['records'])}"
    )

    return result


# ============================================================
# 4. NPCI FASTAG
# ============================================================

FASTAG_URL = (
    "https://www.npci.org.in/"
    "product/netc/product-statistics"
)


def scrape_fastag(session):
    print("\n" + "=" * 70)
    print("🛣️ NPCI — NETC FASTag")
    print("=" * 70)

    result = {
        "source": "NPCI NETC FASTag",
        "source_url": FASTAG_URL,
        "status": "NOT_FOUND",
        "records": []
    }

    r = get(session, FASTAG_URL)

    if not r:
        return result

    soup = BeautifulSoup(r.text, "html.parser")

    tables = soup.find_all("table")

    print(f"   Tables found: {len(tables)}")

    month_map = {
        "january": 1,
        "february": 2,
        "march": 3,
        "april": 4,
        "may": 5,
        "june": 6,
        "july": 7,
        "august": 8,
        "september": 9,
        "october": 10,
        "november": 11,
        "december": 12
    }

    for table in tables:

        rows = table.find_all("tr")

        if not rows:
            continue

        for row in rows:

            cells = [
                c.get_text(" ", strip=True)
                for c in row.find_all(
                    ["td", "th"]
                )
            ]

            if len(cells) < 4:
                continue

            month_cell = cells[0]

            m = re.search(
                r"(January|February|March|April|May|June|"
                r"July|August|September|October|November|December)"
                r"[-\s]+(20\d\d)",
                month_cell,
                re.I
            )

            if not m:
                continue

            month = month_map[
                m.group(1).lower()
            ]

            year = int(m.group(2))

            period = month_key(year, month)

            banks = clean_num(cells[1])
            tags = clean_num(cells[2])
            volume = clean_num(cells[3])
            amount = (
                clean_num(cells[4])
                if len(cells) > 4
                else None
            )

            result["records"].append({
                "period": period,
                "banks_live": banks,
                "tag_issuance_btd": tags,
                "volume_mn_mtd": volume,
                "amount_cr_mtd": amount,
                "source_url": FASTAG_URL,
                "status": "PARSED"
            })

            result["status"] = "PARSED"

    # Deduplicate
    unique = {}

    for row in result["records"]:
        unique[row["period"]] = row

    result["records"] = sorted(
        unique.values(),
        key=lambda x: x["period"]
    )

    print(
        f"   FASTag monthly records: "
        f"{len(result['records'])}"
    )

    return result


# ============================================================
# MASTER OUTPUT
# ============================================================

def load_existing():
    if not os.path.exists(OUTPUT_FILE):
        return {
            "schema_version": "1.0",
            "generated_at": None,
            "snapshots": []
        }

    try:
        with open(
            OUTPUT_FILE,
            "r",
            encoding="utf-8"
        ) as f:
            return json.load(f)

    except Exception:
        return {
            "schema_version": "1.0",
            "generated_at": None,
            "snapshots": []
        }


def run():
    print("=" * 80)
    print("🚀 OFFICIAL MACRO TELEMETRY HARVESTER")
    print("=" * 80)

    print(
        f"Time: "
        f"{NOW.strftime('%Y-%m-%d %H:%M:%S IST')}"
    )

    session = requests.Session()

    # --------------------------------------------------------
    # Scrape
    # --------------------------------------------------------

    dpiit = scrape_dpiit(session)
    ppac = scrape_ppac(session)
    ports = scrape_ports(session)
    fastag = scrape_fastag(session)

    # --------------------------------------------------------
    # Snapshot
    # --------------------------------------------------------

    snapshot = {
        "retrieved_at": NOW.strftime(
            "%Y-%m-%d %H:%M:%S IST"
        ),
        "sources": {
            "dpiit_oea": dpiit,
            "ppac": ppac,
            "ports": ports,
            "npcI_fastag": fastag
        }
    }

    # --------------------------------------------------------
    # Preserve history
    # --------------------------------------------------------

    db = load_existing()

    if not isinstance(
        db.get("snapshots"),
        list
    ):
        db["snapshots"] = []

    db["snapshots"].insert(
        0,
        snapshot
    )

    # Keep last 36 scraper runs
    db["snapshots"] = db["snapshots"][:36]

    db["generated_at"] = NOW.strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )

    # --------------------------------------------------------
    # Write
    # --------------------------------------------------------

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8"
    ) as f:
        json.dump(
            db,
            f,
            ensure_ascii=False,
            indent=2
        )

    print("\n" + "=" * 80)
    print("✅ HARVEST COMPLETE")
    print("=" * 80)

    print(
        f"📁 Output: {OUTPUT_FILE}"
    )

    print(
        f"🏭 DPIIT records: "
        f"{len(dpiit)}"
    )

    print(
        f"🛢️ PPAC records: "
        f"{len(ppac.get('records', []))}"
    )

    print(
        f"🚢 Port records: "
        f"{len(ports.get('records', []))}"
    )

    print(
        f"🛣️ FASTag records: "
        f"{len(fastag.get('records', []))}"
    )

    print("=" * 80)


if __name__ == "__main__":
    run()

Iske liye dependency

"requirements.txt":

requests>=2.31.0
beautifulsoup4>=4.12.0
pdfplumber>=0.11.0

Ek limitation deliberately rakhi hai: PPAC aur NPCI pages dynamically change ho sakte hain, isliye code sirf wahi table values save karega jo page ke HTML mein actually milti hain. PPAC officially historical/current report downloads provide karta hai, aur NPCI ka page monthly statistics table expose karta hai. citeturn0search1turn0search0

Ports ke liye "ipa.nic.in" ko hit nahi kiya gaya hai. Ministry of Ports ka official monthly archive use kiya gaya hai, jahan Major Ports ke monthly documents listed hain. citeturn0search2turn0search7

DPIIT ke liye official ICI Press Release Archive use ho raha hai, jisme 2023, 2024, 2025 aur 2026 ke monthly releases listed hain. citeturn0search6

Lekin ek baat: ye first version archive discovery + extraction engine hai. Isko GitHub Actions mein daalne se pehle local run karke actual output dekhna best hai. Agar kisi source par "records: 0" aata hai, us source ka exact HTML/PDF structure dekhkar parser ko targeted karna hoga—guess karke numbers nahi bharne hain.