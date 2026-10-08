#!/usr/bin/env python3
"""
ARCHIVE-FIRST OFFICIAL MACRO HISTORICAL SCRAPER
================================================

Purpose:
    Scrape official government historical macro data.

Target period:
    2023-11 -> 2026-10

IMPORTANT:
    - NO synthetic values
    - NO guessed values
    - NO AI calculations
    - Missing observations remain None/null
    - Source/report URL is preserved
    - Archive pages are crawled first
    - PDFs are downloaded and parsed locally

Output:
    macro_historical_db.json

Sources:
    1. DPIIT / OEA - Eight Core Industries
    2. PPAC - Industry Consumption Reports
    3. Ministry of Railways / PIB - freight releases
    4. Ministry of Ports, Shipping & Waterways
    5. IPA - secondary/backup port source
    6. NPCI / NETC - FASTag

Dependencies:
    requests
    beautifulsoup4
    pdfplumber
    lxml

Install:
    pip install requests beautifulsoup4 pdfplumber lxml
"""

import os
import io
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

OUTPUT_FILE = "macro_historical_db.json"

START_YEAR = 2023
START_MONTH = 11

END_YEAR = 2026
END_MONTH = 10

IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 "
        "(KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,image/avif,image/webp,*/*;q=0.8"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive",
}

TIMEOUT = 35

MONTHS = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
}


# ============================================================
# DATE HELPERS
# ============================================================

def month_range(start_y, start_m, end_y, end_m):
    result = []

    y = start_y
    m = start_m

    while (y, m) <= (end_y, end_m):
        result.append(f"{y:04d}-{m:02d}")

        m += 1
        if m == 13:
            m = 1
            y += 1

    return result


TARGET_MONTHS = month_range(
    START_YEAR,
    START_MONTH,
    END_YEAR,
    END_MONTH
)


def month_name(period):
    y, m = period.split("-")
    return f"{MONTHS[int(m)]} {y}"


# ============================================================
# BASIC HELPERS
# ============================================================

def now_ist():
    return datetime.now(IST).strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )


def clean_number(value):
    if value is None:
        return None

    text = str(value)

    text = (
        text.replace(",", "")
        .replace("%", "")
        .replace("₹", "")
        .replace("$", "")
        .replace("Rs.", "")
        .replace("Rs", "")
        .strip()
    )

    # Indian accounting notation / dashes
    if text in ("", "-", "—", "–", "NA", "N/A", "nil", "Nil"):
        return None

    match = re.search(
        r"[-+]?\d+(?:\.\d+)?",
        text
    )

    if not match:
        return None

    try:
        return float(match.group(0))
    except Exception:
        return None


def normalize_space(text):
    if not text:
        return ""

    return re.sub(
        r"\s+",
        " ",
        text
    ).strip()


def absolute_url(base, link):
    if not link:
        return None

    return urljoin(base, link)


def looks_like_pdf(url):
    if not url:
        return False

    return (
        ".pdf" in url.lower()
        or "download" in url.lower()
        or "document" in url.lower()
    )


def sha1_text(text):
    return hashlib.sha1(
        text.encode("utf-8", errors="ignore")
    ).hexdigest()


# ============================================================
# HTTP SESSION
# ============================================================

def create_session():
    session = requests.Session()

    session.headers.update(HEADERS)

    # Government sites can be slow.
    # Do NOT aggressively hammer them.
    adapter = requests.adapters.HTTPAdapter(
        pool_connections=10,
        pool_maxsize=10,
        max_retries=2
    )

    session.mount("https://", adapter)
    session.mount("http://", adapter)

    return session


def get(session, url, timeout=TIMEOUT):
    """
    Safe GET.

    We deliberately do not invent fallback values.
    """

    try:
        response = session.get(
            url,
            timeout=timeout,
            verify=True,
            allow_redirects=True
        )

        if response.status_code >= 400:
            print(
                f"   HTTP {response.status_code}: {url}"
            )
            return None

        return response

    except requests.RequestException as exc:
        print(
            f"   Request failed: {url}\n"
            f"   {exc}"
        )
        return None


# ============================================================
# HTML LINK DISCOVERY
# ============================================================

