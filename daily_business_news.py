#!/usr/bin/env python3
"""Daily Indian business-news RSS archive with an optional insight workflow.

The ``archive`` mode only updates business_news_archive.json from publisher RSS
feeds; it does not call AI, edit content_queue.json, or send Telegram messages.
The existing hourly mode can still create a source-linked educational insight
for the existing queue. The Telegram poster handles delivery separately.
"""

from __future__ import annotations

import difflib
import hashlib
import html
import json
import os
import re
import sys
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import requests

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

QUEUE_FILE = "content_queue.json"
STATE_FILE = "daily_news_state.json"
ARCHIVE_FILE = "business_news_archive.json"
ARCHIVE_FETCH_MAX_AGE_HOURS = int(os.environ.get("NEWS_ARCHIVE_MAX_AGE_HOURS", "48"))
POST_CANDIDATE_MAX_AGE_HOURS = int(os.environ.get("NEWS_POST_MAX_AGE_HOURS", "12"))
ARCHIVE_RETENTION_DAYS = 30
ARCHIVE_MAX_ITEMS = 3000
MAX_CANDIDATES = 6
MAX_ARTICLE_CHARS = 3000
MIN_AI_CONTEXT_CHARS = int(os.environ.get("NEWS_MIN_AI_CONTEXT_CHARS", "600"))
POSTING_HOURS_IST = set(range(16, 22))  # 4 PM through 9 PM inclusive

UA = {
    "User-Agent": "Mozilla/5.0 (compatible; DailyBusinessNewsInsight/1.0; +https://github.com/)"
}

# Publisher RSS feeds. Only titles, short excerpts and links are used; the AI
# is instructed to write original commentary and cite the source.
FEEDS = [
    {
        "name": "CNBC-TV18",
        "url": "https://www.cnbctv18.com/commonfeeds/v1/cne/rss/market.xml",
        "priority": 3,
        "domains": ("cnbctv18.com",),
    },
    {
        "name": "Economic Times",
        "url": "https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms",
        "priority": 3,
        "domains": ("economictimes.indiatimes.com",),
    },
    {
        "name": "The Hindu BusinessLine",
        "url": "https://www.thehindubusinessline.com/markets/stock-markets/feeder/default.rss",
        "priority": 2,
        "domains": ("thehindubusinessline.com",),
    },
]

POSITIVE_TERMS = (
    "ipo", "rbi", "sebi", "policy", "repo rate", "tariff", "debt", "capex",
    "order", "contract", "acquisition", "merger", "buyback", "dividend",
    "liquidity", "fundraise", "funding", "default", "npa", "crude", "rupee",
    "export", "import", "regulation", "approval", "capacity", "subscription",
    "listing", "withdrawal", "investment", "inflation", "gdp", "fii", "fpi",
    "dii", "bond", "stock exchange", "settlement",
)

# Hard result markers plus common result metrics/verbs. Metrics are checked in
# context so macro stories about tax revenue, for example, are not mistaken for
# company earnings releases.
RESULTS_EXCLUDE_TERMS = (
    "result", "results", "earning", "earnings", "q1", "q2", "q3", "q4",
    "quarterly", "quarter results", "financial results", "annual results",
    "half-year results", "ebitda", "eps", "net interest income", "pat", "nim",
)
RESULT_METRIC_TERMS = (
    "profit", "profits", "net profit", "loss", "losses", "net loss", "revenue",
    "revenues", "operating income", "net income", "earnings per share",
)
RESULT_REPORTING_VERBS = (
    "reports", "reported", "posts", "posted", "declares", "announces", "records",
    "recorded", "beats", "misses", "rose", "rises", "fell", "falls", "surges",
    "surged", "jumps", "jumped", "drops", "dropped", "grew", "grows", "declines",
    "declined", "dips", "slumps", "slumped", "up", "down", "increases", "increased",
    "increase", "decreases", "decreased", "decrease", "climbs", "climbed", "soars", "soared",
    "doubles", "doubled", "triples", "tripled", "narrows", "narrowed", "widens", "widened",
    "shrinks", "shrunk", "surpasses", "surpassed",
)
ECONOMY_CONTEXT_TERMS = (
    "economy", "economic", "gdp", "gva", "cpi", "wpi", "inflation", "repo rate",
    "monetary policy", "interest rate", "rupee", "currency", "forex", "foreign exchange",
    "trade deficit", "current account", "exports", "imports", "fiscal deficit",
    "gst collection", "tax collection", "budget", "industrial production", "iip", "pmi",
    "government borrowing", "government spending", "manufacturing", "employment",
    "unemployment", "bond yield", "bond yields", "treasury yield", "treasury yields",
    "crude", "crude oil", "oil prices", "rbi", "reserve bank", "central bank",
    "bank indonesia", "federal reserve", "fed rate", "credit growth",
    "debt concerns", "commodity prices", "trade policy", "trade deal", "trade agreement",
    "economic policy", "monetary policy", "tax revenue", "government revenue", "gst revenue",
    "customs revenue",
)
CAPITAL_MARKET_CONTEXT_TERMS = (
    "capital market", "capital markets", "ipo", "fpo", "qip", "rights issue",
    "offer for sale", "anchor investor", "stock exchange", "sebi", "nse", "bse",
    "depository", "mutual fund", "fii", "fiis", "fpi", "dii", "equity market",
    "share market", "liquidity", "market liquidity", "market infrastructure", "securities",
    "settlement", "margin", "corporate bond", "government bond", "bond market",
    "bond markets", "bonds", "bond", "buyback", "dividend", "stock split", "bonus issue",
    "listing", "delisting", "market capitalisation", "market capitalization", "nifty",
    "sensex", "futures", "options", "index", "indices", "shareholding", "market value",
)
STOCK_MARKET_CONTEXT_TERMS = (
    "stock market", "stock markets", "stocks", "stock", "shares", "share price",
    "stock price", "equity", "listed company", "listed companies", "listed firm",
    "listed firms",
)
LISTED_COMPANY_EVENT_TERMS = (
    "order", "contract", "acquisition", "acquires", "acquired", "merger", "takeover",
    "joint venture", "jv agreement", "capex", "capacity", "commission", "commissioned",
    "commercial production", "new plant", "facility", "fundraise", "funding", "stake sale",
    "divestment", "asset sale", "buyback", "dividend", "stock split", "bonus issue",
    "hotel", "property", "fleet expansion", "gas carrier", "vessel", "partnership",
    "signs", "signed", "buys", "acquires",
)

# News formats and framing that are routinely repetitive or opinion-led.
EXCLUDE_TERMS = (
    "broker", "analyst", "recommendation", "recommendations", "recommended", "opinion", "editorial",
    "commentary", "op-ed", "op ed", "viewpoint", "analysis", "market view", "company view",
    "stocks to buy", "stock to buy",
    "stocks to sell", "stock to sell", "stocks to buy today", "stocks to buy now", "should you buy", "should you sell",
    "top stocks to buy", "best stocks", "stock tips", "share tips", "buy call", "sell call",
    "target price", "target prices", "price target", "price targets", "buy rating", "sell rating",
    "buy on dips", "sell on rise", "stocks to watch today",
    "top pick", "stock pick", "prefers", "overweight", "underweight", "upgrades",
    "downgrades", "rating upgrade", "rating downgrade", "recommends", "accumulate",
    "outperform", "underperform", "top brokerage pick", "outlook", "forecast", "forecasts",
    "estimate", "estimates", "estimated", "expects", "expected", "predicts", "prediction",
    "potential", "expert view", "experts say", "experts weigh in", "expert says",
    "buying opportunity", "buying the dip", "more pain ahead", "could mean", "could threaten",
    "may not recover", "better value", "undervalued", "overvalued", "expensive stocks",
    "cheap stocks", "why", "what should", "better value overseas", "sees slowdown",
    "mutual fund slowdown", "dents investor bandwidth", "weighs on markets", "weighs on market",
    "sell these", "buy these", "avoid these", "sell this stock", "buy this stock",
    "flags ipo slowdown",
)
NEWS_FORMAT_EXCLUDE_TERMS = (
    "market wrap", "markets today", "stock market today", "live update", "live updates",
    "live blog", "liveblog", "highlights", "roundup", "round-up", "stocks to watch",
    "market pulse", "key triggers to watch", "stocks in focus",
)
IPO_DEDUPE_GENERIC_TERMS = {
    "ipo", "fpo", "issue", "issues", "public", "offer", "anchor", "investor", "investors",
    "demand", "subscription", "subscribed", "application", "applications", "bid", "bids",
    "qib", "retail", "record", "records", "first", "global", "globally", "largest",
    "day", "highlights", "live", "update", "updates", "crore", "lakh", "million",
    "times", "opens", "open", "opening", "cross", "crosses", "breaks", "jumps",
    "milestone", "milestones", "markets", "market", "stock", "stocks", "shares", "share",
    "equity", "india", "indian", "the", "and", "for", "from", "with", "into", "price",
    "prices", "band", "premium", "debut", "debuted", "list", "listing", "listed", "trading", "trades",
    "nse", "bse", "at", "up", "down", "make", "makes", "made", "rise", "rises", "fell", "falls",
    "jump", "jumps", "flat", "bumper", "stellar", "market", "day", "public", "sale",
    "oct", "nov", "dec", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep",
}
DEDUPE_GENERIC_TERMS = {
    "the", "and", "for", "from", "with", "into", "after", "ahead", "over", "under",
    "amid", "as", "at", "by", "in", "on", "to", "of", "a", "an", "is", "are",
    "was", "were", "be", "been", "being", "will", "its", "it", "this", "that", "their",
    "they", "them", "has", "have", "had", "says", "said", "saying", "reports", "reported",
    "latest", "today", "live", "update", "updates", "highlights", "day", "new", "news",
    "market", "markets", "stock", "stocks", "share", "shares", "equity", "price", "prices",
    "debut", "debuted", "list", "lists", "listing", "listed", "premium",
    "india", "indian", "global", "globally", "first", "record", "records", "crore", "lakh",
    "million", "billion", "thousand", "more", "less", "after", "before", "could", "would",
    "should", "may", "might", "via", "now", "top", "all", "one", "two", "three", "four",
    "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
}
EVENT_DEDUPE_GENERIC_TERMS = DEDUPE_GENERIC_TERMS | {
    "order", "orders", "contract", "contracts", "work", "win", "wins", "won", "bag", "bags",
    "bagged", "award", "awards", "awarded", "secure", "secures", "secured", "capex",
    "capacity", "commission", "commissioned", "commissioning", "commercial", "production",
    "plant", "facility", "acquisition", "acquisitions", "acquire", "acquires", "acquired",
    "merger", "mergers", "merges", "merged", "takeover", "joint", "venture", "agreement",
    "buyback", "buybacks", "dividend", "dividends", "split", "bonus", "issue", "issues",
    "rights", "stake", "stakes", "sale", "asset", "assets", "company", "companies", "firm",
    "firms", "group", "limited", "ltd", "inc", "corporation", "industries", "technology",
    "sebi", "rbi", "nse", "bse",
}
DUPLICATE_EVENT_FAMILIES = (
    ("order_contract", ("order", "orders", "contract", "contracts", "work order")),
    ("capacity_capex", ("capex", "capacity", "commission", "commissioned", "commercial production", "plant", "facility")),
    ("acquisition_jv", ("acquisition", "acquisitions", "acquires", "acquired", "merger", "mergers", "takeover", "joint venture", "jv agreement")),
    ("capital_action", ("buyback", "buybacks", "dividend", "dividends", "stock split", "bonus issue", "rights issue")),
)
ARCHIVE_DEDUPE_WINDOW_HOURS = 72

