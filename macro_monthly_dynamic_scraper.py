import os
import io
import re
import json
from datetime import datetime, timezone, timedelta
from urllib.parse import urljoin
from bs4 import BeautifulSoup
from curl_cffi import requests

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

OUTPUT_DIR = "downloaded_macro_pdfs"
METADATA_FILE = "macro_reports_manifest.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

COMMON_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9"
}

os.makedirs(OUTPUT_DIR, exist_ok=True)

def download_and_extract_summary(session, url, filename_prefix):
    if not url:
        return None, ""
    try:
        resp = session.get(url, headers=COMMON_HEADERS, timeout=45, verify=False)
        if resp.status_code == 200 and (resp.content.startswith(b'%PDF') or ".pdf" in url.lower()):
            filepath = os.path.join(OUTPUT_DIR, f"{filename_prefix}.pdf")
            with open(filepath, "wb") as f:
                f.write(resp.content)
            
            preview_text = ""
            if pdfplumber:
                try:
                    with pdfplumber.open(io.BytesIO(resp.content)) as pdf:
                        first_pages = [p.extract_text() or "" for p in pdf.pages[:2]]
                        preview_text = " ".join(" ".join(first_pages).split())[:1200]
                except Exception:
                    pass
            
            print(f"   💾 Downloaded: {filepath} ({len(resp.content) // 1024} KB)")
            return filepath, preview_text
        else:
            print(f"   ⚠️ PDF download failed for {url} (HTTP {resp.status_code})")
    except Exception as e:
        print(f"   ❌ Download error: {e}")
    return None, ""

# ============================================================
# 1. IPA — Indian Ports Association Traffic Report
# ============================================================

def scrape_ipa_latest(session):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    base_url = "https://ipa.org.in"
    target_urls = [
        "https://ipa.org.in/reports-statistics",
        "https://ipa.org.in/port-performance-report"
    ]
    
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}
    
    for t_url in target_urls:
        try:
            resp = session.get(t_url, headers=COMMON_HEADERS, timeout=25, verify=False)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                
                # Check all anchor tags containing .pdf or downloads
                for a in soup.find_all("a", href=True):
                    href = a['href'].strip()
                    text = " ".join(a.get_text().split()).lower()
                    parent_text = " ".join(a.parent.get_text().split()).lower() if a.parent else ""
                    combined = f"{text} {parent_text} {href.lower()}"
                    
                    if ".pdf" in href.lower() and ("traffic" in combined or "month" in combined or "performance" in combined):
                        result["title"] = a.get_text().strip() or "IPA Monthly Traffic Report"
                        result["pdf_url"] = urljoin(base_url, href)
                        break
            if result["pdf_url"]:
                break
        except Exception as e:
            print(f"   ⚠️ IPA crawl note: {e}")
            continue

    if result["pdf_url"]:
        print(f"   🔗 Found: {result['title']}")
        print(f"   🌐 Link : {result['pdf_url']}")
        path, prev = download_and_extract_summary(session, result["pdf_url"], "IPA_Traffic_Latest")
        result["local_path"] = path
        result["preview_text"] = prev
    else:
        print("   ❌ IPA: No matching Traffic Report link found.")

    return result

# ============================================================
# 2. DPIIT — Eight Core Industries Press Note PDF
# ============================================================

def scrape_eight_core_latest(session):
    print("\n🏭 [2/4] Scraping DPIIT Eight Core Industries PDF...")
    base_url = "https://eaindustry.nic.in"
    target_urls = [
        "https://eaindustry.nic.in/eight_core_infra/",
        "https://eaindustry.nic.in/"
    ]
    
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}
    
    for t_url in target_urls:
        try:
            resp = session.get(t_url, headers=COMMON_HEADERS, timeout=25, verify=False)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                
                # Collect all PDF links
                candidate_pdfs = []
                for a in soup.find_all("a", href=True):
                    href = a['href'].strip()
                    text = " ".join(a.get_text().split())
                    combined = f"{text.lower()} {href.lower()}"
                    
                    if href.lower().endswith(".pdf"):
                        # If inside eight_core directory or mentions core/infra
                        if "eight_core" in t_url or "core" in combined or "press" in combined or "infra" in combined:
                            candidate_pdfs.append({
                                "title": text or os.path.basename(href),
                                "url": urljoin(t_url, href)
                            })
                
                if candidate_pdfs:
                    # Select the latest file (most recent uploaded)
                    selected = candidate_pdfs[0]
                    # Filter for specific keywords if multiple
                    for c in candidate_pdfs:
                        if "press" in c["title"].lower() or "eight" in c["title"].lower() or "core" in c["title"].lower():
                            selected = c
                            break
                    result["title"] = selected["title"]
                    result["pdf_url"] = selected["url"]
                    break
        except Exception as e:
            print(f"   ⚠️ Eight Core crawl note: {e}")
            continue

    # Fallback to direct latest static release path
    if not result["pdf_url"]:
        fallback_link = "https://eaindustry.nic.in/pdf_files/Eight_Core_Infra.pdf"
        test = session.head(fallback_link, headers=COMMON_HEADERS, timeout=15, verify=False)
        if test.status_code == 200:
            result["title"] = "Index of Eight Core Industries"
            result["pdf_url"] = fallback_link

    if result["pdf_url"]:
        print(f"   🔗 Found: {result['title']}")
        print(f"   🌐 Link : {result['pdf_url']}")
        path, prev = download_and_extract_summary(session, result["pdf_url"], "DPIIT_Eight_Core_Latest")
        result["local_path"] = path
        result["preview_text"] = prev
    else:
        print("   ❌ DPIIT Eight Core: Link not found.")

    return result

