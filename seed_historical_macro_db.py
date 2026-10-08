#!/usr/bin/env python3
"""
LIVE MACRO DATA HARVESTER
=========================

Purpose:
    Sirf official sources se raw monthly macro data scrape karna
    aur macro_historical_db.json mein save karna.

NO:
    - AI calculation
    - Buy/Sell signal
    - Stock/company recommendation
    - Synthetic fallback values
    - Hard-coded market numbers

YES:
    - Official government sources
    - Raw monthly observations
    - Source URL
    - Publication/update date where available
    - Scrape status
    - Raw source text where useful

Current sources:
    1. Office of Economic Adviser / DPIIT
       - Cement
       - Steel

    2. PPAC / Ministry of Petroleum & Natural Gas
       - HSD
       - Bitumen

    3. Indian Ports Association
       - Container / port traffic

Output:
    macro_historical_db.json
"""

import io
import os
import re
import json
import time
import requests
import pdfplumber

from bs4 import BeautifulSoup
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin, urlparse


# ============================================================
# CONFIG
# ============================================================

DB_FILE = "macro_historical_db.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
}

REQUEST_TIMEOUT = 30


# ============================================================
# HTTP SESSION
# ============================================================

SESSION = requests.Session()
SESSION.headers.update(HEADERS)


def http_get(url, timeout=REQUEST_TIMEOUT):
    """
    Safe GET request.
    Returns response or None.
    """
    try:
        response = SESSION.get(
            url,
            timeout=timeout,
            allow_redirects=True
        )

        response.raise_for_status()
        return response

    except Exception as exc:
        print(f"   ❌ HTTP error: {url}")
        print(f"      {exc}")
        return None


# ============================================================
# HELPERS
# ============================================================

def clean_text(value):
    if value is None:
        return ""

    value = str(value)
    value = value.replace("\xa0", " ")
    value = re.sub(r"\s+", " ", value)

    return value.strip()


def number_from_text(value):
    """
    Extract first numeric value.

    Examples:
        '41.25' -> 41.25
        '1,234.50' -> 1234.50
        '-' -> None
    """

    if value is None:
        return None

    text = clean_text(value)

    if not text:
        return None

    if text in {"-", "--", "NA", "N/A", "nil", "Nil"}:
        return None

    text = text.replace(",", "")

    match = re.search(
        r"-?\d+(?:\.\d+)?",
        text
    )

    if not match:
        return None

    try:
        return float(match.group(0))
    except Exception:
        return None


def extract_pdf_text(pdf_bytes):
    """
    Extract all text from PDF.
    """
    try:
        output = []

        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                text = page.extract_text()

                if text:
                    output.append(text)

        return "\n".join(output)

    except Exception as exc:
        print(f"   ❌ PDF extraction error: {exc}")
        return ""


def save_json(data):
    """
    Save database atomically.
    """
    temp_file = DB_FILE + ".tmp"

    with open(
        temp_file,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            data,
            f,
            ensure_ascii=False,
            indent=2
        )

    os.replace(temp_file, DB_FILE)


def load_existing_db():
    if not os.path.exists(DB_FILE):
        return {
            "schema_version": "raw-macro-1.0",
            "created_at": NOW.strftime(
                "%Y-%m-%d %H:%M:%S IST"
            ),
            "updated_at": None,
            "sectors": {}
        }

    try:
        with open(
            DB_FILE,
            "r",
            encoding="utf-8"
        ) as f:

            return json.load(f)

    except Exception as exc:
        print(f"⚠️ Existing DB could not be loaded: {exc}")

        return {
            "schema_version": "raw-macro-1.0",
            "created_at": NOW.strftime(
                "%Y-%m-%d %H:%M:%S IST"
            ),
            "updated_at": None,
            "sectors": {}
        }


# ============================================================
# SECTOR INITIALIZER
# ============================================================

def get_sector(db, key, name):
    sectors = db.setdefault("sectors", {})

    if key not in sectors:
        sectors[key] = {
            "sector_key": key,
            "sector_name": name,

            "monthly_demand": [],
            "input_costs": [],
            "supporting_indicators": [],

            "source_documents": [],

            "scrape_metadata": {
                "first_seen": NOW.strftime(
                    "%Y-%m-%d %H:%M:%S IST"
                ),
                "last_updated": None
            }
        }

    return sectors[key]


