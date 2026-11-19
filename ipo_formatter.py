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
import re
from datetime import datetime, timezone, timedelta

IST = timezone(timedelta(hours=5, minutes=30))
CHANNEL_HANDLE = "@ipocentral"
CHANNEL_URL = "https://t.me/ipocentral"
DISCLAIMER = "⚠️ <i>Educational update only. Not financial advice. Not SEBI registered. Always read the Red Herring Prospectus (RHP) before applying.</i>"

REGISTRAR_PORTALS: dict[str, str] = {
    "link intime": "https://linkintime.co.in/initial_offer/public-issues.html",
    "kfin": "https://kosmic.kfintech.com/ipostatus/",
    "kfintech": "https://kosmic.kfintech.com/ipostatus/",
    "bigshare": "https://www.bigshareonline.com/ipo_Allotment.html",
    "cameo": "https://ipo.cameoindia.com/",
    "skyline": "https://www.skylinerta.com/ipo.php",
    "integrated": "https://www.integratedindia.in/",
    "purva": "https://www.purvashare.com/queries/",
    "mas services": "https://www.masserv.com/opt.asp",
    "bse": "https://www.bseindia.com/investors/appli_check.aspx",
    "nse": "https://www.nseindia.com/products/dynaContent/equities/ipos/ipo_login.jsp",
}


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


def format_issue_size(val: str | int | float | None) -> str:
    """Format issue size into clean '₹X,XXX Cr' string."""
    if not val or val == "TBA":
        return "TBA"
    s = str(val).strip()
    if s.endswith("Cr"):
        return s if s.startswith("₹") else f"₹{s}"
    if "crore" in s.lower() or "cr" in s.lower():
        nums = re.findall(r"\d+(?:,\d+)*(?:\.\d+)?", s)
        if nums:
            return f"₹{nums[0]} Cr"
    nums = re.findall(r"\d+(?:\.\d+)?", s.replace(",", ""))
    if nums:
        num = float(nums[0])
        # If in raw rupees (> 100 Crore in rupees = 1,000,000,000)
        if num > 1000000000:
            num = num / 10000000
        return f"₹{num:,.0f} Cr" if num.is_integer() else f"₹{num:,.2f} Cr"
    return f"₹{s} Cr"


def derive_demat_date(allotment_d: str | None, listing_d: str | None, close_d: str | None) -> str:
    """Derive Demat credit date via SEBI T+3 market rules."""
    for d_str, offset in [(listing_d, -1), (allotment_d, 1), (close_d, 2)]:
        if d_str and d_str != "TBA" and re.match(r"^\d{4}-\d{2}-\d{2}$", d_str):
            try:
                dt = datetime.strptime(d_str, "%Y-%m-%d")
                target = dt + timedelta(days=offset)
                if target.weekday() == 6:  # Sunday
                    target += timedelta(days=1 if offset > 0 else -1)
                elif target.weekday() == 5:  # Saturday
                    target += timedelta(days=2 if offset > 0 else -1)
                return target.strftime("%Y-%m-%d")
            except ValueError:
                pass
    return "Prior to Listing"


def clean_registrar_name(name: str) -> str:
    """Shorten registrar name for crisp mobile display."""
    if not name:
        return ""
    clean = re.sub(r"(?i)\s*(?:india\s*)?(?:private|pvt\.?|limited|ltd\.?)\b", "", str(name)).strip()
    clean = re.sub(r"\s+", " ", clean).strip()
    return clean or str(name)


def format_short_date(val: str | None, include_year: bool = True) -> str:
    """Format YYYY-MM-DD into clean '19 Nov 2026' or '19 Nov'."""
    if not val or val in ("TBA", "Tentative", "Announcing Soon", "Prior to Listing"):
        return safe_text(val, default="TBA")
    s = str(val).strip()
    match = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", s)
    if match:
        try:
            dt = datetime.strptime(s, "%Y-%m-%d")
            return dt.strftime("%d %b %Y") if include_year else dt.strftime("%d %b")
        except ValueError:
            pass
    return s


