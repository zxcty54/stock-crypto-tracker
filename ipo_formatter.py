#!/usr/bin/env python3
"""
IPO TELEGRAM POST FORMATTER (ENHANCED WITH DRHP DETAILS)
========================================================
Generates rich, clean, professional HTML messages for Telegram (@ipocentral).

Includes:
1. NEW_IPO_ANNOUNCED - Comprehensive overview with DRHP Objects, Quota Reservations,
                       Financial highlights, KPIs, Promoters, Lead Managers & verified GMP.
2. IPO_OPENS_TODAY   - Opening Day bidding alert with GMP, Kostak, lot details & cutoff times.
3. IPO_CLOSING_TODAY - Final Day bidding reminder with live subscription numbers & GMP.
4. ALLOTMENT_OUT     - Basis of Allotment finalized with 1-click direct registrar & exchange links.
5. LISTING_TODAY     - Market debut alert with issue vs listing price and listing gains.
6. GMP_DASHBOARD     - Daily snapshot of active Mainboard IPOs with GMP, Gain % & Kostak rates.
"""

from __future__ import annotations

import html
from datetime import datetime, timezone, timedelta

IST = timezone(timedelta(hours=5, minutes=30))
CHANNEL_HANDLE = "@ipocentral"
CHANNEL_URL = "https://t.me/ipocentral"
DISCLAIMER = "⚠️ <i>Educational update only. Not financial advice. Not SEBI registered. Always read the Red Herring Prospectus (RHP) before applying.</i>"


def safe_text(val: str | None, default: str = "TBA") -> str:
    """Escape HTML entities and provide fallback for missing data."""
    if val is None or not str(val).strip():
        return default
    return html.escape(str(val).strip())


def format_currency(val: int | float | str | None) -> str:
    """Format numeric amount into clean Indian currency string."""
    if val is None or val == "":
        return "TBA"
    try:
        num = float(str(val).replace(",", "").replace("₹", "").strip())
        return f"{num:,.0f}" if num.is_integer() else f"{num:,.2f}"
    except (ValueError, TypeError):
        return str(val)


# ============================================================
# EVENT FORMATTERS (ENHANCED)
# ============================================================

