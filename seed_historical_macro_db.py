#!/usr/bin/env python3
"""
LIVE OFFICIAL MACRO HARVESTER
=============================

Sources:
  1. DPIIT / Office of Economic Adviser
     - Eight Core Industries
     - Cement
     - Steel

  2. PPAC
     - Petroleum product consumption
     - HSD / Diesel
     - Bitumen

  3. Ministry of Ports, Shipping & Waterways
     - Transport Research Wing
     - Monthly Major Port cargo reports
     - Monthly Non-Major Port cargo reports

IMPORTANT:
  - ZERO SYNTHETIC DATA
  - ZERO HARDCODED FALLBACK VALUES
  - If data cannot be extracted, value remains unavailable.
  - All calculations are performed in Python.
  - Raw source-document metadata is stored in JSON.
"""

import io
import os
import re
import json
import time
import hashlib
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

try:
    import pdfplumber
except ImportError:
    pdfplumber = None


# ============================================================
# CONFIG
# ============================================================

DB_FILE = "macro_historical_db.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

TIMEOUT = (20, 60)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 "
        "(KHTML, like Gecko) "
        "Chrome/124.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,application/pdf;q=0.8,*/*;q=0.7"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive",
}


# ============================================================
# HTTP SESSION
# ============================================================

SESSION = requests.Session()
SESSION.headers.update(HEADERS)


def now_ist():
    return datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")


def clean_url(base, href):
    if not href:
        return None

    href = href.strip()

    if href.startswith(("javascript:", "#", "mailto:")):
        return None

    return urljoin(base, href)


def safe_get(url, retries=3, timeout=TIMEOUT):
    """
    GET with retry + backoff.
    Returns response or None.
    """

    for attempt in range(1, retries + 1):
        try:
            print(
                f"      HTTP GET attempt {attempt}/{retries}: {url}"
            )

            r = SESSION.get(
                url,
                timeout=timeout,
                allow_redirects=True,
            )

            r.raise_for_status()

            return r

        except requests.RequestException as exc:
            print(
                f"      ⚠️ Request failed: {type(exc).__name__}: {exc}"
            )

            if attempt < retries:
                time.sleep(2 * attempt)

    return None


# ============================================================
# PDF HELPERS
# ============================================================

def extract_pdf_text(pdf_bytes):
    """
    Extract all PDF text using pdfplumber.
    """

    if pdfplumber is None:
        raise RuntimeError(
            "pdfplumber is not installed. "
            "Install: pip install pdfplumber"
        )

    output = []

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:

        for page_no, page in enumerate(pdf.pages, start=1):

            try:
                text = page.extract_text() or ""

                output.append(
                    f"\n--- PAGE {page_no} ---\n{text}"
                )

            except Exception as exc:
                print(
                    f"      ⚠️ PDF page {page_no} extraction error: {exc}"
                )

    return "\n".join(output)


def extract_pdf_tables(pdf_bytes):
    """
    Best-effort table extraction.
    """

    if pdfplumber is None:
        return []

    tables = []

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:

        for page_no, page in enumerate(pdf.pages, start=1):

            try:
                page_tables = page.extract_tables()

                for table in page_tables:

                    if table:
                        tables.append({
                            "page": page_no,
                            "rows": table,
                        })

            except Exception:
                continue

    return tables


def download_pdf(url):
    response = safe_get(url)

    if response is None:
        return None, None

    content_type = (
        response.headers.get("Content-Type", "")
        .lower()
    )

    data = response.content

    # Check PDF magic bytes too.
    is_pdf = (
        "application/pdf" in content_type
        or data[:4] == b"%PDF"
        or url.lower().split("?")[0].endswith(".pdf")
    )

    if not is_pdf:
        print(
            f"      ⚠️ URL did not return PDF. "
            f"Content-Type={content_type}"
        )
        return None, response

    return data, response


# ============================================================
# SOURCE METADATA
# ============================================================

