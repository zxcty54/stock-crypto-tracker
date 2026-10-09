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
    "1. Month/Period. "
    "2. Key Headline Growth & Volumes (Cement, Steel, Cargo, Toll). "
    "3. Macro/Sector Signals. "
    "Never hallucinate. State 'Not available' if missing."
)

def make_prompt(fname, data):
    content_str = json.dumps(data, ensure_ascii=False)
    return (
        f"Analyze this raw data from '{fname}':\n\n"
        f"```json\n{content_str}\n```\n\n"
        "Provide: Month, Key Metrics (exact numbers), "
        "Observations, and Economic Signal (Bullish/Neutral/Weak)."
    )

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
    summaries = {}
    md_lines = [
        "# Macro Telemetry Executive Briefing\n",
        f"**Date:** {NOW.strftime('%d-%b-%Y %H:%M IST')}\n",
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
            summaries[name] = {"summary": text}
            md_lines.append(f"## {name}\n\n{text}\n\n---\n")
            print("  Done.")
        except Exception as err:
            summaries[name] = {"error": str(err)}
            print(f"  Error: {err}")

        if i < total:
            print(f"  Sleeping {BREAK_SEC}s...")
            time.sleep(BREAK_SEC)

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(summaries, f, indent=2)

    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines))

    print("Finished.")

if __name__ == "__main__":
    run()
