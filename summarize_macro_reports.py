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
    "You are a strict, forensic econometrician and macroeconomic auditor specializing in Indian physical telemetry. "
    "Your mandate is to extract, juxtapose, and audit raw telemetry data with 100% mathematical fidelity.\n\n"
    "CRITICAL ZERO-TOLERANCE RULES AGAINST HALLUCINATION:\n"
    "1. ABSOLUTE TRUTH ANCHOR: You must rely SOLELY on the explicit numbers, tokens, and table cells provided in the input payload. "
    "NEVER guess, estimate, back-calculate, interpolate, or extrapolate any figure.\n"
    "2. STRICT NULL ENFORCEMENT: If any data point, metric, growth rate (YoY/MoM/FYTD), or volume is not explicitly mentioned "
    "or is ambiguous in the raw text/table, YOU MUST OUTPUT 'null'. It is STRICTLY FORBIDDEN to fill missing fields with assumed data.\n"
    "3. DO NOT FABRICATE BENCHMARKS: If the document does not contain prior-year periods, revisions, or cumulative weights, "
    "do NOT retrieve them from memory or historical assumptions. Write 'null'.\n"
    "4. UNIT INTEGRITY: Maintain exact numerical values and units as reported (e.g., Million Tonnes, TEUs, Index Points, INR Crore)."
)

def make_prompt(fname, data):
    content_str = json.dumps(data, ensure_ascii=False)
    return (
        f"Perform an exhaustive, forensic macroeconomic audit of the raw data extracted from: '{fname}'.\n\n"
        "STRICT CONSTRAINT: If any field, metric, comparison, or cell is missing in the raw payload, output 'null'. Do not infer or invent numbers.\n\n"
        f"RAW TELEMETRY PAYLOAD:\n```json\n{content_str}\n```\n\n"
        "STRUCTURE YOUR FORENSIC REPORT UNDER THESE EXACT HEADINGS:\n\n"
        "### 1. METADATA & HEADLINE ANCHORS\n"
        "- **Report Title & Issuing Body:** [Exact name, or 'null']\n"
        "- **Reporting Period:** [Exact month and year, or 'null']\n"
        "- **Aggregate Headline Metric:** [Primary aggregate figure, or 'null']\n"
        "- **Comparison Anchors (Preserve exact values; write 'null' if absent):**\n"
        "  * Current Month YoY Growth (%): [Value or null]\n"
        "  * Current Month MoM Sequential Growth (%): [Value or null]\n"
        "  * Cumulative FYTD Growth (%): [Value or null]\n"
        "- **Revisions Delta:** [State previous month revision delta if reported, else 'null']\n\n"
        "### 2. EXHAUSTIVE COMPONENT-LEVEL AUDIT TABLE\n"
        "Construct a Markdown comparison table strictly for the sub-components present in the raw input (e.g., Coal, Cement, Steel for Core; Commodity categories for Ports; Toll statistics for FASTag).\n"
        "Rule: If an attribute is missing for any row, the cell value MUST BE 'null'.\n\n"
        "| Sector / Sub-Component | Weight (%) | Current Period Physical Volume / Index | YoY Growth (%) | MoM Change (%) | Cumulative FYTD Growth (%) | Data Grounding / Context |\n"
        "|---|---|---|---|---|---|---|\n"
        "| [Name] | [Value or null] | [Value or null] | [Value or null] | [Value or null] | [Value or null] | [Source statement or null] |\n\n"
        "### 3. EMPIRICAL OBSERVATIONS & DIVERGENCE\n"
        "- **Top Growth Drivers:** [List sectors with confirmed positive growth in source, or 'null']\n"
        "- **Key Drags & Contractions:** [List sectors with confirmed decline in source, or 'null']\n"
        "- **Infrastructure Momentum:** [Direct physical evidence on Cement, Steel, or Freight, or 'null']\n\n"
        "### 4. MACROECONOMIC AUDIT VERDICT\n"
        "- **Institutional Activity Signal:** [State exactly one: EXPANSION / NEUTRAL / CONTRACTION / INSUFFICIENT DATA based strictly on source numbers]\n"
        "- **Empirical Thesis:** [Maximum 2 concise sentences synthesizing only verified metrics. Zero speculation.]\n"
    )

def load_existing_history():
    if not os.path.exists(OUT_JSON):
        return {"latest": {}, "history": []}
    try:
        with open(OUT_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, dict) and "history" in data:
                return data
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
                    temperature=0.0,
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

    master_archive = load_existing_history()
    snapshot = {
        "timestamp": NOW.strftime("%Y-%m-%d %H:%M IST"),
        "date_code": NOW.strftime("%Y-%m"),
        "reports": current_run_summaries
    }

    master_archive["latest"] = snapshot

    history_list = master_archive.get("history", [])
    updated = False
    for idx, entry in enumerate(history_list):
        if entry.get("date_code") == snapshot["date_code"]:
            history_list[idx] = snapshot
            updated = True
            break

    if not updated:
        history_list.insert(0, snapshot)

    master_archive["history"] = history_list

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(master_archive, f, ensure_ascii=False, indent=2)

    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines))

    print(f"\n🎉 Saved successfully! Total historical snapshots in archive: {len(history_list)}")

if __name__ == "__main__":
    run()