# ============================================================
# GENERIC APPEND
# ============================================================

def append_unique(records, new_record, unique_keys):
    """
    Prevent duplicate monthly observations.
    """

    for old in records:

        if all(
            old.get(k) == new_record.get(k)
            for k in unique_keys
        ):
            return

    records.append(new_record)


# ============================================================
# 1. DPIIT / OEA CORE INDUSTRIES
# ============================================================

DPIIT_HOME = "https://eaindustry.nic.in/"


def find_dpiit_pdf():
    """
    Find latest Core Industries PDF from official OEA website.

    No fake fallback.
    """

    print("\n🏗️ DPIIT / OEA")

    response = http_get(DPIIT_HOME)

    if not response:
        return None

    soup = BeautifulSoup(
        response.text,
        "html.parser"
    )

    candidates = []

    for a in soup.find_all("a", href=True):

        href = urljoin(
            response.url,
            a["href"]
        )

        text = clean_text(
            a.get_text(" ", strip=True)
        ).lower()

        href_lower = href.lower()

        if not href_lower.endswith(".pdf"):
            continue

        score = 0

        if "core" in text:
            score += 5

        if "core" in href_lower:
            score += 5

        if "industr" in text:
            score += 2

        if "industr" in href_lower:
            score += 2

        if "press" in text:
            score += 1

        if score > 0:
            candidates.append(
                (score, href)
            )

    if not candidates:
        print("   ⚠️ Core Industries PDF link not found.")
        return None

    candidates.sort(
        key=lambda x: x[0],
        reverse=True
    )

    pdf_url = candidates[0][1]

    print(f"   📄 PDF: {pdf_url}")

    return pdf_url


def parse_dpiit_core():
    """
    Extract Cement and Steel from latest official
    Eight Core Industries release.
    """

    pdf_url = find_dpiit_pdf()

    if not pdf_url:
        return {
            "status": "SOURCE_NOT_FOUND",
            "source_url": DPIIT_HOME,
            "observations": []
        }

    response = http_get(pdf_url)

    if not response:
        return {
            "status": "DOWNLOAD_FAILED",
            "source_url": pdf_url,
            "observations": []
        }

    text = extract_pdf_text(
        response.content
    )

    if not text:
        return {
            "status": "PDF_TEXT_EXTRACTION_FAILED",
            "source_url": pdf_url,
            "observations": []
        }

    observations = []

    # --------------------------------------------------------
    # Try to identify reporting month/year
    # --------------------------------------------------------

    period = None

    period_patterns = [
        r"FOR\s+([A-Z]+,\s+\d{4})",
        r"FOR\s+THE\s+MONTH\s+OF\s+([A-Z]+,\s+\d{4})",
        r"FOR\s+([A-Z]+\s+\d{4})"
    ]

    for pattern in period_patterns:

        match = re.search(
            pattern,
            text,
            re.IGNORECASE
        )

        if match:
            period = clean_text(
                match.group(1)
            )
            break

    # --------------------------------------------------------
    # Extract industry rows
    # --------------------------------------------------------

    industry_patterns = {
        "CEMENT": r"\bCement\b",
        "STEEL": r"\bSteel\b"
    }

    for sector_key, pattern in industry_patterns.items():

        match = re.search(
            pattern,
            text,
            re.IGNORECASE
        )

        if not match:
            print(
                f"   ⚠️ {sector_key} row not found."
            )

            continue

        start = max(
            0,
            match.start() - 150
        )

        end = min(
            len(text),
            match.end() + 500
        )

        context = text[start:end]

        # Keep raw context.
        # We DO NOT manufacture a number if parsing
        # is uncertain.
        numbers = re.findall(
            r"\b\d+(?:\.\d+)?\b",
            context
        )

        observations.append({
            "sector_key": sector_key,
            "period_text": period,
            "raw_context": clean_text(context),
            "candidate_numbers": [
                float(x)
                for x in numbers
            ]
        })

    return {
        "status": "SUCCESS",
        "source_url": pdf_url,
        "period": period,
        "raw_text_length": len(text),
        "observations": observations
    }


