#!/usr/bin/env python3
"""
TELEGRAPH PUBLISHER (SEO & INSTANT VIEW ENGINE)
================================================
Publishes comprehensive, high-ranking DRHP analysis articles to Telegraph (telegra.ph).

Strategic Advantages:
1. Google Search Indexing: Telegraph has DA 80+ domain authority; articles index rapidly on Google.
2. Telegram Instant View: Articles render inside Telegram with native zero-latency Instant View (⚡).
3. Organic Traffic Funnel: High-converting CTA banners funnel organic Google search traffic to @ipocentral.
"""

from __future__ import annotations

import os
import re
import json
import logging
from typing import Any
import requests

from ipo_formatter import (
    format_currency,
    format_issue_size,
    format_short_date,
    format_date_range_display,
    format_gmp_percent,
    clean_registrar_name,
    derive_demat_date,
    REGISTRAR_PORTALS,
    CHANNEL_HANDLE,
    CHANNEL_URL,
)

logger = logging.getLogger("ipo_tracker.telegraph")

TELEGRAPH_API_BASE = "https://api.telegra.ph"
DEFAULT_TOKEN_FILE = ".telegraph_token"


# ============================================================
# TELEGRAPH DOM NODE BUILDERS
# ============================================================

def node(tag: str, children: list[dict | str] | None = None, attrs: dict[str, str] | None = None) -> dict:
    """Create a Telegraph-compliant DOM node element."""
    res: dict[str, Any] = {"tag": tag}
    if attrs:
        res["attrs"] = attrs
    if children:
        res["children"] = [c for c in children if c is not None and c != ""]
    return res


def p(*children) -> dict:
    return node("p", list(children))


def h3(text: str) -> dict:
    return node("h3", [text])


def h4(text: str) -> dict:
    return node("h4", [text])


def strong(text: str) -> dict:
    return node("strong", [text])


def em(text: str) -> dict:
    return node("em", [text])


def a(text: str, href: str) -> dict:
    return node("a", [text], {"href": href})


def li(*children) -> dict:
    return node("li", list(children))


def ul(items: list[dict]) -> dict:
    return node("ul", items)


def blockquote(*children) -> dict:
    return node("blockquote", list(children))


def hr() -> dict:
    return node("hr")


# ============================================================
# TELEGRAPH PUBLISHER CLASS
# ============================================================

