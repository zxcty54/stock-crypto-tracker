#!/usr/bin/env python3
"""
LIVE OFFICIAL MACRO DATA HARVESTER
==================================

Purpose:
    Scrape official macroeconomic / industrial sources and
    save the harvested data into:

        macro_historical_db.json

Sources:
    1. DPIIT / Office of Economic Adviser
    2. PPAC
    3. Indian Ports Association

Design principles:
    - ZERO synthetic values
    - ZERO hardcoded fallback data
    - Official source metadata preserved
    - Raw source text preserved where available
    - Network failures do not create fake data
    - Missing data is represented as null
    - Source documents are recorded
    - JSON is validated before exit

Python:
    3.11+

Dependencies:
    requests
    beautifulsoup4
    pdfplumber
"""

import io
import json
import os
import re
import sys
import time
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup
import pdfplumber


# ============================================================
# CONFIGURATION
# ============================================================

OUTPUT_FILE = "macro_historical_db.json"

IST = timezone(timedelta(hours=5, minutes=30))

REQUEST_TIMEOUT = (
    20,   # connection timeout
    120   # read timeout
)

MAX_RETRIES = 3

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 "
        "(KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,"
        "application/xml;q=0.9,"
        "application/pdf;q=0.8,*/*;q=0.7"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive",
}


# ============================================================
# TIME / LOGGING
# ============================================================

def now_ist():
    return datetime.now(IST).strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )


def log(message):
    print(message, flush=True)


# ============================================================
# HTTP SESSION
# ============================================================

def create_session():
    session = requests.Session()

    session.headers.update(HEADERS)

    return session


def request_with_retry(
    session,
    url,
    method="GET",
    retries=MAX_RETRIES,
    **kwargs
):
    """
    HTTP request with retry.

    Returns:
        requests.Response

    Raises:
        Last encountered exception
    """

    kwargs.setdefault(
        "timeout",
        REQUEST_TIMEOUT
    )

    last_error = None

    for attempt in range(1, retries + 1):

        try:
            log(
                f"   🌐 Request "
                f"{attempt}/{retries}: {url}"
            )

            response = session.request(
                method,
                url,
                **kwargs
            )

            response.raise_for_status()

            return response

        except Exception as exc:

            last_error = exc

            log(
                f"   ⚠️ Attempt {attempt} failed: "
                f"{exc}"
            )

            if attempt < retries:

                sleep_seconds = min(
                    5 * attempt,
                    15
                )

                time.sleep(
                    sleep_seconds
                )

    raise last_error


# ============================================================
# BASIC UTILITIES
# ============================================================

def safe_float(value):
    if value is None:
        return None

    try:
        cleaned = (
            str(value)
            .replace(",", "")
            .replace("%", "")
            .strip()
        )

        if not cleaned:
            return None

        return float(cleaned)

    except Exception:
        return None


def extract_pdf_text(pdf_bytes):
    """
    Extract complete text from PDF.
    """

    pages = []

    with pdfplumber.open(
        io.BytesIO(pdf_bytes)
    ) as pdf:

        for page_number, page in enumerate(
            pdf.pages,
            start=1
        ):

            try:
                text = page.extract_text() or ""

            except Exception as exc:

                log(
                    f"   ⚠️ PDF page "
                    f"{page_number} parse error: "
                    f"{exc}"
                )

                text = ""

            pages.append(text)

    return "\n".join(pages)


def normalize_space(text):
    if not text:
        return ""

    return re.sub(
        r"\s+",
        " ",
        text
    ).strip()


def unique_list(values):
    output = []

    seen = set()

    for value in values:

        if not value:
            continue

        if value in seen:
            continue

        seen.add(value)

        output.append(value)

    return output


def is_pdf_url(url):
    if not url:
        return False

    return ".pdf" in url.lower()


def absolute_url(base_url, href):
    if not href:
        return None

    return urljoin(
        base_url,
        href
    )


# ============================================================
# DATABASE STRUCTURE
# ============================================================

def new_database():
    return {
        "version": "7.0-live-official-raw",
        "generated_at": now_ist(),
        "data_type": "RAW_OFFICIAL_SOURCE_DATA",
        "synthetic_data": False,
        "calculated_by_scraper": False,
        "sectors": {},
        "harvest_status": {},
    }


