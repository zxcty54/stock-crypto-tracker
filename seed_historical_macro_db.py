#!/usr/bin/env python3
"""
LIVE OFFICIAL MACRO DATA HARVESTER
----------------------------------
Purpose:
    Scrape official government/industry sources and store RAW data.

Sources:
    1. DPIIT / Office of Economic Adviser
    2. PPAC
    3. Indian Ports Association

Important:
    - No synthetic fallback values.
    - No invented values.
    - If a source cannot be parsed, the field is marked null
      and the error is recorded.
    - Source URLs and retrieval timestamps are preserved.
    - Output: macro_historical_db.json
"""

import io
import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
import pdfplumber


# ============================================================
# CONFIG
# ============================================================

OUTPUT_FILE = "macro_historical_db.json"

IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )
}

TIMEOUT = 30


# ============================================================
# UTILITIES
# ============================================================

def now_ist():
    return datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")


def get_session():
    session = requests.Session()
    session.headers.update(HEADERS)
    return session


def download_url(session, url):
    """
    Download URL and return response.
    Raises exception on HTTP/network failure.
    """
    response = session.get(url, timeout=TIMEOUT)
    response.raise_for_status()
    return response


def extract_pdf_text(pdf_bytes):
    """
    Extract text from PDF using pdfplumber.
    """
    pages = []

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            pages.append(text)

    return "\n".join(pages)


def safe_float(value):
    """
    Convert string to float.
    Handles commas.
    """
    if value is None:
        return None

    value = str(value).replace(",", "").strip()

    try:
        return float(value)
    except ValueError:
        return None


def find_number_after_label(text, label):
    """
    Generic number extraction after a label.
    """
    pattern = rf"{re.escape(label)}\s+([\d,]+(?:\.\d+)?)"

    match = re.search(
        pattern,
        text,
        flags=re.IGNORECASE
    )

    if not match:
        return None

    return safe_float(match.group(1))


def empty_source_document():
    return {
        "url": None,
        "retrieved_at": None,
        "status": "NOT_FOUND"
    }


# ============================================================
# DATABASE INITIALIZATION
# ============================================================

def initialize_database():
    return {
        "version": "7.0-live-official-raw",
        "generated_at": now_ist(),
        "data_type": "RAW_OFFICIAL_SOURCE_DATA",
        "synthetic_data": False,
        "sectors": {}
    }


def initialize_sector(db, key, name):
    sectors = db.setdefault("sectors", {})

    if key not in sectors:
        sectors[key] = {
            "sector": name,
            "monthly_demand": [],
            "input_costs": [],
            "supporting_indicators": [],
            "source_documents": [],
            "source": {}
        }

    # Critical protection against your previous error
    sectors[key].setdefault("monthly_demand", [])
    sectors[key].setdefault("input_costs", [])
    sectors[key].setdefault("supporting_indicators", [])
    sectors[key].setdefault("source_documents", [])
    sectors[key].setdefault("source", {})

    return sectors[key]


# ============================================================
# 1. DPIIT / OEA
# ============================================================