GEMINI_KEYS = list(dict.fromkeys(filter(None, [
    os.environ.get("GEMINI_API_KEY", "").strip(),
    os.environ.get("GOOGLE_API_KEY", "").strip(),
    os.environ.get("GEMINI_API_KEY2", "").strip(),
    os.environ.get("GOOGLE_API_KEY2", "").strip(),
])))
GROQ_KEYS = list(dict.fromkeys(filter(None, [
    os.environ.get("GROQ_API_KEY", "").strip(),
    os.environ.get("GROQ_API_KEY2", "").strip(),
])))
GROQ_MODEL = os.environ.get("GROQ_MODEL", "").strip() or "llama-3.3-70b-versatile"
GEMINI_MODELS = [
    os.environ.get("GEMINI_MODEL", "").strip() or "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-flash-lite-latest",
]
GEMINI_MODELS = list(dict.fromkeys(m for m in GEMINI_MODELS if m))


class ParagraphExtractor(HTMLParser):
    """Extract readable article paragraphs without extra HTML dependencies."""

    SKIP_TAGS = {"script", "style", "noscript", "svg", "nav", "footer", "header", "aside"}
    TEXT_TAGS = {"p", "h1", "h2", "h3", "li"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip_depth = 0
        self.capture_depth = 0
        self.current = []
        self.paragraphs = []

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in self.SKIP_TAGS:
            self.skip_depth += 1
        elif not self.skip_depth and tag in self.TEXT_TAGS:
            self.capture_depth += 1
            if self.capture_depth == 1:
                self.current = []

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in self.SKIP_TAGS and self.skip_depth:
            self.skip_depth -= 1
        elif not self.skip_depth and tag in self.TEXT_TAGS and self.capture_depth:
            self.capture_depth -= 1
            if self.capture_depth == 0:
                text = _clean_text(" ".join(self.current))
                if len(text) > 35:
                    self.paragraphs.append(text)
                self.current = []

    def handle_data(self, data):
        if not self.skip_depth and self.capture_depth:
            self.current.append(data)


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1].split(":")[-1].lower()


def _clean_text(value: str | None) -> str:
    if not value:
        return ""
    value = html.unescape(value)
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    value = value.replace("\xa0", " ").replace("\u200b", " ")
    return re.sub(r"\s+", " ", value).strip()


def _canonical_url(url: str) -> str:
    try:
        parts = urlsplit(html.unescape(url.strip()))
        if parts.scheme not in ("http", "https") or not parts.netloc:
            return ""
        query = [(k, v) for k, v in parse_qsl(parts.query, keep_blank_values=True)
                 if not k.lower().startswith("utm_") and k.lower() not in {"fbclid", "gclid"}]
        return urlunsplit((parts.scheme.lower(), parts.netloc.lower(), parts.path.rstrip("/"),
                           urlencode(query), ""))
    except Exception:
        return ""


def _parse_datetime(value: str | None):
    if not value:
        return None
    value = value.strip()
    try:
        dt = parsedate_to_datetime(value)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(IST)
    except Exception:
        pass
    try:
        normalized = value.replace("Z", "+00:00")
        dt = datetime.fromisoformat(normalized)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(IST)
    except Exception:
        return None


def _child_text(element, names):
    for child in list(element):
        if _local_name(child.tag) in names:
            # Atom feeds put the actual URL in a link's href attribute.
            if _local_name(child.tag) == "link":
                href = child.attrib.get("href")
                if href:
                    return href.strip()
            text = " ".join(part.strip() for part in child.itertext() if part.strip())
            if text:
                return text
    return ""