def make_source_document(
    source_name,
    source_url,
    document_url=None,
    document_title=None,
    status="UNKNOWN",
    error=None,
    content_bytes=None,
    extracted_text=None,
):
    doc = {
        "source_name": source_name,
        "source_url": source_url,
        "document_url": document_url,
        "document_title": document_title,
        "status": status,
        "scraped_at": now_ist(),
    }

    if error:
        doc["error"] = str(error)

    if content_bytes is not None:
        doc["sha256"] = hashlib.sha256(
            content_bytes
        ).hexdigest()

        doc["bytes"] = len(content_bytes)

    if extracted_text is not None:
        doc["text_length"] = len(extracted_text)

    return doc


# ============================================================
# NUMBER PARSING
# ============================================================

def parse_number(value):
    if value is None:
        return None

    text = str(value)

    text = text.replace(",", "")
    text = text.replace("−", "-")
    text = text.replace("–", "-")

    match = re.search(
        r"[-+]?\d+(?:\.\d+)?",
        text
    )

    if not match:
        return None

    try:
        return float(match.group(0))
    except ValueError:
        return None


def normalize_text(text):
    if text is None:
        return ""

    text = text.replace("\xa0", " ")

    text = re.sub(
        r"[ \t]+",
        " ",
        text
    )

    return text


# ============================================================
# MONTH UTILITIES
# ============================================================

MONTHS = {
    "january": "01",
    "february": "02",
    "march": "03",
    "april": "04",
    "may": "05",
    "june": "06",
    "july": "07",
    "august": "08",
    "september": "09",
    "october": "10",
    "november": "11",
    "december": "12",
}


def detect_month(text):
    """
    Detect YYYY-MM from document text.
    """

    if not text:
        return None

    # YYYY-MM
    match = re.search(
        r"\b(20\d{2})[-/](0?[1-9]|1[0-2])\b",
        text
    )

    if match:
        return f"{match.group(1)}-{int(match.group(2)):02d}"

    # Month YYYY
    lower = text.lower()

    for name, number in MONTHS.items():

        match = re.search(
            rf"\b{name}\s+(20\d{{2}})\b",
            lower
        )

        if match:
            return f"{match.group(1)}-{number}"

    return None


def month_sort_key(value):
    return value


# ============================================================
# TIME SERIES CALCULATIONS
# ============================================================

def calculate_yoy(entries):
    """
    Calculates YoY using exact 12-month lookback.
    """

    entries = sorted(
        entries,
        key=lambda x: x["month"]
    )

    lookup = {
        x["month"]: x.get("value")
        for x in entries
    }

    for entry in entries:

        current = entry.get("value")

        if current is None:
            entry["yoy_pct"] = None
            continue

        year, month = entry["month"].split("-")

        previous_year = str(
            int(year) - 1
        )

        previous_month = (
            f"{previous_year}-{month}"
        )

        previous = lookup.get(
            previous_month
        )

        if previous in (None, 0):
            entry["yoy_pct"] = None
        else:
            entry["yoy_pct"] = round(
                ((current - previous) / previous)
                * 100,
                2,
            )

    return entries


def calculate_mom(entries):
    entries = sorted(
        entries,
        key=lambda x: x["month"]
    )

    previous = None

    for entry in entries:

        current = entry.get("value")

        if (
            current is None
            or previous in (None, 0)
        ):
            entry["mom_pct"] = None
        else:
            entry["mom_pct"] = round(
                ((current - previous) / previous)
                * 100,
                2,
            )

        if current is not None:
            previous = current

    return entries


def trailing_yoy(entries, months):
    valid = [
        x.get("yoy_pct")
        for x in entries[-months:]
        if x.get("yoy_pct") is not None
    ]

    if not valid:
        return None

    return round(
        sum(valid) / len(valid),
        2,
    )


# ============================================================
# HTML DISCOVERY
# ============================================================