def format_date_range_display(open_d: str | None, close_d: str | None) -> str:
    """Format open and close dates into clean '19 – 23 Nov 2026'."""
    if not open_d or open_d in ("TBA", "Announcing Soon"):
        return format_short_date(close_d)
    if not close_d or close_d in ("TBA", "Announcing Soon"):
        return format_short_date(open_d)
    m1 = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", str(open_d).strip())
    m2 = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", str(close_d).strip())
    if m1 and m2:
        try:
            dt1 = datetime.strptime(str(open_d).strip(), "%Y-%m-%d")
            dt2 = datetime.strptime(str(close_d).strip(), "%Y-%m-%d")
            if dt1.year == dt2.year and dt1.month == dt2.month:
                d1 = dt1.strftime("%d")
                d2 = dt2.strftime("%d %b %Y")
                return f"{d1} – {d2}"
            elif dt1.year == dt2.year:
                d1 = dt1.strftime("%d %b")
                d2 = dt2.strftime("%d %b %Y")
                return f"{d1} – {d2}"
            d1 = dt1.strftime("%d %b %Y")
            d2 = dt2.strftime("%d %b %Y")
            return f"{d1} – {d2}"
        except ValueError:
            pass
    return f"{open_d} to {close_d}"


def format_gmp_percent(val: int | float | str | None) -> str:
    """Format GMP percentage with sign and percent symbol, e.g. '+2.21%'."""
    if val is None or val == "" or val == "TBA":
        return ""
    s = str(val).strip()
    if s.endswith("%"):
        return s if s.startswith(("+", "-")) else f"+{s}"
    try:
        num = float(s)
        return f"+{num:.2f}%" if num > 0 else f"{num:.2f}%"
    except (ValueError, TypeError):
        return f"+{s}%"


def format_subscription_summary(sub: dict | None) -> str:
    """Format subscription into crisp single-line mobile string."""
    if not isinstance(sub, dict) or not sub:
        return ""
    total = str(sub.get("total") or "").strip()
    if not total or total in ("Upcoming", "--", "N/A"):
        return ""
    if re.search(r"\d+\.?\d*", total) and ("x" in total.lower() or "times" in total.lower()):
        parts = [f"<b>Total: {total}</b>"]
        retail = str(sub.get("retail") or "").strip()
        if retail and re.search(r"\d", retail) and retail != "Upcoming":
            parts.append(f"Retail: {retail}")
        qib = str(sub.get("qib") or "").strip()
        if qib and re.search(r"\d", qib) and qib != "Upcoming":
            parts.append(f"QIB: {qib}")
        return " | ".join(parts)
    r_val = sub.get("retail", "")
    q_val = sub.get("qib", "")
    full_text = f"{total} {r_val} {q_val}"
    day_match = re.search(r"Day\s*\d+", full_text, re.IGNORECASE)
    day_info = f" ({day_match.group(0)})" if day_match else ""
    return f"Bidding Live{day_info}"