def extract_links(html, base_url):
    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    links = []

    for a in soup.find_all("a", href=True):
        href = a.get("href")
        text = normalize_space(
            a.get_text(" ", strip=True)
        )

        full = absolute_url(
            base_url,
            href
        )

        if not full:
            continue

        links.append({
            "url": full,
            "text": text
        })

    return links


def discover_pdf_links(
    session,
    page_url,
    keywords=None
):
    """
    Discover PDF/download links from archive page.
    """

    response = get(
        session,
        page_url
    )

    if response is None:
        return []

    links = extract_links(
        response.text,
        page_url
    )

    result = []

    for item in links:

        blob = (
            item["url"]
            + " "
            + item["text"]
        ).lower()

        if keywords:
            if not any(
                k.lower() in blob
                for k in keywords
            ):
                continue

        if looks_like_pdf(item["url"]):
            result.append(item)

    # Deduplicate
    seen = set()
    unique = []

    for item in result:
        if item["url"] in seen:
            continue

        seen.add(item["url"])
        unique.append(item)

    return unique


# ============================================================
# PDF DOWNLOAD
# ============================================================

def download_pdf(
    session,
    url
):
    response = get(
        session,
        url,
        timeout=60
    )

    if response is None:
        return None

    content = response.content

    # Check PDF magic bytes.
    if content[:4] != b"%PDF":
        return None

    return content


# ============================================================
# PDF TEXT EXTRACTION
# ============================================================

def extract_pdf_text(pdf_bytes):
    if not pdfplumber:
        print(
            "   pdfplumber not installed."
        )
        return ""

    try:
        with pdfplumber.open(
            io.BytesIO(pdf_bytes)
        ) as pdf:

            pages = []

            for page in pdf.pages:
                text = page.extract_text(
                    x_tolerance=2,
                    y_tolerance=3
                )

                if text:
                    pages.append(text)

            return "\n".join(pages)

    except Exception as exc:
        print(
            f"   PDF extraction failed: {exc}"
        )
        return ""


def extract_pdf_tables(pdf_bytes):
    """
    Return all extractable tables.

    This is intentionally kept separate from text
    because many government PDFs have useful tables
    even when text regex is weak.
    """

    if not pdfplumber:
        return []

    tables = []

    try:
        with pdfplumber.open(
            io.BytesIO(pdf_bytes)
        ) as pdf:

            for page_number, page in enumerate(
                pdf.pages,
                start=1
            ):

                try:
                    page_tables = page.extract_tables()

                    for table in page_tables:

                        tables.append({
                            "page": page_number,
                            "rows": table
                        })

                except Exception:
                    continue

    except Exception:
        pass

    return tables


# ============================================================
# PERIOD DETECTION
# ============================================================