def discover_pdf_links(
    page_url,
    keywords,
    max_links=20,
):
    """
    Finds PDF links from an official page.
    """

    response = safe_get(page_url)

    if response is None:
        return []

    soup = BeautifulSoup(
        response.text,
        "html.parser"
    )

    results = []

    for a in soup.find_all("a", href=True):

        href = clean_url(
            page_url,
            a.get("href")
        )

        if not href:
            continue

        text = normalize_text(
            a.get_text(" ", strip=True)
        )

        combined = (
            f"{text} {href}"
        ).lower()

        if ".pdf" not in combined:
            continue

        if keywords:
            if not any(
                keyword.lower() in combined
                for keyword in keywords
            ):
                continue

        if href not in [
            x["url"] for x in results
        ]:
            results.append({
                "url": href,
                "title": text,
            })

        if len(results) >= max_links:
            break

    return results


# ============================================================
# 1. DPIIT / OEA
# ============================================================

DPIIT_HOME = "https://eaindustry.nic.in"


def harvest_dpiit_core8():
    print("\n" + "=" * 70)
    print("🏗️ DPIIT / OFFICE OF ECONOMIC ADVISER")
    print("=" * 70)

    source_documents = []

    # Search official homepage.
    candidates = discover_pdf_links(
        DPIIT_HOME,
        keywords=[
            "core",
            "industry",
            "ici",
            "eight",
        ],
        max_links=30,
    )

    # Prefer recent PDF-like links.
    candidates = sorted(
        candidates,
        key=lambda x: (
            "2026" not in x["url"],
            "202609" not in x["url"],
            "2026" not in x["title"],
        )
    )

    for candidate in candidates:

        pdf_url = candidate["url"]

        pdf_bytes, response = download_pdf(
            pdf_url
        )

        if pdf_bytes is None:
            continue

        try:
            text = extract_pdf_text(
                pdf_bytes
            )

            normalized = normalize_text(text)

            source_documents.append(
                make_source_document(
                    source_name=(
                        "DPIIT / Office of "
                        "Economic Adviser"
                    ),
                    source_url=DPIIT_HOME,
                    document_url=pdf_url,
                    document_title=candidate["title"],
                    status="SUCCESS",
                    content_bytes=pdf_bytes,
                    extracted_text=text,
                )
            )

            cement = extract_core8_row(
                normalized,
                "Cement"
            )

            steel = extract_core8_row(
                normalized,
                "Steel"
            )

            if cement is not None or steel is not None:

                print(
                    f"   ✅ PDF: {pdf_url}"
                )

                print(
                    f"   Cement: {cement}"
                )

                print(
                    f"   Steel: {steel}"
                )

                return {
                    "cement": cement,
                    "steel": steel,
                    "document_url": pdf_url,
                    "source_documents": source_documents,
                }

        except Exception as exc:

            source_documents.append(
                make_source_document(
                    source_name=(
                        "DPIIT / Office of "
                        "Economic Adviser"
                    ),
                    source_url=DPIIT_HOME,
                    document_url=pdf_url,
                    document_title=candidate["title"],
                    status="PARSE_ERROR",
                    error=exc,
                    content_bytes=pdf_bytes,
                )
            )

    source_documents.append(
        make_source_document(
            source_name=(
                "DPIIT / Office of "
                "Economic Adviser"
            ),
            source_url=DPIIT_HOME,
            status="NO_USABLE_DOCUMENT",
        )
    )

    print(
        "   ❌ No usable DPIIT Core-8 document found."
    )

    return {
        "cement": None,
        "steel": None,
        "document_url": None,
        "source_documents": source_documents,
    }


def extract_core8_row(text, name):
    """
    Attempts to extract the current-period value
    from Core-8 statement text.

    Handles:
        Cement  ...
        Steel   ...

    It deliberately avoids returning a fabricated value.
    """

    lines = [
        normalize_text(line)
        for line in text.splitlines()
    ]

    for line in lines:

        if not re.search(
            rf"\b{name}\b",
            line,
            re.IGNORECASE
        ):
            continue

        numbers = re.findall(
            r"[-+]?\d+(?:,\d{3})*(?:\.\d+)?",
            line
        )

        values = [
            parse_number(x)
            for x in numbers
        ]

        values = [
            x for x in values
            if x is not None
        ]

        if not values:
            continue

        # In many Core-8 tables the row contains
        # previous period and current period.
        # We take the final numeric field.
        return values[-1]

    return None