def get_registrar_link_html(reg: dict | str | None, default_url: str = "") -> str:
    """Generate clean HTML anchor for registrar allotment portal."""
    if not reg:
        return ""
    if isinstance(reg, dict):
        raw_name = safe_text(reg.get("name"), default="")
        url = reg.get("url") or default_url
    else:
        raw_name = safe_text(str(reg), default="")
        url = default_url

    if not raw_name or raw_name == "TBA":
        return ""

    if not url:
        lower_name = raw_name.lower()
        for key, p_url in REGISTRAR_PORTALS.items():
            if key in lower_name:
                url = p_url
                break
        if not url:
            url = REGISTRAR_PORTALS["bse"]

    display_name = clean_registrar_name(raw_name)
    return f'<a href="{html.escape(url, quote=True)}">{display_name}</a>'


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

    open_d = format_short_date(ipo.get("open_date"))
    close_d = format_short_date(ipo.get("close_date"))
    allot_d = format_short_date(ipo.get("allotment_date"))
    refund_d = safe_text(ipo.get("refund_date"), default="Next Business Day")
    demat_d = format_short_date(
        ipo.get("demat_credit_date")
        or ipo.get("demat_date")
        or derive_demat_date(ipo.get("allotment_date"), ipo.get("listing_date"), ipo.get("close_date"))
    )
    list_d = format_short_date(ipo.get("listing_date"))

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
    issue_size = format_issue_size(ipo.get("issue_size_cr"))

    fresh_issue = safe_text(ipo.get("fresh_issue_cr"), default="")
    ofs = safe_text(ipo.get("ofs_cr"), default="")

    size_breakdown = ""
    if fresh_issue or ofs:
        fresh_txt = f"₹{fresh_issue} Cr" if fresh_issue and not fresh_issue.startswith("₹") else (fresh_issue or "TBA")
        ofs_txt = f"₹{ofs} Cr" if ofs and not ofs.startswith("₹") else (ofs or "TBA")
        size_breakdown = f"\n  ├ <b>Fresh Issue:</b> {fresh_txt} (New capital to balance sheet)\n  └ <b>Offer for Sale (OFS):</b> {ofs_txt} (Promoter / PE Exit)"

    # Verified GMP & Kostak / Sub2Sauda
    gmp = ipo.get("gmp")
    gmp_pct_str = format_gmp_percent(ipo.get("gmp_percent"))
    if gmp and str(gmp).strip() not in ("--", "0", ""):
        gmp_text = f"<b>{safe_text(gmp)}</b> ({gmp_pct_str})" if gmp_pct_str else f"<b>{safe_text(gmp)}</b>"
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
    """Curated mobile-optimized template for Opening Day bidding alert."""
    comp_name = safe_text(ipo.get("company_name"))
    sym = safe_text(ipo.get("symbol"), default="")
    sym_tag = f" ({sym})" if sym and sym != "TBA" else ""

    open_d = ipo.get("open_date")
    close_d = ipo.get("close_date")
    bidding_d = format_date_range_display(open_d, close_d)
    allot_d = format_short_date(ipo.get("allotment_date"))
    demat_d = format_short_date(
        ipo.get("demat_credit_date")
        or ipo.get("demat_date")
        or derive_demat_date(ipo.get("allotment_date"), ipo.get("listing_date"), ipo.get("close_date"))
    )
    list_d = format_short_date(ipo.get("listing_date"))

    price_band = safe_text(ipo.get("price_band"))
    if not price_band.startswith("₹") and price_band != "TBA":
        price_band = f"₹{price_band}"

    lot_size = safe_text(ipo.get("lot_size"))
    min_inv = ipo.get("min_investment")
    min_inv_str = f"₹{format_currency(min_inv)}" if min_inv else "TBA"

    issue_size = format_issue_size(ipo.get("issue_size_cr"))

    gmp = safe_text(ipo.get("gmp"))
    gmp_pct_str = format_gmp_percent(ipo.get("gmp_percent"))
    if gmp and str(gmp).strip() not in ("--", "0", "TBA", ""):
        gmp_text = f"<b>{gmp}</b> ({gmp_pct_str})" if gmp_pct_str else f"<b>{gmp}</b>"
    else:
        gmp_text = "Trading yet to start"

    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")
    kostak = safe_text(ipo.get("kostak"), default="")
    sub2 = safe_text(ipo.get("sub2sauda"), default="")
    rate_line = f"\n• <b>Kostak:</b> {kostak} | <b>Sub2Sauda:</b> {sub2}" if (kostak and kostak != "TBA") or (sub2 and sub2 != "TBA") else ""

    res = ipo.get("reservation", {})
    retail_q = safe_text(res.get("retail_pct"), default="35%")

    reg_html = get_registrar_link_html(ipo.get("registrar"))

    return (
        f"🟢 <b>IPO OPENS TODAY: BIDDING IS LIVE</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>{sym_tag}\n"
        f"🏷️ <i>Mainboard IPO · NSE &amp; BSE Listing</i>\n\n"
        f"💰 <b>ISSUE &amp; TICKET DETAILS</b>\n"
        f"• <b>IPO Issue Size:</b> <b>{issue_size}</b>\n"
        f"• <b>Price Band:</b> {price_band}\n"
        f"• <b>Market Lot:</b> {lot_size} Shares (Min: {min_inv_str})\n"
        f"• <b>Retail Quota:</b> {retail_q}\n\n"
        f"🔥 <b>LATEST GREY MARKET PREMIUM (GMP)</b>\n"
        f"• <b>Current GMP:</b> {gmp_text}\n"
        f"• <b>Expected Listing:</b> {est_list}{rate_line}\n\n"
        f"📅 <b>CONFIRMED TIMELINE</b>\n"
        f"• <b>Bidding Window:</b> {bidding_d} (Daily 10 AM - 5 PM)\n"
        f"• <b>Basis of Allotment:</b> {allot_d}\n"
        f"• <b>Demat Credit Date:</b> <b>{demat_d}</b>\n"
        f"• <b>IPO Listing Date:</b> <b>{list_d}</b> (NSE &amp; BSE)\n"
        f"• <b>Registrar Portal:</b> {reg_html}\n\n"
        f"💡 <i>Tip: Retail investors applying at Cut-off price have maximum allocation probability in oversubscribed issues.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Real-time IPO Updates:</b> {CHANNEL_HANDLE}\n"
        f"{DISCLAIMER}"
    )


