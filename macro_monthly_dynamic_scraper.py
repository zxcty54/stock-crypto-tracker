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

# ============================================================
# HELPER: SECURE DOWNLOAD & TEXT PREVIEW
# ============================================================

def download_and_extract_summary(session, url, filename_prefix):
    if not url:
        return None, ""
    try:
        resp = session.get(url, headers=COMMON_HEADERS, timeout=40, verify=False)
        if resp.status_code == 200 and resp.content.startswith(b'%PDF'):
            filepath = os.path.join(OUTPUT_DIR, f"{filename_prefix}.pdf")
            with open(filepath, "wb") as f:
                f.write(resp.content)
            
            preview_text = ""
            if pdfplumber:
                with pdfplumber.open(io.BytesIO(resp.content)) as pdf:
                    first_pages = [p.extract_text() or "" for p in pdf.pages[:2]]
                    preview_text = " ".join(" ".join(first_pages).split())[:1200]
            
            print(f"   💾 Downloaded: {filepath} ({len(resp.content) // 1024} KB)")
            return filepath, preview_text
        else:
            print(f"   ⚠️ PDF download failed for {url} (HTTP {resp.status_code})")
    except Exception as e:
        print(f"   ❌ Download error: {e}")
    return None, ""

# ============================================================
# 1. IPA (Indian Ports Association) — Traffic Month Report
# ============================================================