# ============================================================
# 2. PPAC
# ============================================================

PPAC_HOME = "https://ppac.gov.in"


def harvest_ppac():
    print("\n" + "=" * 70)
    print("⛽ PPAC / PETROLEUM PLANNING & ANALYSIS CELL")
    print("=" * 70)

    source_documents = []

    candidates = discover_pdf_links(
        PPAC_HOME,
        keywords=[
            "consumption",
            "petroleum",
            "product",
            "monthly",
            "report",
            "bitumen",
        ],
        max_links=50,
    )

    for candidate in candidates:

        pdf_url = candidate["url"]

        pdf_bytes, response = download_pdf(
            pdf_url
        )

        if pdf_bytes is None:
            continue

        try:
            text = extract_pdf_text(
                pdf_bytes
            )

            normalized = normalize_text(text)

            hsd = extract_ppac_metric(
                normalized,
                [
                    "HSD",
                    "High Speed Diesel",
                    "High-Speed Diesel",
                    "Diesel",
                ]
            )

            bitumen = extract_ppac_metric(
                normalized,
                [
                    "Bitumen",
                ]
            )

            source_documents.append(
                make_source_document(
                    source_name=(
                        "Petroleum Planning "
                        "& Analysis Cell"
                    ),
                    source_url=PPAC_HOME,
                    document_url=pdf_url,
                    document_title=candidate["title"],
                    status="SUCCESS",
                    content_bytes=pdf_bytes,
                    extracted_text=text,
                )
            )

            if hsd is not None or bitumen is not None:

                print(
                    f"   ✅ PDF: {pdf_url}"
                )

                print(
                    f"   HSD: {hsd}"
                )

                print(
                    f"   Bitumen: {bitumen}"
                )

                return {
                    "hsd": hsd,
                    "bitumen": bitumen,
                    "document_url": pdf_url,
                    "source_documents": source_documents,
                }

        except Exception as exc:

            source_documents.append(
                make_source_document(
                    source_name=(
                        "Petroleum Planning "
                        "& Analysis Cell"
                    ),
                    source_url=PPAC_HOME,
                    document_url=pdf_url,
                    document_title=candidate["title"],
                    status="PARSE_ERROR",
                    error=exc,
                    content_bytes=pdf_bytes,
                )
            )

    source_documents.append(
        make_source_document(
            source_name=(
                "Petroleum Planning "
                "& Analysis Cell"
            ),
            source_url=PPAC_HOME,
            status="NO_USABLE_DOCUMENT",
        )
    )

    print(
        "   ❌ No usable PPAC document found."
    )

    return {
        "hsd": None,
        "bitumen": None,
        "document_url": None,
        "source_documents": source_documents,
    }


def extract_ppac_metric(text, metric_names):
    """
    Generic PPAC row extraction.

    Looks for a line containing metric name
    and returns the final numeric field.
    """

    lines = [
        normalize_text(x)
        for x in text.splitlines()
    ]

    for line in lines:

        if not any(
            re.search(
                rf"\b{re.escape(metric)}\b",
                line,
                re.IGNORECASE,
            )
            for metric in metric_names
        ):
            continue

        numbers = re.findall(
            r"[-+]?\d+(?:,\d{3})*(?:\.\d+)?",
            line
        )

        values = [
            parse_number(x)
            for x in numbers
        ]

        values = [
            x for x in values
            if x is not None
        ]

        if values:
            return values[-1]

    return None


# ============================================================
# 3. PORTS
# ============================================================

IPA_HOME = "https://ipa.nic.in"

MOPSW_HOME = "https://www.shipmin.gov.in"

MOPSW_MAJOR_PAGE = (
    "https://www.shipmin.gov.in/"
    "transport-reseach/"
    "monthly-cargo-traffic-handled-major-ports"
)

MOPSW_TRW_PAGE = (
    "https://www.shipmin.gov.in/"
    "division/transport-research"
)