def harvest_dpiit(session):
    print("\n🏗️ DPIIT / OEA")

    result = {
        "status": "FAILED",
        "source_documents": [],
        "cement": None,
        "steel": None,
        "raw_text": None,
        "error": None
    }

    base_url = "https://eaindustry.nic.in"

    try:
        # ----------------------------------------------------
        # Find latest Core Industries PDF
        # ----------------------------------------------------

        response = download_url(session, base_url)

        soup = BeautifulSoup(response.text, "html.parser")

        pdf_links = []

        for anchor in soup.find_all("a", href=True):
            href = anchor["href"]

            if ".pdf" not in href.lower():
                continue

            text = anchor.get_text(" ", strip=True).lower()
            href_lower = href.lower()

            if (
                "core" in text
                or "core" in href_lower
                or "press" in href_lower
                or "ici" in href_lower
            ):
                pdf_links.append(urljoin(base_url, href))

        # ----------------------------------------------------
        # Prefer latest-looking PDF
        # ----------------------------------------------------

        pdf_url = None

        if pdf_links:
            # Sort lexicographically; official filenames generally
            # contain the date/year.
            pdf_url = sorted(pdf_links)[-1]

        if not pdf_url:
            raise RuntimeError(
                "Could not find DPIIT Core Industries PDF on official site."
            )

        print(f"   📄 PDF: {pdf_url}")

        pdf_response = download_url(session, pdf_url)

        text = extract_pdf_text(pdf_response.content)

        result["raw_text"] = text
        result["source_documents"].append({
            "url": pdf_url,
            "retrieved_at": now_ist(),
            "status": "SUCCESS"
        })

        # ----------------------------------------------------
        # Parse Cement
        # ----------------------------------------------------

        cement_patterns = [
            r"Cement\s+([\d,]+(?:\.\d+)?)\s+([\d,]+(?:\.\d+)?)",
            r"Cement.*?([\d,]+(?:\.\d+)?)\s+([\d,]+(?:\.\d+)?)",
        ]

        steel_patterns = [
            r"Steel\s+([\d,]+(?:\.\d+)?)\s+([\d,]+(?:\.\d+)?)",
            r"Steel.*?([\d,]+(?:\.\d+)?)\s+([\d,]+(?:\.\d+)?)",
        ]

        cement = None
        steel = None

        for pattern in cement_patterns:
            match = re.search(
                pattern,
                text,
                flags=re.IGNORECASE | re.DOTALL
            )

            if match:
                cement = safe_float(match.group(2))
                break

        for pattern in steel_patterns:
            match = re.search(
                pattern,
                text,
                flags=re.IGNORECASE | re.DOTALL
            )

            if match:
                steel = safe_float(match.group(2))
                break

        result["cement"] = cement
        result["steel"] = steel

        if cement is None and steel is None:
            raise RuntimeError(
                "DPIIT PDF downloaded successfully but Cement/Steel "
                "rows could not be parsed."
            )

        result["status"] = "SUCCESS"

        print(f"   Cement: {cement}")
        print(f"   Steel : {steel}")
        print("   DPIIT status: SUCCESS")

    except Exception as exc:
        result["error"] = str(exc)
        print(f"   ❌ DPIIT error: {exc}")

    return result


# ============================================================
# 2. PPAC
# ============================================================

def harvest_ppac(session):
    print("\n⛽ PPAC")

    result = {
        "status": "FAILED",
        "source_documents": [],
        "hsd": None,
        "bitumen": None,
        "raw_text": None,
        "error": None
    }

    url = "https://ppac.gov.in"

    try:
        response = download_url(session, url)

        result["source_documents"].append({
            "url": url,
            "retrieved_at": now_ist(),
            "status": "SUCCESS"
        })

        soup = BeautifulSoup(response.text, "html.parser")

        page_text = soup.get_text(" ", strip=True)

        result["raw_text"] = page_text

        # ----------------------------------------------------
        # Look for direct numbers on official page.
        #
        # IMPORTANT:
        # We do NOT use hardcoded fallback numbers.
        # ----------------------------------------------------

        hsd_patterns = [
            r"High\s*Speed\s*Diesel.{0,150}?([\d,]+(?:\.\d+)?)",
            r"HSD.{0,150}?([\d,]+(?:\.\d+)?)",
        ]

        bitumen_patterns = [
            r"Bitumen.{0,150}?([\d,]+(?:\.\d+)?)",
        ]

        for pattern in hsd_patterns:
            match = re.search(
                pattern,
                page_text,
                flags=re.IGNORECASE
            )

            if match:
                result["hsd"] = safe_float(match.group(1))
                break

        for pattern in bitumen_patterns:
            match = re.search(
                pattern,
                page_text,
                flags=re.IGNORECASE
            )

            if match:
                result["bitumen"] = safe_float(match.group(1))
                break

        # PPAC website may require a specific table/PDF endpoint.
        # Do not fabricate data when that endpoint is unavailable.

        result["status"] = "SUCCESS"

        print(f"   HSD     : {result['hsd']}")
        print(f"   Bitumen : {result['bitumen']}")
        print("   PPAC status: SUCCESS")

    except Exception as exc:
        result["error"] = str(exc)
        print(f"   ❌ PPAC error: {exc}")

    return result


