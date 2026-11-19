#!/usr/bin/env python3
"""
IPO TELEGRAM POST FORMATTER (INSTITUTIONAL DRHP EDITION)
=========================================================
Generates comprehensive, institutional-grade HTML messages for Telegram (@ipocentral).

Includes every critical detail required by retail, HNI & institutional investors:
1. TEST_VERIFICATION - System test and verification broadcast
2. NEW_IPO_ANNOUNCED - Full DRHP Analysis: Timetable, Ticket Sizes (Retail, sNII, bNII),
                       Fresh vs OFS, Live GMP + Kostak + Sub2Sauda, Quota Allocation,
                       Multi-year Restated Financials, Valuation KPIs (P/E, RoNW, RoCE, MCap),
                       Objects of the Issue, Promoters Pre/Post holding, Lead Managers & Registrar.
3. IPO_OPENS_TODAY   - Opening Day bidding alert with GMP, Kostak, lot details & cutoff times.
4. IPO_CLOSING_TODAY - Final Day bidding reminder with live subscription numbers & GMP.
5. ALLOTMENT_OUT     - Basis of Allotment finalized with 1-click direct registrar & exchange links.
6. LISTING_TODAY     - Market debut alert with issue vs listing price and listing gains.
7. GMP_DASHBOARD     - Daily snapshot of active Mainboard IPOs with GMP, Gain % & Kostak rates.
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


def format_test_verification_post() -> str:
    """Template for live bot test and system verification."""
    now_str = datetime.now(IST).strftime("%d-%b-%Y %H:%M IST")
    return (
        f"🧪 <b>MAINBOARD IPO TRACKER — SYSTEM TEST &amp; VERIFICATION</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>BOT STATUS: CONNECTED &amp; OPERATIONAL</b>\n"
        f"🏷️ <i>Target Channel: {CHANNEL_HANDLE}</i>\n"
        f"📅 <i>Timestamp: {now_str}</i>\n\n"
        f"📡 <b>LIVE DATA SOURCES CONFIGURED:</b>\n"
        f"• <b>NSE Live Issue API:</b> Current &amp; upcoming Mainboard equities\n"
        f"• <b>BSE Live Master API:</b> Official BSE equity IPO master\n"
        f"• <b>IPO Central Live GMP:</b> Live GMP, Kostak &amp; Sub2Sauda rates\n"
        f"• <b>Chittorgarh Dashboard:</b> Active bidding &amp; upcoming issues\n\n"
        f"🛡️ <b>STRICT INTEGRITY FILTERS ENFORCED:</b>\n"
        f"• ✅ <b>Mainboard Only:</b> Only NSE &amp; BSE mainboard tracked\n"
        f"• 🚫 <b>SME Blocked:</b> BSE SME &amp; NSE Emerge automatically filtered\n"
        f"• 🚫 <b>Historical Purged:</b> Zero already-listed IPOs posted\n\n"
        f"📊 <b>COMPLETE DRHP DETAILS INCLUDED IN EVERY ALERT:</b>\n"
        f"• Full 6-step timetable (Open, Close, Allotment, Refund, Demat, Listing)\n"
        f"• Ticket sizes: Retail (1 Lot), Retail Max, sNII (14 Lots), bNII (68 Lots)\n"
        f"• Fresh Issue vs Offer for Sale (OFS) capital breakdown\n"
        f"• Verified Live GMP, Expected Listing Price, Kostak &amp; Sub2Sauda\n"
        f"• SEBI DRHP Quota (QIB 50-75%, NII 15%, Retail 35%)\n"
        f"• Restated Financials (Revenue, PAT, Net Worth, Borrowings)\n"
        f"• Valuation KPIs (P/E Ratio, RoNW / ROE %, Post-Issue Market Cap, EPS)\n"
        f"• Objects of the Issue (DRHP Use of Net Proceeds)\n"
        f"• Promoters &amp; Pre/Post Shareholding percentages\n"
        f"• Registrar Allotment Portal link &amp; Lead Managers (BRLMs)\n"
        f"• Official SEBI DRHP / RHP PDF download link\n\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📢 <b>Channel:</b> {CHANNEL_HANDLE}\n"
        f"🤖 <i>Automated IPO dispatch pipeline is ready and monitoring 24x7!</i>"
    )


# ============================================================
# EVENT FORMATTERS (INSTITUTIONAL GRADE)
# ============================================================

def format_new_ipo_alert(ipo: dict) -> str:
    """Comprehensive DRHP overview card containing all essential investor metrics."""
    comp_name = safe_text(ipo.get("company_name"))
    sym = safe_text(ipo.get("symbol"), default="")
    sym_tag = f" ({sym})" if sym and sym != "TBA" else ""

    sector = safe_text(ipo.get("sector"), default="Mainboard Equity")

    open_d = safe_text(ipo.get("open_date"), default="Announcing Soon")
    close_d = safe_text(ipo.get("close_date"), default="Announcing Soon")
    allot_d = safe_text(ipo.get("allotment_date"), default="Tentative")
    refund_d = safe_text(ipo.get("refund_date"), default="Next Business Day")
    demat_d = safe_text(ipo.get("demat_date"), default="Prior to Listing")
    list_d = safe_text(ipo.get("listing_date"), default="Tentative")

    price_band = safe_text(ipo.get("price_band"))
    if not price_band.startswith("₹") and price_band != "TBA":
        price_band = f"₹{price_band}"

    face_val = safe_text(ipo.get("face_value"), default="10")
    lot_size = safe_text(ipo.get("lot_size"))

    # Lot & Investment Calculations
    min_inv = ipo.get("min_investment")
    min_inv_str = f"₹{format_currency(min_inv)}" if min_inv else "TBA"

    lot_int = None
    try:
        lot_int = int(str(ipo.get("lot_size", "")).strip())
    except (ValueError, TypeError):
        pass

    cut_off_num = None
    try:
        cut_off_num = float(str(ipo.get("cut_off_price", "")).replace("₹", "").replace(",", "").strip())
    except (ValueError, TypeError):
        pass

    snii_str = "TBA (> ₹2 Lakhs)"
    bnii_str = "TBA (> ₹10 Lakhs)"
    retail_max_str = "TBA (Max ₹2 Lakhs)"

    if lot_int and cut_off_num:
        snii_lots = 14
        bnii_lots = 68
        ret_max_lots = 13
        snii_amt = int(round(snii_lots * lot_int * cut_off_num))
        bnii_amt = int(round(bnii_lots * lot_int * cut_off_num))
        ret_max_amt = int(round(ret_max_lots * lot_int * cut_off_num))
        snii_str = f"₹{snii_amt:,.0f} ({snii_lots * lot_int} Shares)"
        bnii_str = f"₹{bnii_amt:,.0f} ({bnii_lots * lot_int} Shares)"
        retail_max_str = f"₹{ret_max_amt:,.0f} ({ret_max_lots * lot_int} Shares)"

    # Issue Size Breakdown
    issue_size = safe_text(ipo.get("issue_size_cr"))
    if issue_size != "TBA" and not issue_size.endswith("Cr"):
        issue_size = f"₹{issue_size} Cr"
    elif issue_size != "TBA" and not issue_size.startswith("₹"):
        issue_size = f"₹{issue_size}"

    fresh_issue = safe_text(ipo.get("fresh_issue_cr"), default="")
    ofs = safe_text(ipo.get("ofs_cr"), default="")

    size_breakdown = ""
    if fresh_issue or ofs:
        fresh_txt = f"₹{fresh_issue} Cr" if fresh_issue and not fresh_issue.startswith("₹") else (fresh_issue or "TBA")
        ofs_txt = f"₹{ofs} Cr" if ofs and not ofs.startswith("₹") else (ofs or "TBA")
        size_breakdown = f"\n  ├ <b>Fresh Issue:</b> {fresh_txt} (New capital to balance sheet)\n  └ <b>Offer for Sale (OFS):</b> {ofs_txt} (Promoter / PE Exit)"

    # Verified GMP & Kostak / Sub2Sauda
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
    if (kostak and kostak != "TBA") or (sub2 and sub2 != "TBA"):
        rate_line = f"\n• <b>Kostak:</b> {kostak or 'TBA'} | <b>Sub2Sauda:</b> {sub2 or 'TBA'}"

    # DRHP Quota Allocation
    res = ipo.get("reservation", {})
    qib_q = safe_text(res.get("qib_pct"), default="50%")
    nii_q = safe_text(res.get("nii_pct"), default="15%")
    ret_q = safe_text(res.get("retail_pct"), default="35%")

    # Restated Consolidated Financials
    fin = ipo.get("financials", {})
    kpis = ipo.get("kpis", {})
    fin_lines = []
    if fin.get("revenue"):
        fin_lines.append(f"• <b>Revenue from Operations:</b> ₹{safe_text(fin['revenue'])} Cr")
    if fin.get("pat"):
        fin_lines.append(f"• <b>Profit After Tax (PAT):</b> ₹{safe_text(fin['pat'])} Cr")
    if fin.get("net_worth"):
        fin_lines.append(f"• <b>Total Net Worth:</b> ₹{safe_text(fin['net_worth'])} Cr")
    if fin.get("debt"):
        fin_lines.append(f"• <b>Total Borrowings / Debt:</b> ₹{safe_text(fin['debt'])} Cr")

    fin_section = ""
    if fin_lines:
        fin_section = "\n\n📈 <b>RESTATED CONSOLIDATED FINANCIALS (DRHP)</b>\n" + "\n".join(fin_lines)

    # Valuation & Key Performance Indicators (KPIs)
    kpi_lines = []
    if kpis.get("pe_ratio"):
        kpi_lines.append(f"• <b>P/E Ratio (Upper Band):</b> {safe_text(kpis['pe_ratio'])}x")
    if kpis.get("ronw"):
        kpi_lines.append(f"• <b>RoNW / ROE:</b> {safe_text(kpis['ronw'])}")
    if kpis.get("market_cap"):
        mcap_val = safe_text(kpis['market_cap'])
        kpi_lines.append(f"• <b>Post-Issue Market Cap:</b> ₹{mcap_val} Cr")
    if kpis.get("eps"):
        kpi_lines.append(f"• <b>EPS (Pre-Issue):</b> ₹{safe_text(kpis['eps'])}")
    if kpis.get("debt_to_equity"):
        kpi_lines.append(f"• <b>Debt-to-Equity:</b> {safe_text(kpis['debt_to_equity'])}")

    kpi_section = ""
    if kpi_lines:
        kpi_section = "\n\n⚙️ <b>VALUATION &amp; KEY PERFORMANCE INDICATORS</b>\n" + "\n".join(kpi_lines)

    # Objects of the Issue (Use of Proceeds)
    objects = ipo.get("drhp_objects", [])
    obj_section = ""
    if objects:
        bullets = [f"• {safe_text(o)}" for o in objects[:4]]
        obj_section = "\n\n🎯 <b>OBJECTS OF THE ISSUE (USE OF PROCEEDS)</b>\n" + "\n".join(bullets)

    # Promoters & Shareholding
    promo = ipo.get("promoter_holding", {})
    promo_lines = []
    if promo.get("promoters"):
        promo_lines.append(f"• <b>Promoters:</b> {safe_text(promo.get('promoters'))}")
    if promo.get("pre_issue") or promo.get("post_issue"):
        promo_lines.append(f"• <b>Promoter Holding:</b> Pre: {safe_text(promo.get('pre_issue'))} ➔ Post: {safe_text(promo.get('post_issue'))}")

    promo_section = ""
    if promo_lines:
        promo_section = "\n\n👥 <b>PROMOTERS &amp; SHAREHOLDING</b>\n" + "\n".join(promo_lines)

    # Lead Managers & Registrar
    lms = ipo.get("lead_managers", [])
    lm_line = f"\n• <b>Lead Managers:</b> {safe_text(', '.join(lms[:4]))}" if lms else ""

    reg = ipo.get("registrar", {})
    reg_name = safe_text(reg.get("name") if isinstance(reg, dict) else reg, default="To be announced")
    reg_url = (reg.get("url") if isinstance(reg, dict) else "") or "https://www.bseindia.com/investors/appli_check.aspx"

    about = safe_text(ipo.get("about"), default="")
    about_section = f"\n\nℹ️ <b>Business Overview:</b>\n{about}" if about and about != "TBA" else ""

    drhp_link = ipo.get("drhp_url")
    drhp_line = f'\n\n📄 <b>Official Prospectus:</b> <a href="{html.escape(drhp_link, quote=True)}">Download Official SEBI DRHP / RHP PDF</a>' if drhp_link else ""

    return (
        f"📢 <b>NEW MAINBOARD IPO ALERT (DRHP DETAILS)</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>{sym_tag}\n"
        f"🏷️ <i>Mainboard IPO · NSE &amp; BSE Listing</i>\n"
        f"🏭 <b>Sector:</b> {sector}\n\n"
        f"📅 <b>ISSUE TIMETABLE</b>\n"
        f"• <b>Bidding Opens:</b> {open_d} (10:00 AM IST)\n"
        f"• <b>Bidding Closes:</b> {close_d} (5:00 PM IST)\n"
        f"• <b>Basis of Allotment:</b> {allot_d}\n"
        f"• <b>Initiation of Refunds:</b> {refund_d}\n"
        f"• <b>Credit to Demat Accounts:</b> {demat_d}\n"
        f"• <b>Exchange Listing Date:</b> {list_d}\n\n"
        f"💰 <b>PRICE BAND &amp; TICKET SIZES</b>\n"
        f"• <b>Price Band:</b> {price_band} (Face Value: ₹{face_val})\n"
        f"• <b>Market Lot Size:</b> {lot_size} Shares\n"
        f"• <b>Retail Min. (1 Lot):</b> {min_inv_str} ({lot_size} Shares)\n"
        f"• <b>Retail Max. (13 Lots):</b> {retail_max_str}\n"
        f"• <b>sNII Min. (14 Lots):</b> {snii_str}\n"
        f"• <b>bNII Min. (68 Lots):</b> {bnii_str}\n\n"
        f"📊 <b>ISSUE SIZE BREAKDOWN</b>\n"
        f"• <b>Total Issue Size:</b> {issue_size}{size_breakdown}\n\n"
        f"🔥 <b>GREY MARKET PREMIUM (GMP)</b>\n"
        f"• <b>Current GMP:</b> {gmp_text}{est_list_line}{rate_line}\n\n"
        f"📊 <b>SEBI DRHP ISSUE ALLOCATION</b>\n"
        f"• <b>QIB Quota:</b> {qib_q} (Anchor: up to 60% of QIB)\n"
        f"• <b>NII / HNI Quota:</b> {nii_q} (bNII: 10% | sNII: 5%)\n"
        f"• <b>Retail (RII) Quota:</b> {ret_q}"
        f"{fin_section}"
        f"{kpi_section}"
        f"{obj_section}"
        f"{promo_section}\n\n"
        f"🏛️ <b>INTERMEDIARIES &amp; REGISTRAR</b>\n"
        f"• <b>Registrar:</b> {reg_name} (<a href=\"{html.escape(reg_url, quote=True)}\">Allotment Portal</a>)"
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
    rate_line = f"\n• <b>Kostak:</b> {kostak} | <b>Sub2Sauda:</b> {sub2}" if (kostak and kostak != "TBA") or (sub2 and sub2 != "TBA") else ""

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


def format_gmp_update_alert(ipo: dict, old_gmp: str = "") -> str:
    """Template for significant GMP movement alert."""
    comp_name = safe_text(ipo.get("company_name"))
    sym = safe_text(ipo.get("symbol"), default="")
    sym_tag = f" ({sym})" if sym and sym != "TBA" else ""

    price_band = safe_text(ipo.get("price_band") or ipo.get("cut_off_price"), default="TBA")
    open_d = safe_text(ipo.get("open_date"), default="TBA")
    close_d = safe_text(ipo.get("close_date"), default="TBA")
    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")
    gmp = safe_text(ipo.get("gmp"), default="N/A")
    gmp_pct = safe_text(ipo.get("gmp_percent"), default="")
    gmp_str = f"<b>{gmp}</b> ({gmp_pct})" if gmp_pct else f"<b>{gmp}</b>"

    old_str = f"• <b>Previous GMP:</b> {old_gmp}\n" if old_gmp else ""
    kostak = safe_text(ipo.get("kostak"), default="")
    kostak_str = f"• <b>Kostak Rate:</b> {kostak}\n" if kostak and kostak != "TBA" else ""

    return (
        f"⚡ <b>LIVE GMP MOVEMENT ALERT</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>{sym_tag}\n"
        f"🏷️ <i>Mainboard IPO · Grey Market Revision</i>\n\n"
        f"💰 <b>Price Band:</b> {price_band}\n"
        f"📅 <b>Bidding Window:</b> {open_d} to {close_d}\n\n"
        f"🔥 <b>UPDATED GREY MARKET PREMIUM:</b>\n"
        f"{old_str}"
        f"• <b>Current GMP:</b> {gmp_str}\n"
        f"• <b>Expected Listing Price:</b> {est_list}\n"
        f"{kostak_str}\n"
        f"<i>*GMP is based on unofficial market trades &amp; subject to rapid fluctuations.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Real-time IPO Tracking:</b> {CHANNEL_HANDLE}"
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
    today_str = datetime.now(IST).strftime("%Y-%m-%d")

    lines = []
    for ipo in ipos:
        # Strictly exclude already listed or expired past issues
        if ipo.get("is_already_listed"):
            continue
        close_d = ipo.get("close_date")
        if close_d and close_d < today_str:
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
        close_d_str = safe_text(close_d, default="TBA")

        kostak = safe_text(ipo.get("kostak"), default="")
        rate_info = f" | Kostak: {kostak}" if kostak and kostak != "TBA" else ""

        # Live NSE Demand / Bids if available
        sub = ipo.get("subscription", {})
        sub_line = ""
        if isinstance(sub, dict) and sub.get("total") and sub.get("total") not in ("Upcoming", ""):
            sub_parts = []
            if sub.get("qib") and sub.get("qib") != "Upcoming":
                sub_parts.append(f"QIB: {sub['qib']}")
            if sub.get("nii") and sub.get("nii") != "Upcoming":
                sub_parts.append(f"NII: {sub['nii']}")
            if sub.get("retail") and sub.get("retail") != "Upcoming":
                sub_parts.append(f"Retail: {sub['retail']}")
            sub_parts.append(f"<b>Total: {sub['total']}</b>")
            sub_line = f"\n   • <b>NSE Demand:</b> {' | '.join(sub_parts)}"

        lines.append(
            f"🔹 <b>{name}</b>\n"
            f"   • Price: {price} | Dates: {open_d} to {close_d_str}\n"
            f"   • <b>GMP:</b> <b>{gmp_display}</b>{rate_info}"
            f"{sub_line}\n"
        )

    content = "\n".join(lines) if lines else "<i>Currently, no Mainboard IPO is actively open for bidding on NSE/BSE. Tracking upcoming SEBI DRHP issue filings &amp; announcements...</i>"

    return (
        f"📊 <b>MAINBOARD IPO: LIVE GMP DASHBOARD</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📅 <i>As of {date_str}</i>\n\n"
        f"{content}\n\n"
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
        "TEST_VERIFICATION": lambda x: format_test_verification_post(),
        "NEW_IPO_ANNOUNCED": format_new_ipo_alert,
        "IPO_OPENS_TODAY": format_opens_today_alert,
        "IPO_CLOSING_TODAY": format_closing_today_alert,
        "ALLOTMENT_OUT": format_allotment_out_alert,
        "LISTING_TODAY": format_listing_today_alert,
        "GMP_UPDATE": format_gmp_update_alert,
    }
    formatter = formatters.get(event_type)
    if not formatter:
        return None
    return formatter(ipo)