# ============================================================
# 2. PPAC
# ============================================================

PPAC_CONSUMPTION_URL = (
    "https://ppac.gov.in/index.php/consumption/products-wise"
)

PPAC_PRODUCTION_URL = (
    "https://ppac.gov.in/index.php/production/petroleum-products"
)


def find_ppac_report(page_url):
    """
    Find official downloadable report from PPAC page.
    """

    response = http_get(page_url)

    if not response:
        return None

    soup = BeautifulSoup(
        response.text,
        "html.parser"
    )

    candidates = []

    for a in soup.find_all("a", href=True):

        href = urljoin(
            response.url,
            a["href"]
        )

        text = clean_text(
            a.get_text(" ", strip=True)
        ).lower()

        href_lower = href.lower()

        if (
            ".pdf" in href_lower
            or ".xls" in href_lower
            or ".xlsx" in href_lower
            or "download" in href_lower
        ):

            score = 0

            if "current" in text:
                score += 5

            if "historical" in text:
                score += 3

            if "report" in text:
                score += 2

            if "download" in text:
                score += 1

            candidates.append(
                (score, href, text)
            )

    if not candidates:
        return None

    candidates.sort(
        key=lambda x: x[0],
        reverse=True
    )

    return candidates[0][1]


def parse_ppac_pdf(pdf_url):
    """
    Download PPAC report and extract HSD/Bitumen rows.
    """

    if not pdf_url:
        return {
            "status": "REPORT_NOT_FOUND",
            "observations": []
        }

    print(
        f"   📄 PPAC report: {pdf_url}"
    )

    response = http_get(pdf_url)

    if not response:
        return {
            "status": "DOWNLOAD_FAILED",
            "source_url": pdf_url,
            "observations": []
        }

    content_type = (
        response.headers
        .get("Content-Type", "")
        .lower()
    )

    # --------------------------------------------------------
    # PDF
    # --------------------------------------------------------

    if (
        "pdf" in content_type
        or pdf_url.lower().endswith(".pdf")
    ):

        text = extract_pdf_text(
            response.content
        )

        if not text:
            return {
                "status": "PDF_TEXT_EXTRACTION_FAILED",
                "source_url": pdf_url,
                "observations": []
            }

        observations = []

        for product in [
            "HSD",
            "Bitumen"
        ]:

            pattern = rf"\b{product}\b"

            match = re.search(
                pattern,
                text,
                re.IGNORECASE
            )

            if not match:
                continue

            start = max(
                0,
                match.start() - 100
            )

            end = min(
                len(text),
                match.end() + 250
            )

            context = text[start:end]

            numbers = re.findall(
                r"\b\d+(?:\.\d+)?\b",
                context
            )

            observations.append({
                "product": product,
                "raw_context": clean_text(context),
                "candidate_numbers": [
                    float(x)
                    for x in numbers
                ]
            })

        return {
            "status": "SUCCESS",
            "source_url": pdf_url,
            "observations": observations
        }

    # --------------------------------------------------------
    # HTML / XLS / XLSX
    # --------------------------------------------------------

    return {
        "status": "DOWNLOADED_NON_PDF",
        "source_url": pdf_url,
        "content_type": content_type,
        "file_size": len(response.content),
        "observations": []
    }


def scrape_ppac():
    """
    Scrape PPAC consumption and production reports.
    """

    print("\n⛽ PPAC")

    consumption_report = find_ppac_report(
        PPAC_CONSUMPTION_URL
    )

    production_report = find_ppac_report(
        PPAC_PRODUCTION_URL
    )

    consumption_data = parse_ppac_pdf(
        consumption_report
    )

    production_data = parse_ppac_pdf(
        production_report
    )

    return {
        "consumption": consumption_data,
        "production": production_data
    }


# ============================================================
# 3. INDIAN PORTS ASSOCIATION
# ============================================================

IPA_HOME = "https://ipa.nic.in/"