def parse_rss(xml_bytes: bytes, source: dict):
    """Parse RSS 2.0 or Atom items using Python's standard library."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as exc:
        print(f"   ⚠️ RSS parse error ({source['name']}): {exc}")
        return []

    output = []
    for element in root.iter():
        if _local_name(element.tag) not in {"item", "entry"}:
            continue
        title = _clean_text(_child_text(element, {"title"}))
        link = _canonical_url(_child_text(element, {"link"}))
        summary = _clean_text(_child_text(element, {"description", "summary", "encoded", "content"}))
        raw_date = _child_text(element, {"pubdate", "published", "updated", "date"})
        published = _parse_datetime(raw_date)
        if not title or not link or not published:
            continue
        host = (urlsplit(link).hostname or "").lower()
        if not any(host == domain or host.endswith("." + domain) for domain in source["domains"]):
            continue
        output.append({
            "source": source["name"],
            "source_priority": source["priority"],
            "title": title,
            "url": link,
            "summary": summary[:1800],
            "published": published,
        })
    return output


def _normalized_words(text):
    return re.sub(r"[^a-z0-9]+", " ", str(text or "").lower()).strip()


def _contains_any_phrase(text, phrases):
    normalized = _normalized_words(text)
    padded = f" {normalized} "
    return any(f" {_normalized_words(phrase)} " in padded for phrase in phrases)


def _is_financial_results_headline(title):
    if _contains_any_phrase(title, RESULTS_EXCLUDE_TERMS):
        return True
    if not _contains_any_phrase(title, RESULT_METRIC_TERMS):
        return False
    if _contains_any_phrase(title, ("tax revenue", "gst revenue", "government revenue", "customs revenue", "budget revenue")):
        return False
    return _contains_any_phrase(title, RESULT_REPORTING_VERBS)


def _is_opinion_headline(title):
    normalized = _normalized_words(title)
    if _contains_any_phrase(normalized, EXCLUDE_TERMS):
        return True
    if re.search(r"\b(?:analysts?|brokers?|brokerages?)\b", normalized):
        return True
    if re.search(
        r"\b(?:may|might|could|should|can)\s+(?:not\s+)?"
        r"(?:rise|fall|gain|drop|surge|soar|decline|recover|weaken|strengthen|boost|hurt|"
        r"lead|drive|trigger|reach|cross|double|halve|grow|increase|decrease|tighten|ease|"
        r"cut|raise|benefit|deliver|become|remain|face|threaten|improve|worsen|stay|"
        r"prioritise|prioritize|outperform|underperform)\b",
        normalized,
    ):
        return True
    if re.search(r"\bsees?\s+(?:a\s+|the\s+)?(?:slowdown|growth|recovery|rally|correction|decline|fall|rise|increase|decrease|expansion)\b", normalized):
        return True
    if re.search(r"\b(?:likely|unlikely|expected|expects|predicts|forecast|estimates?)\b", normalized):
        return True
    # Question-framed analysis is usually a recommendation or interpretation,
    # rather than a reported economic/market event.
    if "?" in str(title) and _contains_any_phrase(
        normalized, ("why", "what", "should", "could", "would", "can", "will")
    ):
        return True
    return False


def classify_news_story(title, summary="", url=""):
    """Return the in-scope topic, or ``None`` for results, opinion or noise.

    Scope is determined from the headline, not the RSS summary: publisher
    excerpts can mention unrelated terms and otherwise pull consumer/tech items
    into an economy or market archive.
    """
    headline = _clean_text(str(title or ""))
    if not headline or _is_financial_results_headline(headline):
        return None
    if _is_opinion_headline(headline) or _contains_any_phrase(headline, NEWS_FORMAT_EXCLUDE_TERMS):
        return None

    if _contains_any_phrase(headline, ECONOMY_CONTEXT_TERMS):
        return "economy"
    if _contains_any_phrase(headline, CAPITAL_MARKET_CONTEXT_TERMS):
        return "capital_market"
    if _contains_any_phrase(headline, STOCK_MARKET_CONTEXT_TERMS):
        return "stock_market"

    path = urlsplit(str(url or "")).path.lower()
    if (_contains_any_phrase(headline, LISTED_COMPANY_EVENT_TERMS)
            and ("/market/" in path or "/markets/" in path)):
        return "stock_market"
    return None


def _item_score(item):
    title = str(item.get("title", ""))
    if not classify_news_story(title, item.get("summary", ""), item.get("url", "")):
        return -100
    score = int(item.get("source_priority", 1))
    score += sum(2 for term in POSITIVE_TERMS if _contains_any_phrase(title, (term,)))
    if len(item.get("summary", "")) > 120:
        score += 2
    published = item.get("published")
    if published:
        age_hours = max(0, (NOW - published).total_seconds() / 3600)
        score += max(0, 3 - age_hours / 12)
    return score


def _title_similarity(left: str, right: str) -> float:
    def tokens(text):
        return {w for w in re.findall(r"[a-z0-9]+", text.lower()) if len(w) > 2}
    a, b = tokens(left), tokens(right)
    if not a or not b:
        return 0.0
    jaccard = len(a & b) / len(a | b)
    containment = len(a & b) / min(len(a), len(b))
    return max(difflib.SequenceMatcher(None, left.lower(), right.lower()).ratio(),
               jaccard, containment * 0.88)


def _dedupe_title_tokens(title):
    return {
        token for token in re.findall(r"[a-z0-9]+", str(title or "").lower())
        if len(token) > 2 and not re.search(r"\d", token) and token not in DEDUPE_GENERIC_TERMS
    }


def _duplicate_event_family(title):
    for family, terms in DUPLICATE_EVENT_FAMILIES:
        if _contains_any_phrase(title, terms):
            return family
    return None


def _event_entity_tokens(title):
    return _dedupe_title_tokens(title) - EVENT_DEDUPE_GENERIC_TERMS


def _ipo_event_type(title):
    if _contains_any_phrase(title, ("market liquidity", "liquidity shift", "investor bandwidth", "listed stocks", "market impact")):
        return "market_impact"
    if _contains_any_phrase(title, ("debut", "debuted", "listing", "listed at", "shares list", "share listing")):
        return "listing"
    if _contains_any_phrase(title, ("subscription", "subscribed", "oversubscribed", "bids", "applications", "demand", "investor demand", "crosses demand")):
        return "subscription"
    if _contains_any_phrase(title, ("opens", "opening", "price band", "anchor investor", "anchor book")):
        return "offer"
    return "ipo_misc"


def _is_listing_story(title):
    return _contains_any_phrase(title, ("debut", "debuted", "listing", "listed at", "shares list", "shares debut"))


def _story_datetime(story):
    if isinstance(story.get("published"), datetime):
        return story["published"]
    return _parse_archive_time(story.get("published_at"))


def _stories_are_duplicates(left, right):
    left_url = _canonical_url(left.get("url", ""))
    right_url = _canonical_url(right.get("url", ""))
    if left_url and left_url == right_url:
        return True

    left_title = str(left.get("title", left.get("headline", "")))
    right_title = str(right.get("title", right.get("headline", "")))
    left_tokens = _dedupe_title_tokens(left_title)
    right_tokens = _dedupe_title_tokens(right_title)
    shared_tokens = left_tokens & right_tokens
    similarity = _title_similarity(left_title, right_title)
    left_date, right_date = _story_datetime(left), _story_datetime(right)
    hours_apart = (
        abs((left_date - right_date).total_seconds()) / 3600
        if left_date and right_date else None
    )
    left_is_ipo = _contains_any_phrase(left_title, ("ipo", "fpo", "initial public offering"))
    right_is_ipo = _contains_any_phrase(right_title, ("ipo", "fpo", "initial public offering"))

    if hours_apart is not None and hours_apart > ARCHIVE_DEDUPE_WINDOW_HOURS:
        if not (left_is_ipo and right_is_ipo and hours_apart <= 14 * 24):
            return False

    if (_is_listing_story(left_title) and _is_listing_story(right_title)
            and (hours_apart is None or hours_apart <= ARCHIVE_DEDUPE_WINDOW_HOURS)):
        listing_entities_left = left_tokens - IPO_DEDUPE_GENERIC_TERMS
        listing_entities_right = right_tokens - IPO_DEDUPE_GENERIC_TERMS
        if listing_entities_left & listing_entities_right:
            return True

    # Group repeated updates only for the same issuer and IPO phase: subscription
    # coverage should not erase a distinct listing or market-impact story.
    if left_is_ipo and right_is_ipo:
        ipo_entities_left = left_tokens - IPO_DEDUPE_GENERIC_TERMS
        ipo_entities_right = right_tokens - IPO_DEDUPE_GENERIC_TERMS
        overlap = ipo_entities_left & ipo_entities_right
        same_phase = _ipo_event_type(left_title) == _ipo_event_type(right_title)
        if overlap:
            if same_phase and (hours_apart is None or hours_apart <= 14 * 24):
                return True
            return False
        # Never merge different issuers' IPOs based on generic words such as
        # "debut", "premium", or the issue month.
        if ipo_entities_left and ipo_entities_right:
            return False
        if similarity >= 0.88 and len(shared_tokens) >= 3 and same_phase:
            return True

    # Same-event company disclosures need a shared issuer/project token; a
    # common phrase like "wins NHAI contract" alone must not merge two firms.
    left_family = _duplicate_event_family(left_title)
    right_family = _duplicate_event_family(right_title)
    if left_family and left_family == right_family:
        shared_entities = _event_entity_tokens(left_title) & _event_entity_tokens(right_title)
        if not shared_entities:
            return False
        if similarity >= 0.70 or (len(shared_entities) >= 2 and similarity >= 0.58):
            return True

    # Same-session currency/commodity updates are often republished with
    # different wording. Collapse only same-day moves in the same lead instrument.
    if left_date and right_date and left_date.date() == right_date.date():
        def leading_instrument(title):
            normalized = _normalized_words(title)
            if normalized.startswith("rupee "):
                return "rupee"
            if normalized.startswith(("crude ", "brent ", "oil prices ")):
                return "crude"
            return None

        movement_terms = (
            "rise", "rises", "rose", "fall", "falls", "fell", "drop", "drops", "dropped",
            "gain", "gains", "gained", "edge", "edges", "slip", "slips", "tumble", "tumbles",
            "sink", "sinks", "little changed", "weaken", "weakens", "strengthen", "strengthens",
            "snap", "snaps", "lower", "higher", "surge", "surges", "decline", "declines",
        )
        left_instrument = leading_instrument(left_title)
        right_instrument = leading_instrument(right_title)
        if (left_instrument and left_instrument == right_instrument
                and _contains_any_phrase(left_title, movement_terms)
                and _contains_any_phrase(right_title, movement_terms)):
            return True

    if similarity >= 0.80 and len(shared_tokens) >= 2:
        return True
    return similarity >= 0.74 and len(shared_tokens) >= 3


def group_stories(items):
    """Filter to the requested topics and group repeated event coverage."""
    groups = []
    for item in sorted(items, key=lambda x: (x.get("published") or NOW, _item_score(x)), reverse=True):
        if _item_score(item) < 0:
            continue
        match = next((group for group in groups
                      if _stories_are_duplicates(item, group["items"][0])), None)
        if match:
            if all(item.get("url") != old.get("url") for old in match["items"]):
                match["items"].append(item)
        else:
            story_key = hashlib.sha256(
                (item.get("url", "") + "|" + item.get("title", "").lower()).encode()
            ).hexdigest()
            groups.append({"key": story_key, "items": [item]})

    for group in groups:
        group["items"].sort(
            key=lambda x: (x.get("source_priority", 1), x.get("published") or NOW),
            reverse=True,
        )
        primary = group["items"][0]
        group["topic"] = classify_news_story(
            primary.get("title", ""), primary.get("summary", ""), primary.get("url", "")
        )
        group["score"] = max(_item_score(item) for item in group["items"]) + min(
            3, len(group["items"]) - 1
        ) * 1.5
    groups.sort(key=lambda x: (x["score"], x["items"][0].get("published") or NOW), reverse=True)
    return groups


def fetch_feeds():
    all_items = []
    feed_status = {}
    successful_feeds = 0
    cutoff = NOW - timedelta(hours=ARCHIVE_FETCH_MAX_AGE_HOURS)
    for source in FEEDS:
        try:
            response = requests.get(source["url"], headers=UA, timeout=25)
            response.raise_for_status()
            successful_feeds += 1
            items = parse_rss(response.content, source)
            fresh = [item for item in items
                     if cutoff <= item["published"] <= NOW + timedelta(hours=2)]
            accepted = []
            for item in fresh:
                topic = classify_news_story(item["title"], item.get("summary", ""), item.get("url", ""))
                if not topic:
                    continue
                item["topic"] = topic
                accepted.append(item)
            feed_status[source["name"]] = {
                "checked_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
                "http_status": response.status_code,
                "fresh_items": len(fresh),
                "accepted_items": len(accepted),
                "filtered_items": len(fresh) - len(accepted),
                "error": None,
            }
            print(
                f"   📰 {source['name']}: {len(accepted)} in-scope stories "
                f"({len(fresh) - len(accepted)} filtered from {len(fresh)} fresh)"
            )
            all_items.extend(accepted)
        except Exception as exc:
            feed_status[source["name"]] = {
                "checked_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
                "http_status": None,
                "fresh_items": 0,
                "accepted_items": 0,
                "filtered_items": 0,
                "error": str(exc)[:160],
            }
            print(f"   ⚠️ Feed unavailable ({source['name']}): {str(exc)[:120]}")
    return {"items": all_items, "status": feed_status, "any_success": successful_feeds > 0}


def _parse_archive_time(value):
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(value)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=IST)
        return dt.astimezone(IST)
    except Exception:
        return _parse_datetime(value)


def _safe_int(value, default=1):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _archive_status_priority(record):
    return {"posted": 3, "queued": 2, "rejected": 1, "new": 0}.get(record.get("status"), 0)


def _archive_rank(record):
    published = _story_datetime(record)
    return (
        _archive_status_priority(record),
        published.timestamp() if published else 0,
        _safe_int(record.get("source_priority", 1), 1),
        len(str(record.get("summary", "") or "")),
    )


def _archive_stamp_datetime(record, field):
    return _parse_archive_time(record.get(field))


def _format_archive_stamp(value):
    return value.strftime("%Y-%m-%d %H:%M:%S IST") if value else None


def _merge_duplicate_records(keeper, duplicate):
    """Keep one event record, preserving processed state and the latest facts."""
    update_latest = _archive_rank(duplicate)[1:] > _archive_rank(keeper)[1:]
    if update_latest:
        for key in (
            "source", "source_priority", "headline", "url", "published_at", "published_ist",
            "summary", "topic",
        ):
            if key in duplicate:
                keeper[key] = duplicate[key]

    if _archive_status_priority(duplicate) > _archive_status_priority(keeper):
        for key in ("status", "post_id", "processed_ist", "posted_at"):
            if key in duplicate:
                keeper[key] = duplicate[key]

    for field, choose_earlier in (("first_seen_at", True), ("last_seen_at", False)):
        dates = [dt for dt in (_archive_stamp_datetime(keeper, field),
                               _archive_stamp_datetime(duplicate, field)) if dt]
        if dates:
            chosen = min(dates) if choose_earlier else max(dates)
            keeper[field] = chosen.isoformat()
            ist_field = field.replace("_at", "_ist")
            keeper[ist_field] = _format_archive_stamp(chosen)

    if not keeper.get("id"):
        keeper["id"] = duplicate.get("id")


def _curate_archive_stories(stories):
    """Remove out-of-scope records and collapse one event to one archive row."""
    accepted = []
    removed = 0
    for source_record in stories:
        if not isinstance(source_record, dict):
            removed += 1
            continue
        record = dict(source_record)
        title = record.get("headline", record.get("title", ""))
        url = _canonical_url(record.get("url", ""))
        topic = classify_news_story(title, record.get("summary", ""), url)
        if not topic or not url:
            removed += 1
            continue
        record["headline"] = _clean_text(str(title))
        record["url"] = url
        record["topic"] = topic
        record.setdefault("status", "new")
        accepted.append(record)

    accepted.sort(key=_archive_rank, reverse=True)
    curated = []
    duplicates = 0
    for record in accepted:
        match = next((old for old in curated if _stories_are_duplicates(record, old)), None)
        if match:
            _merge_duplicate_records(match, record)
            duplicates += 1
        else:
            curated.append(record)

    curated.sort(
        key=lambda item: (_story_datetime(item).timestamp() if _story_datetime(item) else 0),
        reverse=True,
    )
    return curated, removed, duplicates


def _new_archive_record(feed_item, topic):
    url = _canonical_url(feed_item.get("url", ""))
    published = feed_item["published"].astimezone(IST)
    now_iso = NOW.isoformat()
    now_ist = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    return {
        "id": _alpha_id(url),
        "source": feed_item.get("source", "News source"),
        "source_priority": int(feed_item.get("source_priority", 1) or 1),
        "headline": _clean_text(feed_item.get("title", "")),
        "url": url,
        "published_at": published.isoformat(),
        "published_ist": published.strftime("%Y-%m-%d %H:%M IST"),
        "summary": _clean_text(feed_item.get("summary", ""))[:900],
        "first_seen_at": now_iso,
        "last_seen_at": now_iso,
        "first_seen_ist": now_ist,
        "last_seen_ist": now_ist,
        "status": "new",
        "topic": topic,
    }


def _refresh_archive_record(record, feed_item, topic):
    """Refresh a canonical event row without resetting queued/posted state."""
    url = _canonical_url(feed_item.get("url", ""))
    published = feed_item["published"].astimezone(IST)
    old_published = _parse_archive_time(record.get("published_at"))
    old_summary = record.get("summary", "")
    new_summary = _clean_text(feed_item.get("summary", ""))[:900]
    should_refresh = (
        old_published is None
        or published > old_published
        or (
            published == old_published
            and (
                int(feed_item.get("source_priority", 1) or 1) > int(record.get("source_priority", 1) or 1)
                or len(new_summary) > len(old_summary)
            )
        )
    )
    before = (record.get("headline"), record.get("url"), record.get("published_at"), old_summary)
    now_iso = NOW.isoformat()
    now_ist = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    record.setdefault("first_seen_at", now_iso)
    record.setdefault("first_seen_ist", now_ist)
    record["last_seen_at"] = now_iso
    record["last_seen_ist"] = now_ist
    record.setdefault("status", "new")

    if should_refresh:
        record["source"] = feed_item.get("source", record.get("source", "News source"))
        record["source_priority"] = int(feed_item.get("source_priority", 1) or 1)
        record["headline"] = _clean_text(feed_item.get("title", record.get("headline", "")))
        record["url"] = url or record.get("url", "")
        record["published_at"] = published.isoformat()
        record["published_ist"] = published.strftime("%Y-%m-%d %H:%M IST")
        if new_summary:
            record["summary"] = new_summary
    elif new_summary and not old_summary:
        record["summary"] = new_summary
    record["topic"] = topic
    after = (record.get("headline"), record.get("url"), record.get("published_at"), record.get("summary", ""))
    return before != after


def merge_archive(archive, feed_result):
    """Filter, deduplicate and merge RSS metadata; never store full article text."""
    if not isinstance(archive, dict) or not isinstance(archive.get("stories", []), list):
        raise ValueError("business_news_archive.json has an unexpected schema")

    stories, removed_existing, existing_duplicates = _curate_archive_stories(
        archive.setdefault("stories", [])
    )
    by_url = {item.get("url"): item for item in stories if item.get("url")}
    added = 0
    filtered_feed_items = 0
    feed_duplicates = 0
    new_or_updated_urls = set()
    feed_items = feed_result.get("items", [])

    for feed_item in feed_items:
        topic = classify_news_story(
            feed_item.get("title", ""), feed_item.get("summary", ""), feed_item.get("url", "")
        )
        url = _canonical_url(feed_item.get("url", ""))
        if not topic or not url or not feed_item.get("published"):
            filtered_feed_items += 1
            continue

        normalized_item = dict(feed_item)
        normalized_item["url"] = url
        record = by_url.get(url)
        if record:
            changed = _refresh_archive_record(record, normalized_item, topic)
            if changed:
                new_or_updated_urls.add(url)
                new_or_updated_urls.add(record.get("url", url))
            continue

        candidate = _new_archive_record(normalized_item, topic)
        duplicate = next((old for old in stories if _stories_are_duplicates(candidate, old)), None)
        if duplicate:
            feed_duplicates += 1
            old_url = duplicate.get("url", "")
            changed = _refresh_archive_record(duplicate, normalized_item, topic)
            by_url[url] = duplicate
            by_url[old_url] = duplicate
            if changed:
                new_or_updated_urls.add(url)
                new_or_updated_urls.add(duplicate.get("url", url))
            continue

        stories.append(candidate)
        by_url[url] = candidate
        added += 1
        new_or_updated_urls.add(url)

    stories, removed_final, final_duplicates = _curate_archive_stories(stories)
    retention_cutoff = NOW - timedelta(days=ARCHIVE_RETENTION_DAYS)
    retained = []
    for item in stories:
        published = _parse_archive_time(item.get("published_at"))
        if published is None or published >= retention_cutoff:
            retained.append(item)
    retained.sort(key=lambda item: item.get("published_at", ""), reverse=True)
    archive["stories"] = retained[:ARCHIVE_MAX_ITEMS]
    archive["last_scraped_at"] = NOW.isoformat()
    archive["last_scraped_ist"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    archive["feed_status"] = feed_result.get("status", {})
    archive["retention_days"] = ARCHIVE_RETENTION_DAYS
    old_curation = archive.get("curation", {})
    archive["curation"] = {
        "version": 1,
        "scope": ["economy", "capital_market", "stock_market"],
        "excludes": ["financial_results", "opinions_and_recommendations", "generic_market_wraps"],
        "near_duplicate_window_hours": ARCHIVE_DEDUPE_WINDOW_HOURS,
        "ipo_phase_window_days": 14,
        "last_curated_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
    }
    if isinstance(old_curation, dict) and old_curation.get("initial_cleanup_stats"):
        archive["curation"]["initial_cleanup_stats"] = old_curation["initial_cleanup_stats"]

    status = archive["feed_status"] if isinstance(archive["feed_status"], dict) else {}
    fetched_items = sum(_safe_int(value.get("fresh_items", 0), 0)
                        for value in status.values() if isinstance(value, dict))
    filtered_at_fetch = sum(_safe_int(value.get("filtered_items", 0), 0)
                            for value in status.values() if isinstance(value, dict))
    accepted_at_merge = max(0, len(feed_items) - filtered_feed_items)
    archive["last_run_stats"] = {
        "updated_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "fetched_items": fetched_items or len(feed_items),
        "accepted_feed_items": accepted_at_merge,
        "filtered_feed_items": filtered_at_fetch + filtered_feed_items,
        "new_unique_stories": added,
        "duplicate_items_collapsed": existing_duplicates + feed_duplicates + final_duplicates,
        "out_of_scope_archive_items_removed": removed_existing + removed_final,
        "stories_total": len(archive["stories"]),
    }
    return archive, added, new_or_updated_urls


def archive_to_items(archive, previous_scraped_at=None, fresh_urls=None):
    """Return only unprocessed stories from the latest hourly polling interval.

    The first run in the 4–9 PM window gets a wider same-day lookback. Later
    runs use the prior scrape timestamp with a 45-minute overlap for feed/action
    delays. Newly discovered URLs may still qualify up to the 12-hour age cap.
    """
    fresh_urls = fresh_urls or set()
    if previous_scraped_at:
        cutoff = previous_scraped_at - timedelta(minutes=45)
    else:
        cutoff = NOW - timedelta(hours=6)
    hard_cutoff = NOW - timedelta(hours=POST_CANDIDATE_MAX_AGE_HOURS)
    output = []
    for record in archive.get("stories", []):
        if not isinstance(record, dict) or record.get("status") in {"queued", "posted", "rejected"}:
            continue
        published = _parse_archive_time(record.get("published_at"))
        if not published or published > NOW + timedelta(hours=2) or published < hard_cutoff:
            continue
        if previous_scraped_at:
            if published < cutoff and record.get("url") not in fresh_urls:
                continue
        elif published < cutoff:
            continue
        output.append({
            "source": record.get("source", "News source"),
            "source_priority": int(record.get("source_priority", 1)),
            "title": record.get("headline", ""),
            "url": record.get("url", ""),
            "summary": record.get("summary", ""),
            "topic": record.get("topic"),
            "published": published,
        })
    return output


def mark_archive_group(archive, selected, status, post_id=None):
    urls = set(selected.get("source_urls", []))
    urls.add(selected.get("source_url", ""))
    now_stamp = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    for record in archive.get("stories", []):
        if record.get("url") in urls:
            record["status"] = status
            record["processed_ist"] = now_stamp
            if post_id:
                record["post_id"] = post_id


def reconcile_archive_with_queue(archive, queue):
    queue_items = [item for item in queue.get("queue", [])
                   if isinstance(item, dict) and item.get("kind") == "business_news_insight"]
    for record in archive.get("stories", []):
        if not isinstance(record, dict):
            continue
        match = next((item for item in queue_items
                      if item.get("id") == record.get("post_id")
                      or item.get("source_url") == record.get("url")), None)
        if not match:
            continue
        record["post_id"] = match.get("id")
        if match.get("used"):
            record["status"] = "posted"
            record["posted_at"] = match.get("posted_at", record.get("posted_at"))
        else:
            record["status"] = "queued"
    return archive


def has_due_news(queue):
    now_str = NOW.strftime("%Y-%m-%d %H:%M")
    return any(
        item.get("kind") == "business_news_insight"
        and not item.get("used")
        and item.get("scheduled_ist", "9999") <= now_str
        for item in queue.get("queue", [])
    )


def set_action_output(name, value):
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as output:
            output.write(f"{name}={str(value).lower()}\n")


def _walk_json(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_json(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_json(child)


def _extract_meta_description(document: str):
    for match in re.finditer(r"<meta\b[^>]*>", document, flags=re.I | re.S):
        tag = match.group(0)
        name = re.search(r"(?:name|property)\s*=\s*['\"]([^'\"]+)['\"]", tag, flags=re.I)
        content = re.search(r"content\s*=\s*['\"]([^'\"]*)['\"]", tag, flags=re.I | re.S)
        if name and content and name.group(1).lower() in {
            "description", "og:description", "twitter:description"
        }:
            text = _clean_text(content.group(1))
            if len(text) > 40:
                return text
    return ""


def fetch_article_context(url: str) -> str:
    """Best-effort article context extraction; fall back to the RSS excerpt."""
    try:
        response = requests.get(url, headers=UA, timeout=18)
        response.raise_for_status()
        document = response.text[:2_500_000]
    except Exception as exc:
        print(f"   ℹ️ Article body unavailable: {str(exc)[:100]}")
        return ""

    # Prefer schema.org articleBody when the publisher exposes it.
    for match in re.finditer(
        r"<script\b[^>]*type=['\"]application/ld\+json['\"][^>]*>(.*?)</script>",
        document, flags=re.I | re.S,
    ):
        try:
            data = json.loads(html.unescape(match.group(1).strip()))
        except Exception:
            continue
        descriptions = []
        for node in _walk_json(data):
            body = node.get("articleBody")
            if isinstance(body, str):
                text = _clean_text(body)
                if len(text) > 250:
                    return text[:MAX_ARTICLE_CHARS]
            description = node.get("description")
            if isinstance(description, str) and len(description) > 250:
                descriptions.append(_clean_text(description))
        if descriptions:
            return descriptions[0][:MAX_ARTICLE_CHARS]

    # Otherwise take readable paragraphs, not page chrome.
    parser = ParagraphExtractor()
    try:
        parser.feed(document)
    except Exception:
        pass
    paragraphs = []
    for paragraph in parser.paragraphs:
        if paragraph not in paragraphs:
            paragraphs.append(paragraph)
        if sum(len(p) for p in paragraphs) >= MAX_ARTICLE_CHARS:
            break
    article_text = " ".join(paragraphs)
    if len(article_text) > 250:
        return article_text[:MAX_ARTICLE_CHARS]

    return _extract_meta_description(document)[:MAX_ARTICLE_CHARS]


def build_candidates(groups, state):
    seen = set(state.get("seen_story_keys", []))
    seen_titles = state.get("seen_story_titles", [])
    output = []
    for group in groups:
        if group["key"] in seen:
            continue
        items = group["items"]
        primary = items[0]
        if any(_title_similarity(primary["title"], old_title) >= 0.78
               for old_title in seen_titles if isinstance(old_title, str)):
            continue
        article_context = fetch_article_context(primary["url"])
        rss_context = primary.get("summary", "")
        if len(article_context) >= MIN_AI_CONTEXT_CHARS:
            context = article_context
            context_source = "publisher article page"
        elif len(rss_context) >= MIN_AI_CONTEXT_CHARS:
            context = rss_context
            context_source = "RSS excerpt (article page was too short/unavailable)"
        else:
            print(
                f"   ⏭️ Insufficient source context ({len(article_context)} article / "
                f"{len(rss_context)} RSS chars; need {MIN_AI_CONTEXT_CHARS}); "
                f"skipping: {primary['title'][:90]}"
            )
            continue
        story_id = f"story_{len(output) + 1}"
        output.append({
            "id": story_id,
            "story_key": group["key"],
            "topic": group.get("topic") or primary.get("topic"),
            "headline": primary["title"],
            "published_ist": primary["published"].strftime("%Y-%m-%d %H:%M IST"),
            "source": primary["source"],
            "source_url": primary["url"],
            "source_urls": [item["url"] for item in items],
            "other_coverage": [
                {"source": item["source"], "headline": item["title"], "url": item["url"]}
                for item in items[1:3]
            ],
            "reported_context": context[:MAX_ARTICLE_CHARS],
            "context_source": context_source,
            "context_chars": len(context[:MAX_ARTICLE_CHARS]),
        })
        if len(output) >= MAX_CANDIDATES:
            break
    return output


def make_prompt(candidates):
    public_candidates = []
    for item in candidates:
        public_candidates.append({
            "id": item["id"],
            "topic": item.get("topic"),
            "headline": item["headline"],
            "published_ist": item["published_ist"],
            "source": item["source"],
            "other_coverage": [
                {"source": related.get("source"), "headline": related.get("headline")}
                for related in item.get("other_coverage", [])
            ],
            "context_source": item.get("context_source", "source article context"),
            "context_chars": item.get("context_chars", len(item["reported_context"])),
            "reported_context": item["reported_context"],
        })
    payload = json.dumps(public_candidates, ensure_ascii=False, separators=(",", ":"))
    return f"""You are the business-news editor for a Hindi/Hinglish Telegram channel for Indian retail traders. The channel wants useful, current company/business context—not generic textbook lessons and not stock tips.