def harvest_ports():
    """
    Port strategy:

    1. Try IPA.
    2. If IPA fails, use official Ministry of Ports
       Transport Research Wing.
    3. Never fabricate a TEU number.
    """

    print("\n" + "=" * 70)
    print("🚢 INDIAN PORTS / MINISTRY OF PORTS")
    print("=" * 70)

    source_documents = []

    # --------------------------------------------------------
    # IPA
    # --------------------------------------------------------

    ipa_result = try_ipa_ports()

    source_documents.extend(
        ipa_result.get(
            "source_documents",
            []
        )
    )

    if ipa_result.get("container_teu") is not None:

        return {
            "container_teu": ipa_result["container_teu"],
            "document_url": ipa_result.get(
                "document_url"
            ),
            "source_documents": source_documents,
        }

    # --------------------------------------------------------
    # MOPSW FALLBACK
    # --------------------------------------------------------

    print(
        "   ℹ️ IPA unavailable. "
        "Using official Ministry of Ports TRW."
    )

    ministry_result = try_mopsw_ports()

    source_documents.extend(
        ministry_result.get(
            "source_documents",
            []
        )
    )

    return {
        "container_teu": ministry_result.get(
            "container_teu"
        ),
        "document_url": ministry_result.get(
            "document_url"
        ),
        "source_documents": source_documents,
    }


def try_ipa_ports():
    source_documents = []

    response = safe_get(
        IPA_HOME,
        retries=3,
        timeout=(20, 90),
    )

    if response is None:

        source_documents.append(
            make_source_document(
                source_name=(
                    "Indian Ports Association"
                ),
                source_url=IPA_HOME,
                status="CONNECTION_FAILED",
                error="IPA homepage unavailable",
            )
        )

        print(
            "   ⚠️ IPA unavailable."
        )

        return {
            "container_teu": None,
            "document_url": None,
            "source_documents": source_documents,
        }

    soup = BeautifulSoup(
        response.text,
        "html.parser"
    )

    links = []

    for a in soup.find_all(
        "a",
        href=True
    ):

        href = clean_url(
            IPA_HOME,
            a.get("href")
        )

        if not href:
            continue

        text = normalize_text(
            a.get_text(
                " ",
                strip=True
            )
        )

        combined = (
            f"{text} {href}"
        ).lower()

        if (
            "container" in combined
            or "traffic" in combined
            or "cargo" in combined
            or "monthly" in combined
        ):
            links.append({
                "url": href,
                "title": text,
            })

    for candidate in links[:30]:

        if ".pdf" not in candidate["url"].lower():
            continue

        pdf_bytes, response = download_pdf(
            candidate["url"]
        )

        if pdf_bytes is None:
            continue

        try:

            text = extract_pdf_text(
                pdf_bytes
            )

            teu = extract_container_teu(
                text
            )

            source_documents.append(
                make_source_document(
                    source_name=(
                        "Indian Ports Association"
                    ),
                    source_url=IPA_HOME,
                    document_url=candidate["url"],
                    document_title=candidate["title"],
                    status="SUCCESS",
                    content_bytes=pdf_bytes,
                    extracted_text=text,
                )
            )

            if teu is not None:

                print(
                    f"   ✅ IPA Container TEU: {teu}"
                )

                return {
                    "container_teu": teu,
                    "document_url": candidate["url"],
                    "source_documents": source_documents,
                }

        except Exception as exc:

            source_documents.append(
                make_source_document(
                    source_name=(
                        "Indian Ports Association"
                    ),
                    source_url=IPA_HOME,
                    document_url=candidate["url"],
                    document_title=candidate["title"],
                    status="PARSE_ERROR",
                    error=exc,
                    content_bytes=pdf_bytes,
                )
            )

    source_documents.append(
        make_source_document(
            source_name=(
                "Indian Ports Association"
            ),
            source_url=IPA_HOME,
            status="NO_USABLE_CONTAINER_DOCUMENT",
        )
    )

    return {
        "container_teu": None,
        "document_url": None,
        "source_documents": source_documents,
    }


