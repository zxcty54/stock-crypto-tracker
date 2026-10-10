"""Temporary read-only recovery of a new public dependency lock; no artifacts."""
import base64
from pathlib import Path
import subprocess

path = Path('pubspec.lock')
current = path.read_bytes()
prior = subprocess.run(['git','show','HEAD:apps/danapur_marketplace/pubspec.lock'],check=True,capture_output=True).stdout
if current != prior:
    encoded = base64.b64encode(current).decode()
    for index,start in enumerate(range(0,len(encoded),3000)):
        print(f'::notice title=Danapur dependency lock {index:03d}::{encoded[start:start+3000]}')
    raise SystemExit('New public dependency lock resolved; commit the emitted lock before the verified build.')