CURRENT TIME: {NOW.strftime('%Y-%m-%d %H:%M IST')}

Choose ONE distinct, unseen story from the supplied candidate list with clear reader value. Only choose factual news directly about the economy, capital markets, or stock markets, including a listed-company development when it materially relates to those areas. Prefer policy/regulation, macro data, IPO/subscription/listing mechanics, market structure, financing/debt, or verified company actions such as major orders, contracts, capex and acquisitions. Do NOT choose financial results/earnings, opinion or editorial pieces, analyst/broker commentary, recommendations, forecasts, target prices, rumours, generic market-wrap filler, or repeated coverage/update stories. Do not choose a story already posted in an earlier hourly slot. If nothing is strong enough, return skip=true.

Write an original educational Telegram post in natural Hinglish, mostly Roman script (about 160–220 words). This must teach the reader how to interpret THIS news—not just repeat the headline, and not paste a generic trading lesson. Use these parts:
1. 📰 Kya hua: the essential reported facts.
2. 🧩 News ko kaise padhein: explain the relevant number/term/structure (for example order win vs revenue recognition, fresh issue vs OFS, debt repayment, subscription vs listing gain) only when relevant to this story.
3. 💡 Business mein iska matlab: explain the business mechanism and why it could matter to the company, sector, market liquidity, or economy. Tie the lesson to the supplied facts.
4. 🔭 Aage kya dekhein: name concrete follow-up events/metrics and, where useful, explain conditional scenarios (“agar X dikhe toh…; agar Y ho toh…”). No confident prediction.
5. End with one thoughtful reader question.