def format_closing_today_alert(ipo: dict) -> str:
    """Curated mobile-optimized template for Final Day bidding alert."""
    comp_name = safe_text(ipo.get("company_name"))
    sym = safe_text(ipo.get("symbol"), default="")
    sym_tag = f" ({sym})" if sym and sym != "TBA" else ""

    cut_off = ipo.get("cut_off_price") or ipo.get("price_band")
    cut_off_str = f"₹{cut_off}" if cut_off and not str(cut_off).startswith("₹") else safe_text(cut_off)

    lot_size = safe_text(ipo.get("lot_size"))
    min_inv = ipo.get("min_investment")
    min_inv_str = f"₹{format_currency(min_inv)}" if min_inv else "TBA"

    issue_size = format_issue_size(ipo.get("issue_size_cr"))

    sub = ipo.get("subscription", {})
    sub_summary = format_subscription_summary(sub)
    if not sub_summary or sub_summary.startswith("Bidding"):
        qib = safe_text(sub.get("qib"), default="Updating...")
        nii = safe_text(sub.get("nii"), default="Updating...")
        retail = safe_text(sub.get("retail"), default="Updating...")
        total = safe_text(sub.get("total"), default="Updating...")
        sub_section = (
            f"📊 <b>LIVE NSE SUBSCRIPTION DEMAND</b>\n"
            f"• <b>QIB:</b> {qib}\n"
            f"• <b>NII / HNI:</b> {nii}\n"
            f"• <b>Retail (RII):</b> {retail}\n"
            f"• <b>TOTAL SUBSCRIPTION:</b> <b>{total}</b>\n\n"
        )
    else:
        sub_section = f"📊 <b>NSE Demand:</b> {sub_summary}\n\n"

    gmp = safe_text(ipo.get("gmp"))
    gmp_pct_str = format_gmp_percent(ipo.get("gmp_percent"))
    if gmp and str(gmp).strip() not in ("--", "0", "TBA", ""):
        gmp_text = f"<b>{gmp}</b> ({gmp_pct_str})" if gmp_pct_str else f"<b>{gmp}</b>"
    else:
        gmp_text = "N/A"

    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")
    allot_d = format_short_date(ipo.get("allotment_date"))
    demat_d = format_short_date(
        ipo.get("demat_credit_date")
        or ipo.get("demat_date")
        or derive_demat_date(ipo.get("allotment_date"), ipo.get("listing_date"), ipo.get("close_date"))
    )
    list_d = format_short_date(ipo.get("listing_date"))

    reg_html = get_registrar_link_html(ipo.get("registrar"))

    return (
        f"🔴 <b>IPO CLOSING TODAY: LAST CHANCE TO APPLY</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>{sym_tag}\n"
        f"🏷️ <i>Mainboard IPO · Final Bidding Day!</i>\n\n"
        f"⏳ <b>Deadline:</b> Today by 5:00 PM IST (UPI Mandate: 5:00 PM)\n"
        f"💰 <b>IPO Issue Size:</b> <b>{issue_size}</b> | <b>Cut-off:</b> {cut_off_str}\n"
        f"📦 <b>Market Lot:</b> {lot_size} Shares (Min: {min_inv_str})\n\n"
        f"{sub_section}"
        f"🔥 <b>LATEST GREY MARKET PREMIUM (GMP)</b>\n"
        f"• <b>Current GMP:</b> {gmp_text}\n"
        f"• <b>Expected Listing:</b> {est_list}\n\n"
        f"📅 <b>NEXT STEPS &amp; TIMELINE</b>\n"
        f"• <b>Basis of Allotment:</b> {allot_d}\n"
        f"• <b>Demat Credit Date:</b> <b>{demat_d}</b>\n"
        f"• <b>IPO Listing Date:</b> <b>{list_d}</b> (NSE &amp; BSE)\n"
        f"• <b>Registrar Portal:</b> {reg_html}\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Instant Allotment Alerts:</b> {CHANNEL_HANDLE}"
    )