def ensure_sector(
    db,
    sector_key,
    sector_name
):

    sectors = db.setdefault(
        "sectors",
        {}
    )

    if sector_key not in sectors:

        sectors[sector_key] = {
            "sector": sector_name,
            "monthly_demand": [],
            "input_costs": [],
            "supporting_indicators": [],
            "source_documents": [],
            "source": {},
        }

    sector = sectors[sector_key]

    # Prevent KeyError such as the previous
    # source_documents error.

    sector.setdefault(
        "monthly_demand",
        []
    )

    sector.setdefault(
        "input_costs",
        []
    )

    sector.setdefault(
        "supporting_indicators",
        []
    )

    sector.setdefault(
        "source_documents",
        []
    )

    sector.setdefault(
        "source",
        {}
    )

    return sector


def append_source_document(
    sector,
    document
):

    if not document:
        return

    url = document.get(
        "url"
    )

    existing_urls = {
        item.get("url")
        for item in sector[
            "source_documents"
        ]
    }

    if url and url in existing_urls:
        return

    sector[
        "source_documents"
    ].append(document)


# ============================================================
# GENERIC MONTHLY RECORD
# ============================================================

def append_monthly_demand(
    sector,
    month,
    value,
    unit,
    source_url
):

    # IMPORTANT:
    # No value = no record.
    # Never insert synthetic value.

    if value is None:
        return

    existing_months = {
        item.get("month")
        for item in sector[
            "monthly_demand"
        ]
    }

    if month in existing_months:
        return

    sector[
        "monthly_demand"
    ].append(
        {
            "month": month,
            "value": value,
            "unit": unit,
            "source_url": source_url,
            "retrieved_at": now_ist(),
        }
    )


# ============================================================
# DPIIT / OEA
# ============================================================

def discover_dpiit_pdfs(
    session,
    base_url
):

    candidates = []

    try:

        response = request_with_retry(
            session,
            base_url
        )

        soup = BeautifulSoup(
            response.text,
            "html.parser"
        )

        for anchor in soup.find_all(
            "a",
            href=True
        ):

            href = anchor.get(
                "href"
            )

            text = normalize_space(
                anchor.get_text(
                    " ",
                    strip=True
                )
            )

            absolute = absolute_url(
                base_url,
                href
            )

            if not absolute:
                continue

            if not is_pdf_url(
                absolute
            ):
                continue

            combined = (
                f"{text} "
                f"{absolute}"
            ).lower()

            if (
                "core" in combined
                or "eight" in combined
                or "ici" in combined
                or "infra" in combined
                or "industry" in combined
            ):
                candidates.append(
                    absolute
                )

    except Exception as exc:

        log(
            f"   ⚠️ DPIIT discovery error: "
            f"{exc}"
        )

    return unique_list(
        candidates
    )