def format_new_ipo_alert(ipo: dict) -> str:
    """Template for newly announced / filed Mainboard IPO enriched with DRHP details."""
    comp_name = safe_text(ipo.get("company_name"))
    open_d = safe_text(ipo.get("open_date"), default="Announcing Soon")
    close_d = safe_text(ipo.get("close_date"), default="Announcing Soon")
    allot_d = safe_text(ipo.get("allotment_date"), default="Tentative")
    list_d = safe_text(ipo.get("listing_date"), default="Tentative")

    price_band = safe_text(ipo.get("price_band"))
    if not price_band.startswith("₹") and price_band != "TBA":
        price_band = f"₹{price_band}"

    lot_size = safe_text(ipo.get("lot_size"))
    min_inv = ipo.get("min_investment")
    min_inv_str = f"₹{format_currency(min_inv)}" if min_inv else "TBA"

    issue_size = safe_text(ipo.get("issue_size_cr"))
    if issue_size != "TBA" and not issue_size.endswith("Cr"):
        issue_size = f"₹{issue_size} Cr"
    elif issue_size != "TBA" and not issue_size.startswith("₹"):
        issue_size = f"₹{issue_size}"

    fresh_issue = safe_text(ipo.get("fresh_issue_cr"), default="")
    ofs = safe_text(ipo.get("ofs_cr"), default="")

    size_breakdown = ""
    if fresh_issue or ofs:
        size_breakdown = f"\n  ├ <b>Fresh Issue:</b> {fresh_issue or 'TBA'}\n  └ <b>Offer for Sale (OFS):</b> {ofs or 'TBA'}"

    # Verified GMP & Kostak
    gmp = ipo.get("gmp")
    gmp_pct = ipo.get("gmp_percent", "")
    if gmp and str(gmp).strip() not in ("--", "0", ""):
        gmp_text = f"<b>{safe_text(gmp)}</b> ({safe_text(gmp_pct)})" if gmp_pct else f"<b>{safe_text(gmp)}</b>"
    else:
        gmp_text = "Trading yet to start"

    est_list = safe_text(ipo.get("est_listing_price"), default="")
    est_list_line = f"\n• <b>Est. Listing Price:</b> {est_list}" if est_list and est_list != "TBA" else ""

    kostak = safe_text(ipo.get("kostak"), default="")
    sub2 = safe_text(ipo.get("sub2sauda"), default="")
    rate_line = ""
    if kostak != "TBA" or sub2 != "TBA":
        rate_line = f"\n• <b>Kostak:</b> {kostak} | <b>Sub2Sauda:</b> {sub2}"

    # DRHP Quota Allocation
    res = ipo.get("reservation", {})
    quota_lines = []
    if res.get("qib_pct"):
        quota_lines.append(f"• <b>QIB Quota:</b> {safe_text(res['qib_pct'])}")
    if res.get("nii_pct"):
        quota_lines.append(f"• <b>NII / HNI Quota:</b> {safe_text(res['nii_pct'])}")
    if res.get("retail_pct"):
        quota_lines.append(f"• <b>Retail (RII) Quota:</b> {safe_text(res['retail_pct'])}")

    quota_section = ""
    if quota_lines:
        quota_section = "\n\n📊 <b>SEBI DRHP ISSUE ALLOCATION</b>\n" + "\n".join(quota_lines)

    # DRHP Financial Highlights
    fin = ipo.get("financials", {})
    kpis = ipo.get("kpis", {})
    fin_lines = []
    if fin.get("revenue"):
        fin_lines.append(f"• <b>Revenue (Latest):</b> ₹{safe_text(fin['revenue'])} Cr")
    if fin.get("pat"):
        fin_lines.append(f"• <b>Profit After Tax (PAT):</b> ₹{safe_text(fin['pat'])} Cr")
    if kpis.get("pe_ratio"):
        fin_lines.append(f"• <b>P/E Ratio:</b> {safe_text(kpis['pe_ratio'])}x")
    if kpis.get("ronw"):
        fin_lines.append(f"• <b>RoNW / ROE:</b> {safe_text(kpis['ronw'])}")
    if kpis.get("market_cap"):
        fin_lines.append(f"• <b>Post-Issue Market Cap:</b> ₹{safe_text(kpis['market_cap'])} Cr")

    fin_section = ""
    if fin_lines:
        fin_section = "\n\n📈 <b>FINANCIAL HIGHLIGHTS (RESTATED CONSOLIDATED)</b>\n" + "\n".join(fin_lines)

    # DRHP Objects of the Issue
    objects = ipo.get("drhp_objects", [])
    obj_section = ""
    if objects:
        bullets = [f"• {safe_text(o)}" for o in objects[:4]]
        obj_section = "\n\n🎯 <b>OBJECTS OF THE ISSUE (USE OF PROCEEDS)</b>\n" + "\n".join(bullets)

    # Promoters & Lead Managers
    promo = ipo.get("promoter_holding", {})
    promo_line = ""
    if promo.get("pre_issue") or promo.get("post_issue"):
        promo_line = f"\n👥 <b>Promoter Holding:</b> Pre: {safe_text(promo.get('pre_issue'))} ➔ Post: {safe_text(promo.get('post_issue'))}"

    lms = ipo.get("lead_managers", [])
    lm_line = ""
    if lms:
        lm_line = f"\n👔 <b>Lead Managers:</b> {safe_text(', '.join(lms[:3]))}"

    reg = ipo.get("registrar", {})
    reg_name = safe_text(reg.get("name") if isinstance(reg, dict) else reg, default="To be announced")

    about = safe_text(ipo.get("about"), default="")
    about_section = f"\n\nℹ️ <b>About the Company:</b>\n{about}" if about and about != "TBA" else ""

    drhp_link = ipo.get("drhp_url")
    drhp_line = f'\n\n📄 <b>Official Document:</b> <a href="{html.escape(drhp_link, quote=True)}">Download SEBI DRHP / RHP PDF</a>' if drhp_link else ""

    return (
        f"📢 <b>NEW MAINBOARD IPO ANNOUNCED</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>\n"
        f"🏷️ <i>Mainboard Issue · NSE &amp; BSE Listing</i>\n\n"
        f"📅 <b>TENTATIVE TIMETABLE</b>\n"
        f"• <b>IPO Opens:</b> {open_d}\n"
        f"• <b>IPO Closes:</b> {close_d}\n"
        f"• <b>Basis of Allotment:</b> {allot_d}\n"
        f"• <b>Listing Date:</b> {list_d}\n\n"
        f"💰 <b>PRICE &amp; ISSUE DETAILS</b>\n"
        f"• <b>Price Band:</b> {price_band} per share\n"
        f"• <b>Market Lot:</b> {lot_size} Shares\n"
        f"• <b>Min. Investment (Retail):</b> {min_inv_str}\n"
        f"• <b>Total Issue Size:</b> {issue_size}{size_breakdown}\n\n"
        f"🔥 <b>GREY MARKET PREMIUM (GMP)</b>\n"
        f"• <b>Current GMP:</b> {gmp_text}{est_list_line}{rate_line}"
        f"{quota_section}"
        f"{fin_section}"
        f"{obj_section}"
        f"{promo_line}\n"
        f"🏛️ <b>Registrar:</b> {reg_name}"
        f"{lm_line}"
        f"{about_section}"
        f"{drhp_line}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Channel:</b> {CHANNEL_HANDLE}\n"
        f"{DISCLAIMER}"
    )


