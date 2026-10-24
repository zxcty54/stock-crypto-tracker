#!/usr/bin/env python3
"""Hourly business news â†’ educational insight â†’ existing Telegram queue.

Each run archives fresh RSS metadata to business_news_archive.json. During the
16:00â€“21:00 IST window it may add one source-linked, news-based explainer to
content_queue.json. The existing Telegram poster publishes it; this script
never sends a Telegram message. If no fresh, useful story is available, it
skips that hour rather than inventing filler.
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
    "ipo", "q1", "q2", "q3", "q4", "results", "earnings", "profit", "loss",
    "revenue", "guidance", "outlook", "rbi", "sebi", "policy", "rate", "tariff",
    "debt", "capex", "order", "acquisition", "merger", "buyback", "dividend",
    "liquidity", "fundraise", "funding", "default", "npa", "crude", "rupee",
    "export", "import", "regulation", "approval", "capacity", "market share",
    "subscription", "listing", "layoff", "restructuring", "withdrawal", "investment",
)

# Exclude broker calls and generic stock-pick headlines. The goal is business
# context, not a buy/sell recommendation or a recycled tips post.
EXCLUDE_TERMS = (
    "broker", "analyst", "recommendation", "recommended", "stocks to buy", "stock to buy",
    "stocks to sell", "stock to sell", "should you buy", "should you sell",
    "top stocks to buy", "buy call", "sell call", "target price", "price target",
    "buy rating", "sell rating", "buy on dips", "sell on rise", "stocks to watch today",
    "top pick", "stock pick", "prefers", "overweight", "underweight", "upgrades",
    "downgrades", "rating upgrade", "rating downgrade", "recommends",
    "accumulate", "outperform", "underperform", "top brokerage pick",
)

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
        print(f"   âš ï¸ RSS parse error ({source['name']}): {exc}")
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


def _item_score(item):
    title = item["title"].lower()
    if any(term in title for term in EXCLUDE_TERMS):
        return -100
    score = item["source_priority"]
    score += sum(2 for term in POSITIVE_TERMS if term in title)
    if len(item.get("summary", "")) > 120:
        score += 2
    age_hours = max(0, (NOW - item["published"]).total_seconds() / 3600)
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


def group_stories(items):
    """Combine near-identical cross-publisher headlines into one story."""
    groups = []
    for item in sorted(items, key=lambda x: (x["published"], _item_score(x)), reverse=True):
        if _item_score(item) < 0:
            continue
        match = None
        for group in groups:
            if _title_similarity(item["title"], group["items"][0]["title"]) >= 0.70:
                match = group
                break
        if match:
            if all(item["url"] != old["url"] for old in match["items"]):
                match["items"].append(item)
        else:
            story_key = hashlib.sha256((item["url"] + "|" + item["title"].lower()).encode()).hexdigest()
            groups.append({"key": story_key, "items": [item]})

    for group in groups:
        group["items"].sort(key=lambda x: (x["source_priority"], x["published"]), reverse=True)
        group["score"] = max(_item_score(item) for item in group["items"]) + min(3, len(group["items"]) - 1) * 1.5
    groups.sort(key=lambda x: (x["score"], x["items"][0]["published"]), reverse=True)
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
            feed_status[source["name"]] = {
                "checked_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
                "http_status": response.status_code,
                "fresh_items": len(fresh),
                "error": None,
            }
            print(f"   ðŸ“° {source['name']}: {len(fresh)} fresh items")
            all_items.extend(fresh)
        except Exception as exc:
            feed_status[source["name"]] = {
                "checked_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
                "http_status": None,
                "fresh_items": 0,
                "error": str(exc)[:160],
            }
            print(f"   âš ï¸ Feed unavailable ({source['name']}): {str(exc)[:120]}")
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


def merge_archive(archive, feed_result):
    """Append/update RSS metadata in the archive; never store full article text."""
    if not isinstance(archive, dict) or not isinstance(archive.get("stories", []), list):
        raise ValueError("business_news_archive.json has an unexpected schema")

    stories = archive.setdefault("stories", [])
    by_url = {item.get("url"): item for item in stories if isinstance(item, dict) and item.get("url")}
    added = 0
    new_or_updated_urls = set()
    for feed_item in feed_result["items"]:
        url = feed_item["url"]
        published_at = feed_item["published"].isoformat()
        record = by_url.get(url)
        if record:
            now_iso = NOW.isoformat()
            record.setdefault("first_seen_at", now_iso)
            record["last_seen_at"] = now_iso
            record["last_seen_ist"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
            old_published = _parse_archive_time(record.get("published_at"))
            if old_published and feed_item["published"] > old_published:
                record["published_at"] = published_at
                record["published_ist"] = feed_item["published"].strftime("%Y-%m-%d %H:%M IST")
                record["headline"] = feed_item["title"]
                new_or_updated_urls.add(url)
            if feed_item.get("summary"):
                summary = feed_item["summary"][:900]
                if summary != record.get("summary", ""):
                    record["summary"] = summary
                    # A materially updated feed excerpt can represent new information.
                    new_or_updated_urls.add(url)
            continue
        record = {
            "id": _alpha_id(url),
            "source": feed_item["source"],
            "source_priority": feed_item["source_priority"],
            "headline": feed_item["title"],
            "url": url,
            "published_at": published_at,
            "published_ist": feed_item["published"].strftime("%Y-%m-%d %H:%M IST"),
            "summary": feed_item.get("summary", "")[:900],
            "first_seen_at": NOW.isoformat(),
            "last_seen_at": NOW.isoformat(),
            "first_seen_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            "last_seen_ist": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
            "status": "new",
        }
        stories.append(record)
        by_url[url] = record
        added += 1
        new_or_updated_urls.add(url)

    retention_cutoff = NOW - timedelta(days=ARCHIVE_RETENTION_DAYS)
    retained = []
    for item in stories:
        published = _parse_archive_time(item.get("published_at")) if isinstance(item, dict) else None
        if published is None or published >= retention_cutoff:
            retained.append(item)
    retained.sort(key=lambda item: item.get("published_at", ""), reverse=True)
    archive["stories"] = retained[:ARCHIVE_MAX_ITEMS]
    archive["last_scraped_at"] = NOW.isoformat()
    archive["last_scraped_ist"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    archive["feed_status"] = feed_result["status"]
    archive["retention_days"] = ARCHIVE_RETENTION_DAYS
    return archive, added, new_or_updated_urls


def archive_to_items(archive, previous_scraped_at=None, fresh_urls=None):
    """Return only unprocessed stories from the latest hourly polling interval.

    The first run in the 4â€“9 PM window gets a wider same-day lookback. Later
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
        print(f"   â„¹ï¸ Article body unavailable: {str(exc)[:100]}")
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
        context = fetch_article_context(primary["url"])
        if not context:
            context = primary.get("summary", "")
        if len(context) < 100:
            print(f"   â­ï¸ Insufficient source detail; skipping: {primary['title'][:90]}")
            continue
        story_id = f"story_{len(output) + 1}"
        output.append({
            "id": story_id,
            "story_key": group["key"],
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
        })
        if len(output) >= MAX_CANDIDATES:
            break
    return output