Separate reported fact from interpretation. Explain what the news does NOT prove when relevant (e.g. an IPO subscription figure is not a guaranteed listing gain; an announced MoU is not automatically a firm order). Keep it specific and practical for an Indian market reader.

STRICT RULES:
- Each candidate includes the context source and context length. Use the article context—not just the headline. If the supplied context does not support a meaningful, story-specific explanation, return skip=true rather than padding with generic content.
- Use company-specific facts and numbers ONLY from the supplied story's reported_context/headline. Do not invent figures, dates, company relationships, causes, or future outcomes. A numeric grounding check will reject unsupported digits.
- General business concepts may be explained in your own words, but never present an unverified company-specific effect as fact.
- No broker/analyst recommendations, buy/sell/subscribe calls, target prices, entry/stop-loss levels, guaranteed gains, or price predictions. Do not use grey-market premium as a signal.
- Do not copy source sentences. Paraphrase; do not reproduce long excerpts.
- Do not invent an “official source” if the link is a news publisher.
- Do not include source URLs or disclaimer in the body; the script adds credited links and a disclaimer.

Return ONLY valid JSON with these keys:
{{"skip": false, "selected_story_id": "story_1", "headline": "Short factual Hinglish headline", "body": "News-specific explanation with interpretation, mechanism, follow-up and one question"}}