def harvest_dpiit(session):

    log("\n🏗️ DPIIT / OEA")

    result = {
        "status": "FAILED",
        "cement": None,
        "steel": None,
        "source_documents": [],
        "raw_text": None,
        "error": None,
    }

    base_url = (
        "https://eaindustry.nic.in"
    )

    try:

        pdf_candidates = (
            discover_dpiit_pdfs(
                session,
                base_url
            )
        )

        # ----------------------------------------------------
        # Known official archive pattern fallback.
        #
        # This is a URL PATTERN, not a data fallback.
        # ----------------------------------------------------

        archive_candidates = [
            (
                "https://eaindustry.nic.in/"
                "eight_core_infra/"
                "Press_Release_ICI_20260921.pdf"
            ),
        ]

        pdf_candidates = unique_list(
            pdf_candidates
            + archive_candidates
        )

        if not pdf_candidates:

            raise RuntimeError(
                "No DPIIT Core Industries PDF "
                "was discovered."
            )

        for pdf_url in pdf_candidates:

            try:

                log(
                    f"   📄 Trying PDF: "
                    f"{pdf_url}"
                )

                response = request_with_retry(
                    session,
                    pdf_url
                )

                content_type = (
                    response.headers
                    .get(
                        "Content-Type",
                        ""
                    )
                    .lower()
                )

                if (
                    "pdf" not in content_type
                    and not is_pdf_url(
                        response.url
                    )
                ):
                    log(
                        "   ⚠️ Response does not "
                        "look like PDF."
                    )
                    continue

                text = extract_pdf_text(
                    response.content
                )

                if not text.strip():

                    log(
                        "   ⚠️ PDF has no "
                        "extractable text."
                    )

                    continue

                result[
                    "raw_text"
                ] = text

                result[
                    "source_documents"
                ].append(
                    {
                        "url": response.url,
                        "retrieved_at": now_ist(),
                        "status": "SUCCESS",
                        "content_type": content_type,
                    }
                )

                # ------------------------------------------------
                # Cement
                # ------------------------------------------------

                cement_patterns = [

                    r"\bCement\s+"
                    r"([\d,]+(?:\.\d+)?)\s+"
                    r"([\d,]+(?:\.\d+)?)",

                    r"\bCement\b.{0,150}?"
                    r"([\d,]+(?:\.\d+)?)\s+"
                    r"([\d,]+(?:\.\d+)?)",
                ]

                # ------------------------------------------------
                # Steel
                # ------------------------------------------------

                steel_patterns = [

                    r"\bSteel\s+"
                    r"([\d,]+(?:\.\d+)?)\s+"
                    r"([\d,]+(?:\.\d+)?)",

                    r"\bSteel\b.{0,150}?"
                    r"([\d,]+(?:\.\d+)?)\s+"
                    r"([\d,]+(?:\.\d+)?)",
                ]

                cement = None
                steel = None

                for pattern in cement_patterns:

                    match = re.search(
                        pattern,
                        text,
                        flags=(
                            re.IGNORECASE
                            | re.DOTALL
                        )
                    )

                    if match:

                        cement = safe_float(
                            match.group(2)
                        )

                        if cement is not None:
                            break

                for pattern in steel_patterns:

                    match = re.search(
                        pattern,
                        text,
                        flags=(
                            re.IGNORECASE
                            | re.DOTALL
                        )
                    )

                    if match:

                        steel = safe_float(
                            match.group(2)
                        )

                        if steel is not None:
                            break

                result[
                    "cement"
                ] = cement

                result[
                    "steel"
                ] = steel

                # We successfully downloaded and parsed
                # the official PDF even if one row is missing.

                result[
                    "status"
                ] = "SUCCESS"

                log(
                    f"   Cement: {cement}"
                )

                log(
                    f"   Steel : {steel}"
                )

                log(
                    "   DPIIT status: SUCCESS"
                )

                return result

            except Exception as exc:

                log(
                    f"   ⚠️ PDF failed: "
                    f"{exc}"
                )

        raise RuntimeError(
            "All discovered DPIIT PDFs "
            "failed to download/parse."
        )

    except Exception as exc:

        result[
            "error"
        ] = str(exc)

        log(
            f"   ❌ DPIIT error: {exc}"
        )

    return result


# ============================================================
# PPAC
# ============================================================

def discover_ppac_documents(
    session
):

    base_urls = [
        "https://ppac.gov.in",
        "https://www.ppac.gov.in",
    ]

    documents = []

    for base_url in base_urls:

        try:

            response = request_with_retry(
                session,
                base_url,
                retries=2
            )

            soup = BeautifulSoup(
                response.text,
                "html.parser"
            )

            for anchor in soup.find_all(
                "a",
                href=True
            ):

                href = anchor[
                    "href"
                ]

                text = normalize_space(
                    anchor.get_text(
                        " ",
                        strip=True
                    )
                )

                absolute = absolute_url(
                    response.url,
                    href
                )

                if not absolute:
                    continue

                combined = (
                    f"{text} "
                    f"{absolute}"
                ).lower()

                if (
                    ".pdf" in absolute.lower()
                    or "consumption" in combined
                    or "petroleum" in combined
                    or "product" in combined
                    or "monthly" in combined
                    or "statistics" in combined
                    or "report" in combined
                ):

                    documents.append(
                        absolute
                    )

        except Exception as exc:

            log(
                f"   ⚠️ PPAC endpoint "
                f"unavailable: {exc}"
            )

    return unique_list(
        documents
    )


def parse_ppac_text(
    text
):

    hsd = None
    bitumen = None

    normalized = normalize_space(
        text
    )

    hsd_patterns = [

        r"High\s+Speed\s+Diesel"
        r".{0,250}?"
        r"([\d,]+(?:\.\d+)?)",

        r"\bHSD\b"
        r".{0,250}?"
        r"([\d,]+(?:\.\d+)?)",
    ]

    bitumen_patterns = [

        r"\bBitumen\b"
        r".{0,250}?"
        r"([\d,]+(?:\.\d+)?)",
    ]

    for pattern in hsd_patterns:

        match = re.search(
            pattern,
            normalized,
            flags=re.IGNORECASE
        )

        if match:

            hsd = safe_float(
                match.group(1)
            )

            if hsd is not None:
                break

    for pattern in bitumen_patterns:

        match = re.search(
            pattern,
            normalized,
            flags=re.IGNORECASE
        )

        if match:

            bitumen = safe_float(
                match.group(1)
            )

            if bitumen is not None:
                break

    return hsd, bitumen


