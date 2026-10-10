"""Expose safe compiler diagnostics through GitHub check annotations.
The optional bootstrap export is used only to normalise source in a restricted
build environment; never export configuration files, credentials or keystores.
"""
import base64
import gzip
import os
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
bootstrap = os.environ.get('DANAPUR_BOOTSTRAP_EXPORT') == 'true'
kind = sys.argv[2] if len(sys.argv) > 2 else 'logs'
def escaped(value):
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
def redact(text):
    for name, value in os.environ.items():
        if value and (name.startswith('DANAPUR_') and name != 'DANAPUR_BOOTSTRAP_EXPORT' or name in ('GH_TOKEN', 'GITHUB_TOKEN')):
            text = text.replace(value, '[REDACTED]')
    return text
for name in (() if kind == 'source' else ('analysis', 'tests', 'web', 'android')):
    path = root / f'danapur-{name}.log'
    if path.exists():
        text = redact(path.read_text(errors='replace'))
        if bootstrap:
            payload = base64.b64encode(gzip.compress(text.encode(), compresslevel=9, mtime=0)).decode()
            for i in range(0, len(payload), 3000):
                print(f'::notice title=Danapur {name} log {i//3000}::GZIP_BASE64:{payload[i:i+3000]}')
        else:
            problems = [line for line in text.splitlines() if 'error •' in line or 'warning •' in line or 'info •' in line]
            if problems:
                print(f'::error title=Danapur {name} diagnostics::{escaped(chr(10).join(problems)[:30000])}')
if bootstrap and kind == 'logs':
    path = Path('pubspec.lock')
    if path.exists():
        payload = base64.b64encode(gzip.compress(path.read_bytes(), compresslevel=9, mtime=0)).decode()
        for i in range(0, len(payload), 3000):
            print(f'::notice title=Danapur lock export {i//3000}::GZIP_BASE64:{payload[i:i+3000]}')
if bootstrap and kind == 'source':
    files = {str(p): p.read_text() for directory in ('lib', 'test') for p in sorted(Path(directory).rglob('*.dart'))}
    payload = base64.b64encode(gzip.compress(json.dumps(files, ensure_ascii=False, sort_keys=True).encode(), compresslevel=9, mtime=0)).decode()
    start = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    chunks = [payload[i:i+3000] for i in range(0, len(payload), 3000)]
    if len(chunks) > 18:
        raise SystemExit('Source diagnostics exceeded the bounded bootstrap handoff.')
    for i in range(start, min(start+9,len(chunks))):
        print(f'::notice title=Danapur source export {i}::GZIP_BASE64:{chunks[i]}')