def make_prompt(candidates):
    public_candidates = []
    for item in candidates:
        public_candidates.append({
            "id": item["id"],
            "headline": item["headline"],
            "published_ist": item["published_ist"],
            "source": item["source"],
            "other_coverage": [
                {"source": related.get("source"), "headline": related.get("headline")}
                for related in item.get("other_coverage", [])
            ],
            "reported_context": item["reported_context"],
        })
    payload = json.dumps(public_candidates, ensure_ascii=False, separators=(",", ":"))
    return f"""You are the business-news editor for a Hindi/Hinglish Telegram channel for Indian retail traders. The channel wants useful, current company/business contextâ€”not generic textbook lessons and not stock tips.

CURRENT TIME: {NOW.strftime('%Y-%m-%d %H:%M IST')}

Choose ONE distinct, unseen story from the supplied candidate list with clear reader value. Prefer material company/business events, results, IPO mechanics, policy/regulation, financing/debt, capex/orders, or macro changes with a concrete business link. Skip brokerage opinion, broker/analyst buy-sell calls, targets, rumours, generic market-wrap filler, and stories too thin to explain. Do not choose a story already posted in an earlier hourly slot. If nothing is strong enough, return skip=true.

Write an original educational Telegram post in natural Hinglish, mostly Roman script (about 160â€“220 words). This must teach the reader how to interpret THIS newsâ€”not just repeat the headline, and not paste a generic trading lesson. Use these parts:
1. ðŸ“° Kya hua: the essential reported facts.
2. ðŸ§© News ko kaise padhein: explain the key number/term/structure (for example YoY vs QoQ, revenue vs profit, order win vs revenue recognition, fresh issue vs OFS, debt repayment, subscription vs listing gain) only when relevant to this story.
3. ðŸ’¡ Business mein iska matlab: explain the business mechanism and why it could matter to the company, sector, market liquidity, or economy. Tie the lesson to the supplied facts.
4. ðŸ”­ Aage kya dekhein: name concrete follow-up metrics/events and, where useful, explain conditional scenarios (â€œagar X dikhe tohâ€¦; agar Y ho tohâ€¦â€). No confident prediction.
5. End with one thoughtful reader question.

Separate reported fact from interpretation. Explain what the news does NOT prove when relevant (e.g. strong demand is not a guaranteed listing gain; one quarter is not automatically a long-term trend). Keep it specific and practical for an Indian market reader.

STRICT RULES:
- Use company-specific facts and numbers ONLY from the supplied story's reported_context/headline. Do not invent figures, dates, company relationships, causes, or future outcomes. A numeric grounding check will reject unsupported digits.
- General business concepts may be explained in your own words, but never present an unverified company-specific effect as fact.
- No broker/analyst recommendations, buy/sell/subscribe calls, target prices, entry/stop-loss levels, guaranteed gains, or price predictions. Do not use grey-market premium as a signal.
- Do not copy source sentences. Paraphrase; do not reproduce long excerpts.
- Do not invent an â€œofficial sourceâ€ if the link is a news publisher.
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
                    print(f"   âš ï¸ Gemini network error: {str(exc)[:100]}")
                    time.sleep(3)
                    continue
                if response.status_code == 200:
                    try:
                        return response.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                    except Exception:
                        print("   âš ï¸ Gemini returned an unexpected response")
                        break
                if response.status_code == 404:
                    print(f"   â„¹ï¸ Gemini model {model} unavailable; trying fallback")
                    break
                if response.status_code in (429, 500, 503):
                    time.sleep(4 * (attempt + 1))
                    continue
                print(f"   âš ï¸ Gemini HTTP {response.status_code}: {response.text[:160]}")
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
            print(f"   âš ï¸ Groq network error: {str(exc)[:100]}")
            continue
        if response.status_code == 200:
            try:
                return response.json()["choices"][0]["message"]["content"].strip()
            except Exception:
                continue
        print(f"   âš ï¸ Groq HTTP {response.status_code}: {response.text[:160]}")
    return None


def call_ai(prompt):
    raw = _call_gemini(prompt)
    if raw:
        return raw
    print("   ðŸ” Gemini unavailable; trying Groq fallback")
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
        print(f"   â­ï¸ No post created: {reason}")
        return None
    allowed = {item["id"] for item in candidates}
    story_id = str(draft.get("selected_story_id", ""))
    title = _clean_text(str(draft.get("headline", "")))
    body = str(draft.get("body", "")).strip()
    if story_id not in allowed:
        print("   âš ï¸ AI selected a story not in the supplied source list; rejecting")
        return None
    if len(title) < 8 or len(title) > 130 or len(body) < 450 or len(body) > 2500:
        print("   âš ï¸ AI draft length/title outside safe limits; rejecting")
        return None
    unsafe = re.compile(
        r"\b(?:buy|sell)\s+(?:this\s+|the\s+)?(?:stocks?|shares?|now|above|below|at|on\s+dips|on\s+rise)\b|"
        r"\bsubscribe\s+(?:to\s+)?(?:this\s+|the\s+)?(?:ipo|issue|offer)\b|"
        r"\b(?:investor|trader)s?\s+should\s+(?:buy|sell|subscribe)\b|"
        r"\b(?:target|entry|stop[- ]?loss|sl)\s*[:=\-]\s*â‚¹?\s*\d+|"
        r"\b(?:price\s+target|target\s+price|buy\s+call|sell\s+call|buy\s+recommendation|sell\s+recommendation|strong\s+buy|strong\s+sell)\b|"
        r"\bguaranteed\s+(?:return|profit|gain)\b",
        re.I,
    )
    if unsafe.search(title + "\n" + body):
        print("   âš ï¸ AI draft contains a direct trading call/level; rejecting")
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
        print(f"   âš ï¸ AI draft introduced numbers absent from source: {sorted(unsupported_numbers)}; rejecting")
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

    links = " Â· ".join(_source_html(src["source"], src["url"]) for src in sources)
    title = html.escape(draft["title"], quote=False)
    body = html.escape(draft["body"], quote=False)
    text = (
        f"ðŸ“Š <b>{title}</b>\n\n{body}\n\n"
        f"ðŸ”— Source: {links}\n"
        "ðŸ¤– <i>AI-assisted analysis of public business news.</i>\n"
        "âš ï¸ <i>Educational only. Not investment advice. Not SEBI registered.</i>"
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


def write_preview_report(feed_result, groups, candidates, draft, ai_status, write_summary=True):
    top_stories = []
    for group in groups[:20]:
        items = group.get("items", [])
        if not items:
            continue
        primary = items[0]
        top_stories.append({
            "headline": primary["title"],
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
        "screened_story_count": len(groups),
        "top_stories": top_stories,
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
        count = status.get("fresh_items", 0)
        code = status.get("http_status") or "unavailable"
        lines.append(f"- **{source}:** {count} recent items; HTTP {code}")
    lines.extend(["", f"## Screened stories ({len(top_stories)} shown; {len(groups)} groups)"])
    if top_stories:
        for index, story in enumerate(top_stories, 1):
            lines.append(
                f"{index}. **{story['headline']}** â€” {story['source']}, "
                f"{story['published_ist']} (screen score {story['screening_score']})"
            )
            lines.append(f"   Source: {story['url']}")
            if story.get("rss_summary"):
                lines.append(f"   RSS: {story['rss_summary']}")
    else:
        lines.append("No recent eligible stories were returned by the feeds.")

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
    print(f"ðŸ“Ž Preview files created: {json_path}, {md_path}; no production files changed")


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
        print("   â„¹ï¸ This story is already in the content queue; not adding a duplicate")
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


def main():
    mode = (sys.argv[1].strip().lower() if len(sys.argv) > 1 else "hourly") or "hourly"
    if mode not in {"hourly", "process", "preview", "dry-run"}:
        print("Usage: python daily_business_news.py [hourly|process|preview]")
        return 2

    set_action_output("post_ready", False)
    print("=" * 72)
    print(f"ðŸ“° BUSINESS NEWS â†’ EDUCATIONAL INSIGHT | {NOW.strftime('%d-%b-%Y %H:%M IST')}")
    print(f"Mode: {mode} | Archive: {ARCHIVE_FILE} | Queue: {QUEUE_FILE}")
    print("=" * 72)

    if mode in {"preview", "dry-run"}:
        feed_result = fetch_feeds()
        if not feed_result["any_success"]:
            write_preview_report(feed_result, [], [], None, "Feed fetch failed")
            return 0
        preview_cutoff = NOW - timedelta(hours=POST_CANDIDATE_MAX_AGE_HOURS)
        preview_items = [item for item in feed_result["items"]
                         if preview_cutoff <= item["published"] <= NOW + timedelta(hours=2)]
        preview_groups = group_stories(preview_items)
        preview_candidates = []
        preview_draft = None
        want_ai = os.environ.get("NEWS_PREVIEW_AI", "true").strip().lower() not in {"false", "0", "no"}
        ai_status = "No AI key configured; raw news preview only"
        if preview_groups:
            if not want_ai:
                preliminary_status = "AI preview disabled by selection"
            elif GEMINI_KEYS or GROQ_KEYS:
                preliminary_status = "AI draft pending"
            else:
                preliminary_status = "No AI key configured; raw news preview only"
            write_preview_report(feed_result, preview_groups, [], None, preliminary_status, write_summary=False)
        if preview_groups and not want_ai:
            ai_status = "AI preview disabled by selection"
        elif preview_groups and (GEMINI_KEYS or GROQ_KEYS):
            preview_candidates = build_candidates(
                preview_groups,
                {"seen_story_keys": [], "seen_story_titles": []},
            )
            if preview_candidates:
                raw = call_ai(make_prompt(preview_candidates))
                parsed = parse_ai_json(raw)
                if isinstance(parsed, dict) and parsed.get("skip"):
                    ai_status = "Quality gate skipped: " + str(parsed.get("reason", "no suitable story"))[:120]
                elif not raw:
                    ai_status = "AI provider unavailable; raw news preview only"
                else:
                    preview_draft = validate_draft(parsed, preview_candidates)
                    ai_status = "Draft preview generated" if preview_draft else "Draft rejected by source/recommendation checks"
            else:
                ai_status = "No article context was available for an AI draft"
        elif not preview_groups:
            ai_status = "No fresh candidate in the preview window"
        write_preview_report(feed_result, preview_groups, preview_candidates, preview_draft, ai_status)
        return 0

    state = load_json(STATE_FILE, {
        "generated_slots": [], "seen_story_keys": [], "seen_story_titles": []
    })
    if (not isinstance(state, dict)
            or not isinstance(state.get("generated_slots", []), list)
            or not isinstance(state.get("seen_story_keys", []), list)
            or not isinstance(state.get("seen_story_titles", []), list)):
        print("âŒ News state has an unexpected schema; no queue changes made")
        return 1

    archive = load_json(ARCHIVE_FILE, {"stories": []})
    if not isinstance(archive, dict) or not isinstance(archive.get("stories", []), list):
        print("âŒ News archive has an unexpected schema; refusing to overwrite it")
        return 1

    queue = load_json(QUEUE_FILE, {"queue": []})
    if not isinstance(queue, dict) or not isinstance(queue.get("queue"), list):
        print("âŒ content_queue.json has an unexpected schema; refusing to overwrite it")
        return 1

    previous_scraped_at = _parse_archive_time(archive.get("last_scraped_at"))
    feed_result = fetch_feeds()
    archive, added_count, new_or_updated_urls = merge_archive(archive, feed_result)
    archive = reconcile_archive_with_queue(archive, queue)

    # Scheduled hourly runs persist every fresh RSS item, even when no post is
    # suitable. Dry-run is deliberately read-only.
    save_json(ARCHIVE_FILE, archive)
    print(f"ðŸ—ƒï¸ Archive now contains {len(archive.get('stories', []))} items; {added_count} new URLs this run")

    in_window = NOW.hour in POSTING_HOURS_IST
    pending_due = in_window and has_due_news(queue)
    if not feed_result["any_success"]:
        print("âŒ All RSS feeds unavailable; archive status saved, no post this hour")
        set_action_output("post_ready", pending_due)
        return 1

    if not in_window:
        print("â„¹ï¸ Outside the 4â€“9 PM IST posting window: archive updated; no post queued")
        return 0

    slot_key = NOW.strftime("%Y-%m-%d %H")
    if slot_key in state.get("generated_slots", []):
        print("â„¹ï¸ This hourly slot was already processed; preventing a duplicate post")
        set_action_output("post_ready", pending_due)
        return 0

    candidate_items = archive_to_items(archive, previous_scraped_at, new_or_updated_urls)
    groups = group_stories(candidate_items)
    candidates = build_candidates(groups, state)
    if not candidates:
        print("â„¹ï¸ No new, fresh story passed the educational-value/source-detail filters; skipping this hour")
        set_action_output("post_ready", pending_due)
        return 0

    if not GEMINI_KEYS and not GROQ_KEYS:
        print("âŒ No Gemini/Google or Groq API key is configured; archive saved, no post queued")
        return 1

    raw = call_ai(make_prompt(candidates))
    parsed = parse_ai_json(raw)
    if not raw:
        print("âŒ AI provider unavailable; stories remain archived for the next hourly retry")
        set_action_output("post_ready", pending_due)
        return 1

    if isinstance(parsed, dict) and parsed.get("skip"):
        for candidate in candidates:
            mark_archive_group(archive, candidate, "rejected")
        save_json(ARCHIVE_FILE, archive)
        reason = str(parsed.get("reason", "no candidate had enough reader value"))[:160]
        print(f"â­ï¸ AI quality gate: {reason}; skipping this hour, no filler post")
        set_action_output("post_ready", pending_due)
        return 0

    draft = validate_draft(parsed, candidates)
    if not draft:
        print("â­ï¸ Draft failed source/number/recommendation checks; skipping this hour")
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
        print(f"âœ… Queued {item['id']} for the {item['scheduled_ist']} IST hourly slot")
    else:
        existing = next((q for q in queue["queue"]
                         if q.get("source_url") == selected["source_url"]
                         or q.get("story_key") == selected["story_key"]), None)
        if existing:
            mark_archive_group(archive, selected, "queued", existing.get("id"))
        print("â„¹ï¸ Existing queue item found; no duplicate item added")

    _update_news_state(state, slot_key, selected)
    save_json(STATE_FILE, state)
    save_json(ARCHIVE_FILE, archive)

    ready = in_window and (added or has_due_news(queue))
    set_action_output("post_ready", ready)
    if ready:
        print("ðŸ“¨ Existing Telegram poster will handle delivery; no direct Telegram send from this script.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())