def try_mopsw_ports():
    source_documents = []

    # The Ministry currently publishes monthly
    # Major Port and Non-Major Port cargo reports
    # through its Transport Research Wing.

    pages = [
        MOPSW_MAJOR_PAGE,
        MOPSW_TRW_PAGE,
    ]

    candidates = []

    for page_url in pages:

        found = discover_pdf_links(
            page_url,
            keywords=[
                "cargo",
                "major",
                "container",
                "traffic",
                "port",
            ],
            max_links=50,
        )

        candidates.extend(found)

    # Remove duplicates.
    unique = {}
    for item in candidates:
        unique[item["url"]] = item

    candidates = list(
        unique.values()
    )

    # Prefer latest-looking documents.
    candidates.sort(
        key=lambda x: (
            "2026" not in (
                x["url"] + x["title"]
            ),
            "Aug" not in (
                x["url"] + x["title"]
            ),
            "July" not in (
                x["url"] + x["title"]
            ),
        )
    )

    for candidate in candidates:

        pdf_url = candidate["url"]

        pdf_bytes, response = download_pdf(
            pdf_url
        )

        if pdf_bytes is None:
            continue

        try:

            text = extract_pdf_text(
                pdf_bytes
            )

            teu = extract_container_teu(
                text
            )

            source_documents.append(
                make_source_document(
                    source_name=(
                        "Ministry of Ports, "
                        "Shipping & Waterways "
                        "Transport Research Wing"
                    ),
                    source_url=MOPSW_HOME,
                    document_url=pdf_url,
                    document_title=candidate["title"],
                    status="SUCCESS",
                    content_bytes=pdf_bytes,
                    extracted_text=text,
                )
            )

            if teu is not None:

                print(
                    "   ✅ MoPSW Container TEU: "
                    f"{teu}"
                )

                return {
                    "container_teu": teu,
                    "document_url": pdf_url,
                    "source_documents": source_documents,
                }

        except Exception as exc:

            source_documents.append(
                make_source_document(
                    source_name=(
                        "Ministry of Ports, "
                        "Shipping & Waterways "
                        "Transport Research Wing"
                    ),
                    source_url=MOPSW_HOME,
                    document_url=pdf_url,
                    document_title=candidate["title"],
                    status="PARSE_ERROR",
                    error=exc,
                    content_bytes=pdf_bytes,
                )
            )

    source_documents.append(
        make_source_document(
            source_name=(
                "Ministry of Ports, "
                "Shipping & Waterways "
                "Transport Research Wing"
            ),
            source_url=MOPSW_HOME,
            status="NO_USABLE_CONTAINER_DOCUMENT",
        )
    )

    print(
        "   ❌ No container TEU figure extracted "
        "from official port reports."
    )

    return {
        "container_teu": None,
        "document_url": None,
        "source_documents": source_documents,
    }


def extract_container_teu(text):
    """
    Extract an explicitly reported container/TEU number.

    This intentionally does NOT convert cargo tonnes into TEUs.

    Accepts patterns such as:
      Container 1.23 million TEUs
      Containers 1.23
      TEUs 1.23

    If only generic cargo tonnage is available,
    returns None.
    """

    normalized = normalize_text(
        text
    )

    # Explicit million TEU patterns.
    patterns = [
        r"([\d,.]+)\s*million\s*(?:TEUs?|TEU)",
        r"(?:TEUs?|TEU)\s*[:\-]?\s*([\d,.]+)\s*million",
        r"([\d,.]+)\s*mn\s*(?:TEUs?|TEU)",
    ]

    for pattern in patterns:

        match = re.search(
            pattern,
            normalized,
            re.IGNORECASE,
        )

        if match:

            value = parse_number(
                match.group(1)
            )

            if value is not None:
                return value

    # Explicit TEU value without million.
    patterns = [
        r"(?:TEUs?|TEU)\s*[:\-]?\s*([\d,]+(?:\.\d+)?)",
        r"([\d,]+(?:\.\d+)?)\s*(?:TEUs?|TEU)",
    ]

    for pattern in patterns:

        match = re.search(
            pattern,
            normalized,
            re.IGNORECASE,
        )

        if match:

            value = parse_number(
                match.group(1)
            )

            if value is not None:

                # Convert raw TEUs to million TEUs.
                if value > 100:
                    value = value / 1_000_000

                return round(
                    value,
                    4
                )

    return None