def harvest_ppac(session):

    log("\n⛽ PPAC")

    result = {
        "status": "FAILED",
        "hsd": None,
        "bitumen": None,
        "source_documents": [],
        "raw_text": None,
        "error": None,
    }

    try:

        candidates = (
            discover_ppac_documents(
                session
            )
        )

        # Also try official homepages
        # themselves.

        candidates = unique_list(
            [
                "https://ppac.gov.in",
                "https://www.ppac.gov.in",
            ]
            + candidates
        )

        for url in candidates:

            try:

                log(
                    f"   📄 PPAC source: "
                    f"{url}"
                )

                response = request_with_retry(
                    session,
                    url,
                    retries=2
                )

                content_type = (
                    response.headers
                    .get(
                        "Content-Type",
                        ""
                    )
                    .lower()
                )

                text = ""

                if (
                    "pdf" in content_type
                    or is_pdf_url(
                        response.url
                    )
                ):

                    text = extract_pdf_text(
                        response.content
                    )

                else:

                    soup = BeautifulSoup(
                        response.text,
                        "html.parser"
                    )

                    text = soup.get_text(
                        "\n",
                        strip=True
                    )

                if not text.strip():
                    continue

                hsd, bitumen = (
                    parse_ppac_text(
                        text
                    )
                )

                # Only accept document as useful
                # if relevant values are found.

                if (
                    hsd is None
                    and bitumen is None
                ):
                    continue

                result[
                    "hsd"
                ] = hsd

                result[
                    "bitumen"
                ] = bitumen

                result[
                    "raw_text"
                ] = text

                result[
                    "source_documents"
                ].append(
                    {
                        "url": response.url,
                        "retrieved_at": now_ist(),
                        "status": "SUCCESS",
                        "content_type": content_type,
                    }
                )

                result[
                    "status"
                ] = "SUCCESS"

                log(
                    f"   HSD     : {hsd}"
                )

                log(
                    f"   Bitumen : {bitumen}"
                )

                log(
                    "   PPAC status: SUCCESS"
                )

                return result

            except Exception as exc:

                log(
                    f"   ⚠️ PPAC source failed: "
                    f"{exc}"
                )

        # Site can be reachable while relevant
        # table isn't discoverable.

        result[
            "error"
        ] = (
            "PPAC website was reachable or "
            "attempted, but no reliably parsed "
            "HSD/Bitumen value was found."
        )

        log(
            "   ⚠️ PPAC data not parsed."
        )

    except Exception as exc:

        result[
            "error"
        ] = str(exc)

        log(
            f"   ❌ PPAC error: {exc}"
        )

    return result


# ============================================================
# INDIAN PORTS ASSOCIATION
# ============================================================

def discover_ipa_documents(
    session
):

    base_urls = [
        "https://ipa.nic.in",
        "http://ipa.nic.in",
        "https://www.ipa.nic.in",
        "http://www.ipa.nic.in",
    ]

    documents = []

    for base_url in base_urls:

        try:

            response = request_with_retry(
                session,
                base_url,
                retries=2
            )

            soup = BeautifulSoup(
                response.text,
                "html.parser"
            )

            for anchor in soup.find_all(
                "a",
                href=True
            ):

                href = anchor[
                    "href"
                ]

                text = normalize_space(
                    anchor.get_text(
                        " ",
                        strip=True
                    )
                )

                absolute = absolute_url(
                    response.url,
                    href
                )

                if not absolute:
                    continue

                combined = (
                    f"{text} "
                    f"{absolute}"
                ).lower()

                if (
                    ".pdf" in absolute.lower()
                    or "traffic" in combined
                    or "container" in combined
                    or "teu" in combined
                    or "performance" in combined
                    or "monthly" in combined
                    or "statistics" in combined
                    or "cargo" in combined
                ):

                    documents.append(
                        absolute
                    )

        except Exception as exc:

            log(
                f"   ⚠️ IPA endpoint failed: "
                f"{exc}"
            )

    return unique_list(
        documents
    )