def period_from_text(text):
    """
    Detect report period from title/text.
    """

    if not text:
        return None

    text_lower = text.lower()

    month_patterns = {
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

    for name, number in month_patterns.items():

        pattern = (
            rf"\b{name}\b"
            r"[\s,\-_/]*(20\d{2})"
        )

        match = re.search(
            pattern,
            text_lower
        )

        if match:
            return (
                f"{match.group(1)}-{number}"
            )

    # YYYY-MM
    match = re.search(
        r"\b(20\d{2})[-/](0[1-9]|1[0-2])\b",
        text
    )

    if match:
        return (
            f"{match.group(1)}-{match.group(2)}"
        )

    return None


# ============================================================
# GENERIC TABLE SEARCH
# ============================================================

def rows_as_text(tables):
    output = []

    for table in tables:

        for row in table.get("rows", []):

            if not row:
                continue

            cleaned = [
                normalize_space(cell)
                if cell is not None
                else ""
                for cell in row
            ]

            line = " | ".join(
                cell for cell in cleaned
                if cell
            )

            if line:
                output.append(line)

    return output


def find_row(
    rows,
    keywords
):
    """
    Find first row containing all required
    semantic keywords.
    """

    for row in rows:

        low = row.lower()

        if all(
            keyword.lower() in low
            for keyword in keywords
        ):
            return row

    return None


def numbers_from_row(row):
    if not row:
        return []

    matches = re.findall(
        r"[-+]?\d[\d,]*(?:\.\d+)?",
        row
    )

    values = []

    for item in matches:

        value = clean_number(item)

        if value is not None:
            values.append(value)

    return values


# ============================================================
# DPIIT
# ============================================================

DPIIT_ARCHIVES = [
    "https://eaindustry.nic.in/",
    "https://eaindustry.nic.in/eight_core_infra.asp",
]


def parse_dpiit_document(
    pdf_bytes,
    report_url,
    period
):
    text = extract_pdf_text(
        pdf_bytes
    )

    tables = extract_pdf_tables(
        pdf_bytes
    )

    rows = rows_as_text(
        tables
    )

    result = {
        "period": period,
        "source": "DPIIT/OEA",
        "report_url": report_url,
        "cement": None,
        "steel": None,
        "overall_core_growth_pct": None,
        "raw_sha1": sha1_text(text),
    }

    # ---- table first ----

    for row in rows:

        low = row.lower()
        nums = numbers_from_row(row)

        if not nums:
            continue

        if (
            "cement" in low
            and result["cement"] is None
        ):
            # Prefer production-like values
            candidates = [
                n for n in nums
                if 1 <= n <= 100
            ]

            if candidates:
                result["cement"] = candidates[-1]

        if (
            "steel" in low
            and result["steel"] is None
        ):
            candidates = [
                n for n in nums
                if 1 <= n <= 150
            ]

            if candidates:
                result["steel"] = candidates[-1]

    # ---- text fallback ----

    if result["cement"] is None:

        match = re.search(
            r"Cement.{0,150}?(\d+(?:\.\d+)?)",
            text,
            re.IGNORECASE | re.DOTALL
        )

        if match:
            value = clean_number(
                match.group(1)
            )

            if value is not None:
                result["cement"] = value

    if result["steel"] is None:

        match = re.search(
            r"Steel.{0,150}?(\d+(?:\.\d+)?)",
            text,
            re.IGNORECASE | re.DOTALL
        )

        if match:
            value = clean_number(
                match.group(1)
            )

            if value is not None:
                result["steel"] = value

    return result


def scrape_dpiit(
    session,
    period
):
    print(
        f"\n🏭 DPIIT/OEA — {period}"
    )

    # We intentionally do not use fake hardcoded
    # values if official archive discovery fails.

    candidate_links = []

    for archive in DPIIT_ARCHIVES:

        response = get(
            session,
            archive
        )

        if response is None:
            continue

        links = extract_links(
            response.text,
            archive
        )

        for item in links:

            blob = (
                item["url"]
                + " "
                + item["text"]
            ).lower()

            if (
                "core" in blob
                or "industr" in blob
                or "press" in blob
            ):
                candidate_links.append(
                    item["url"]
                )

    # Deduplicate
    candidate_links = list(
        dict.fromkeys(
            candidate_links
        )
    )

    target_year = period[:4]
    target_month = MONTHS[
        int(period[5:7])
    ].lower()

    for url in candidate_links:

        blob = url.lower()

        if (
            target_year in blob
            or target_month in blob
        ):
            pdf = download_pdf(
                session,
                url
            )

            if pdf:
                parsed = parse_dpiit_document(
                    pdf,
                    url,
                    period
                )

                if (
                    parsed["cement"] is not None
                    or parsed["steel"] is not None
                ):
                    return parsed

    return {
        "period": period,
        "source": "DPIIT/OEA",
        "report_url": None,
        "cement": None,
        "steel": None,
        "overall_core_growth_pct": None,
    }


# ============================================================
# PPAC
# ============================================================

PPAC_ARCHIVE_BASE = (
    "https://ppac.gov.in/archives/reports"
)


def scrape_ppac_archive_pages(
    session,
    max_pages=30
):
    """
    PPAC archive is paginated.

    Collect Industry Consumption Report links
    from all relevant archive pages.
    """

    all_reports = []

    for page_number in range(
        0,
        max_pages
    ):

        if page_number == 0:
            url = PPAC_ARCHIVE_BASE
        else:
            url = (
                PPAC_ARCHIVE_BASE
                + f"?page={page_number}"
            )

        print(
            f"   PPAC archive page: {page_number}"
        )

        response = get(
            session,
            url
        )

        if response is None:
            continue

        links = extract_links(
            response.text,
            url
        )

        found_any = False

        for item in links:

            text = item["text"]

            low = text.lower()

            if (
                "industry consumption report"
                in low
            ):
                found_any = True

                all_reports.append({
                    "title": text,
                    "url": item["url"]
                })

        # Stop only after multiple empty pages.
        if not found_any and page_number > 5:
            break

    # Deduplicate
    unique = {}

    for item in all_reports:
        unique[item["url"]] = item

    return list(
        unique.values()
    )


def parse_ppac_document(
    pdf_bytes,
    report_url,
    period
):
    text = extract_pdf_text(
        pdf_bytes
    )

    tables = extract_pdf_tables(
        pdf_bytes
    )

    rows = rows_as_text(
        tables
    )

    result = {
        "period": period,
        "source": "PPAC",
        "report_url": report_url,
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None,
        "raw_sha1": sha1_text(text),
    }

    # ---- Table extraction ----

    for row in rows:

        low = row.lower()
        nums = numbers_from_row(row)

        if not nums:
            continue

        if (
            result["hsd_diesel_tmt"] is None
            and (
                "hsd" in low
                or "high speed diesel" in low
                or "diesel" in low
            )
        ):

            candidates = [
                n for n in nums
                if 1000 <= n <= 15000
            ]

            if candidates:
                result["hsd_diesel_tmt"] = (
                    candidates[-1]
                )

        if (
            result["bitumen_tmt"] is None
            and "bitumen" in low
        ):

            candidates = [
                n for n in nums
                if 100 <= n <= 5000
            ]

            if candidates:
                result["bitumen_tmt"] = (
                    candidates[-1]
                )

        if (
            result["petcoke_tmt"] is None
            and (
                "petcoke" in low
                or "petroleum coke" in low
            )
        ):

            candidates = [
                n for n in nums
                if 50 <= n <= 5000
            ]

            if candidates:
                result["petcoke_tmt"] = (
                    candidates[-1]
                )

    return result


def scrape_ppac(
    session,
    period,
    archive_reports
):
    print(
        f"\n🛢️ PPAC — {period}"
    )

    target_name = month_name(
        period
    ).lower()

    candidates = []

    for report in archive_reports:

        title = report["title"].lower()

        # Current reports explicitly carry month/year.
        # Older reports sometimes have generic titles,
        # therefore publication metadata is not blindly
        # converted into a value.
        if (
            target_name in title
            or (
                MONTHS[
                    int(period[5:7])
                ].lower()
                in title
                and period[:4] in title
            )
        ):
            candidates.append(
                report
            )

    # For older PPAC generic titles, don't guess.
    # We only parse a document when its own content
    # identifies the target month.
    for candidate in candidates:

        response = get(
            session,
            candidate["url"]
        )

        if response is None:
            continue

        pdf_bytes = response.content

        if pdf_bytes[:4] != b"%PDF":
            continue

        text = extract_pdf_text(
            pdf_bytes
        )

        detected_period = period_from_text(
            text
        )

        if detected_period != period:
            continue

        return parse_ppac_document(
            pdf_bytes,
            candidate["url"],
            period
        )

    return {
        "period": period,
        "source": "PPAC",
        "report_url": None,
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None,
    }


# ============================================================
# PORTS — MINISTRY OF PORTS
# ============================================================

PORTS_ARCHIVE = (
    "https://shipmin.gov.in/"
    "transport-reseach/"
    "monthly-cargo-traffic-handled-major-ports"
)


def scrape_ports_archive(
    session
):
    print(
        "\n⚓ Reading Ministry of Ports archive..."
    )

    response = get(
        session,
        PORTS_ARCHIVE
    )

    if response is None:
        return []

    links = extract_links(
        response.text,
        PORTS_ARCHIVE
    )

    result = []

    for item in links:

        blob = (
            item["url"]
            + " "
            + item["text"]
        ).lower()

        if (
            "major port" in blob
            and (
                "cargo" in blob
                or "traffic" in blob
            )
        ):
            result.append(item)

    unique = {}

    for item in result:
        unique[item["url"]] = item

    return list(
        unique.values()
    )


def parse_ports_document(
    pdf_bytes,
    report_url,
    period
):
    text = extract_pdf_text(
        pdf_bytes
    )

    tables = extract_pdf_tables(
        pdf_bytes
    )

    rows = rows_as_text(
        tables
    )

    result = {
        "period": period,
        "source": "Ministry of Ports",
        "report_url": report_url,
        "cargo_traffic_mt": None,
        "container_teus": None,
        "raw_sha1": sha1_text(text),
    }

    for row in rows:

        low = row.lower()
        nums = numbers_from_row(row)

        if not nums:
            continue

        if (
            result["container_teus"] is None
            and (
                "container" in low
                or "teu" in low
            )
        ):

            candidates = [
                n for n in nums
                if 0.01 <= n <= 100
            ]

            if candidates:
                result["container_teus"] = (
                    candidates[-1]
                )

        if (
            result["cargo_traffic_mt"] is None
            and (
                "total traffic" in low
                or "cargo traffic" in low
                or "total cargo" in low
            )
        ):

            candidates = [
                n for n in nums
                if 0.1 <= n <= 500
            ]

            if candidates:
                result["cargo_traffic_mt"] = (
                    candidates[-1]
                )

    # Text fallback
    if result["container_teus"] is None:

        match = re.search(
            r"([\d,.]+)\s*(?:million\s*)?TEU",
            text,
            re.IGNORECASE
        )

        if match:
            result["container_teus"] = (
                clean_number(
                    match.group(1)
                )
            )

    return result


def scrape_ports(
    session,
    period,
    archive_links
):
    print(
        f"\n🚢 PORTS — {period}"
    )

    month = MONTHS[
        int(period[5:7])
    ].lower()

    year = period[:4]

    candidates = []

    for item in archive_links:

        blob = (
            item["url"]
            + " "
            + item["text"]
        ).lower()

        if (
            year in blob
            and month in blob
            and "major port" in blob
        ):
            candidates.append(
                item
            )

    for candidate in candidates:

        # The content page may itself contain the PDF.
        response = get(
            session,
            candidate["url"]
        )

        if response is None:
            continue

        links = extract_links(
            response.text,
            candidate["url"]
        )

        pdf_candidates = [
            x["url"]
            for x in links
            if looks_like_pdf(x["url"])
        ]

        # Sometimes the page itself redirects to PDF.
        if (
            not pdf_candidates
            and response.content[:4] == b"%PDF"
        ):
            pdf_candidates = [
                candidate["url"]
            ]

        for pdf_url in pdf_candidates:

            pdf_bytes = download_pdf(
                session,
                pdf_url
            )

            if not pdf_bytes:
                continue

            text = extract_pdf_text(
                pdf_bytes
            )

            detected_period = period_from_text(
                text
            )

            # Some port PDFs don't expose the month
            # cleanly; in that case the archive title
            # is used because it explicitly identifies
            # the month/year.
            if (
                detected_period
                and detected_period != period
            ):
                continue

            return parse_ports_document(
                pdf_bytes,
                pdf_url,
                period
            )

    return {
        "period": period,
        "source": "Ministry of Ports",
        "report_url": None,
        "cargo_traffic_mt": None,
        "container_teus": None,
    }


# ============================================================
# RAILWAYS
# ============================================================

PIB_RELEASES = [
    "https://pib.gov.in/AllRelease.aspx"
]


def scrape_railways(
    session,
    period
):
    """
    Railway data is intentionally conservative.

    We only save values when an official release
    containing the target period can be located.

    No guessed monthly value.
    """

    print(
        f"\n🚂 RAILWAYS — {period}"
    )

    result = {
        "period": period,
        "source": "Ministry of Railways / PIB",
        "report_url": None,
        "originating_freight_mt": None,
        "freight_revenue_cr": None,
        "cement_clinker_mt": None,
        "iron_ore_mt": None,
    }

    for archive in PIB_RELEASES:

        response = get(
            session,
            archive
        )

        if response is None:
            continue

        links = extract_links(
            response.text,
            archive
        )

        target_month = MONTHS[
            int(period[5:7])
        ].lower()

        target_year = period[:4]

        for item in links:

            blob = (
                item["text"]
                + " "
                + item["url"]
            ).lower()

            if (
                "railway" not in blob
                and "freight" not in blob
            ):
                continue

            if target_year not in blob:
                continue

            if target_month not in blob:
                continue

            release_url = item["url"]

            rel = get(
                session,
                release_url
            )

            if rel is None:
                continue

            text = BeautifulSoup(
                rel.text,
                "html.parser"
            ).get_text(
                " ",
                strip=True
            )

            result["report_url"] = (
                release_url
            )

            # Freight loading
            match = re.search(
                r"(?:freight loading|"
                r"originating freight|"
                r"freight of)"
                r".{0,80}?"
                r"([\d,]+(?:\.\d+)?)\s*"
                r"(?:million\s*)?MT",
                text,
                re.IGNORECASE
            )

            if match:
                result[
                    "originating_freight_mt"
                ] = clean_number(
                    match.group(1)
                )

            # Revenue
            match = re.search(
                r"(?:revenue|freight revenue)"
                r".{0,60}?"
                r"₹?\s*([\d,]+(?:\.\d+)?)"
                r"\s*crore",
                text,
                re.IGNORECASE
            )

            if match:
                result[
                    "freight_revenue_cr"
                ] = clean_number(
                    match.group(1)
                )

            # Cement
            match = re.search(
                r"([\d,]+(?:\.\d+)?)\s*"
                r"(?:million\s*)?MT\s*"
                r"(?:of\s*)?cement",
                text,
                re.IGNORECASE
            )

            if match:
                result[
                    "cement_clinker_mt"
                ] = clean_number(
                    match.group(1)
                )

            # Iron ore
            match = re.search(
                r"([\d,]+(?:\.\d+)?)\s*"
                r"(?:million\s*)?MT\s*"
                r"(?:of\s*)?iron ore",
                text,
                re.IGNORECASE
            )

            if match:
                result[
                    "iron_ore_mt"
                ] = clean_number(
                    match.group(1)
                )

            return result

    return result


# ============================================================
# FASTAG
# ============================================================

FASTAG_SOURCES = [
    "https://www.npci.org.in/what-we-do/netc-fastag/product-statistics",
    "https://ihmcl.co.in/fastag-statistics/"
]


def scrape_fastag(
    session,
    period
):
    print(
        f"\n🛣️ FASTag — {period}"
    )

    result = {
        "period": period,
        "source": "NPCI / NETC FASTag",
        "report_url": None,
        "toll_volume_crores": None,
        "toll_value_inr_crores": None,
    }

    target_month = MONTHS[
        int(period[5:7])
    ].lower()

    target_year = period[:4]

    for url in FASTAG_SOURCES:

        response = get(
            session,
            url
        )

        if response is None:
            continue

        text = BeautifulSoup(
            response.text,
            "html.parser"
        ).get_text(
            " ",
            strip=True
        )

        low = text.lower()

        if (
            target_year not in low
            or target_month not in low
        ):
            continue

        result["report_url"] = url

        # We do NOT blindly take random numbers from
        # the page. Only explicitly labelled statistics.

        match = re.search(
            r"(?:transactions?|volume)"
            r".{0,100}?"
            r"([\d,.]+)\s*(?:crore|cr)",
            text,
            re.IGNORECASE
        )

        if match:
            result[
                "toll_volume_crores"
            ] = clean_number(
                match.group(1)
            )

        match = re.search(
            r"(?:value|amount)"
            r".{0,100}?"
            r"₹?\s*([\d,.]+)\s*(?:crore|cr)",
            text,
            re.IGNORECASE
        )

        if match:
            result[
                "toll_value_inr_crores"
            ] = clean_number(
                match.group(1)
            )

        return result

    return result


# ============================================================
# DATABASE
# ============================================================

def load_database():
    if not os.path.exists(
        OUTPUT_FILE
    ):
        return {
            "schema_version": "1.0",
            "generated_at": None,
            "period_start": TARGET_MONTHS[0],
            "period_end": TARGET_MONTHS[-1],
            "months": {}
        }

    try:

        with open(
            OUTPUT_FILE,
            "r",
            encoding="utf-8"
        ) as f:

            data = json.load(f)

        if not isinstance(
            data,
            dict
        ):
            raise ValueError(
                "Invalid database"
            )

        data.setdefault(
            "months",
            {}
        )

        return data

    except Exception:
        return {
            "schema_version": "1.0",
            "generated_at": None,
            "period_start": TARGET_MONTHS[0],
            "period_end": TARGET_MONTHS[-1],
            "months": {}
        }


def save_database(db):
    db["generated_at"] = now_ist()

    tmp_file = (
        OUTPUT_FILE
        + ".tmp"
    )

    with open(
        tmp_file,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            db,
            f,
            ensure_ascii=False,
            indent=2
        )

    os.replace(
        tmp_file,
        OUTPUT_FILE
    )


# ============================================================
# NORMALIZE OUTPUT
# ============================================================

def build_month_record(
    period
):
    return {
        "period": period,

        "cement": {
            "production_mt": None,
            "source": None,
            "report_url": None
        },

        "steel": {
            "production_mt": None,
            "source": None,
            "report_url": None
        },

        "ppac": {
            "hsd_diesel_tmt": None,
            "bitumen_tmt": None,
            "petcoke_tmt": None,
            "source": None,
            "report_url": None
        },

        "railways": {
            "originating_freight_mt": None,
            "freight_revenue_cr": None,
            "cement_clinker_mt": None,
            "iron_ore_mt": None,
            "source": None,
            "report_url": None
        },

        "ports": {
            "cargo_traffic_mt": None,
            "container_teus": None,
            "source": None,
            "report_url": None
        },

        "fastag": {
            "toll_volume_crores": None,
            "toll_value_inr_crores": None,
            "source": None,
            "report_url": None
        }
    }


def merge_dpiit(
    record,
    data
):
    record["cement"][
        "production_mt"
    ] = data.get("cement")

    record["cement"][
        "source"
    ] = data.get("source")

    record["cement"][
        "report_url"
    ] = data.get("report_url")

    record["steel"][
        "production_mt"
    ] = data.get("steel")

    record["steel"][
        "source"
    ] = data.get("source")

    record["steel"][
        "report_url"
    ] = data.get("report_url")


def merge_ppac(
    record,
    data
):
    record["ppac"][
        "hsd_diesel_tmt"
    ] = data.get(
        "hsd_diesel_tmt"
    )

    record["ppac"][
        "bitumen_tmt"
    ] = data.get(
        "bitumen_tmt"
    )

    record["ppac"][
        "petcoke_tmt"
    ] = data.get(
        "petcoke_tmt"
    )

    record["ppac"][
        "source"
    ] = data.get("source")

    record["ppac"][
        "report_url"
    ] = data.get("report_url")


def merge_railways(
    record,
    data
):
    for key in [
        "originating_freight_mt",
        "freight_revenue_cr",
        "cement_clinker_mt",
        "iron_ore_mt"
    ]:
        record["railways"][key] = (
            data.get(key)
        )

    record["railways"][
        "source"
    ] = data.get("source")

    record["railways"][
        "report_url"
    ] = data.get("report_url")


def merge_ports(
    record,
    data
):
    record["ports"][
        "cargo_traffic_mt"
    ] = data.get(
        "cargo_traffic_mt"
    )

    record["ports"][
        "container_teus"
    ] = data.get(
        "container_teus"
    )

    record["ports"][
        "source"
    ] = data.get("source")

    record["ports"][
        "report_url"
    ] = data.get("report_url")


def merge_fastag(
    record,
    data
):
    record["fastag"][
        "toll_volume_crores"
    ] = data.get(
        "toll_volume_crores"
    )

    record["fastag"][
        "toll_value_inr_crores"
    ] = data.get(
        "toll_value_inr_crores"
    )

    record["fastag"][
        "source"
    ] = data.get("source")

    record["fastag"][
        "report_url"
    ] = data.get("report_url")


# ============================================================
# SUMMARY
# ============================================================

def print_summary(db):

    print("\n")
    print("=" * 80)
    print("HARVEST COMPLETE")
    print("=" * 80)

    months = db.get(
        "months",
        {}
    )

    print(
        f"📁 File: {OUTPUT_FILE}"
    )

    print(
        f"📅 Target: "
        f"{TARGET_MONTHS[0]} → "
        f"{TARGET_MONTHS[-1]}"
    )

    print(
        f"📊 Months stored: "
        f"{len(months)}/{len(TARGET_MONTHS)}"
    )

    counters = {
        "cement": 0,
        "steel": 0,
        "hsd": 0,
        "bitumen": 0,
        "ports": 0,
        "railways": 0,
        "fastag": 0,
    }

    for record in months.values():

        if record["cement"][
            "production_mt"
        ] is not None:
            counters["cement"] += 1

        if record["steel"][
            "production_mt"
        ] is not None:
            counters["steel"] += 1

        if record["ppac"][
            "hsd_diesel_tmt"
        ] is not None:
            counters["hsd"] += 1

        if record["ppac"][
            "bitumen_tmt"
        ] is not None:
            counters["bitumen"] += 1

        if (
            record["ports"][
                "cargo_traffic_mt"
            ] is not None
            or
            record["ports"][
                "container_teus"
            ] is not None
        ):
            counters["ports"] += 1

        if (
            record["railways"][
                "originating_freight_mt"
            ] is not None
            or
            record["railways"][
                "cement_clinker_mt"
            ] is not None
        ):
            counters["railways"] += 1

        if (
            record["fastag"][
                "toll_volume_crores"
            ] is not None
        ):
            counters["fastag"] += 1

    for key, value in counters.items():

        print(
            f"   {key.upper():12} "
            f"{value}/{len(TARGET_MONTHS)}"
        )

    print("=" * 80)
    print(
        "ℹ️ No synthetic fallback values inserted."
    )
    print(
        "ℹ️ Missing official observations remain null."
    )
    print("=" * 80)


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 80)
    print(
        "🚀 OFFICIAL MACRO ARCHIVE HARVESTER"
    )
    print("=" * 80)

    print(
        f"📅 Period: "
        f"{TARGET_MONTHS[0]} → "
        f"{TARGET_MONTHS[-1]}"
    )

    print(
        f"🕒 Started: {now_ist()}"
    )

    if pdfplumber is None:

        print(
            "\n❌ pdfplumber is required."
        )

        print(
            "Install:"
        )

        print(
            "pip install pdfplumber"
        )

        return

    session = create_session()

    db = load_database()

    db[
        "schema_version"
    ] = "2.0-official-archive"

    db[
        "period_start"
    ] = TARGET_MONTHS[0]

    db[
        "period_end"
    ] = TARGET_MONTHS[-1]

    # --------------------------------------------------------
    # Pre-discover archives
    # --------------------------------------------------------

    print(
        "\n📚 Discovering PPAC archive..."
    )

    ppac_reports = scrape_ppac_archive_pages(
        session
    )

    print(
        f"   PPAC reports found: "
        f"{len(ppac_reports)}"
    )

    print(
        "\n📚 Discovering Ports archive..."
    )

    ports_reports = scrape_ports_archive(
        session
    )

    print(
        f"   Ports reports found: "
        f"{len(ports_reports)}"
    )

    # --------------------------------------------------------
    # Month-by-month
    # --------------------------------------------------------

    for index, period in enumerate(
        TARGET_MONTHS,
        start=1
    ):

        print("\n")
        print(
            "=" * 80
        )

        print(
            f"MONTH {index}/"
            f"{len(TARGET_MONTHS)}"
            f" — {period}"
        )

        print(
            "=" * 80
        )

        record = db[
            "months"
        ].get(
            period,
            build_month_record(
                period
            )
        )

        # ---------------- DPIIT ----------------

        try:

            dpiit = scrape_dpiit(
                session,
                period
            )

            merge_dpiit(
                record,
                dpiit
            )

        except Exception as exc:

            print(
                f"   DPIIT failed: {exc}"
            )

        # ---------------- PPAC ----------------

        try:

            ppac = scrape_ppac(
                session,
                period,
                ppac_reports
            )

            merge_ppac(
                record,
                ppac
            )

        except Exception as exc:

            print(
                f"   PPAC failed: {exc}"
            )

        # ---------------- Railways ----------------

        try:

            railways = scrape_railways(
                session,
                period
            )

            merge_railways(
                record,
                railways
            )

        except Exception as exc:

            print(
                f"   Railways failed: {exc}"
            )

        # ---------------- Ports ----------------

        try:

            ports = scrape_ports(
                session,
                period,
                ports_reports
            )

            merge_ports(
                record,
                ports
            )

        except Exception as exc:

            print(
                f"   Ports failed: {exc}"
            )

        # ---------------- FASTag ----------------

        try:

            fastag = scrape_fastag(
                session,
                period
            )

            merge_fastag(
                record,
                fastag
            )

        except Exception as exc:

            print(
                f"   FASTag failed: {exc}"
            )

        db[
            "months"
        ][period] = record

        # Save after every month.
        # If GitHub Actions/network fails halfway,
        # already harvested months remain saved.

        save_database(
            db
        )

        # Be polite to government servers.
        time.sleep(1.5)

    # --------------------------------------------------------
    # Final save
    # --------------------------------------------------------

    save_database(
        db
    )

    print_summary(
        db
    )


if __name__ == "__main__":
    main()