def format_allotment_out_alert(ipo: dict) -> str:
    """Curated mobile-optimized template for Allotment Out alert with direct 1-click links."""
    comp_name = safe_text(ipo.get("company_name"))
    sym = safe_text(ipo.get("symbol"), default="")
    sym_tag = f" ({sym})" if sym and sym != "TBA" else ""

    issue_size = format_issue_size(ipo.get("issue_size_cr"))
    issue_price = safe_text(ipo.get("cut_off_price") or ipo.get("price_band"))
    if not issue_price.startswith("₹") and issue_price != "TBA":
        issue_price = f"₹{issue_price}"

    gmp = safe_text(ipo.get("gmp"))
    gmp_pct_str = format_gmp_percent(ipo.get("gmp_percent"))
    gmp_text = f"{gmp} ({gmp_pct_str})" if gmp and str(gmp).strip() not in ("--", "0", "TBA", "") else "TBA"
    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")

    demat_d = format_short_date(
        ipo.get("demat_credit_date")
        or ipo.get("demat_date")
        or derive_demat_date(ipo.get("allotment_date"), ipo.get("listing_date"), ipo.get("close_date"))
    )
    list_d = format_short_date(ipo.get("listing_date"))

    reg = ipo.get("registrar", {})
    reg_name = clean_registrar_name(reg.get("name") if isinstance(reg, dict) else reg) or "Registrar Portal"
    reg_html = get_registrar_link_html(reg)

    return (
        f"🎯 <b>IPO ALLOTMENT OUT: CHECK STATUS NOW</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>{sym_tag}\n"
        f"🏷️ <i>Mainboard IPO Allotment Finalized</i>\n\n"
        f"Basis of allotment has been finalized. Investors can verify status using PAN, Application Number, or DP Client ID.\n\n"
        f"🔗 <b>DIRECT ALLOTMENT CHECK LINKS:</b>\n"
        f"• <b>Official Registrar ({reg_name}):</b>\n"
        f"  👉 {reg_html}\n\n"
        f"• <b>BSE Allotment Portal:</b>\n"
        f"  👉 <a href=\"https://www.bseindia.com/investors/appli_check.aspx\">Check on BSE India</a>\n\n"
        f"• <b>NSE Allotment Verification:</b>\n"
        f"  👉 <a href=\"https://www.nseindia.com/products/dynaContent/equities/ipos/ipo_login.jsp\">Check on NSE India</a>\n\n"
        f"💰 <b>PRE-LISTING METRICS</b>\n"
        f"• <b>IPO Issue Size:</b> {issue_size} | <b>Issue Price:</b> {issue_price}\n"
        f"• <b>Current GMP:</b> <b>{gmp_text}</b>\n"
        f"• <b>Estimated Listing Price:</b> {est_list}\n\n"
        f"📅 <b>UPCOMING DATES</b>\n"
        f"• <b>Demat Credit Date:</b> <b>{demat_d}</b>\n"
        f"• <b>IPO Listing Date:</b> <b>{list_d}</b> (NSE &amp; BSE)\n\n"
        f"<i>Note: If shares are allotted, debit notification or SMS from bank/CDSL will follow. Unallotted funds will be unblocked automatically.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Stay Tuned for Listing Day Updates:</b> {CHANNEL_HANDLE}"
    )