def parse_ipa_text(
    text
):

    normalized = normalize_space(
        text
    )

    patterns = [

        r"Container\s+Traffic"
        r".{0,250}?"
        r"([\d,]+(?:\.\d+)?)",

        r"Container"
        r".{0,250}?"
        r"TEU"
        r".{0,250}?"
        r"([\d,]+(?:\.\d+)?)",

        r"\bTEU\b"
        r".{0,250}?"
        r"([\d,]+(?:\.\d+)?)",
    ]

    for pattern in patterns:

        match = re.search(
            pattern,
            normalized,
            flags=re.IGNORECASE
        )

        if match:

            value = safe_float(
                match.group(1)
            )

            if value is not None:
                return value

    return None


def harvest_ipa(session):

    log("\n🚢 Indian Ports Association")

    result = {
        "status": "FAILED",
        "container_teu": None,
        "source_documents": [],
        "raw_text": None,
        "error": None,
    }

    # Multiple official endpoints.
    #
    # The important part is that failure of one
    # endpoint does NOT immediately terminate
    # the scraper.

    base_urls = [
        "https://ipa.nic.in",
        "http://ipa.nic.in",
        "https://www.ipa.nic.in",
        "http://www.ipa.nic.in",
    ]

    last_error = None

    # --------------------------------------------------------
    # First try direct official endpoints
    # --------------------------------------------------------

    for url in base_urls:

        try:

            log(
                f"   🌐 Trying: {url}"
            )

            response = request_with_retry(
                session,
                url,
                retries=3,
                timeout=(
                    30,
                    180
                )
            )

            log(
                f"   ✅ Connected: "
                f"{response.status_code} "
                f"{response.url}"
            )

            content_type = (
                response.headers
                .get(
                    "Content-Type",
                    ""
                )
                .lower()
            )

            if (
                "pdf" in content_type
                or is_pdf_url(
                    response.url
                )
            ):

                text = extract_pdf_text(
                    response.content
                )

            else:

                soup = BeautifulSoup(
                    response.text,
                    "html.parser"
                )

                text = soup.get_text(
                    "\n",
                    strip=True
                )

            value = parse_ipa_text(
                text
            )

            result[
                "raw_text"
            ] = text

            result[
                "source_documents"
            ].append(
                {
                    "url": response.url,
                    "retrieved_at": now_ist(),
                    "status": "SUCCESS",
                    "content_type": content_type,
                }
            )

            if value is not None:

                result[
                    "container_teu"
                ] = value

                result[
                    "status"
                ] = "SUCCESS"

                log(
                    f"   Container TEUs: "
                    f"{value}"
                )

                log(
                    "   IPA status: SUCCESS"
                )

                return result

            log(
                "   ⚠️ Connected but "
                "container TEU value "
                "was not found."
            )

        except Exception as exc:

            last_error = str(exc)

            log(
                f"   ⚠️ Failed: {url}"
            )

            log(
                f"      {exc}"
            )

    # --------------------------------------------------------
    # If homepage failed, try document discovery
    # from any reachable official endpoint.
    # --------------------------------------------------------

    documents = []

    for url in base_urls:

        try:

            documents.extend(
                discover_ipa_documents(
                    session
                )
            )

            if documents:
                break

        except Exception as exc:

            last_error = str(exc)

    documents = unique_list(
        documents
    )

    # --------------------------------------------------------
    # Try discovered official documents
    # --------------------------------------------------------

    for document_url in documents:

        try:

            log(
                f"   📄 IPA document: "
                f"{document_url}"
            )

            response = request_with_retry(
                session,
                document_url,
                retries=2,
                timeout=(
                    30,
                    180
                )
            )

            content_type = (
                response.headers
                .get(
                    "Content-Type",
                    ""
                )
                .lower()
            )

            if (
                "pdf" in content_type
                or is_pdf_url(
                    response.url
                )
            ):

                text = extract_pdf_text(
                    response.content
                )

            else:

                soup = BeautifulSoup(
                    response.text,
                    "html.parser"
                )

                text = soup.get_text(
                    "\n",
                    strip=True
                )

            value = parse_ipa_text(
                text
            )

            if value is None:
                continue

            result[
                "container_teu"
            ] = value

            result[
                "raw_text"
            ] = text

            result[
                "source_documents"
            ].append(
                {
                    "url": response.url,
                    "retrieved_at": now_ist(),
                    "status": "SUCCESS",
                    "content_type": content_type,
                }
            )

            result[
                "status"
            ] = "SUCCESS"

            log(
                f"   Container TEUs: "
                f"{value}"
            )

            log(
                "   IPA status: SUCCESS"
            )

            return result

        except Exception as exc:

            last_error = str(exc)

            log(
                f"   ⚠️ IPA document failed: "
                f"{exc}"
            )

    # --------------------------------------------------------
    # Nothing worked.
    # --------------------------------------------------------

    result[
        "error"
    ] = (
        "IPA official website/documents "
        "could not be reached or parsed. "
        f"Last error: {last_error}"
    )

    log(
        "   ❌ IPA unavailable "
        "from this runner."
    )

    return result


