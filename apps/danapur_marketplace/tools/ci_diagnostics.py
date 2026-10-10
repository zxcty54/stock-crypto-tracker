"""Publish concise, credential-redacted failure context to GitHub checks."""
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
def escaped(value):
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
def redact(text):
    for name, value in os.environ.items():
        if value and (name.startswith('DANAPUR_') or name in ('GH_TOKEN', 'GITHUB_TOKEN')):
            text = text.replace(value, '[REDACTED]')
    return text
for name in ('analysis', 'tests', 'web', 'android'):
    path = root / f'danapur-{name}.log'
    if not path.exists():
        continue
    text = redact(path.read_text(errors='replace'))
    problems = [line for line in text.splitlines() if 'error •' in line or 'warning •' in line or 'info •' in line]
    if problems:
        detail = '\n'.join(problems)
    elif any(marker in text for marker in ('::error::', 'Test failed.', 'FAILURE: Build failed', 'Error:')):
        detail = '\n'.join(text.splitlines()[-45:])
    else:
        continue
    for start in range(0, len(detail), 3000):
        print(f'::error title=Danapur {name} diagnostics::{escaped(detail[start:start+3000])}')