If skipping, return:
{{"skip": true, "reason": "short reason"}}

STORIES:
{payload}
"""


def _call_gemini(prompt):
    if not GEMINI_KEYS:
        return None
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.35, "responseMimeType": "application/json"},
    }
    for model in GEMINI_MODELS:
        for key in GEMINI_KEYS:
            for attempt in range(2):
                try:
                    response = requests.post(
                        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}",
                        json=payload,
                        headers={"Content-Type": "application/json"},
                        timeout=90,
                    )
                except Exception as exc:
                    print(f"   ⚠️ Gemini network error: {str(exc)[:100]}")
                    time.sleep(3)
                    continue
                if response.status_code == 200:
                    try:
                        return response.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                    except Exception:
                        print("   ⚠️ Gemini returned an unexpected response")
                        break
                if response.status_code == 404:
                    print(f"   ℹ️ Gemini model {model} unavailable; trying fallback")
                    break
                if response.status_code in (429, 500, 503):
                    time.sleep(4 * (attempt + 1))
                    continue
                print(f"   ⚠️ Gemini HTTP {response.status_code}: {response.text[:160]}")
                break
    return None


def _call_groq(prompt):
    if not GROQ_KEYS:
        return None
    payload = {
        "model": GROQ_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.35,
        "response_format": {"type": "json_object"},
    }
    for key in GROQ_KEYS:
        try:
            response = requests.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
                json=payload,
                timeout=90,
            )
        except Exception as exc:
            print(f"   ⚠️ Groq network error: {str(exc)[:100]}")
            continue
        if response.status_code == 200:
            try:
                return response.json()["choices"][0]["message"]["content"].strip()
            except Exception:
                continue
        print(f"   ⚠️ Groq HTTP {response.status_code}: {response.text[:160]}")
    return None


def call_ai(prompt):
    raw = _call_gemini(prompt)
    if raw:
        return raw
    print("   🔁 Gemini unavailable; trying Groq fallback")
    return _call_groq(prompt)


def parse_ai_json(raw):
    if not raw:
        return None
    cleaned = raw.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.I)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start < 0 or end <= start:
        return None
    try:
        return json.loads(cleaned[start:end + 1])
    except json.JSONDecodeError:
        return None


def _numeric_tokens(text: str):
    return {value.replace(",", "") for value in re.findall(r"\d+(?:,\d{3})*(?:\.\d+)?", text or "")}


def validate_draft(draft, candidates):
    if not isinstance(draft, dict) or draft.get("skip"):
        reason = draft.get("reason", "AI decided no story meets the quality bar") if isinstance(draft, dict) else "AI output was not valid JSON"
        print(f"   ⏭️ No post created: {reason}")
        return None
    allowed = {item["id"] for item in candidates}
    story_id = str(draft.get("selected_story_id", ""))
    title = _clean_text(str(draft.get("headline", "")))
    body = str(draft.get("body", "")).strip()
    if story_id not in allowed:
        print("   ⚠️ AI selected a story not in the supplied source list; rejecting")
        return None
    if len(title) < 8 or len(title) > 130 or len(body) < 450 or len(body) > 2500:
        print("   ⚠️ AI draft length/title outside safe limits; rejecting")
        return None
    unsafe = re.compile(
        r"\b(?:buy|sell)\s+(?:this\s+|the\s+)?(?:stocks?|shares?|now|above|below|at|on\s+dips|on\s+rise)\b|"
        r"\bsubscribe\s+(?:to\s+)?(?:this\s+|the\s+)?(?:ipo|issue|offer)\b|"
        r"\b(?:investor|trader)s?\s+should\s+(?:buy|sell|subscribe)\b|"
        r"\b(?:target|entry|stop[- ]?loss|sl)\s*[:=\-]\s*₹?\s*\d+|"
        r"\b(?:price\s+target|target\s+price|buy\s+call|sell\s+call|buy\s+recommendation|sell\s+recommendation|strong\s+buy|strong\s+sell)\b|"
        r"\bguaranteed\s+(?:return|profit|gain)\b",
        re.I,
    )
    if unsafe.search(title + "\n" + body):
        print("   ⚠️ AI draft contains a direct trading call/level; rejecting")
        return None
    selected = next(item for item in candidates if item["id"] == story_id)
    source_text = " ".join([
        selected.get("headline", ""),
        selected.get("reported_context", ""),
        selected.get("published_ist", ""),
        json.dumps([
            {"source": item.get("source"), "headline": item.get("headline")}
            for item in selected.get("other_coverage", [])
        ], ensure_ascii=False),
    ])
    unsupported_numbers = _numeric_tokens(title + "\n" + body) - _numeric_tokens(source_text)
    if unsupported_numbers:
        print(f"   ⚠️ AI draft introduced numbers absent from source: {sorted(unsupported_numbers)}; rejecting")
        return None
    return {"story_id": story_id, "title": title, "body": body}


def _alpha_id(seed: str) -> str:
    """Letters-only ID so content_generator's numeric ID counter is unaffected."""
    raw = hashlib.sha256(seed.encode("utf-8")).digest()[:10]
    return "news" + "".join(chr(ord("a") + (byte % 26)) for byte in raw)


def _source_html(name: str, url: str) -> str:
    safe_name = html.escape(name, quote=True)
    safe_url = html.escape(url, quote=True)
    return f'<a href="{safe_url}">{safe_name}</a>'