def find_ipa_monthly_traffic():
    """
    Find Monthly Traffic at Major Ports page/file.
    """

    print("\n🚢 Indian Ports Association")

    response = http_get(IPA_HOME)

    if not response:
        return None

    soup = BeautifulSoup(
        response.text,
        "html.parser"
    )

    candidates = []

    for a in soup.find_all(
        "a",
        href=True
    ):

        href = urljoin(
            response.url,
            a["href"]
        )

        text = clean_text(
            a.get_text(" ", strip=True)
        ).lower()

        combined = (
            text + " " + href.lower()
        )

        if (
            "monthly traffic" in combined
            or "container traffic" in combined
        ):

            candidates.append(
                href
            )

    if not candidates:
        print(
            "   ⚠️ IPA monthly traffic link not found."
        )
        return None

    return candidates[0]


def parse_ipa_traffic():
    """
    Download IPA monthly traffic page/file and preserve
    raw table information.
    """

    url = find_ipa_monthly_traffic()

    if not url:
        return {
            "status": "SOURCE_NOT_FOUND",
            "observations": []
        }

    print(
        f"   📄 IPA source: {url}"
    )

    response = http_get(url)

    if not response:
        return {
            "status": "DOWNLOAD_FAILED",
            "source_url": url,
            "observations": []
        }

    content_type = (
        response.headers
        .get("Content-Type", "")
        .lower()
    )

    # --------------------------------------------------------
    # PDF
    # --------------------------------------------------------

    if (
        "pdf" in content_type
        or url.lower().endswith(".pdf")
    ):

        text = extract_pdf_text(
            response.content
        )

        return {
            "status": "SUCCESS",
            "source_url": url,
            "content_type": content_type,
            "raw_text": text[:100000],
            "observations": []
        }

    # --------------------------------------------------------
    # HTML
    # --------------------------------------------------------

    soup = BeautifulSoup(
        response.text,
        "html.parser"
    )

    tables = []

    for table in soup.find_all("table"):

        rows = []

        for tr in table.find_all("tr"):

            cells = [
                clean_text(
                    c.get_text(" ", strip=True)
                )
                for c in tr.find_all(
                    ["th", "td"]
                )
            ]

            if cells:
                rows.append(cells)

        if rows:
            tables.append(rows)

    return {
        "status": "SUCCESS",
        "source_url": url,
        "content_type": content_type,
        "tables": tables
    }


# ============================================================
# STORE RAW DATA
# ============================================================

def store_raw_dpiit(db, dpiit):
    """
    Store DPIIT raw observations.

    IMPORTANT:
        We don't force uncertain numbers into database.
    """

    cement = get_sector(
        db,
        "CEMENT",
        "Cement & Clinker"
    )

    steel = get_sector(
        db,
        "STEEL",
        "Primary Steel Manufacturing"
    )

    for obs in dpiit.get(
        "observations",
        []
    ):

        key = obs.get(
            "sector_key"
        )

        target = (
            cement
            if key == "CEMENT"
            else steel
            if key == "STEEL"
            else None
        )

        if not target:
            continue

        record = {
            "scraped_at": NOW.strftime(
                "%Y-%m-%d %H:%M:%S IST"
            ),
            "period_text": obs.get(
                "period_text"
            ),
            "raw_context": obs.get(
                "raw_context"
            ),
            "candidate_numbers": obs.get(
                "candidate_numbers",
                []
            ),
            "source_url": dpiit.get(
                "source_url"
            ),
            "data_status": dpiit.get(
                "status"
            )
        }

        append_unique(
            target["source_documents"],
            record,
            [
                "period_text",
                "source_url"
            ]
        )

    for target in [cement, steel]:

        target["scrape_metadata"][
            "last_updated"
        ] = NOW.strftime(
            "%Y-%m-%d %H:%M:%S IST"
        )