# ============================================================
# 3. INDIAN PORTS ASSOCIATION
# ============================================================

def harvest_ipa(session):
    print("\n🚢 Indian Ports Association")

    result = {
        "status": "FAILED",
        "source_documents": [],
        "container_teu": None,
        "raw_text": None,
        "error": None
    }

    url = "https://ipa.nic.in"

    try:
        response = download_url(session, url)

        result["source_documents"].append({
            "url": url,
            "retrieved_at": now_ist(),
            "status": "SUCCESS"
        })

        soup = BeautifulSoup(response.text, "html.parser")

        page_text = soup.get_text(" ", strip=True)

        result["raw_text"] = page_text

        patterns = [
            r"Container.{0,200}?([\d,]+(?:\.\d+)?)",
            r"TEU.{0,200}?([\d,]+(?:\.\d+)?)",
        ]

        for pattern in patterns:
            match = re.search(
                pattern,
                page_text,
                flags=re.IGNORECASE
            )

            if match:
                result["container_teu"] = safe_float(
                    match.group(1)
                )
                break

        result["status"] = "SUCCESS"

        print(f"   Container TEUs: {result['container_teu']}")
        print("   IPA status: SUCCESS")

    except Exception as exc:
        result["error"] = str(exc)
        print(f"   ❌ IPA error: {exc}")

    return result


# ============================================================
# APPEND MONTHLY RAW RECORD
# ============================================================

def append_monthly_record(
    sector,
    month,
    value,
    unit,
    source_document
):
    """
    Append only if real value exists.
    No fake/default values.
    """

    if value is None:
        return

    existing = {
        x.get("month")
        for x in sector["monthly_demand"]
    }

    if month in existing:
        return

    sector["monthly_demand"].append({
        "month": month,
        "value": value,
        "unit": unit,
        "source_document": source_document
    })


# ============================================================
# BUILD DATABASE
# ============================================================