# ============================================================
# BUILD FINAL DATABASE
# ============================================================

def build_database(
    dpiit,
    ppac,
    ipa
):

    db = new_database()

    current_month = (
        datetime.now(IST)
        .strftime("%Y-%m")
    )

    # --------------------------------------------------------
    # CEMENT
    # --------------------------------------------------------

    cement = ensure_sector(
        db,
        "CEMENT",
        "Cement & Clinker"
    )

    if dpiit.get(
        "cement"
    ) is not None:

        source_url = None

        if dpiit[
            "source_documents"
        ]:

            source_url = dpiit[
                "source_documents"
            ][0].get("url")

        append_monthly_demand(
            cement,
            current_month,
            dpiit["cement"],
            "million tonnes",
            source_url
        )

    for document in dpiit[
        "source_documents"
    ]:

        append_source_document(
            cement,
            document
        )

    cement[
        "source"
    ] = {
        "provider":
            "DPIIT / Office of Economic Adviser",
        "official_url":
            "https://eaindustry.nic.in",
        "retrieved_at":
            now_ist(),
    }

    # --------------------------------------------------------
    # STEEL
    # --------------------------------------------------------

    steel = ensure_sector(
        db,
        "STEEL",
        "Primary Steel Manufacturing"
    )

    if dpiit.get(
        "steel"
    ) is not None:

        source_url = None

        if dpiit[
            "source_documents"
        ]:

            source_url = dpiit[
                "source_documents"
            ][0].get("url")

        append_monthly_demand(
            steel,
            current_month,
            dpiit["steel"],
            "million tonnes crude steel",
            source_url
        )

    for document in dpiit[
        "source_documents"
    ]:

        append_source_document(
            steel,
            document
        )

    steel[
        "source"
    ] = {
        "provider":
            "DPIIT / Office of Economic Adviser",
        "official_url":
            "https://eaindustry.nic.in",
        "retrieved_at":
            now_ist(),
    }

    # --------------------------------------------------------
    # ROAD EPC
    # --------------------------------------------------------

    road = ensure_sector(
        db,
        "ROAD_EPC",
        "Road EPC & Construction"
    )

    if ppac.get(
        "bitumen"
    ) is not None:

        source_url = None

        if ppac[
            "source_documents"
        ]:

            source_url = ppac[
                "source_documents"
            ][0].get("url")

        append_monthly_demand(
            road,
            current_month,
            ppac["bitumen"],
            "thousand MT bitumen",
            source_url
        )

    for document in ppac[
        "source_documents"
    ]:

        append_source_document(
            road,
            document
        )

    road[
        "source"
    ] = {
        "provider":
            "Petroleum Planning & Analysis Cell",
        "official_url":
            "https://ppac.gov.in",
        "retrieved_at":
            now_ist(),
    }

    # --------------------------------------------------------
    # LOGISTICS
    # --------------------------------------------------------

    logistics = ensure_sector(
        db,
        "LOGISTICS",
        "Heavy Commercial Fleet Logistics"
    )

    if ppac.get(
        "hsd"
    ) is not None:

        source_url = None

        if ppac[
            "source_documents"
        ]:

            source_url = ppac[
                "source_documents"
            ][0].get("url")

        append_monthly_demand(
            logistics,
            current_month,
            ppac["hsd"],
            "thousand MT HSD consumption",
            source_url
        )

    for document in ppac[
        "source_documents"
    ]:

        append_source_document(
            logistics,
            document
        )

    logistics[
        "source"
    ] = {
        "provider":
            "Petroleum Planning & Analysis Cell",
        "official_url":
            "https://ppac.gov.in",
        "retrieved_at":
            now_ist(),
    }

    # --------------------------------------------------------
    # PORT EXIM
    # --------------------------------------------------------

    ports = ensure_sector(
        db,
        "PORT_EXIM",
        "Maritime Ports & Container EXIM"
    )

    if ipa.get(
        "container_teu"
    ) is not None:

        source_url = None

        if ipa[
            "source_documents"
        ]:

            source_url = ipa[
                "source_documents"
            ][0].get("url")

        append_monthly_demand(
            ports,
            current_month,
            ipa["container_teu"],
            "million TEUs",
            source_url
        )

    for document in ipa[
        "source_documents"
    ]:

        append_source_document(
            ports,
            document
        )

    ports[
        "source"
    ] = {
        "provider":
            "Indian Ports Association",
        "official_url":
            "https://ipa.nic.in",
        "retrieved_at":
            now_ist(),
    }

    # --------------------------------------------------------
    # HARVEST STATUS
    # --------------------------------------------------------

    db[
        "harvest_status"
    ] = {

        "timestamp":
            now_ist(),

        "DPIIT": {
            "status":
                dpiit["status"],
            "cement":
                dpiit["cement"],
            "steel":
                dpiit["steel"],
            "error":
                dpiit["error"],
        },

        "PPAC": {
            "status":
                ppac["status"],
            "hsd":
                ppac["hsd"],
            "bitumen":
                ppac["bitumen"],
            "error":
                ppac["error"],
        },

        "IPA": {
            "status":
                ipa["status"],
            "container_teu":
                ipa["container_teu"],
            "error":
                ipa["error"],
        },
    }

    return db