def format_opens_today_alert(ipo: dict) -> str:
    """Template for Opening Day bidding alert."""
    comp_name = safe_text(ipo.get("company_name"))
    open_d = safe_text(ipo.get("open_date"))
    close_d = safe_text(ipo.get("close_date"))
    allot_d = safe_text(ipo.get("allotment_date"), default="TBA")
    list_d = safe_text(ipo.get("listing_date"), default="TBA")

    price_band = safe_text(ipo.get("price_band"))
    if not price_band.startswith("₹") and price_band != "TBA":
        price_band = f"₹{price_band}"

    lot_size = safe_text(ipo.get("lot_size"))
    min_inv = ipo.get("min_investment")
    min_inv_str = f"₹{format_currency(min_inv)}" if min_inv else "TBA"

    issue_size = safe_text(ipo.get("issue_size_cr"))
    if issue_size != "TBA" and not issue_size.startswith("₹"):
        issue_size = f"₹{issue_size} Cr"

    gmp = ipo.get("gmp")
    gmp_pct = ipo.get("gmp_percent", "")
    if gmp and str(gmp).strip() not in ("--", "0", ""):
        gmp_text = f"<b>{safe_text(gmp)}</b> ({safe_text(gmp_pct)})" if gmp_pct else f"<b>{safe_text(gmp)}</b>"
    else:
        gmp_text = "N/A"

    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")
    kostak = safe_text(ipo.get("kostak"), default="")
    sub2 = safe_text(ipo.get("sub2sauda"), default="")
    rate_line = f"\n• <b>Kostak:</b> {kostak} | <b>Sub2Sauda:</b> {sub2}" if kostak != "TBA" or sub2 != "TBA" else ""

    res = ipo.get("reservation", {})
    retail_q = safe_text(res.get("retail_pct"), default="35%")

    return (
        f"🟢 <b>IPO OPENS TODAY: BIDDING IS LIVE</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>\n"
        f"🏷️ <i>Mainboard IPO · NSE &amp; BSE</i>\n\n"
        f"⏰ <b>Bidding Window:</b> {open_d} to {close_d} (Daily 10:00 AM - 5:00 PM IST)\n"
        f"💰 <b>Price Band:</b> {price_band}\n"
        f"📦 <b>Lot Size:</b> {lot_size} Shares (Min: {min_inv_str})\n"
        f"📊 <b>Total Issue Size:</b> {issue_size} (Retail Quota: {retail_q})\n\n"
        f"🔥 <b>LATEST GMP UPDATE</b>\n"
        f"• <b>Grey Market Premium:</b> {gmp_text}\n"
        f"• <b>Expected Listing:</b> {est_list}{rate_line}\n\n"
        f"📌 <b>KEY TIMELINES</b>\n"
        f"• <b>Closing Date:</b> {close_d} (5:00 PM Cutoff)\n"
        f"• <b>Allotment Finalization:</b> {allot_d}\n"
        f"• <b>Listing Date:</b> {list_d}\n\n"
        f"💡 <i>Tip: Retail investors applying at Cut-off price have maximum allocation probability in oversubscribed issues.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Live Updates:</b> {CHANNEL_HANDLE}\n"
        f"{DISCLAIMER}"
    )


