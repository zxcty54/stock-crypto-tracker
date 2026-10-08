import os
import io
import json
import re
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin

from bs4 import BeautifulSoup
from curl_cffi import requests

try:
    import pdfplumber
except ImportError:
    pdfplumber = None


OUTPUT_FILE = "macro_telemetry_master.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


def clean_num(value):
    if value is None:
        return None

    text = str(value).replace(",", "").replace("%", "").strip()

    match = re.search(r"[-+]?\d+(?:\.\d+)?", text)

    if not match:
        return None

    try:
        return float(match.group(0))
    except Exception:
        return None


def make_session():
    return requests.Session(
        impersonate="chrome124"
    )


def get(session, url, timeout=30):
    try:
        response = session.get(
            url,
            headers=HEADERS,
            timeout=timeout,
            verify=False,
            allow_redirects=True,
        )

        if response.status_code == 200:
            return response

        print(f"   HTTP {response.status_code}: {url}")

    except Exception as exc:
        print(f"   Request failed: {url}")
        print(f"   {exc}")

    return None


# ============================================================
# DPIIT / OEA
# ============================================================

def scrape_dpiit(session):

    print("\n" + "=" * 70)
    print("🏭 DPIIT / OEA — EIGHT CORE INDUSTRIES")
    print("=" * 70)

    result = {
        "source": "DPIIT / Office of Economic Adviser",
        "cement_growth_pct": None,
        "steel_growth_pct": None,
        "overall_core_growth_pct": None,
        "cement_production_mt": None,
        "steel_production_mt": None,
        "source_url": None,
        "status": "NOT_FOUND",
    }

    urls = [
        "https://eaindustry.nic.in/eight_core_infra.asp",
        "https://eaindustry.nic.in/",
    ]

    text = ""

    for url in urls:

        response = get(session, url)

        if not response:
            continue

        result["source_url"] = url

        content_type = response.headers.get(
            "content-type", ""
        ).lower()

        if "pdf" in content_type and pdfplumber:

            try:
                with pdfplumber.open(
                    io.BytesIO(response.content)
                ) as pdf:

                    text = "\n".join(
                        page.extract_text() or ""
                        for page in pdf.pages
                    )

            except Exception:
                continue

        else:

            soup = BeautifulSoup(
                response.text,
                "html.parser"
            )

            # Search PDF links.
            for a in soup.find_all("a", href=True):

                href = a["href"]

                label = (
                    a.get_text(" ", strip=True)
                    + " "
                    + href
                ).lower()

                if ".pdf" in href.lower() and (
                    "core" in label
                    or "press" in label
                    or "industry" in label
                ):

                    pdf_url = urljoin(
                        url,
                        href
                    )

                    print(f"   📄 PDF: {pdf_url}")

                    pdf_response = get(
                        session,
                        pdf_url,
                        timeout=40
                    )

                    if (
                        pdf_response
                        and pdfplumber
                    ):

                        try:

                            with pdfplumber.open(
                                io.BytesIO(
                                    pdf_response.content
                                )
                            ) as pdf:

                                text = "\n".join(
                                    page.extract_text() or ""
                                    for page in pdf.pages
                                )

                            result["source_url"] = pdf_url
                            break

                        except Exception:
                            pass

            if not text:
                text = soup.get_text(
                    " ",
                    strip=True
                )

        if text:
            break

    if not text:
        print("   ⚠️ DPIIT data not extracted.")
        return result

    lower = text.lower()

    # Overall core growth
    patterns = [
        r"eight core industries.*?(\d+(?:\.\d+)?)\s*%",
        r"combined index.*?(\d+(?:\.\d+)?)\s*%",
    ]

    for pattern in patterns:

        match = re.search(
            pattern,
            lower,
            re.IGNORECASE | re.DOTALL
        )

        if match:

            result["overall_core_growth_pct"] = clean_num(
                match.group(1)
            )

            break

    # Cement growth
    match = re.search(
        r"cement.*?(\d+(?:\.\d+)?)\s*%",
        lower,
        re.IGNORECASE | re.DOTALL
    )

    if match:
        result["cement_growth_pct"] = clean_num(
            match.group(1)
        )

    # Steel growth
    match = re.search(
        r"steel.*?(\d+(?:\.\d+)?)\s*%",
        lower,
        re.IGNORECASE | re.DOTALL
    )

    if match:
        result["steel_growth_pct"] = clean_num(
            match.group(1)
        )

    if (
        result["cement_growth_pct"] is not None
        or result["steel_growth_pct"] is not None
    ):
        result["status"] = "SUCCESS"

    print(
        "   Cement growth:",
        result["cement_growth_pct"]
    )

    print(
        "   Steel growth:",
        result["steel_growth_pct"]
    )

    return result