# ============================================================
# DATABASE HELPERS
# ============================================================

def load_database():
    if not os.path.exists(DB_FILE):

        return {
            "version": "7.0-live-official",
            "generated_at": now_ist(),
            "sectors": {},
        }

    try:

        with open(
            DB_FILE,
            "r",
            encoding="utf-8"
        ) as f:

            return json.load(f)

    except Exception as exc:

        print(
            f"⚠️ Existing DB load failed: {exc}"
        )

        return {
            "version": "7.0-live-official",
            "generated_at": now_ist(),
            "sectors": {},
        }


def ensure_sector(
    sectors,
    key,
    name,
):
    return sectors.setdefault(
        key,
        {
            "sector": name,
            "monthly_demand": [],
            "input_costs": [],
            "supporting_indicators": [],
            "source_documents": [],
            "source": {},
        },
    )


def upsert_monthly(
    entries,
    month,
    value,
    unit,
):
    """
    Updates month if present,
    otherwise appends.

    None values are NOT inserted as fake data.
    """

    if value is None:
        return

    for entry in entries:

        if entry.get("month") == month:

            entry["value"] = value
            entry["unit"] = unit
            return

    entries.append({
        "month": month,
        "value": value,
        "unit": unit,
    })


def add_source_documents(
    sector,
    documents,
):
    existing = {
        (
            d.get("document_url"),
            d.get("sha256"),
        )
        for d in sector.get(
            "source_documents",
            []
        )
    }

    for document in documents:

        key = (
            document.get("document_url"),
            document.get("sha256"),
        )

        if key not in existing:

            sector.setdefault(
                "source_documents",
                []
            ).append(document)

            existing.add(key)


# ============================================================
# MAIN DB UPDATE
# ============================================================