def format_closing_today_alert(ipo: dict) -> str:
    """Template for Final Day / Closing Day bidding alert with subscription."""
    comp_name = safe_text(ipo.get("company_name"))
    cut_off = ipo.get("cut_off_price") or ipo.get("price_band")
    cut_off_str = f"₹{cut_off}" if cut_off and not str(cut_off).startswith("₹") else safe_text(cut_off)

    lot_size = safe_text(ipo.get("lot_size"))
    min_inv = ipo.get("min_investment")
    min_inv_str = f"₹{format_currency(min_inv)}" if min_inv else "TBA"

    sub = ipo.get("subscription", {})
    qib = safe_text(sub.get("qib"), default="Updating...")
    nii = safe_text(sub.get("nii"), default="Updating...")
    retail = safe_text(sub.get("retail"), default="Updating...")
    total = safe_text(sub.get("total"), default="Updating...")

    gmp = ipo.get("gmp")
    gmp_pct = ipo.get("gmp_percent", "")
    if gmp and str(gmp).strip() not in ("--", "0", ""):
        gmp_text = f"<b>{safe_text(gmp)}</b> ({safe_text(gmp_pct)})" if gmp_pct else f"<b>{safe_text(gmp)}</b>"
    else:
        gmp_text = "N/A"

    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")
    allot_d = safe_text(ipo.get("allotment_date"), default="TBA")
    list_d = safe_text(ipo.get("listing_date"), default="TBA")

    return (
        f"🔴 <b>IPO CLOSING TODAY: LAST CHANCE TO APPLY</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>\n"
        f"🏷️ <i>Mainboard IPO · Final Bidding Day!</i>\n\n"
        f"⏳ <b>Deadline:</b> Today by 5:00 PM IST (UPI Mandate: 5:00 PM)\n"
        f"💰 <b>Cut-off Price:</b> {cut_off_str}\n"
        f"📦 <b>Min Investment:</b> {min_inv_str} ({lot_size} Shares)\n\n"
        f"📊 <b>LATEST SUBSCRIPTION STATUS</b>\n"
        f"• <b>QIB:</b> {qib}\n"
        f"• <b>NII / HNI:</b> {nii}\n"
        f"• <b>Retail (RII):</b> {retail}\n"
        f"• <b>TOTAL SUBSCRIPTION:</b> <b>{total}</b>\n\n"
        f"🔥 <b>LATEST GMP EXPECTATION</b>\n"
        f"• <b>GMP:</b> {gmp_text}\n"
        f"• <b>Est. Listing Price:</b> {est_list}\n\n"
        f"📅 <b>NEXT STEPS</b>\n"
        f"• <b>Allotment Finalization:</b> {allot_d}\n"
        f"• <b>Refund Initiation:</b> Next Business Day\n"
        f"• <b>Listing on Exchanges:</b> {list_d}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Instant Allotment Alerts:</b> {CHANNEL_HANDLE}"
    )


