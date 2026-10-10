"""Expose safe compiler diagnostics through GitHub check annotations.
The optional bootstrap export is used only to normalise source in a restricted
build environment; never export configuration files, credentials or keystores.
"""
import base64
import gzip
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
bootstrap = os.environ.get('DANAPUR_BOOTSTRAP_EXPORT') == 'true'
def escaped(value):
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
def redact(text):
    for name, value in os.environ.items():
        if value and (name.startswith('DANAPUR_') and name != 'DANAPUR_BOOTSTRAP_EXPORT' or name in ('GH_TOKEN', 'GITHUB_TOKEN')):
            text = text.replace(value, '[REDACTED]')
    return text
for name in ('analysis', 'tests', 'web', 'android'):
    path = root / f'danapur-{name}.log'
    if path.exists():
        text = redact(path.read_text(errors='replace'))
        if bootstrap:
            payload = base64.b64encode(gzip.compress(text.encode())).decode()
            for i in range(0, len(payload), 30000):
                print(f'::notice title=Danapur {name} log {i//30000}::GZIP_BASE64:{payload[i:i+30000]}')
        else:
            problems = [line for line in text.splitlines() if 'error •' in line or 'warning •' in line or 'info •' in line]
            if problems:
                print(f'::error title=Danapur {name} diagnostics::{escaped(chr(10).join(problems)[:30000])}')
if bootstrap:
    for name, path in [('format', root/'danapur-format.patch'), ('lock', Path('pubspec.lock'))]:
        if path.exists():
            payload = base64.b64encode(gzip.compress(path.read_bytes())).decode()
            for i in range(0, len(payload), 30000):
                print(f'::notice title=Danapur {name} export {i//30000}::GZIP_BASE64:{payload[i:i+30000]}')