def scrape_ipa_latest(session):
    print("\n⚓ [1/4] Scraping IPA Ports Monthly Traffic Report...")
    base_url = "https://ipa.org.in"
    target_url = "https://ipa.org.in/reports-statistics"
    
    result = {
        "title": None,
        "pdf_url": None,
        "local_path": None,
        "preview_text": ""
    }
    
    try:
        resp = session.get(target_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            
            # Pattern: "Traffic Month of <Month> <Year>" ya "Traffic <Month> <Year>"
            pattern = re.compile(r'traffic\s+(?:month\s+of\s+)?([A-Za-z]+)\s+(\d{4})', re.IGNORECASE)
            
            candidate_links = []
            for a in soup.find_all("a", href=True):
                text = " ".join(a.get_text().split())
                href = a['href']
                match = pattern.search(text)
                if match and (".pdf" in href.lower() or "download" in href.lower() or "report" in href.lower()):
                    candidate_links.append({
                        "title": text,
                        "url": urljoin(base_url, href)
                    })
            
            # Sabse top/latest entry select karein
            if candidate_links:
                selected = candidate_links[0]
                result["title"] = selected["title"]
                result["pdf_url"] = selected["url"]
                print(f"   🔗 Found: {result['title']}")
                print(f"   🌐 Link : {result['pdf_url']}")
                
                path, prev = download_and_extract_summary(session, result["pdf_url"], "IPA_Traffic_Latest")
                result["local_path"] = path
                result["preview_text"] = prev
            else:
                # Fallback: Find first PDF inside reports section
                for a in soup.find_all("a", href=True):
                    if ".pdf" in a['href'].lower() and "traffic" in a['href'].lower():
                        result["title"] = a.get_text().strip() or "IPA Traffic Report"
                        result["pdf_url"] = urljoin(base_url, a['href'])
                        path, prev = download_and_extract_summary(session, result["pdf_url"], "IPA_Traffic_Latest")
                        result["local_path"] = path
                        result["preview_text"] = prev
                        break
    except Exception as e:
        print(f"   ❌ IPA Scraper Error: {e}")
        
    return result

# ============================================================
# 2. DPIIT — Eight Core Industries Press Note PDF
# ============================================================

def scrape_eight_core_latest(session):
    print("\n🏭 [2/4] Scraping DPIIT Eight Core Industries PDF...")
    base_url = "https://eaindustry.nic.in"
    target_url = "https://eaindustry.nic.in/eight_core_infra/"
    
    result = {
        "title": None,
        "pdf_url": None,
        "local_path": None,
        "preview_text": ""
    }
    
    try:
        resp = session.get(target_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            
            # Directory listing ya links me se sabse naya .pdf dhoondhna
            found_pdfs = []
            for a in soup.find_all("a", href=True):
                href = a['href']
                text = " ".join(a.get_text().split())
                if href.lower().endswith(".pdf"):
                    found_pdfs.append({
                        "title": text or os.path.basename(href),
                        "url": urljoin(target_url, href)
                    })
            
            if found_pdfs:
                # Latest release typically tops the list or matches 'press' / current year
                selected = found_pdfs[0]
                for p in found_pdfs:
                    if "press" in p["title"].lower() or "eight" in p["title"].lower() or str(NOW.year) in p["title"]:
                        selected = p
                        break
                        
                result["title"] = selected["title"]
                result["pdf_url"] = selected["url"]
                print(f"   🔗 Found: {result['title']}")
                print(f"   🌐 Link : {result['pdf_url']}")
                
                path, prev = download_and_extract_summary(session, result["pdf_url"], "DPIIT_Eight_Core_Latest")
                result["local_path"] = path
                result["preview_text"] = prev
    except Exception as e:
        print(f"   ❌ Eight Core Scraper Error: {e}")
        
    return result

# ============================================================
# 3. DPIIT — Wholesale Price Index (WPI) Press Release PDF
# ============================================================

def scrape_wpi_latest(session):
    print("\n📈 [3/4] Scraping DPIIT WPI (Wholesale Price Index) PDF...")
    base_url = "https://eaindustry.nic.in"
    archive_url = "https://eaindustry.nic.in/"
    
    result = {
        "title": None,
        "pdf_url": None,
        "local_path": None,
        "preview_text": ""
    }
    
    try:
        resp = session.get(archive_url, headers=COMMON_HEADERS, timeout=25, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            
            # Pattern: press_release_YYYYMM.pdf ya anchor text me "WPI" / "Press Release"
            wpi_pdf_link = None
            
            for a in soup.find_all("a", href=True):
                href = a['href']
                text = a.get_text().lower()
                if "press_release_" in href.lower() and href.lower().endswith(".pdf"):
                    wpi_pdf_link = urljoin(base_url, href)
                    result["title"] = a.get_text().strip() or os.path.basename(href)
                    break
            
            # Fallback direct generation agar page dynamically update na ho
            if not wpi_pdf_link:
                # WPI 1 month lag ke sath aata hai
                prev_month = NOW.replace(day=1) - timedelta(days=1)
                month_str = prev_month.strftime("%Y%m")
                candidate_url = f"https://eaindustry.nic.in/press_release/press_release_{month_str}.pdf"
                
                test_resp = session.head(candidate_url, headers=COMMON_HEADERS, timeout=15, verify=False)
                if test_resp.status_code == 200:
                    wpi_pdf_link = candidate_url
                    result["title"] = f"WPI Press Release {prev_month.strftime('%B %Y')}"
            
            if wpi_pdf_link:
                result["pdf_url"] = wpi_pdf_link
                print(f"   🔗 Found: {result['title']}")
                print(f"   🌐 Link : {result['pdf_url']}")
                
                path, prev = download_and_extract_summary(session, result["pdf_url"], "DPIIT_WPI_Latest")
                result["local_path"] = path
                result["preview_text"] = prev
    except Exception as e:
        print(f"   ❌ WPI Scraper Error: {e}")
        
    return result

# ============================================================
# 4. MoSPI — Index of Industrial Production (IIP) Latest Release
# ============================================================

def scrape_mospi_iip_latest(session):
    print("\n🏭 [4/4] Scraping MoSPI IIP (Index of Industrial Production) PDF...")
    base_url = "https://www.mospi.gov.in"
    target_url = "https://www.mospi.gov.in/themes/product/54-index-of-industrial-production"
    
    result = {
        "title": None,
        "pdf_url": None,
        "local_path": None,
        "preview_text": ""
    }
    
    try:
        resp = session.get(target_url, headers=COMMON_HEADERS, timeout=30, verify=False)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            
            # Target 1: Check section with id="latest-release"
            latest_block = soup.find(id="latest-release") or soup.find("div", class_=re.compile(r'latest[-_]release', re.I))
            
            selected_link = None
            selected_title = None
            
            search_scope = latest_block if latest_block else soup
            
            pattern = re.compile(r'Quick Estimates of Index of Industrial Production.*?(?:Month of)?\s*([A-Za-z]+)\s*(\d{4})?', re.IGNORECASE)
            
            for a in search_scope.find_all("a", href=True):
                href = a['href']
                text = " ".join(a.get_text().split())
                
                # Match title text or uploads path
                if (pattern.search(text) or "iip press release" in text.lower() or "iip" in href.lower()) and href.lower().endswith(".pdf"):
                    selected_link = urljoin(base_url, href)
                    selected_title = text or "MoSPI IIP Press Release"
                    break
            
            if selected_link:
                result["title"] = selected_title
                result["pdf_url"] = selected_link
                print(f"   🔗 Found: {result['title']}")
                print(f"   🌐 Link : {result['pdf_url']}")
                
                path, prev = download_and_extract_summary(session, result["pdf_url"], "MoSPI_IIP_Latest")
                result["local_path"] = path
                result["preview_text"] = prev
            else:
                print("   ⚠️ No matching IIP anchor tag found on MoSPI page.")
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