def format_allotment_out_alert(ipo: dict) -> str:
    """Template for Allotment Out alert with direct 1-click links."""
    comp_name = safe_text(ipo.get("company_name"))
    reg = ipo.get("registrar", {})
    reg_name = safe_text(reg.get("name") if isinstance(reg, dict) else reg, default="Registrar Portal")
    reg_url = (reg.get("url") if isinstance(reg, dict) else "") or "https://www.bseindia.com/investors/appli_check.aspx"

    issue_price = safe_text(ipo.get("cut_off_price") or ipo.get("price_band"))
    if not issue_price.startswith("₹") and issue_price != "TBA":
        issue_price = f"₹{issue_price}"

    gmp = ipo.get("gmp")
    gmp_pct = ipo.get("gmp_percent", "")
    gmp_text = f"₹{safe_text(gmp)} ({safe_text(gmp_pct)})" if gmp and gmp != "--" else "TBA"
    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")
    list_d = safe_text(ipo.get("listing_date"), default="TBA")

    return (
        f"🎯 <b>IPO ALLOTMENT OUT: CHECK STATUS NOW</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>\n"
        f"🏷️ <i>Mainboard IPO Allotment Finalized</i>\n\n"
        f"Basis of allotment has been processed. Investors can verify status using PAN, Application Number, or DP Client ID.\n\n"
        f"🔗 <b>DIRECT ALLOTMENT CHECK LINKS:</b>\n"
        f"• <b>Official Registrar ({reg_name}):</b>\n"
        f"  👉 <a href=\"{html.escape(reg_url, quote=True)}\">Check on Registrar Website</a>\n\n"
        f"• <b>BSE Allotment Portal:</b>\n"
        f"  👉 <a href=\"https://www.bseindia.com/investors/appli_check.aspx\">Check on BSE India</a>\n\n"
        f"• <b>NSE Allotment Verification:</b>\n"
        f"  👉 <a href=\"https://www.nseindia.com/products/dynaContent/equities/ipos/ipo_login.jsp\">Check on NSE India</a>\n\n"
        f"💰 <b>PRE-LISTING METRICS</b>\n"
        f"• <b>Issue Price:</b> {issue_price}\n"
        f"• <b>Current GMP:</b> {gmp_text}\n"
        f"• <b>Estimated Listing Price:</b> {est_list}\n"
        f"🚀 <b>Listing Date:</b> {list_d}\n\n"
        f"<i>Note: If shares are allotted, debit notification or SMS from bank/CDSL will follow. Unallotted funds will be unblocked automatically.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Stay Tuned for Listing Day Updates:</b> {CHANNEL_HANDLE}"
    )