def update_database():

    print("=" * 75)
    print("📡 LIVE OFFICIAL MACRO DATA HARVESTER")
    print("=" * 75)
    print(
        f"Time: {now_ist()}"
    )

    # --------------------------------------------------------
    # SCRAPE
    # --------------------------------------------------------

    dpiit = harvest_dpiit_core8()

    ppac = harvest_ppac()

    ports = harvest_ports()

    current_month = NOW.strftime(
        "%Y-%m"
    )

    # --------------------------------------------------------
    # DATABASE
    # --------------------------------------------------------

    db = load_database()

    db["version"] = "7.0-live-official"
    db["updated_at"] = now_ist()

    sectors = db.setdefault(
        "sectors",
        {}
    )

    # --------------------------------------------------------
    # CEMENT
    # --------------------------------------------------------

    cement = ensure_sector(
        sectors,
        "CEMENT",
        "Cement & Clinker",
    )

    upsert_monthly(
        cement["monthly_demand"],
        current_month,
        dpiit.get("cement"),
        "million tonnes",
    )

    add_source_documents(
        cement,
        dpiit.get(
            "source_documents",
            []
        ),
    )

    cement.setdefault(
        "source",
        {}
    ).update({
        "primary": (
            "DPIIT / Office of "
            "Economic Adviser"
        ),
        "source_url": DPIIT_HOME,
        "last_scraped": now_ist(),
    })

    # --------------------------------------------------------
    # STEEL
    # --------------------------------------------------------

    steel = ensure_sector(
        sectors,
        "STEEL",
        "Primary Steel Manufacturing",
    )

    upsert_monthly(
        steel["monthly_demand"],
        current_month,
        dpiit.get("steel"),
        "million tonnes (crude)",
    )

    add_source_documents(
        steel,
        dpiit.get(
            "source_documents",
            []
        ),
    )

    steel.setdefault(
        "source",
        {}
    ).update({
        "primary": (
            "DPIIT / Office of "
            "Economic Adviser"
        ),
        "source_url": DPIIT_HOME,
        "last_scraped": now_ist(),
    })

    # --------------------------------------------------------
    # ROAD EPC
    # --------------------------------------------------------

    road = ensure_sector(
        sectors,
        "ROAD_EPC",
        "Road EPC & Construction",
    )

    upsert_monthly(
        road["monthly_demand"],
        current_month,
        ppac.get("bitumen"),
        "thousand MT (bitumen)",
    )

    add_source_documents(
        road,
        ppac.get(
            "source_documents",
            []
        ),
    )

    road.setdefault(
        "source",
        {}
    ).update({
        "primary": (
            "Petroleum Planning "
            "& Analysis Cell"
        ),
        "source_url": PPAC_HOME,
        "last_scraped": now_ist(),
    })

    # --------------------------------------------------------
    # LOGISTICS
    # --------------------------------------------------------

    logistics = ensure_sector(
        sectors,
        "LOGISTICS",
        "Heavy Commercial Fleet Logistics",
    )

    upsert_monthly(
        logistics["monthly_demand"],
        current_month,
        ppac.get("hsd"),
        "thousand MT (HSD)",
    )

    add_source_documents(
        logistics,
        ppac.get(
            "source_documents",
            []
        ),
    )

    logistics.setdefault(
        "source",
        {}
    ).update({
        "primary": (
            "Petroleum Planning "
            "& Analysis Cell"
        ),
        "source_url": PPAC_HOME,
        "last_scraped": now_ist(),
    })

    # --------------------------------------------------------
    # PORT EXIM
    # --------------------------------------------------------

    ports_sector = ensure_sector(
        sectors,
        "PORT_EXIM",
        "Maritime Ports & Container EXIM",
    )

    upsert_monthly(
        ports_sector["monthly_demand"],
        current_month,
        ports.get("container_teu"),
        "million TEUs",
    )

    add_source_documents(
        ports_sector,
        ports.get(
            "source_documents",
            []
        ),
    )

    ports_sector.setdefault(
        "source",
        {}
    ).update({
        "primary": (
            "Ministry of Ports, "
            "Shipping & Waterways / "
            "Indian Ports Association"
        ),
        "source_url": MOPSW_HOME,
        "last_scraped": now_ist(),
    })

    # --------------------------------------------------------
    # CALCULATE TELEMETRY
    # --------------------------------------------------------

    for key, sector in sectors.items():

        demand = sector.get(
            "monthly_demand",
            []
        )

        demand = sorted(
            demand,
            key=lambda x: x["month"]
        )

        calculate_yoy(demand)
        calculate_mom(demand)

        sector["monthly_demand"] = demand

        if demand:

            sector["latest_month"] = (
                demand[-1]["month"]
            )

            latest = demand[-1]

            sector["latest_telemetry"] = {
                "current_volume": latest.get(
                    "value"
                ),
                "unit": latest.get(
                    "unit"
                ),
                "mom_pct": latest.get(
                    "mom_pct"
                ),
                "yoy_pct": latest.get(
                    "yoy_pct"
                ),
                "trailing_3m_yoy_pct":
                    trailing_yoy(
                        demand,
                        3
                    ),
                "trailing_6m_yoy_pct":
                    trailing_yoy(
                        demand,
                        6
                    ),
            }

    # --------------------------------------------------------
    # SAVE
    # --------------------------------------------------------

    with open(
        DB_FILE,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            db,
            f,
            ensure_ascii=False,
            indent=2,
        )

    print("\n" + "=" * 75)
    print("✅ HARVEST COMPLETE")
    print("=" * 75)

    print(
        f"📁 File: {DB_FILE}"
    )

    print(
        f"📅 Latest month: {current_month}"
    )

    print(
        f"🏗️ Cement: "
        f"{dpiit.get('cement')}"
    )

    print(
        f"🏭 Steel: "
        f"{dpiit.get('steel')}"
    )

    print(
        f"🛣️ Bitumen: "
        f"{ppac.get('bitumen')}"
    )

    print(
        f"🚛 HSD: "
        f"{ppac.get('hsd')}"
    )

    print(
        f"🚢 Container TEU: "
        f"{ports.get('container_teu')}"
    )

    print("=" * 75)


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    update_database()