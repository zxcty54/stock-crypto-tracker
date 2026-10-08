#!/usr/bin/env python3
"""
3-YEAR OFFICIAL MACRO HISTORICAL HARVESTER
==========================================

Purpose:
    Scrape/collect official historical macro data and save ONLY raw/derived
    historical observations to:

        macro_historical_db.json

Target period:
    Last 36 completed months.

Sectors:
    CEMENT
    STEEL
    ROAD_EPC
    LOGISTICS
    PORT_EXIM

Sources:
    1. DPIIT / Office of Economic Adviser
       https://eaindustry.nic.in

    2. PPAC
       https://ppac.gov.in

    3. Indian Ports Association
       https://ipa.nic.in

Rules:
    - NO synthetic/fallback numbers.
    - If official value cannot be obtained -> null.
    - Python calculates MoM / YoY only when actual observations exist.
    - Source URL/document is retained.
    - One source failure must NOT kill the complete harvest.
    - Existing database is preserved where possible.
"""

import io
import os
import re
import json
import time
import calendar
from datetime import datetime, timedelta, timezone
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

END_DATE = datetime(NOW.year, NOW.month, 1)
START_DATE = END_DATE

for _ in range(35):
    START_DATE = (START_DATE.replace(day=1) - timedelta(days=1)).replace(day=1)

# This gives 36 calendar months including current month.
TARGET_MONTHS = []