# ============================================================
# WRITE DATABASE
# ============================================================

def save_database(db):

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8"
    ) as file:

        json.dump(
            db,
            file,
            ensure_ascii=False,
            indent=2
        )

    # Validate JSON immediately.

    with open(
        OUTPUT_FILE,
        "r",
        encoding="utf-8"
    ) as file:

        json.load(file)

    return os.path.getsize(
        OUTPUT_FILE
    )


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 75)
    print(
        "📡 LIVE OFFICIAL MACRO DATA HARVESTER"
    )
    print("=" * 75)

    print(
        f"Time: {now_ist()}"
    )

    print(
        "Mode: ZERO SYNTHETIC DATA"
    )

    print(
        "Output: "
        f"{OUTPUT_FILE}"
    )

    print("=" * 75)

    session = create_session()

    # --------------------------------------------------------
    # SOURCE HARVEST
    # --------------------------------------------------------

    dpiit = harvest_dpiit(
        session
    )

    ppac = harvest_ppac(
        session
    )

    ipa = harvest_ipa(
        session
    )

    # --------------------------------------------------------
    # BUILD DATABASE
    # --------------------------------------------------------

    database = build_database(
        dpiit,
        ppac,
        ipa
    )

    # --------------------------------------------------------
    # SAVE
    # --------------------------------------------------------

    file_size = save_database(
        database
    )

    # --------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------

    print("\n")
    print("=" * 75)
    print("✅ HARVEST COMPLETE")
    print("=" * 75)

    print(
        f"📁 File: {OUTPUT_FILE}"
    )

    print(
        f"📦 Size: {file_size} bytes"
    )

    print("\nSource Results:")

    print(
        f"🏗️ DPIIT : "
        f"{dpiit['status']}"
    )

    print(
        f"   Cement = "
        f"{dpiit['cement']}"
    )

    print(
        f"   Steel  = "
        f"{dpiit['steel']}"
    )

    print(
        f"\n⛽ PPAC : "
        f"{ppac['status']}"
    )

    print(
        f"   HSD     = "
        f"{ppac['hsd']}"
    )

    print(
        f"   Bitumen = "
        f"{ppac['bitumen']}"
    )

    print(
        f"\n🚢 IPA : "
        f"{ipa['status']}"
    )

    print(
        f"   Container TEU = "
        f"{ipa['container_teu']}"
    )

    print("\nJSON validation: OK")

    print(
        "\n⚠️ IMPORTANT: "
        "Any unavailable source is stored as null. "
        "No synthetic fallback values are used."
    )


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":

    try:

        main()

    except KeyboardInterrupt:

        print(
            "\n❌ Interrupted."
        )

        sys.exit(1)

    except Exception as exc:

        print(
            "\n❌ FATAL ERROR:"
        )

        print(
            str(exc)
        )

        sys.exit(1)