# ============================================================
# PPAC
# ============================================================

def scrape_ppac(session):

    print("\n" + "=" * 70)
    print("🛢️ PPAC — PETROLEUM CONSUMPTION")
    print("=" * 70)

    result = {
        "source": "PPAC",
        "hsd_diesel_tmt": None,
        "bitumen_tmt": None,
        "petcoke_tmt": None,
        "source_url": None,
        "status": "NOT_FOUND",
    }

    urls = [
        "https://ppac.gov.in/",
        "https://ppac.gov.in/consumption",
    ]

    for url in urls:

        response = get(
            session,
            url
        )

        if not response:
            continue

        result["source_url"] = url

        soup = BeautifulSoup(
            response.text,
            "html.parser"
        )

        page_text = soup.get_text(
            " ",
            strip=True
        )

        # Look through visible tables.
        for row in soup.find_all("tr"):

            cells = [
                c.get_text(
                    " ",
                    strip=True
                )
                for c in row.find_all(
                    ["td", "th"]
                )
            ]

            if not cells:
                continue

            row_text = " ".join(cells).lower()

            numbers = [
                clean_num(x)
                for x in re.findall(
                    r"[-+]?\d[\d,]*(?:\.\d+)?",
                    " ".join(cells)
                )
            ]

            numbers = [
                x for x in numbers
                if x is not None
            ]

            if (
                ("hsd" in row_text
                 or "diesel" in row_text)
                and numbers
            ):

                candidates = [
                    x for x in numbers
                    if 3000 <= x <= 15000
                ]

                if candidates:
                    result["hsd_diesel_tmt"] = candidates[-1]

            if "bitumen" in row_text:

                candidates = [
                    x for x in numbers
                    if 100 <= x <= 3000
                ]

                if candidates:
                    result["bitumen_tmt"] = candidates[-1]

            if (
                "pet coke" in row_text
                or "petcoke" in row_text
                or "petroleum coke" in row_text
            ):

                candidates = [
                    x for x in numbers
                    if 100 <= x <= 5000
                ]

                if candidates:
                    result["petcoke_tmt"] = candidates[-1]

        if (
            result["hsd_diesel_tmt"] is not None
            or result["bitumen_tmt"] is not None
        ):
            result["status"] = "PARTIAL"

        if (
            result["hsd_diesel_tmt"] is not None
            and result["bitumen_tmt"] is not None
        ):
            result["status"] = "SUCCESS"

        if result["status"] != "NOT_FOUND":
            break

    print(
        "   HSD:",
        result["hsd_diesel_tmt"]
    )

    print(
        "   Bitumen:",
        result["bitumen_tmt"]
    )

    print(
        "   Petcoke:",
        result["petcoke_tmt"]
    )

    return result


# ============================================================
# INDIAN RAILWAYS
# ============================================================