def format_listing_today_alert(ipo: dict) -> str:
    """Template for Listing Day debut alert."""
    comp_name = safe_text(ipo.get("company_name"))
    sym = safe_text(ipo.get("symbol"), default="")
    sym_tag = f" ({sym})" if sym and sym != "TBA" else ""

    issue_p = safe_text(ipo.get("cut_off_price") or ipo.get("price_band"))
    if not issue_p.startswith("₹") and issue_p != "TBA":
        issue_p = f"₹{issue_p}"

    list_p = safe_text(ipo.get("listing_price"), default="Updating...")
    if list_p != "Updating..." and not list_p.startswith("₹"):
        list_p = f"₹{list_p}"

    gain = safe_text(ipo.get("listing_gain"), default="")
    gain_str = f" ({gain})" if gain else ""

    issue_size = safe_text(ipo.get("issue_size_cr"))
    if issue_size != "TBA" and not issue_size.startswith("₹"):
        issue_size = f"₹{issue_size} Cr"

    sub = ipo.get("subscription", {})
    total_sub = safe_text(sub.get("total"), default="Over-subscribed")

    return (
        f"🚀 <b>IPO LISTING TODAY: MARKET DEBUT</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>{sym_tag}\n"
        f"🏷️ <i>Mainboard Listing · Trading Commences at 10:00 AM IST</i>\n\n"
        f"🔔 <b>LISTING SUMMARY</b>\n"
        f"• <b>Issue Price:</b> {issue_p}\n"
        f"• <b>Listing Price:</b> <b>{list_p}</b>{gain_str}\n"
        f"• <b>Exchanges:</b> NSE &amp; BSE\n\n"
        f"📊 <b>ISSUE RECAP</b>\n"
        f"• <b>Total Issue Size:</b> {issue_size}\n"
        f"• <b>Overall Subscription:</b> {total_sub}\n\n"
        f"💡 <i>Post-listing strategy: Long-term allottees can review quarterly earnings; listing gain seekers can maintain trailing stop-loss.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Real-time IPO Performance:</b> {CHANNEL_HANDLE}\n"
        f"{DISCLAIMER}"
    )


def format_gmp_dashboard(ipos: list[dict], as_of_date: str | None = None) -> str:
    """Template for Daily/Weekly Mainboard IPO GMP Dashboard."""
    date_str = as_of_date or datetime.now(IST).strftime("%d-%b-%Y")

    lines = []
    for ipo in ipos:
        # Exclude already listed past IPOs from active GMP dashboard
        if ipo.get("is_already_listed"):
            continue

        name = safe_text(ipo.get("company_name"))
        gmp = ipo.get("gmp")
        gmp_pct = ipo.get("gmp_percent", "")
        price = safe_text(ipo.get("price_band") or ipo.get("cut_off_price"), default="TBA")

        if gmp and str(gmp).strip() not in ("--", "0", ""):
            gmp_display = f"{safe_text(gmp)}"
            if gmp_pct:
                gmp_display += f" ({safe_text(gmp_pct)})"
        else:
            gmp_display = "Trading yet to start"

        open_d = safe_text(ipo.get("open_date"), default="TBA")
        close_d = safe_text(ipo.get("close_date"), default="TBA")

        kostak = safe_text(ipo.get("kostak"), default="")
        rate_info = f" | Kostak: {kostak}" if kostak and kostak != "TBA" else ""

        lines.append(
            f"🔹 <b>{name}</b>\n"
            f"   • Price: {price} | Dates: {open_d} to {close_d}\n"
            f"   • <b>GMP:</b> <b>{gmp_display}</b>{rate_info}\n"
        )

    content = "\n".join(lines) if lines else "<i>No active Mainboard IPOs currently in bidding.</i>"

    return (
        f"📊 <b>MAINBOARD IPO: LIVE GMP DASHBOARD</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📅 <i>As of {date_str}</i>\n\n"
        f"{content}\n"
        f"<i>*GMP is unofficial market sentiment &amp; subject to rapid fluctuations.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📢 <b>Join {CHANNEL_HANDLE} for Fastest Mainboard IPO Alerts</b>"
    )


# ============================================================
# DISPATCHER
# ============================================================

def format_ipo_post(event_type: str, ipo: dict) -> str | None:
    """Format an IPO alert message based on its lifecycle event type."""
    formatters = {
        "NEW_IPO_ANNOUNCED": format_new_ipo_alert,
        "IPO_OPENS_TODAY": format_opens_today_alert,
        "IPO_CLOSING_TODAY": format_closing_today_alert,
        "ALLOTMENT_OUT": format_allotment_out_alert,
        "LISTING_TODAY": format_listing_today_alert,
    }
    formatter = formatters.get(event_type)
    if not formatter:
        return None
    return formatter(ipo)
