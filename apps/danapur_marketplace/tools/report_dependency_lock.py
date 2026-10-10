"""One-off compressed public dependency-lock recovery. No credentials/artifacts."""
import base64
import gzip
import hashlib
from pathlib import Path

current = Path('pubspec.lock').read_bytes()
encoded = base64.b64encode(gzip.compress(current,compresslevel=9,mtime=0)).decode()
for index,start in enumerate(range(0,len(encoded),3000)):
    print(f'::notice title=Danapur compressed lock {index:03d}::{encoded[start:start+3000]}')
print('::notice title=Danapur lock checksum::'+hashlib.sha256(current).hexdigest())
raise SystemExit('Commit the complete resolved public dependency lock before the verified build.')