def render_post(draft, candidates):
    selected = next(item for item in candidates if item["id"] == draft["story_id"])
    sources = [{"source": selected["source"], "url": selected["source_url"]}]
    for item in selected.get("other_coverage", []):
        if item.get("source") and item.get("url") and all(item["url"] != src["url"] for src in sources):
            sources.append({"source": item["source"], "url": item["url"]})
        if len(sources) >= 2:
            break

    links = " · ".join(_source_html(src["source"], src["url"]) for src in sources)
    title = html.escape(draft["title"], quote=False)
    body = html.escape(draft["body"], quote=False)
    text = (
        f"📊 <b>{title}</b>\n\n{body}\n\n"
        f"🔗 Source: {links}\n"
        "🤖 <i>AI-assisted analysis of public business news.</i>\n"
        "⚠️ <i>Educational only. Not investment advice. Not SEBI registered.</i>"
    )
    return text[:3900], selected


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as file:
            return json.load(file)
    except FileNotFoundError:
        return default
    except Exception as exc:
        raise ValueError(f"{path} is invalid JSON; refusing to overwrite it") from exc


def save_json(path, data):
    temp_path = path + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=2)
        file.write("\n")
    os.replace(temp_path, path)


def write_preview_report(
    feed_result, groups, candidates, draft, ai_status, write_summary=True,
    ai_requested=False, ai_provider_configured=False,
):
    top_stories = []
    for group in groups[:20]:
        items = group.get("items", [])
        if not items:
            continue
        primary = items[0]
        top_stories.append({
            "headline": primary["title"],
            "topic": group.get("topic"),
            "source": primary["source"],
            "published_ist": primary["published"].strftime("%Y-%m-%d %H:%M IST"),
            "url": primary["url"],
            "rss_summary": primary.get("summary", "")[:900],
            "screening_score": round(group.get("score", 0), 2),
            "other_coverage": [
                {"source": item["source"], "headline": item["title"], "url": item["url"]}
                for item in items[1:4]
            ],
        })

    selected = None
    ai_preview = None
    if draft and candidates:
        selected = next((item for item in candidates if item["id"] == draft["story_id"]), None)
        if selected:
            ai_preview = {
                "headline": draft["title"],
                "body": draft["body"],
                "source": selected["source"],
                "source_url": selected["source_url"],
                "other_sources": selected.get("other_coverage", [])[:2],
            }

    report = {
        "generated_at_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "preview_only": True,
        "telegram_sent": False,
        "queue_changed": False,
        "archive_changed": False,
        "lookback_hours": 12,
        "feed_status": feed_result.get("status", {}),
        "filters_applied": [
            "Only economy, capital-market and stock-market headlines retained",
            "Company financial results and earnings stories excluded",
            "Opinions, analyst/broker commentary, forecasts, recommendations and price targets excluded",
            "Generic market wraps and repeated/near-duplicate coverage excluded",
        ],
        "screened_story_count": len(groups),
        "top_stories": top_stories,
        "minimum_ai_context_chars": MIN_AI_CONTEXT_CHARS,
        "ai_preview_requested": bool(ai_requested),
        "ai_provider_configured": bool(ai_provider_configured),
        "context_sent_to_ai": bool(ai_requested and ai_provider_configured and candidates),
        "ai_source_context_check": [
            {
                "headline": item.get("headline", ""),
                "source": item.get("source", ""),
                "context_source": item.get("context_source", "unknown"),
                "context_chars": item.get("context_chars", len(item.get("reported_context", ""))),
            }
            for item in candidates
        ],
        "ai_status": ai_status,
        "ai_educational_draft": ai_preview,
    }
    json_path = os.environ.get("NEWS_PREVIEW_JSON", "business_news_preview.json")
    md_path = os.environ.get("NEWS_PREVIEW_MARKDOWN", "business_news_preview.md")
    save_json(json_path, report)

    lines = [
        "# Business-news preview (no Telegram post)",
        f"Generated: {report['generated_at_ist']}",
        "",
        "## RSS feed check",
    ]
    for source, status in report["feed_status"].items():
        fresh_count = status.get("fresh_items", 0)
        accepted_count = status.get("accepted_items", fresh_count)
        filtered_count = status.get("filtered_items", max(0, fresh_count - accepted_count))
        code = status.get("http_status") or "unavailable"
        lines.append(
            f"- **{source}:** {accepted_count} in-scope / {fresh_count} recent "
            f"({filtered_count} filtered); HTTP {code}"
        )
    lines.extend([
        "",
        "## Filters applied",
        "- Only economy, capital-market and stock-market stories are retained.",
        "- Financial results/earnings, opinions, forecasts, analyst/broker commentary, recommendations and price targets are excluded.",
        "- Generic market wraps and repeated/near-duplicate coverage are collapsed.",
        "",
        f"## Screened stories ({len(top_stories)} shown; {len(groups)} groups)",
    ])
    if top_stories:
        for index, story in enumerate(top_stories, 1):
            lines.append(
                f"{index}. **{story['headline']}** — {story.get('topic') or 'in scope'}; "
                f"{story['source']}, {story['published_ist']} "
                f"(screen score {story['screening_score']})"
            )
            lines.append(f"   Source: {story['url']}")
            if story.get("rss_summary"):
                lines.append(f"   RSS: {story['rss_summary']}")
    else:
        lines.append("No recent eligible stories were returned by the feeds.")

    lines.extend([
        "",
        f"## Source-context check ({len(candidates)} AI-eligible candidates)",
        f"- Minimum context required: {MIN_AI_CONTEXT_CHARS} characters.",
        f"- Context sent to AI: {'Yes' if report['context_sent_to_ai'] else 'No'}.",
    ])
    if candidates:
        for candidate in candidates:
            lines.append(
                f"- **{candidate['headline']}** — {candidate['context_source']}; "
                f"{candidate['context_chars']} chars"
            )
    elif ai_status == "AI preview disabled by selection":
        lines.append("Article pages were checked locally, but no context was sent to an AI because AI preview was off.")
    elif not ai_provider_configured:
        lines.append("Article pages were checked locally, but no AI provider key is configured; nothing was sent to an AI.")
    elif groups:
        lines.append(f"No story met the {MIN_AI_CONTEXT_CHARS}-character source-context minimum; no AI draft was made.")
    else:
        lines.append("No eligible story was available to inspect for an AI draft.")

    lines.extend(["", f"## AI draft status: {ai_status}"])
    if ai_preview:
        lines.extend([
            "",
            f"### {ai_preview['headline']}",
            "",
            ai_preview["body"],
            "",
            f"Source: {ai_preview['source_url']}",
            "",
            "This is a preview only. It was not added to the production queue or sent to Telegram.",
        ])
    else:
        lines.extend(["", "No AI post was created for this preview run."])

    markdown = "\n".join(lines) + "\n"
    with open(md_path, "w", encoding="utf-8") as file:
        file.write(markdown)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if write_summary:
        if summary_path:
            with open(summary_path, "a", encoding="utf-8") as summary:
                summary.write(markdown)
        else:
            print(markdown)
    print(f"📎 Preview files created: {json_path}, {md_path}; no production files changed")


def current_queue_slot():
    """Stamp the current hourly posting window; the queue consumer sends it now."""
    when = NOW.replace(minute=0, second=0, microsecond=0)
    return f"H{NOW.hour:02d}", when


def add_to_queue(queue, draft, candidates):
    text, selected = render_post(draft, candidates)
    items = queue.setdefault("queue", [])
    item_id = _alpha_id(selected["source_url"] + "|" + selected["story_key"])
    if any(item.get("id") == item_id
           or item.get("source_url") == selected["source_url"]
           or item.get("story_key") == selected["story_key"]
           or (item.get("source_headline") and
               _title_similarity(selected["headline"], item["source_headline"]) >= 0.78)
           for item in items):
        print("   ℹ️ This story is already in the content queue; not adding a duplicate")
        return False, None

    slot, when = current_queue_slot()
    item = {
        "id": item_id,
        "slot": slot,
        "hourly_slot_ist": when.strftime("%Y-%m-%d %H:%M"),
        "scheduled_ist": when.strftime("%Y-%m-%d %H:%M"),
        "title": draft["title"][:80],
        "text": text,
        "used": False,
        "topic_key": "business_news_insight:" + selected["story_key"][:12],
        "kind": "business_news_insight",
        "source_name": selected["source"],
        "source_url": selected["source_url"],
        "source_headline": selected["headline"],
        "story_key": selected["story_key"],
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
    }
    items.append(item)
    items.sort(key=lambda value: value.get("scheduled_ist", "9999"))
    queue["total"] = len(items)
    queue["last_scheduled"] = items[-1].get("scheduled_ist") if items else None
    return True, item


