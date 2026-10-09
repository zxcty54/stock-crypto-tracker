import os
import json
import time
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

RAW_DUMP = "macro_raw_extracted_dump.json"
OUT_JSON = "macro_executive_ai_summary.json"
OUT_MD = "macro_executive_ai_summary.md"
MODEL_ID = "gemini-3.5-flash-lite"
BREAK_SEC = 15

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    raise ValueError("GEMINI_API_KEY missing.")

client = genai.Client(api_key=API_KEY)

SYS_INST = (
    "You are a macroeconomic analyst for Indian physical infrastructure. "
    "Analyze raw JSON telemetry and extract: "
    "1. Exact Reporting Month & Year (e.g., September 2026). "
    "2. Key Headline Growth & Volumes (Cement, Steel, Cargo, Toll). "
    "3. Macro/Sector Signals. "
    "Never hallucinate. State 'Not available' if missing."
)

def make_prompt(fname, data):
    content_str = json.dumps(data, ensure_ascii=False)
    return (
        f"Analyze this raw data from '{fname}':\n\n"
        f"```json\n{content_str}\n```\n\n"
        "Provide: Exact Reporting Month & Year, Key Metrics (exact numbers), "
        "Observations, and Economic Signal (Bullish/Neutral/Weak)."
    )

def load_existing_history():
    """Purani JSON history load karta hai taaki overwrite na ho."""
    if not os.path.exists(OUT_JSON):
        return {"latest": {}, "history": []}
    try:
        with open(OUT_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, dict) and "history" in data:
                return data
            # Agar purana format flat dict tha toh use migrate karein
            return {"latest": data, "history": [data]}
    except Exception:
        return {"latest": {}, "history": []}

def run():
    print(f"🚀 Summarizer started: {NOW.strftime('%Y-%m-%d %H:%M IST')}")

    if not os.path.exists(RAW_DUMP):
        print(f"File {RAW_DUMP} not found.")
        return

    with open(RAW_DUMP, "r", encoding="utf-8") as f:
        raw_obj = json.load(f)

    items = raw_obj.get("extracted_content", {})
    if not items:
        print("No content to summarize.")
        return

    total = len(items)
    current_run_summaries = {}
    
    md_lines = [
        "# Macro Telemetry Executive Briefing\n",
        f"**Run Date:** {NOW.strftime('%d-%b-%Y %H:%M IST')}\n",
        "---\n"
    ]

    for i, (name, payload) in enumerate(items.items(), 1):
        print(f"[{i}/{total}] Processing: {name}")
        prompt = make_prompt(name, payload)

        try:
            resp = client.models.generate_content(
                model=MODEL_ID,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=SYS_INST,
                    temperature=0.2,
                )
            )
            text = resp.text.strip()
            current_run_summaries[name] = {
                "summary": text,
                "extracted_at": NOW.strftime("%Y-%m-%d %H:%M IST")
            }
            md_lines.append(f"## {name}\n\n{text}\n\n---\n")
            print("  Done.")
        except Exception as err:
            current_run_summaries[name] = {"error": str(err)}
            print(f"  Error: {err}")

        if i < total:
            print(f"  Sleeping {BREAK_SEC}s...")
            time.sleep(BREAK_SEC)

    # ============================================================
    # HISTORICAL ARCHIVE LOGIC (NO OVERWRITE)
    # ============================================================
    master_archive = load_existing_history()

    # Naya snapshot record
    snapshot = {
        "timestamp": NOW.strftime("%Y-%m-%d %H:%M IST"),
        "date_code": NOW.strftime("%Y-%m"),
        "reports": current_run_summaries
    }

    # Latest pointer update karein
    master_archive["latest"] = snapshot

    # Duplicate check: agar same date_code already history me hai toh update karein, warna naya insert karein
    history_list = master_archive.get("history", [])
    updated = False
    for idx, entry in enumerate(history_list):
        if entry.get("date_code") == snapshot["date_code"]:
            history_list[idx] = snapshot
            updated = True
            break
    
    if not updated:
        # Latest record ko top par rakhna (descending chronological order)
        history_list.insert(0, snapshot)

    master_archive["history"] = history_list

    # Save to JSON
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(master_archive, f, ensure_ascii=False, indent=2)

    # Save latest Markdown briefing
    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines))

    print(f"\n🎉 Saved successfully! Total historical snapshots in archive: {len(history_list)}")

if __name__ == "__main__":
    run()