def store_raw_ppac(db, ppac):
    """
    Store PPAC raw data without inventing parsed values.
    """

    road = get_sector(
        db,
        "ROAD_EPC",
        "Road EPC & Construction"
    )

    logistics = get_sector(
        db,
        "LOGISTICS",
        "Heavy Commercial Fleet Logistics"
    )

    # Production report
    production = ppac.get(
        "production",
        {}
    )

    for obs in production.get(
        "observations",
        []
    ):

        product = obs.get(
            "product"
        )

        target = None

        if product == "Bitumen":
            target = road

        elif product == "HSD":
            target = logistics

        if not target:
            continue

        record = {
            "scraped_at": NOW.strftime(
                "%Y-%m-%d %H:%M:%S IST"
            ),
            "product": product,
            "raw_context": obs.get(
                "raw_context"
            ),
            "candidate_numbers": obs.get(
                "candidate_numbers",
                []
            ),
            "source_url": production.get(
                "source_url"
            ),
            "data_status": production.get(
                "status"
            )
        }

        append_unique(
            target["source_documents"],
            record,
            [
                "product",
                "source_url"
            ]
        )

    road["scrape_metadata"][
        "last_updated"
    ] = NOW.strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )

    logistics["scrape_metadata"][
        "last_updated"
    ] = NOW.strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )


def store_raw_ipa(db, ipa):
    """
    Store IPA raw traffic tables.
    """

    port = get_sector(
        db,
        "PORT_EXIM",
        "Maritime Ports & Container EXIM"
    )

    record = {
        "scraped_at": NOW.strftime(
            "%Y-%m-%d %H:%M:%S IST"
        ),
        "source_url": ipa.get(
            "source_url"
        ),
        "status": ipa.get(
            "status"
        )
    }

    if "tables" in ipa:
        record["tables"] = ipa["tables"]

    if "raw_text" in ipa:
        record["raw_text"] = ipa[
            "raw_text"
        ]

    append_unique(
        port["source_documents"],
        record,
        [
            "source_url",
            "scraped_at"
        ]
    )

    port["scrape_metadata"][
        "last_updated"
    ] = NOW.strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 75)
    print("📡 LIVE OFFICIAL MACRO DATA HARVESTER")
    print("=" * 75)

    print(
        "Time:",
        NOW.strftime(
            "%Y-%m-%d %H:%M:%S IST"
        )
    )

    db = load_existing_db()

    # --------------------------------------------------------
    # 1. DPIIT
    # --------------------------------------------------------

    dpiit = parse_dpiit_core()

    print(
        f"\nDPIIT status: {dpiit.get('status')}"
    )

    store_raw_dpiit(
        db,
        dpiit
    )

    time.sleep(1)

    # --------------------------------------------------------
    # 2. PPAC
    # --------------------------------------------------------

    ppac = scrape_ppac()

    print(
        "\nPPAC consumption:",
        ppac["consumption"].get("status")
    )

    print(
        "PPAC production:",
        ppac["production"].get("status")
    )

    store_raw_ppac(
        db,
        ppac
    )

    time.sleep(1)

    # --------------------------------------------------------
    # 3. IPA
    # --------------------------------------------------------

    ipa = parse_ipa_traffic()

    print(
        f"\nIPA status: {ipa.get('status')}"
    )

    store_raw_ipa(
        db,
        ipa
    )

    # --------------------------------------------------------
    # DATABASE METADATA
    # --------------------------------------------------------

    db["updated_at"] = NOW.strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )

    db["last_scrape"] = {
        "timestamp": NOW.strftime(
            "%Y-%m-%d %H:%M:%S IST"
        ),
        "sources": {
            "DPIIT_OEA": dpiit.get(
                "status"
            ),
            "PPAC_CONSUMPTION": ppac[
                "consumption"
            ].get("status"),
            "PPAC_PRODUCTION": ppac[
                "production"
            ].get("status"),
            "IPA": ipa.get(
                "status"
            )
        }
    }

    save_json(db)

    print("\n" + "=" * 75)
    print(
        f"✅ RAW DATA SAVED: {DB_FILE}"
    )
    print("=" * 75)

    # --------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------

    print("\n📊 DATABASE SUMMARY")

    for key, sector in db[
        "sectors"
    ].items():

        print(
            f"   {key}: "
            f"{len(sector.get('source_documents', []))} "
            f"source records"
        )


if __name__ == "__main__":
    main()