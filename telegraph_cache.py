"""Content-aware cache helpers for Telegraph pages stored in telegraph_state.json."""

import hashlib
import json


def page_content_hash(title, text):
    """Return a stable fingerprint so a reused post ID cannot reuse stale page content."""
    payload = json.dumps(
        {"title": str(title or ""), "text": str(text or "")},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def find_cached_page(state, page_id, title, text):
    """Return a cached URL only when its recorded content matches this exact draft."""
    published = state.get("published", {}) if isinstance(state, dict) else {}
    entry = published.get(page_id) if isinstance(published, dict) else None
    if not isinstance(entry, dict) or not isinstance(entry.get("url"), str):
        return None
    if not entry["url"] or entry.get("content_hash") != page_content_hash(title, text):
        return None
    return entry["url"]


def remember_page(state, page_id, title, text, url, kind, at):
    """Store the page URL together with its fingerprint for safe reuse."""
    if not isinstance(state, dict):
        raise TypeError("Telegraph state must be a dictionary")
    published = state.setdefault("published", {})
    if not isinstance(published, dict):
        raise TypeError("Telegraph state 'published' must be a dictionary")
    published[page_id] = {
        "url": url,
        "kind": kind,
        "at": at,
        "title": str(title or "")[:256],
        "content_hash": page_content_hash(title, text),
    }