class TelegraphPublisher:
    """Manages Telegraph authentication and publishes SEO-optimized IPO articles."""

    def __init__(self, token_file: str = DEFAULT_TOKEN_FILE) -> None:
        self.token_file = token_file
        self.access_token: str | None = os.environ.get("TELEGRAPH_ACCESS_TOKEN")
        if not self.access_token and os.path.exists(self.token_file):
            try:
                with open(self.token_file, "r", encoding="utf-8") as f:
                    self.access_token = f.read().strip() or None
            except Exception as e:
                logger.warning(f"Failed to read {self.token_file}: {e}")

    def get_or_create_account(
        self,
        short_name: str = "IPOCentral",
        author_name: str = "IPO Central",
        author_url: str = CHANNEL_URL,
    ) -> str | None:
        """Retrieve cached access token or create a new Telegraph account."""
        if self.access_token:
            return self.access_token

        logger.info(f"Creating new Telegraph account: {short_name} ({author_name})...")
        try:
            resp = requests.get(
                f"{TELEGRAPH_API_BASE}/createAccount",
                params={
                    "short_name": short_name,
                    "author_name": author_name,
                    "author_url": author_url,
                },
                timeout=12,
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("ok"):
                    token = data.get("result", {}).get("access_token")
                    if token:
                        self.access_token = token
                        try:
                            with open(self.token_file, "w", encoding="utf-8") as f:
                                f.write(token)
                            logger.info("Saved Telegraph access token to cache.")
                        except Exception as e:
                            logger.warning(f"Could not persist Telegraph token: {e}")
                        return token
                else:
                    logger.error(f"Telegraph createAccount error: {data.get('error')}")
            else:
                logger.error(f"Telegraph API returned HTTP {resp.status_code}")
        except Exception as e:
            logger.warning(f"Could not reach Telegraph API for account creation: {e}")

        return None

    def build_ipo_article_nodes(self, ipo: dict) -> list[dict]:
        """Build rich, structured, and SEO-optimized Telegraph DOM nodes for an IPO."""
        comp_name = ipo.get("company_name", "Mainboard IPO")
        sym = ipo.get("symbol", "")
        sector = ipo.get("sector", "")
        about = ipo.get("about", "")

        open_d = ipo.get("open_date")
        close_d = ipo.get("close_date")
        bidding_window = format_date_range_display(open_d, close_d)
        open_str = format_short_date(open_d)
        close_str = format_short_date(close_d)
        allot_str = format_short_date(ipo.get("allotment_date"))
        list_str = format_short_date(ipo.get("listing_date"))
        demat_str = format_short_date(
            ipo.get("demat_credit_date")
            or ipo.get("demat_date")
            or derive_demat_date(ipo.get("allotment_date"), ipo.get("listing_date"), ipo.get("close_date"))
        )

        price_band = ipo.get("price_band") or ipo.get("cut_off_price") or "TBA"
        if not str(price_band).startswith("₹") and price_band != "TBA":
            price_band = f"₹{price_band}"
        face_val = ipo.get("face_value", "10")
        lot_size = ipo.get("lot_size", "TBA")
        min_inv = ipo.get("min_investment")
        min_inv_str = f"₹{format_currency(min_inv)}" if min_inv else "TBA"

        issue_size = format_issue_size(ipo.get("issue_size_cr"))
        fresh_cr = format_currency(ipo.get("fresh_issue_cr"))
        ofs_cr = format_currency(ipo.get("ofs_cr"))

        gmp = ipo.get("gmp", "N/A")
        gmp_pct = format_gmp_percent(ipo.get("gmp_percent"))
        gmp_display = f"{gmp} ({gmp_pct})" if gmp_pct and gmp != "N/A" else str(gmp)
        est_list = ipo.get("est_listing_price", "TBA")
        kostak = ipo.get("kostak", "TBA")
        sub2 = ipo.get("sub2sauda", "TBA")

        # Registrar
        reg_obj = ipo.get("registrar", {})
        if isinstance(reg_obj, dict):
            raw_reg_name = reg_obj.get("name", "Official Registrar")
            reg_url = reg_obj.get("url") or REGISTRAR_PORTALS.get("bse", "https://www.bseindia.com")
        else:
            raw_reg_name = str(reg_obj) if reg_obj else "Official Registrar"
            reg_url = REGISTRAR_PORTALS.get("bse", "https://www.bseindia.com")

        for key, p_url in REGISTRAR_PORTALS.items():
            if key in raw_reg_name.lower():
                reg_url = p_url
                break

        reg_name = clean_registrar_name(raw_reg_name)

        nodes: list[dict] = []

        # 1. Hero / Header Funnel CTA
        nodes.append(
            blockquote(
                strong("📢 Official Broadcast Channel: "),
                "Get instant push notifications for live bidding subscriptions, GMP movements, and 1-click allotment status direct on your phone. 👉 ",
                a(f"Join {CHANNEL_HANDLE} on Telegram", CHANNEL_URL),
            )
        )
        nodes.append(hr())

        # 2. Key Issue Details & Timetable
        nodes.append(h3("📅 Issue Details & Complete Timetable"))
        timetable_items = [
            li(strong("Company Name: "), comp_name),
            li(strong("NSE & BSE Symbol: "), sym or "TBA"),
            li(strong("Issue Type: "), "100% Book Built Mainboard Issue (BSE & NSE Listed)"),
            li(strong("Total Issue Size: "), f"{issue_size} (Fresh: ₹{fresh_cr} Cr | OFS: ₹{ofs_cr} Cr)"),
            li(strong("Price Band: "), f"{price_band} per equity share (Face Value: ₹{face_val})"),
            li(strong("Market Lot Size: "), f"{lot_size} Shares (Retail Min. Application: {min_inv_str})"),
            li(strong("Bidding Window: "), bidding_window),
            li(strong("Issue Opening Date: "), open_str),
            li(strong("Issue Closing Date: "), close_str),
            li(strong("Basis of Allotment: "), allot_str),
            li(strong("Credit of Shares to Demat: "), demat_str),
            li(strong("IPO Listing Date: "), f"{list_str} (NSE & BSE Mainboard)"),
        ]
        nodes.append(ul(timetable_items))

        # 3. Live Grey Market Premium (GMP)
        nodes.append(h3("🔥 Live Grey Market Premium (GMP) & Expected Listing"))
        gmp_items = [
            li(strong("Current Live GMP: "), gmp_display),
            li(strong("Estimated Listing Price: "), str(est_list)),
            li(strong("Kostak Rate: "), str(kostak)),
            li(strong("Subject to Sauda (Sub2Sauda): "), str(sub2)),
        ]
        nodes.append(ul(gmp_items))
        nodes.append(
            p(
                em(
                    "*Note: Grey Market Premium (GMP) is an unregulated, unofficial sentiment metric traded off-exchange and is subject to rapid fluctuations based on market volatility."
                )
            )
        )

        # 4. About the Company
        if about or sector:
            nodes.append(h3("🏢 About the Company & Business Profile"))
            if sector:
                nodes.append(p(strong("Industry / Sector: "), sector))
            if about:
                nodes.append(p(about))

        # 5. Financial Highlights
        fin = ipo.get("financials", {})
        if fin and any(fin.values()):
            nodes.append(h3("📊 Financial Highlights (₹ in Crore)"))
            nodes.append(
                ul([
                    li(strong("Total Revenue: "), f"₹{format_currency(fin.get('revenue'))} Cr"),
                    li(strong("Profit After Tax (PAT): "), f"₹{format_currency(fin.get('pat'))} Cr"),
                    li(strong("Net Worth: "), f"₹{format_currency(fin.get('net_worth'))} Cr"),
                    li(strong("Total Borrowings (Debt): "), f"₹{format_currency(fin.get('debt', '0.00'))} Cr"),
                ])
            )

        # 6. Key Performance Indicators (KPIs)
        kpis = ipo.get("kpis", {})
        if kpis and any(kpis.values()):
            nodes.append(h3("📈 Valuation Multiples & KPIs"))
            nodes.append(
                ul([
                    li(strong("Price-to-Earnings (P/E) Ratio: "), str(kpis.get("pe_ratio", "TBA"))),
                    li(strong("Return on Net Worth (RoNW): "), str(kpis.get("ronw", "TBA"))),
                    li(strong("Earnings Per Share (EPS): "), f"₹{kpis.get('eps', 'TBA')}"),
                    li(strong("Debt-to-Equity Ratio: "), str(kpis.get("debt_to_equity", "0.00"))),
                    li(strong("Post-Issue Market Capitalization: "), f"₹{format_currency(kpis.get('market_cap'))} Cr"),
                ])
            )

        # 7. Category Allocation Quota
        res = ipo.get("reservation", {})
        if res and any(res.values()):
            nodes.append(h3("🎯 SEBI DRHP Quota Allocation"))
            nodes.append(
                ul([
                    li(strong("Qualified Institutional Buyers (QIB): "), f"{res.get('qib_pct', '50%')} of the net offer"),
                    li(strong("Non-Institutional Investors (NII / HNI): "), f"{res.get('nii_pct', '15%')} of the net offer (bNII: 10% | sNII: 5%)"),
                    li(strong("Retail Individual Investors (RII): "), f"{res.get('retail_pct', '35%')} of the net offer"),
                ])
            )

        # 8. Promoters & Shareholding Pattern
        promo = ipo.get("promoter_holding", {})
        if promo and any(promo.values()):
            nodes.append(h3("👥 Promoters & Shareholding Structure"))
            nodes.append(
                ul([
                    li(strong("Promoter(s): "), str(promo.get("promoters", "TBA"))),
                    li(strong("Pre-Issue Shareholding: "), str(promo.get("pre_issue", "TBA"))),
                    li(strong("Post-Issue Shareholding: "), str(promo.get("post_issue", "TBA"))),
                ])
            )

        # 9. Objects of the Issue (DRHP)
        objects = ipo.get("drhp_objects", [])
        if objects and isinstance(objects, list):
            nodes.append(h3("🎯 Objects of the Issue (Use of Proceeds)"))
            nodes.append(ul([li(str(obj)) for obj in objects]))

        # 10. Intermediaries & Registrar with Direct Allotment Link
        lead_managers = ipo.get("lead_managers", [])
        nodes.append(h3("🏛️ Lead Managers & Official Registrar"))
        lm_str = ", ".join(lead_managers) if lead_managers else "Refer to DRHP"
        nodes.append(
            ul([
                li(strong("Book Running Lead Managers (BRLMs): "), lm_str),
                li(strong("Registrar to the Issue: "), reg_name, " — ", a("Visit Allotment Portal", reg_url)),
            ])
        )

        # 11. Official Direct Allotment Verification Links
        nodes.append(h3("🔗 Direct Official Allotment Check Links"))
        nodes.append(
            ul([
                li(strong(f"Official Registrar ({reg_name}): "), a(reg_url, reg_url)),
                li(strong("BSE India Application Status: "), a("https://www.bseindia.com/investors/appli_check.aspx", "https://www.bseindia.com/investors/appli_check.aspx")),
                li(strong("NSE India Allotment Portal: "), a("https://www.nseindia.com/products/dynaContent/equities/ipos/ipo_login.jsp", "https://www.nseindia.com/products/dynaContent/equities/ipos/ipo_login.jsp")),
            ])
        )

        # 12. Bottom Conversion Callout & Disclaimer
        nodes.append(hr())
        nodes.append(
            blockquote(
                strong("🚀 Stay Ahead in Indian Capital Markets: "),
                "Get live updates, institutional subscription reports, and real-time grey market premium notifications. 👉 ",
                a(f"Join {CHANNEL_HANDLE} on Telegram", CHANNEL_URL),
            )
        )
        nodes.append(
            blockquote(
                em(
                    "⚠️ Disclaimer: This publication is prepared strictly for educational and informational purposes based on publicly filed Draft Red Herring Prospectus (DRHP) documents. It does not constitute financial, investment, or legal advice. Grey Market Premium (GMP) is an unregulated, speculative indicator. Always read the Red Herring Prospectus (RHP) thoroughly and consult a SEBI-registered investment advisor before applying."
                )
            )
        )

        return nodes

    def publish_ipo_review(
        self,
        ipo: dict,
        force: bool = False,
    ) -> str | None:
        """
        Publish an in-depth DRHP analysis page to Telegraph.
        Idempotent: returns existing telegraph_url unless force=True.
        """
        existing_url = ipo.get("telegraph_url")
        if existing_url and not force:
            return existing_url

        token = self.get_or_create_account()
        if not token:
            logger.warning("No Telegraph access token available; skipping publish.")
            return None

        comp_name = ipo.get("company_name", "Mainboard IPO")
        title = f"{comp_name} IPO: DRHP Review, Live GMP & Allotment Dates"[:250]
        nodes = self.build_ipo_article_nodes(ipo)

        try:
            logger.info(f"Publishing Telegraph review for: {comp_name}...")
            resp = requests.post(
                f"{TELEGRAPH_API_BASE}/createPage",
                json={
                    "access_token": token,
                    "title": title,
                    "author_name": "IPO Central",
                    "author_url": CHANNEL_URL,
                    "content": nodes,
                    "return_content": False,
                },
                timeout=15,
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("ok"):
                    url = data.get("result", {}).get("url")
                    if url:
                        logger.info(f"✅ Telegraph article published successfully: {url}")
                        return url
                else:
                    logger.error(f"Telegraph createPage failed: {data.get('error')}")
            else:
                logger.error(f"Telegraph API returned HTTP {resp.status_code}: {resp.text[:200]}")
        except Exception as e:
            logger.warning(f"Could not connect to Telegraph API: {e}")

        return None


if __name__ == "__main__":
    import sys
    print("Testing Telegraph Publisher locally...")
    publisher = TelegraphPublisher()
    sample_ipo = {
        "company_name": "Mahanadi Coalfields Limited",
        "symbol": "MAHACOAL",
        "price_band": "₹129 - ₹136",
        "open_date": "2026-11-19",
        "close_date": "2026-11-23",
        "allotment_date": "2026-11-24",
        "listing_date": "2026-11-26",
        "issue_size_cr": "4,200",
        "gmp": "+₹3.00",
        "gmp_percent": 2.21,
        "est_listing_price": "₹139 (+2.21%)",
        "lot_size": 110,
        "min_investment": 14960,
        "about": "Subsidiary of Coal India Limited.",
        "registrar": {"name": "KFin Technologies Limited", "url": "https://kosmic.kfintech.com/ipostatus/"},
    }
    nodes = publisher.build_ipo_article_nodes(sample_ipo)
    print(f"Built {len(nodes)} Telegraph DOM nodes successfully.")
    print("Sample Node 0:", json.dumps(nodes[0]))
    print("Sample Node 1:", json.dumps(nodes[1]))