def scrape_railways(session):

    print("\n" + "=" * 70)
    print("🚂 INDIAN RAILWAYS — FREIGHT")
    print("=" * 70)

    result = {
        "source": "Indian Railways",
        "originating_freight_mt": None,
        "freight_revenue_cr": None,
        "cement_clinker_mt": None,
        "iron_ore_mt": None,
        "source_url": None,
        "status": "NOT_FOUND",
    }

    urls = [
        "https://pib.gov.in/",
        "https://www.indianrailways.gov.in/",
    ]

    for url in urls:

        response = get(
            session,
            url
        )

        if not response:
            continue

        result["source_url"] = url

        text = BeautifulSoup(
            response.text,
            "html.parser"
        ).get_text(
            " ",
            strip=True
        )

        # Freight loading
        patterns = [
            r"freight loading.*?([\d,]+(?:\.\d+)?)\s*mt",
            r"originating freight.*?([\d,]+(?:\.\d+)?)\s*mt",
            r"loading.*?([\d,]+(?:\.\d+)?)\s*mt",
        ]

        for pattern in patterns:

            match = re.search(
                pattern,
                text,
                re.IGNORECASE
            )

            if match:
                result["originating_freight_mt"] = clean_num(
                    match.group(1)
                )
                break

        match = re.search(
            r"revenue.*?₹?\s*([\d,]+(?:\.\d+)?)\s*crore",
            text,
            re.IGNORECASE
        )

        if match:
            result["freight_revenue_cr"] = clean_num(
                match.group(1)
            )

        if result["originating_freight_mt"] is not None:
            result["status"] = "SUCCESS"
            break

    print(
        "   Freight:",
        result["originating_freight_mt"]
    )

    print(
        "   Revenue:",
        result["freight_revenue_cr"]
    )

    return result


# ============================================================
# PORTS
# ============================================================

def scrape_ports(session):

    print("\n" + "=" * 70)
    print("🚢 INDIAN PORTS — CARGO / CONTAINER")
    print("=" * 70)

    result = {
        "source": "Indian Ports Association / Ministry of Ports",
        "cargo_traffic_mt": None,
        "container_teus": None,
        "source_url": None,
        "status": "NOT_FOUND",
    }

    # Do NOT depend only on ipa.nic.in.
    # Try Ministry / PIB sources too.
    urls = [
        "https://shipmin.gov.in/",
        "https://pib.gov.in/",
        "https://ipa.nic.in/",
    ]

    for url in urls:

        print(f"   🌐 Trying {url}")

        response = get(
            session,
            url,
            timeout=25
        )

        if not response:
            continue

        result["source_url"] = url

        soup = BeautifulSoup(
            response.text,
            "html.parser"
        )

        text = soup.get_text(
            " ",
            strip=True
        )

        # Container TEU
        patterns_teu = [
            r"([\d,]+(?:\.\d+)?)\s*million\s*teu",
            r"([\d,]+(?:\.\d+)?)\s*million\s*teus",
            r"([\d,]+(?:\.\d+)?)\s*teus",
        ]

        for pattern in patterns_teu:

            match = re.search(
                pattern,
                text,
                re.IGNORECASE
            )

            if match:

                value = clean_num(
                    match.group(1)
                )

                if value is not None:
                    result["container_teus"] = value
                    break

        # Cargo traffic
        patterns_cargo = [
            r"([\d,]+(?:\.\d+)?)\s*million\s*tonnes.*?cargo",
            r"cargo.*?([\d,]+(?:\.\d+)?)\s*million\s*tonnes",
            r"([\d,]+(?:\.\d+)?)\s*mt.*?cargo",
        ]

        for pattern in patterns_cargo:

            match = re.search(
                pattern,
                text,
                re.IGNORECASE
            )

            if match:

                value = clean_num(
                    match.group(1)
                )

                if value is not None:
                    result["cargo_traffic_mt"] = value
                    break

        if (
            result["container_teus"] is not None
            or result["cargo_traffic_mt"] is not None
        ):
            result["status"] = "PARTIAL"

        if (
            result["container_teus"] is not None
            and result["cargo_traffic_mt"] is not None
        ):
            result["status"] = "SUCCESS"

        if result["status"] != "NOT_FOUND":
            break

    print(
        "   Container TEUs:",
        result["container_teus"]
    )

    print(
        "   Cargo:",
        result["cargo_traffic_mt"]
    )

    return result


# ============================================================
# FASTAG
# ============================================================