def _update_news_state(state, slot_key, selected):
    state.setdefault("generated_slots", [])
    state["generated_slots"] = (state["generated_slots"] + [slot_key])[-180:]
    if selected:
        state.setdefault("seen_story_keys", [])
        state["seen_story_keys"] = (state["seen_story_keys"] + [selected["story_key"]])[-500:]
        state.setdefault("seen_story_titles", [])
        state["seen_story_titles"] = (state["seen_story_titles"] + [selected["headline"]])[-500:]
        state["last_story_title"] = selected["headline"][:160]
        state["last_story_url"] = selected["source_url"]
    state["last_generated_at"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")


def run_archive_only():
    """Fetch publisher RSS feeds and persist only the deduplicated news archive."""
    archive = load_json(ARCHIVE_FILE, {"stories": []})
    if not isinstance(archive, dict) or not isinstance(archive.get("stories", []), list):
        print("❌ News archive has an unexpected schema; refusing to overwrite it")
        return 1

    feed_result = fetch_feeds()
    if not feed_result.get("any_success"):
        print("❌ All RSS feeds unavailable; existing archive left unchanged")
        return 1

    archive, added_count, _ = merge_archive(archive, feed_result)
    save_json(ARCHIVE_FILE, archive)
    stats = archive.get("last_run_stats", {})
    print(
        f"🗃️ Archive saved to {ARCHIVE_FILE}: {len(archive.get('stories', []))} stories total; "
        f"{added_count} new unique stories, {stats.get('duplicate_items_collapsed', 0)} duplicates collapsed, "
        f"{stats.get('filtered_feed_items', 0)} feed items filtered"
    )
    return 0


def main():
    mode = (sys.argv[1].strip().lower() if len(sys.argv) > 1 else "hourly") or "hourly"
    if mode not in {"archive", "hourly", "process", "preview", "dry-run"}:
        print("Usage: python daily_business_news.py [archive|hourly|process|preview]")
        return 2

    set_action_output("post_ready", False)
    print("=" * 72)
    heading = "BUSINESS NEWS RSS ARCHIVE" if mode == "archive" else "BUSINESS NEWS → EDUCATIONAL INSIGHT"
    print(f"📰 {heading} | {NOW.strftime('%d-%b-%Y %H:%M IST')}")
    print(f"Mode: {mode} | Archive: {ARCHIVE_FILE} | Queue: {QUEUE_FILE}")
    print("=" * 72)

    if mode == "archive":
        return run_archive_only()

    if mode in {"preview", "dry-run"}:
        want_ai = os.environ.get("NEWS_PREVIEW_AI", "true").strip().lower() not in {"false", "0", "no"}
        has_ai_provider = bool(GEMINI_KEYS or GROQ_KEYS)
        feed_result = fetch_feeds()
        if not feed_result["any_success"]:
            write_preview_report(
                feed_result, [], [], None, "Feed fetch failed",
                ai_requested=want_ai, ai_provider_configured=has_ai_provider,
            )
            return 0
        preview_cutoff = NOW - timedelta(hours=POST_CANDIDATE_MAX_AGE_HOURS)
        preview_items = [item for item in feed_result["items"]
                         if preview_cutoff <= item["published"] <= NOW + timedelta(hours=2)]
        preview_groups = group_stories(preview_items)
        preview_candidates = []
        preview_draft = None
        if preview_groups:
            # Always audit publisher context for the strongest stories. If AI is
            # off, this is a local read-only check only; no text is sent to a model.
            preview_candidates = build_candidates(
                preview_groups,
                {"seen_story_keys": [], "seen_story_titles": []},
            )
        if not want_ai:
            ai_status = "AI preview disabled by selection"
        elif not has_ai_provider:
            ai_status = "No AI key configured; source-context audit only"
        elif preview_groups and preview_candidates:
            raw = call_ai(make_prompt(preview_candidates))
            parsed = parse_ai_json(raw)
            if isinstance(parsed, dict) and parsed.get("skip"):
                ai_status = "Quality gate skipped: " + str(parsed.get("reason", "no suitable story"))[:120]
            elif not raw:
                ai_status = "AI provider unavailable; raw news preview only"
            else:
                preview_draft = validate_draft(parsed, preview_candidates)
                ai_status = "Draft preview generated" if preview_draft else "Draft rejected by source/recommendation checks"
        elif preview_groups:
            ai_status = f"No story met the {MIN_AI_CONTEXT_CHARS}-character source-context minimum"
        else:
            ai_status = "No fresh candidate in the preview window"
        write_preview_report(
            feed_result, preview_groups, preview_candidates, preview_draft, ai_status,
            ai_requested=want_ai, ai_provider_configured=has_ai_provider,
        )
        return 0

    state = load_json(STATE_FILE, {
        "generated_slots": [], "seen_story_keys": [], "seen_story_titles": []
    })
    if (not isinstance(state, dict)
            or not isinstance(state.get("generated_slots", []), list)
            or not isinstance(state.get("seen_story_keys", []), list)
            or not isinstance(state.get("seen_story_titles", []), list)):
        print("❌ News state has an unexpected schema; no queue changes made")
        return 1

    archive = load_json(ARCHIVE_FILE, {"stories": []})
    if not isinstance(archive, dict) or not isinstance(archive.get("stories", []), list):
        print("❌ News archive has an unexpected schema; refusing to overwrite it")
        return 1

    queue = load_json(QUEUE_FILE, {"queue": []})
    if not isinstance(queue, dict) or not isinstance(queue.get("queue"), list):
        print("❌ content_queue.json has an unexpected schema; refusing to overwrite it")
        return 1

    previous_scraped_at = _parse_archive_time(archive.get("last_scraped_at"))
    feed_result = fetch_feeds()
    archive, added_count, new_or_updated_urls = merge_archive(archive, feed_result)
    archive = reconcile_archive_with_queue(archive, queue)

    # Scheduled hourly runs persist every fresh RSS item, even when no post is
    # suitable. Dry-run is deliberately read-only.
    save_json(ARCHIVE_FILE, archive)
    stats = archive.get("last_run_stats", {})
    print(
        f"🗃️ Archive now contains {len(archive.get('stories', []))} curated stories; "
        f"{added_count} new unique, {stats.get('duplicate_items_collapsed', 0)} duplicates collapsed"
    )

    in_window = NOW.hour in POSTING_HOURS_IST
    pending_due = in_window and has_due_news(queue)
    if not feed_result["any_success"]:
        print("❌ All RSS feeds unavailable; archive status saved, no post this hour")
        set_action_output("post_ready", pending_due)
        return 1

    if not in_window:
        print("ℹ️ Outside the 4–9 PM IST posting window: archive updated; no post queued")
        return 0

    slot_key = NOW.strftime("%Y-%m-%d %H")
    if slot_key in state.get("generated_slots", []):
        print("ℹ️ This hourly slot was already processed; preventing a duplicate post")
        set_action_output("post_ready", pending_due)
        return 0

    candidate_items = archive_to_items(archive, previous_scraped_at, new_or_updated_urls)
    groups = group_stories(candidate_items)
    candidates = build_candidates(groups, state)
    if not candidates:
        print("ℹ️ No new, fresh story passed the educational-value/source-detail filters; skipping this hour")
        set_action_output("post_ready", pending_due)
        return 0

    if not GEMINI_KEYS and not GROQ_KEYS:
        print("❌ No Gemini/Google or Groq API key is configured; archive saved, no post queued")
        return 1

    raw = call_ai(make_prompt(candidates))
    parsed = parse_ai_json(raw)
    if not raw:
        print("❌ AI provider unavailable; stories remain archived for the next hourly retry")
        set_action_output("post_ready", pending_due)
        return 1

    if isinstance(parsed, dict) and parsed.get("skip"):
        for candidate in candidates:
            mark_archive_group(archive, candidate, "rejected")
        save_json(ARCHIVE_FILE, archive)
        reason = str(parsed.get("reason", "no candidate had enough reader value"))[:160]
        print(f"⏭️ AI quality gate: {reason}; skipping this hour, no filler post")
        set_action_output("post_ready", pending_due)
        return 0

    draft = validate_draft(parsed, candidates)
    if not draft:
        print("⏭️ Draft failed source/number/recommendation checks; skipping this hour")
        set_action_output("post_ready", pending_due)
        return 0

    rendered, selected = render_post(draft, candidates)
    print("\n--- EDUCATIONAL NEWS POST ---\n")
    print(re.sub(r"<[^>]+>", "", rendered))
    print(f"\nSelected: {selected['headline']} | Source: {selected['source']}")

    added, item = add_to_queue(queue, draft, candidates)
    if added:
        mark_archive_group(archive, selected, "queued", item["id"])
        save_json(QUEUE_FILE, queue)
        print(f"✅ Queued {item['id']} for the {item['scheduled_ist']} IST hourly slot")
    else:
        existing = next((q for q in queue["queue"]
                         if q.get("source_url") == selected["source_url"]
                         or q.get("story_key") == selected["story_key"]), None)
        if existing:
            mark_archive_group(archive, selected, "queued", existing.get("id"))
        print("ℹ️ Existing queue item found; no duplicate item added")

    _update_news_state(state, slot_key, selected)
    save_json(STATE_FILE, state)
    save_json(ARCHIVE_FILE, archive)

    ready = in_window and (added or has_due_news(queue))
    set_action_output("post_ready", ready)
    if ready:
        print("📨 Existing Telegram poster will handle delivery; no direct Telegram send from this script.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