def format_gmp_update_alert(ipo: dict, old_gmp: str = "", surge_text: str = "") -> str:
    """Curated mobile-optimized template for significant GMP movement alert."""
    comp_name = safe_text(ipo.get("company_name"))
    sym = safe_text(ipo.get("symbol"), default="")
    sym_tag = f" ({sym})" if sym and sym != "TBA" else ""

    price_band = safe_text(ipo.get("price_band") or ipo.get("cut_off_price"), default="TBA")
    open_d = ipo.get("open_date")
    close_d = ipo.get("close_date")
    bidding_d = format_date_range_display(open_d, close_d)
    list_d = format_short_date(ipo.get("listing_date"))
    demat_d = format_short_date(
        ipo.get("demat_credit_date")
        or ipo.get("demat_date")
        or derive_demat_date(ipo.get("allotment_date"), ipo.get("listing_date"), ipo.get("close_date"))
    )
    issue_size = format_issue_size(ipo.get("issue_size_cr"))

    est_list = safe_text(ipo.get("est_listing_price"), default="TBA")
    gmp = safe_text(ipo.get("gmp"), default="N/A")
    gmp_pct_str = format_gmp_percent(ipo.get("gmp_percent"))

    surge_disp = f" <b>{surge_text}</b>" if surge_text else ""
    gmp_str = f"<b>{gmp}</b> ({gmp_pct_str}){surge_disp}" if gmp_pct_str else f"<b>{gmp}</b>{surge_disp}"

    old_str = f"• <b>Previous GMP:</b> {old_gmp}\n" if old_gmp else ""
    kostak = safe_text(ipo.get("kostak"), default="")
    kostak_str = f"• <b>Kostak Rate:</b> {kostak}\n" if kostak and kostak != "TBA" else ""

    reg_html = get_registrar_link_html(ipo.get("registrar"))

    # Live NSE Demand / Bids if available
    sub = ipo.get("subscription", {})
    sub_summary = format_subscription_summary(sub)
    demand_line = f"• <b>NSE Demand:</b> {sub_summary}\n" if sub_summary else ""

    return (
        f"⚡ <b>LIVE GMP MOVEMENT ALERT</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"🏢 <b>{comp_name}</b>{sym_tag}\n"
        f"🏷️ <i>Mainboard IPO · Grey Market Revision</i>\n\n"
        f"💰 <b>IPO Issue Size:</b> {issue_size}\n"
        f"🏷️ <b>Price Band:</b> {price_band}\n"
        f"📅 <b>Bidding:</b> {bidding_d}\n"
        f"🚀 <b>IPO Listing Date:</b> <b>{list_d}</b>\n"
        f"📌 <b>Demat Credit:</b> {demat_d}\n"
        f"🏛️ <b>Registrar:</b> {reg_html}\n\n"
        f"🔥 <b>UPDATED GREY MARKET PREMIUM:</b>\n"
        f"{old_str}"
        f"• <b>Current GMP:</b> {gmp_str}\n"
        f"• <b>Expected Listing Price:</b> {est_list}\n"
        f"{kostak_str}"
        f"{demand_line}\n"
        f"<i>*GMP is based on unofficial market trades &amp; subject to rapid fluctuations.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Real-time IPO Tracking:</b> {CHANNEL_HANDLE}"
    )