# ============================================================
# 3. DPIIT — WPI Press Release PDF (Verified Working)
# ============================================================

def scrape_wpi_latest(session):
    print("\n📈 [3/4] Scraping DPIIT WPI (Wholesale Price Index) PDF...")
    base_url = "https://eaindustry.nic.in"
    target_url = "https://eaindustry.nic.in/"
    
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}
    
    try:
        resp = session.get(target_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            for a in soup.find_all("a", href=True):
                href = a['href'].strip()
                if "press_release_" in href.lower() and href.lower().endswith(".pdf"):
                    result["pdf_url"] = urljoin(base_url, href)
                    result["title"] = a.get_text().strip() or os.path.basename(href)
                    break

        if result["pdf_url"]:
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path, prev = download_and_extract_summary(session, result["pdf_url"], "DPIIT_WPI_Latest")
            result["local_path"] = path
            result["preview_text"] = prev
    except Exception as e:
        print(f"   ❌ WPI Scraper Error: {e}")
        
    return result

# ============================================================
# 4. MoSPI — Index of Industrial Production (IIP) Release
# ============================================================

def scrape_mospi_iip_latest(session):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    base_url = "https://www.mospi.gov.in"
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    
    result = {"title": None, "pdf_url": None, "local_path": None, "preview_text": ""}
    
    try:
        resp = session.get(target_url, headers=COMMON_HEADERS, timeout=30, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            
            # MoSPI files always upload to /uploads/latestreleasesfiles/ or have 'IIP' in url/text
            for a in soup.find_all("a", href=True):
                href = a['href'].strip()
                text = " ".join(a.get_text().split()).lower()
                
                # Check for IIP indicators in href or text
                is_iip_file = (
                    "iip" in href.lower() 
                    or "industrial-production" in href.lower() 
                    or "quick estimates" in text
                    or "iip press release" in text
                )
                
                if is_iip_file and (".pdf" in href.lower() or "latestreleasesfiles" in href.lower()):
                    result["title"] = a.get_text().strip() or "MoSPI IIP Press Release"
                    result["pdf_url"] = urljoin(base_url, href)
                    break
                    
        if result["pdf_url"]:
            print(f"   🔗 Found: {result['title']}")
            print(f"   🌐 Link : {result['pdf_url']}")
            path, prev = download_and_extract_summary(session, result["pdf_url"], "MoSPI_IIP_Latest")
            result["local_path"] = path
            result["preview_text"] = prev
        else:
            print("   ❌ MoSPI: No matching IIP PDF link found.")
    except Exception as e:
        print(f"   ❌ MoSPI Scraper Error: {e}")
        
    return result

# ============================================================
# MASTER ORCHESTRATOR
# ============================================================

def run_macro_document_crawler():
    print("=" * 80)
    print("🚀 DYNAMIC MACRO DOCUMENT SCRAPER & INGESTION PIPELINE")
    print(f"📅 Timestamp: {NOW.strftime('%Y-%m-%d %H:%M:%S IST')}")
    print("=" * 80)
    
    session = requests.Session(impersonate="chrome124")
    
    manifest = {
        "timestamp": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "reports": {
            "ipa_ports_traffic": scrape_ipa_latest(session),
            "dpiit_eight_core": scrape_eight_core_latest(session),
            "dpiit_wpi": scrape_wpi_latest(session),
            "mospi_iip": scrape_mospi_iip_latest(session)
        }
    }
    
    with open(METADATA_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        
    print("\n" + "=" * 80)
    print("✅ EXECUTION SUMMARY:")
    for key, val in manifest["reports"].items():
        status = "✅ Downloaded" if val["local_path"] else "❌ Failed"
        print(f"   • {key.upper():<20} : {status} | Link: {val['pdf_url']}")
    print(f"📁 Manifest Metadata saved to: '{METADATA_FILE}'")
    print(f"📂 PDFs Directory             : '{OUTPUT_DIR}/'")
    print("=" * 80)

if __name__ == "__main__":
    run_macro_document_crawler()