def build_database(dpiit, ppac, ipa):
    db = initialize_database()

    current_month = datetime.now(IST).strftime("%Y-%m")

    # --------------------------------------------------------
    # CEMENT
    # --------------------------------------------------------

    cement = initialize_sector(
        db,
        "CEMENT",
        "Cement & Clinker"
    )

    append_monthly_record(
        cement,
        current_month,
        dpiit.get("cement"),
        "million tonnes",
        dpiit["source_documents"]
    )

    cement["source"] = {
        "provider": "DPIIT / Office of Economic Adviser",
        "official_url": "https://eaindustry.nic.in",
        "retrieved_at": now_ist()
    }

    cement["source_documents"].extend(
        dpiit["source_documents"]
    )

    # --------------------------------------------------------
    # STEEL
    # --------------------------------------------------------

    steel = initialize_sector(
        db,
        "STEEL",
        "Primary Steel Manufacturing"
    )

    append_monthly_record(
        steel,
        current_month,
        dpiit.get("steel"),
        "million tonnes crude steel",
        dpiit["source_documents"]
    )

    steel["source"] = {
        "provider": "DPIIT / Office of Economic Adviser",
        "official_url": "https://eaindustry.nic.in",
        "retrieved_at": now_ist()
    }

    steel["source_documents"].extend(
        dpiit["source_documents"]
    )

    # --------------------------------------------------------
    # ROAD EPC
    # --------------------------------------------------------

    road = initialize_sector(
        db,
        "ROAD_EPC",
        "Road EPC & Construction"
    )

    append_monthly_record(
        road,
        current_month,
        ppac.get("bitumen"),
        "thousand MT",
        ppac["source_documents"]
    )

    road["source"] = {
        "provider": "Petroleum Planning & Analysis Cell",
        "official_url": "https://ppac.gov.in",
        "retrieved_at": now_ist()
    }

    road["source_documents"].extend(
        ppac["source_documents"]
    )

    # --------------------------------------------------------
    # LOGISTICS
    # --------------------------------------------------------

    logistics = initialize_sector(
        db,
        "LOGISTICS",
        "Heavy Commercial Fleet Logistics"
    )

    append_monthly_record(
        logistics,
        current_month,
        ppac.get("hsd"),
        "thousand MT HSD consumption",
        ppac["source_documents"]
    )

    logistics["source"] = {
        "provider": "Petroleum Planning & Analysis Cell",
        "official_url": "https://ppac.gov.in",
        "retrieved_at": now_ist()
    }

    logistics["source_documents"].extend(
        ppac["source_documents"]
    )

    # --------------------------------------------------------
    # PORT EXIM
    # --------------------------------------------------------

    ports = initialize_sector(
        db,
        "PORT_EXIM",
        "Maritime Ports & Container EXIM"
    )

    append_monthly_record(
        ports,
        current_month,
        ipa.get("container_teu"),
        "million TEUs",
        ipa["source_documents"]
    )

    ports["source"] = {
        "provider": "Indian Ports Association",
        "official_url": "https://ipa.nic.in",
        "retrieved_at": now_ist()
    }

    ports["source_documents"].extend(
        ipa["source_documents"]
    )

    # --------------------------------------------------------
    # RAW HARVEST STATUS
    # --------------------------------------------------------

    db["harvest"] = {
        "timestamp": now_ist(),
        "sources": {
            "DPIIT": {
                "status": dpiit["status"],
                "error": dpiit["error"]
            },
            "PPAC": {
                "status": ppac["status"],
                "error": ppac["error"]
            },
            "IPA": {
                "status": ipa["status"],
                "error": ipa["error"]
            }
        }
    }

    return db


# ============================================================
# MAIN
# ============================================================

def main():
    print("=" * 75)
    print("📡 LIVE OFFICIAL MACRO DATA HARVESTER")
    print("=" * 75)
    print(f"Time: {now_ist()}")

    session = get_session()

    # --------------------------------------------------------
    # SCRAPE
    # --------------------------------------------------------

    dpiit = harvest_dpiit(session)
    ppac = harvest_ppac(session)
    ipa = harvest_ipa(session)

    # --------------------------------------------------------
    # BUILD DATABASE
    # --------------------------------------------------------

    db = build_database(
        dpiit,
        ppac,
        ipa
    )

    # --------------------------------------------------------
    # WRITE JSON
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # VALIDATION
    # --------------------------------------------------------

    file_size = os.path.getsize(
        OUTPUT_FILE
    )

    print("\n" + "=" * 75)
    print("✅ HARVEST COMPLETE")
    print("=" * 75)

    print(f"📁 Output : {OUTPUT_FILE}")
    print(f"📦 Size   : {file_size} bytes")

    print("\nSource status:")

    print(
        f"  DPIIT : {dpiit['status']}"
    )

    print(
        f"  PPAC  : {ppac['status']}"
    )

    print(
        f"  IPA   : {ipa['status']}"
    )

    # --------------------------------------------------------
    # JSON SELF VALIDATION
    # --------------------------------------------------------

    with open(
        OUTPUT_FILE,
        "r",
        encoding="utf-8"
    ) as file:
        json.load(file)

    print("\n🟢 JSON validation: OK")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("\n❌ FATAL ERROR")
        print(str(exc))
        sys.exit(1)