cursor = START_DATE
while cursor <= END_DATE:
    TARGET_MONTHS.append(cursor.strftime("%Y-%m"))
    if cursor.month == 12:
        cursor = cursor.replace(year=cursor.year + 1, month=1)
    else:
        cursor = cursor.replace(month=cursor.month + 1)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 Chrome/124.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,application/pdf;q=0.8,*/*;q=0.7"
    ),
    "Accept-Language": "en-IN,en;q=0.9",
}

TIMEOUT = 40

SESSION = requests.Session()
SESSION.headers.update(HEADERS)


# ============================================================
# GENERAL HELPERS
# ============================================================

def log(msg=""):
    print(msg, flush=True)


def safe_get(url, timeout=TIMEOUT):
    try:
        r = SESSION.get(
            url,
            timeout=timeout,
            allow_redirects=True
        )
        r.raise_for_status()
        return r
    except Exception as e:
        log(f"      HTTP error: {url} -> {e}")
        return None


def clean_number(value):
    if value is None:
        return None

    value = str(value).strip()
    value = value.replace(",", "")
    value = value.replace("%", "")

    m = re.search(r"-?\d+(?:\.\d+)?", value)

    if not m:
        return None

    try:
        return float(m.group())
    except Exception:
        return None


def month_sort_key(month):
    try:
        return datetime.strptime(month, "%Y-%m")
    except Exception:
        return datetime.max


def month_minus(month, months):
    dt = datetime.strptime(month, "%Y-%m")

    year = dt.year
    mon = dt.month - months

    while mon <= 0:
        year -= 1
        mon += 12

    return f"{year:04d}-{mon:02d}"


def calculate_growth(records, value_key="value"):
    """
    Adds:
        mom_pct
        yoy_pct

    ONLY if actual historical comparison exists.
    """

    by_month = {
        x["month"]: x
        for x in records
        if x.get("month")
    }

    for rec in records:
        current = rec.get(value_key)

        if current is None:
            rec["mom_pct"] = None
            rec["yoy_pct"] = None
            continue

        previous_month = month_minus(rec["month"], 1)
        previous_year = month_minus(rec["month"], 12)

        prev = by_month.get(previous_month)
        yoy = by_month.get(previous_year)

        prev_val = prev.get(value_key) if prev else None
        yoy_val = yoy.get(value_key) if yoy else None

        if prev_val not in (None, 0):
            rec["mom_pct"] = round(
                ((current - prev_val) / prev_val) * 100,
                2
            )
        else:
            rec["mom_pct"] = None

        if yoy_val not in (None, 0):
            rec["yoy_pct"] = round(
                ((current - yoy_val) / yoy_val) * 100,
                2
            )
        else:
            rec["yoy_pct"] = None

    return records


def extract_pdf_text(content):
    if pdfplumber is None:
        log("      pdfplumber is not installed.")
        return ""

    try:
        text_parts = []

        with pdfplumber.open(io.BytesIO(content)) as pdf:
            for page in pdf.pages:
                try:
                    text_parts.append(page.extract_text() or "")
                except Exception:
                    pass

        return "\n".join(text_parts)

    except Exception as e:
        log(f"      PDF extraction error: {e}")
        return ""


def download_pdf(url):
    r = safe_get(url)

    if not r:
        return None

    content_type = r.headers.get("Content-Type", "").lower()

    if "pdf" in content_type or url.lower().endswith(".pdf"):
        return r.content

    # Some government servers return PDF without correct MIME.
    if r.content[:4] == b"%PDF":
        return r.content

    return None


def find_pdf_links(page_url, html):
    soup = BeautifulSoup(html, "html.parser")

    links = []

    for a in soup.find_all("a", href=True):
        href = a.get("href", "").strip()

        if not href:
            continue

        absolute = urljoin(page_url, href)

        text = (
            a.get_text(" ", strip=True)
            + " "
            + href
        ).lower()

        if ".pdf" in absolute.lower() or "pdf" in text:
            links.append(absolute)

    return list(dict.fromkeys(links))


def save_source_document(source_documents, sector, month, url, title=None):
    if not url:
        return

    source_documents.append({
        "sector": sector,
        "month": month,
        "url": url,
        "title": title,
        "captured_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    })


# ============================================================
# DATABASE STRUCTURE
# ============================================================

def empty_sector(name):
    return {
        "sector": name,
        "monthly_demand": [],
        "input_costs": [],
        "supporting_indicators": [],
        "source_documents": [],
        "data_quality": {
            "months_requested": len(TARGET_MONTHS),
            "months_with_demand": 0,
            "months_with_cost": 0,
            "months_with_supporting": 0
        }
    }


def load_database():
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass

    return {
        "version": "7.0-official-36-month",
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "period_start": TARGET_MONTHS[0],
        "period_end": TARGET_MONTHS[-1],
        "sectors": {}
    }


def ensure_sector(db, key, name):
    sectors = db.setdefault("sectors", {})

    if key not in sectors:
        sectors[key] = empty_sector(name)

    sec = sectors[key]

    sec.setdefault("sector", name)
    sec.setdefault("monthly_demand", [])
    sec.setdefault("input_costs", [])
    sec.setdefault("supporting_indicators", [])
    sec.setdefault("source_documents", [])
    sec.setdefault("data_quality", {})

    return sec


# ============================================================
# DPIIT
# ============================================================

DPIIT_URL = "https://eaindustry.nic.in"


def parse_core8_pdf(text):
    """
    Attempts to identify Cement and Steel rows from Core 8 PDF.

    Government PDF layouts can change, so multiple regex patterns
    are attempted.
    """

    result = {
        "cement": None,
        "steel": None
    }

    if not text:
        return result

    normalized = re.sub(r"\s+", " ", text)

    patterns = {
        "cement": [
            r"Cement\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)",
            r"Cement.*?([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)"
        ],
        "steel": [
            r"Steel\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)",
            r"Steel.*?([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)"
        ]
    }

    for key, pats in patterns.items():
        for pat in pats:
            m = re.search(pat, normalized, re.IGNORECASE)

            if m:
                # Usually current period is the later number.
                result[key] = clean_number(m.group(2))
                break

    return result


def harvest_dpiit():
    log("\n" + "=" * 70)
    log("🏗️ DPIIT / OFFICE OF ECONOMIC ADVISER")
    log("=" * 70)

    output = {
        month: {
            "cement": None,
            "steel": None,
            "source_url": None
        }
        for month in TARGET_MONTHS
    }

    page = safe_get(DPIIT_URL)

    if not page:
        log("   ❌ DPIIT landing page unavailable.")
        return output

    links = find_pdf_links(DPIIT_URL, page.text)

    # First try links containing core/eight/core industries.
    priority = []

    for link in links:
        low = link.lower()

        score = 0

        if "eight" in low:
            score += 5

        if "core" in low:
            score += 5

        if "infra" in low:
            score += 2

        priority.append((score, link))

    priority.sort(reverse=True)

    candidates = [x[1] for x in priority]

    # Search page itself for PDF-looking URLs.
    candidates += re.findall(
        r'https?://[^"\']+\.pdf',
        page.text,
        flags=re.IGNORECASE
    )

    candidates = list(dict.fromkeys(candidates))

    log(f"   📄 Candidate PDFs: {len(candidates)}")

    for pdf_url in candidates[:80]:
        low = pdf_url.lower()

        # Extract date from URL where possible.
        m = re.search(r"(20\d{2})(\d{2})(\d{2})", low)

        detected_month = None

        if m:
            detected_month = f"{m.group(1)}-{m.group(2)}"

        if detected_month not in TARGET_MONTHS:
            continue

        log(f"   📥 {detected_month}: {pdf_url}")

        content = download_pdf(pdf_url)

        if not content:
            continue

        text = extract_pdf_text(content)

        parsed = parse_core8_pdf(text)

        if parsed["cement"] is not None:
            output[detected_month]["cement"] = parsed["cement"]

        if parsed["steel"] is not None:
            output[detected_month]["steel"] = parsed["steel"]

        output[detected_month]["source_url"] = pdf_url

        if parsed["cement"] is not None or parsed["steel"] is not None:
            log(
                f"      ✅ Cement={parsed['cement']} "
                f"Steel={parsed['steel']}"
            )

    return output


# ============================================================
# PPAC
# ============================================================

PPAC_URL = "https://ppac.gov.in"


def parse_ppac_report(text):
    """
    Extract HSD and Bitumen monthly values from PPAC report text.

    PPAC reports normally expose product-level consumption in TMT.
    """

    result = {
        "hsd": None,
        "bitumen": None
    }

    if not text:
        return result

    lines = [
        re.sub(r"\s+", " ", x).strip()
        for x in text.splitlines()
        if x.strip()
    ]

    for line in lines:

        low = line.lower()

        # HSD
        if (
            re.search(r"\bHSD\b", line, re.IGNORECASE)
            and result["hsd"] is None
        ):
            nums = re.findall(
                r"\d+(?:\.\d+)?",
                line.replace(",", "")
            )

            if nums:
                # Prefer first sensible number.
                for n in nums:
                    v = float(n)
                    if 100 <= v <= 50000:
                        result["hsd"] = v
                        break

        # Bitumen
        if (
            "bitumen" in low
            and result["bitumen"] is None
        ):
            nums = re.findall(
                r"\d+(?:\.\d+)?",
                line.replace(",", "")
            )

            if nums:
                for n in nums:
                    v = float(n)

                    if 50 <= v <= 5000:
                        result["bitumen"] = v
                        break

    return result


def get_ppac_archive_pages():
    pages = [
        "https://ppac.gov.in/archives",
        "https://ppac.gov.in/archives/reports",
        "https://ppac.gov.in/all-whats-new"
    ]

    htmls = []

    for url in pages:
        r = safe_get(url)

        if r:
            htmls.append((url, r.text))

    return htmls


def harvest_ppac():
    log("\n" + "=" * 70)
    log("⛽ PPAC")
    log("=" * 70)

    output = {
        month: {
            "hsd": None,
            "bitumen": None,
            "source_url": None
        }
        for month in TARGET_MONTHS
    }

    archive_pages = get_ppac_archive_pages()

    candidates = []

    for page_url, html in archive_pages:

        soup = BeautifulSoup(html, "html.parser")

        for a in soup.find_all("a", href=True):
            href = a.get("href", "")
            text = a.get_text(" ", strip=True)

            combined = f"{text} {href}".lower()

            if (
                "consumption" in combined
                or "petroleum" in combined
                or "monthly report" in combined
                or "industry consumption" in combined
            ):
                absolute = urljoin(page_url, href)

                candidates.append(
                    (
                        absolute,
                        text
                    )
                )

    # Direct historical report pages are also useful.
    candidates = list(dict.fromkeys(candidates))

    log(f"   📄 Candidate reports: {len(candidates)}")

    for url, title in candidates:

        low = (url + " " + title).lower()

        # Find year/month from title or URL.
        detected = None

        # 2026_09, 202609, September_2026 etc.
        m = re.search(
            r"(20\d{2})[-_](0[1-9]|1[0-2])",
            low
        )

        if m:
            detected = f"{m.group(1)}-{m.group(2)}"

        if detected is None:
            month_names = {
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

            for name, num in month_names.items():

                mm = re.search(
                    rf"{name}[^0-9]*(20\d{{2}})",
                    low
                )

                if mm:
                    detected = (
                        f"{mm.group(1)}-{num:02d}"
                    )
                    break

        if detected not in TARGET_MONTHS:
            continue

        log(f"   📥 {detected}: {title or url}")

        content = download_pdf(url)

        if not content:
            continue

        text = extract_pdf_text(content)

        parsed = parse_ppac_report(text)

        if (
            parsed["hsd"] is not None
            or parsed["bitumen"] is not None
        ):
            output[detected]["hsd"] = parsed["hsd"]
            output[detected]["bitumen"] = parsed["bitumen"]
            output[detected]["source_url"] = url

            log(
                f"      ✅ HSD={parsed['hsd']} "
                f"Bitumen={parsed['bitumen']}"
            )

    return output


# ============================================================
# IPA
# ============================================================

IPA_URLS = [
    "https://ipa.nic.in",
    "http://ipa.nic.in"
]


def parse_ipa_html(html):
    """
    Generic parser.

    Because IPA page layouts can change, this does not invent values.
    It only captures numbers that appear next to container/TEU terms.
    """

    result = []

    soup = BeautifulSoup(html, "html.parser")

    text = soup.get_text(" ", strip=True)

    text = re.sub(r"\s+", " ", text)

    patterns = [
        r"container.{0,100}?([0-9]+(?:\.[0-9]+)?)\s*(?:million\s*)?TEU",
        r"([0-9]+(?:\.[0-9]+)?)\s*(?:million\s*)?TEU"
    ]

    for pat in patterns:

        matches = re.findall(
            pat,
            text,
            flags=re.IGNORECASE
        )

        for x in matches:
            v = clean_number(x)

            if v is not None:
                result.append(v)

    return result


def harvest_ipa():
    log("\n" + "=" * 70)
    log("🚢 INDIAN PORTS ASSOCIATION")
    log("=" * 70)

    output = {
        month: {
            "container_teu": None,
            "source_url": None
        }
        for month in TARGET_MONTHS
    }

    # IPA can timeout. Try HTTPS and HTTP independently.
    for base in IPA_URLS:

        log(f"   🌐 Trying {base}")

        try:
            r = SESSION.get(
                base,
                timeout=20,
                allow_redirects=True
            )

            if r.status_code >= 400:
                continue

            # We do NOT assign a number to every month from current page.
            # Only actual month-labelled values are accepted.
            values = parse_ipa_html(r.text)

            if values:
                log(
                    f"   ℹ️ IPA page returned "
                    f"{len(values)} container-like values."
                )

            # Search linked reports/pages.
            links = find_pdf_links(base, r.text)

            for pdf_url in links[:100]:

                low = pdf_url.lower()

                if not (
                    "traffic" in low
                    or "container" in low
                    or "statistics" in low
                    or "monthly" in low
                    or "performance" in low
                ):
                    continue

                content = download_pdf(pdf_url)

                if not content:
                    continue

                text = extract_pdf_text(content)

                if not text:
                    continue

                # Detect month from URL.
                detected = None

                m = re.search(
                    r"(20\d{2})[-_](0[1-9]|1[0-2])",
                    low
                )

                if m:
                    detected = f"{m.group(1)}-{m.group(2)}"

                if detected not in TARGET_MONTHS:
                    continue

                # Look for TEU numbers.
                matches = re.findall(
                    r"([0-9]+(?:\.[0-9]+)?)\s*(?:million\s*)?TEU",
                    text,
                    flags=re.IGNORECASE
                )

                if matches:
                    vals = [
                        clean_number(x)
                        for x in matches
                    ]

                    vals = [
                        x for x in vals
                        if x is not None
                    ]

                    if vals:
                        # Do not blindly take first random number.
                        # Use the largest plausible TEU figure.
                        value = max(vals)

                        output[detected]["container_teu"] = value
                        output[detected]["source_url"] = pdf_url

                        log(
                            f"      ✅ {detected} "
                            f"Container TEU={value}"
                        )

        except Exception as e:
            log(f"   ⚠️ IPA attempt failed: {e}")

    return output


# ============================================================
# SUPPORTING DATA
# ============================================================

def build_supporting_indicators(db):
    """
    This function DOES NOT fabricate supporting indicators.

    It creates supporting records only when the primary source
    already contains a directly usable operational metric.

    Otherwise value remains null.
    """

    for key, sec in db["sectors"].items():

        demand = sec.get("monthly_demand", [])

        existing = {
            x["month"]: x
            for x in sec.get("supporting_indicators", [])
        }

        for d in demand:

            month = d["month"]

            if month in existing:
                continue

            sec["supporting_indicators"].append({
                "month": month,
                "indicator": None,
                "value": None,
                "unit": None,
                "source_url": None
            })


# ============================================================
# WRITE OBSERVATIONS
# ============================================================

def upsert_monthly(records, record):
    month = record["month"]

    for i, old in enumerate(records):

        if old.get("month") == month:

            merged = old.copy()

            for k, v in record.items():

                if v is not None:
                    merged[k] = v

            records[i] = merged
            return

    records.append(record)


def write_demand(sec, month, value, unit, source_url=None):

    record = {
        "month": month,
        "value": value,
        "unit": unit,
        "source_url": source_url
    }

    upsert_monthly(
        sec["monthly_demand"],
        record
    )


def write_cost(sec, month, metric, value, unit, source_url=None):

    record = {
        "month": month,
        "metric": metric,
        "value": value,
        "unit": unit,
        "source_url": source_url
    }

    upsert_monthly(
        sec["input_costs"],
        record
    )


# ============================================================
# FINALIZE
# ============================================================

def finalize_database(db):

    for key, sec in db["sectors"].items():

        sec["monthly_demand"].sort(
            key=lambda x: month_sort_key(x["month"])
        )

        sec["input_costs"].sort(
            key=lambda x: month_sort_key(x["month"])
        )

        sec["supporting_indicators"].sort(
            key=lambda x: month_sort_key(x["month"])
        )

        sec["source_documents"].sort(
            key=lambda x: month_sort_key(x.get("month", "9999-12"))
        )

        calculate_growth(
            sec["monthly_demand"],
            "value"
        )

        calculate_growth(
            sec["input_costs"],
            "value"
        )

        calculate_growth(
            sec["supporting_indicators"],
            "value"
        )

        dq = sec.setdefault("data_quality", {})

        dq["months_requested"] = len(TARGET_MONTHS)

        dq["months_with_demand"] = sum(
            1
            for x in sec["monthly_demand"]
            if x.get("value") is not None
        )

        dq["months_with_cost"] = sum(
            1
            for x in sec["input_costs"]
            if x.get("value") is not None
        )

        dq["months_with_supporting"] = sum(
            1
            for x in sec["supporting_indicators"]
            if x.get("value") is not None
        )

        dq["coverage_demand_pct"] = round(
            dq["months_with_demand"]
            / max(len(TARGET_MONTHS), 1)
            * 100,
            2
        )

        dq["coverage_cost_pct"] = round(
            dq["months_with_cost"]
            / max(len(TARGET_MONTHS), 1)
            * 100,
            2
        )

        dq["coverage_supporting_pct"] = round(
            dq["months_with_supporting"]
            / max(len(TARGET_MONTHS), 1)
            * 100,
            2
        )

    db["generated_at"] = NOW.strftime(
        "%Y-%m-%d %H:%M:%S IST"
    )

    db["period_start"] = TARGET_MONTHS[0]
    db["period_end"] = TARGET_MONTHS[-1]

    db["requested_month_count"] = len(TARGET_MONTHS)

    db["methodology"] = {
        "synthetic_data": False,
        "missing_values": "null",
        "growth_calculation": "Python from actual observations",
        "historical_period_months": 36,
        "ai_analysis_included": False
    }


# ============================================================
# MAIN
# ============================================================

def main():

    log("=" * 70)
    log("📡 OFFICIAL 36-MONTH MACRO HISTORICAL HARVESTER")
    log("=" * 70)

    log(
        f"📅 Period: "
        f"{TARGET_MONTHS[0]} → {TARGET_MONTHS[-1]}"
    )

    log(f"📊 Months requested: {len(TARGET_MONTHS)}")

    db = load_database()

    # --------------------------------------------------------
    # Ensure sectors
    # --------------------------------------------------------

    cement = ensure_sector(
        db,
        "CEMENT",
        "Cement & Clinker"
    )

    steel = ensure_sector(
        db,
        "STEEL",
        "Primary Steel Manufacturing"
    )

    road = ensure_sector(
        db,
        "ROAD_EPC",
        "Road EPC & Construction"
    )

    logistics = ensure_sector(
        db,
        "LOGISTICS",
        "Heavy Commercial Fleet Logistics"
    )

    ports = ensure_sector(
        db,
        "PORT_EXIM",
        "Maritime Ports & Container EXIM"
    )

    # --------------------------------------------------------
    # DPIIT
    # --------------------------------------------------------

    dpiit = harvest_dpiit()

    for month in TARGET_MONTHS:

        source = dpiit[month]["source_url"]

        write_demand(
            cement,
            month,
            dpiit[month]["cement"],
            "million tonnes",
            source
        )

        write_demand(
            steel,
            month,
            dpiit[month]["steel"],
            "million tonnes",
            source
        )

        if source:
            save_source_document(
                cement["source_documents"],
                "CEMENT",
                month,
                source,
                "DPIIT/OEA Eight Core Industries"
            )

            save_source_document(
                steel["source_documents"],
                "STEEL",
                month,
                source,
                "DPIIT/OEA Eight Core Industries"
            )

    # --------------------------------------------------------
    # PPAC
    # --------------------------------------------------------

    ppac = harvest_ppac()

    for month in TARGET_MONTHS:

        source = ppac[month]["source_url"]

        write_demand(
            road,
            month,
            ppac[month]["bitumen"],
            "thousand metric tonnes",
            source
        )

        write_demand(
            logistics,
            month,
            ppac[month]["hsd"],
            "thousand metric tonnes",
            source
        )

        if source:

            save_source_document(
                road["source_documents"],
                "ROAD_EPC",
                month,
                source,
                "PPAC Petroleum Products / Consumption Report"
            )

            save_source_document(
                logistics["source_documents"],
                "LOGISTICS",
                month,
                source,
                "PPAC Petroleum Products / Consumption Report"
            )

    # --------------------------------------------------------
    # IPA
    # --------------------------------------------------------

    ipa = harvest_ipa()

    for month in TARGET_MONTHS:

        source = ipa[month]["source_url"]

        write_demand(
            ports,
            month,
            ipa[month]["container_teu"],
            "million TEUs",
            source
        )

        if source:

            save_source_document(
                ports["source_documents"],
                "PORT_EXIM",
                month,
                source,
                "Indian Ports Association"
            )

    # --------------------------------------------------------
    # Supporting indicators
    # --------------------------------------------------------

    build_supporting_indicators(db)

    # --------------------------------------------------------
    # Remove duplicate source documents
    # --------------------------------------------------------

    for sec in db["sectors"].values():

        unique = {}

        for doc in sec.get("source_documents", []):

            key = (
                doc.get("month"),
                doc.get("url")
            )

            unique[key] = doc

        sec["source_documents"] = list(
            unique.values()
        )

    # --------------------------------------------------------
    # Calculate Python analytics
    # --------------------------------------------------------

    finalize_database(db)

    # --------------------------------------------------------
    # Save
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
            indent=2
        )

    # --------------------------------------------------------
    # Summary
    # --------------------------------------------------------

    log("\n" + "=" * 70)
    log("✅ HARVEST COMPLETE")
    log("=" * 70)

    log(f"📁 File: {DB_FILE}")
    log(f"📅 Period: {TARGET_MONTHS[0]} → {TARGET_MONTHS[-1]}")

    for key, sec in db["sectors"].items():

        dq = sec["data_quality"]

        log(
            f"   {key}: "
            f"demand={dq['months_with_demand']}/"
            f"{dq['months_requested']} "
            f"({dq['coverage_demand_pct']}%)"
        )

    log("=" * 70)
    log("ℹ️ No synthetic fallback values were inserted.")
    log("ℹ️ Missing official observations remain null.")
    log("ℹ️ AI analysis has NOT been performed.")


if __name__ == "__main__":
    main()