def scrape_fastag(session):

    print("\n" + "=" * 70)
    print("🛣️ NPCI / NETC FASTag")
    print("=" * 70)

    result = {
        "source": "NPCI / NETC FASTag",
        "toll_volume_crore": None,
        "toll_value_crore": None,
        "source_url": None,
        "status": "NOT_FOUND",
    }

    urls = [
        "https://www.npci.org.in/what-we-do/netc-fastag/product-statistics",
        "https://www.npci.org.in/what-we-do/netc-fastag",
    ]

    for url in urls:

        response = get(
            session,
            url
        )

        if not response:
            continue

        result["source_url"] = url

        soup = BeautifulSoup(
            response.text,
            "html.parser"
        )

        # Search tables first.
        for row in soup.find_all("tr"):

            cells = [
                c.get_text(
                    " ",
                    strip=True
                )
                for c in row.find_all(
                    ["td", "th"]
                )
            ]

            if not cells:
                continue

            row_text = " ".join(
                cells
            ).lower()

            nums = [
                clean_num(x)
                for x in re.findall(
                    r"[\d,]+(?:\.\d+)?",
                    " ".join(cells)
                )
            ]

            nums = [
                x for x in nums
                if x is not None
            ]

            if not nums:
                continue

            if (
                "volume" in row_text
                or "transaction" in row_text
                or "transactions" in row_text
            ):

                candidates = [
                    x for x in nums
                    if 1 <= x <= 100
                ]

                if candidates:
                    result["toll_volume_crore"] = candidates[-1]

            if (
                "value" in row_text
                or "amount" in row_text
                or "toll" in row_text
            ):

                candidates = [
                    x for x in nums
                    if 500 <= x <= 20000
                ]

                if candidates:
                    result["toll_value_crore"] = candidates[-1]

        if (
            result["toll_volume_crore"] is not None
            or result["toll_value_crore"] is not None
        ):
            result["status"] = "PARTIAL"

        if (
            result["toll_volume_crore"] is not None
            and result["toll_value_crore"] is not None
        ):
            result["status"] = "SUCCESS"
            break

    print(
        "   Volume:",
        result["toll_volume_crore"]
    )

    print(
        "   Value:",
        result["toll_value_crore"]
    )

    return result


# ============================================================
# MAIN
# ============================================================

def run():

    print("=" * 80)
    print("🚀 LIVE MACRO TELEMETRY SCRAPER")
    print("=" * 80)

    print(
        "Time:",
        NOW.strftime(
            "%Y-%m-%d %H:%M:%S IST"
        )
    )

    session = make_session()

    payload = {
        "timestamp": NOW.strftime(
            "%Y-%m-%d %H:%M:%S IST"
        ),
        "data_period": NOW.strftime(
            "%Y-%m"
        ),
        "synthetic_data": False,
        "metrics": {
            "dpiit_eight_core":
                scrape_dpiit(session),

            "ppac_petroleum":
                scrape_ppac(session),

            "railways_freight":
                scrape_railways(session),

            "ports":
                scrape_ports(session),

            "fastag":
                scrape_fastag(session),
        }
    }

    # Existing history
    history = []

    if os.path.exists(OUTPUT_FILE):

        try:

            with open(
                OUTPUT_FILE,
                "r",
                encoding="utf-8"
            ) as f:

                old = json.load(f)

            if isinstance(old, list):
                history = old
            elif isinstance(old, dict):
                history = [old]

        except Exception:
            history = []

    # Avoid duplicate exact timestamp.
    history = [
        x for x in history
        if x.get("timestamp") != payload["timestamp"]
    ]

    history.insert(
        0,
        payload
    )

    # Keep last 36 snapshots.
    history = history[:36]

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            history,
            f,
            ensure_ascii=False,
            indent=2
        )

    print("\n" + "=" * 80)
    print("✅ HARVEST COMPLETE")
    print("=" * 80)

    print(
        f"📁 File: {OUTPUT_FILE}"
    )

    print(
        f"📊 Snapshots stored: {len(history)}"
    )

    print(
        "ℹ️ No synthetic fallback values were inserted."
    )

    print(
        "ℹ️ Unavailable official observations remain null."
    )


if __name__ == "__main__":
    run()