def format_listing_today_alert(ipo: dict) -> str:
    """Curated mobile-optimized template for Listing Day debut alert."""
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

    issue_size = format_issue_size(ipo.get("issue_size_cr"))

    sub = ipo.get("subscription", {})
    total_sub = safe_text(sub.get("total"), default="Over-subscribed")

    reg_html = get_registrar_link_html(ipo.get("registrar"))
    reg_line = f"• <b>Registrar:</b> {reg_html}\n" if reg_html else ""

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
        f"• <b>IPO Issue Size:</b> {issue_size}\n"
        f"• <b>Overall Subscription:</b> {total_sub}\n"
        f"{reg_line}\n"
        f"💡 <i>Post-listing strategy: Long-term allottees can review quarterly earnings; listing gain seekers can maintain trailing stop-loss.</i>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"📊 <b>Real-time IPO Performance:</b> {CHANNEL_HANDLE}\n"
        f"{DISCLAIMER}"
    )


def format_gmp_dashboard(ipos: list[dict], as_of_date: str | None = None) -> str:
    """Curated mobile-optimized template for Daily/Weekly Mainboard IPO GMP Dashboard."""
    date_str = as_of_date or datetime.now(IST).strftime("%d %b %Y")
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
        gmp = safe_text(ipo.get("gmp"))
        gmp_pct = ipo.get("gmp_percent", "")
        gmp_pct_str = format_gmp_percent(gmp_pct)
        price = safe_text(ipo.get("price_band") or ipo.get("cut_off_price"), default="TBA")

        if gmp and str(gmp).strip() not in ("--", "0", "TBA", ""):
            gmp_display = f"{gmp} ({gmp_pct_str})" if gmp_pct_str else f"{gmp}"
        else:
            gmp_display = "Trading yet to start"

        open_d = ipo.get("open_date")
        close_d_val = ipo.get("close_date")
        bidding_d = format_date_range_display(open_d, close_d_val)
        list_d = format_short_date(ipo.get("listing_date"))
        demat_d = format_short_date(
            ipo.get("demat_credit_date")
            or ipo.get("demat_date")
            or derive_demat_date(ipo.get("allotment_date"), ipo.get("listing_date"), ipo.get("close_date"))
        )
        issue_size = format_issue_size(ipo.get("issue_size_cr"))

        kostak = safe_text(ipo.get("kostak"), default="")
        rate_info = f" | Kostak: {kostak}" if kostak and kostak != "TBA" else ""

        reg_html = get_registrar_link_html(ipo.get("registrar"))

        # Live NSE Demand / Bids if available
        sub = ipo.get("subscription", {})
        sub_summary = format_subscription_summary(sub)
        demand_line = f"\n• <b>NSE Demand:</b> {sub_summary}" if sub_summary else ""

        lines.append(
            f"🔹 <b>{name}</b>\n"
            f"• <b>Issue Size:</b> {issue_size}\n"
            f"• <b>Price Band:</b> {price}\n"
            f"• <b>Bidding Window:</b> {bidding_d}\n"
            f"• <b>IPO Listing Date:</b> <b>{list_d}</b>\n"
            f"• <b>Demat Credit:</b> {demat_d}\n"
            f"• <b>Registrar:</b> {reg_html}\n"
            f"• <b>Live GMP:</b> <b>{gmp_display}</b>{rate_info}"
            f"{demand_line}\n"
        )

    content = "\n".join(lines) if lines else "<i>Currently, no Mainboard IPO is actively open for bidding on NSE/BSE. Tracking upcoming SEBI DRHP issue filings &amp; announcements...</i>"

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
        "TEST_VERIFICATION": lambda x: format_test_verification_post(),
        "NEW_IPO_ANNOUNCED": format_new_ipo_alert,
        "IPO_OPENS_TODAY": format_opens_today_alert,
        "IPO_CLOSING_TODAY": format_closing_today_alert,
        "ALLOTMENT_OUT": format_allotment_out_alert,
        "LISTING_TODAY": format_listing_today_alert,
        "GMP_UPDATE": lambda x: format_gmp_update_alert(
            x,
            old_gmp=x.get("last_posted_gmp", ""),
            surge_text=x.get("surge_text", ""),
        ),
    }
    formatter = formatters.get(event_type)
    if not formatter:
        return None
    return formatter(ipo)
