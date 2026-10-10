"""Optional restricted-network preview handoff through a dangling GitHub blob.
No branch/tag/tree is changed and no build files are added to version history.
Normal users should download the standard Actions artifacts instead.
"""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import zipfile

if os.environ.get('GITHUB_REF') != 'refs/heads/arena/c2853110-stock-crypto-tracker':
    raise SystemExit('Preview handoff is restricted to the session branch.')
root = Path(sys.argv[1])
output = Path(sys.argv[2])
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted((root/'web').rglob('*')):
        if path.is_file(): archive.write(path, 'web/'+str(path.relative_to(root/'web')))
    apk = root/'apks'/'app-arm64-v8a-release.apk'
    archive.write(apk, 'danapur-bazaar-arm64.apk')
if output.stat().st_size > 90 * 1024 * 1024:
    raise SystemExit('Preview bundle exceeds the bounded handoff size.')
payload = output.with_suffix('.json')
payload.write_text(json.dumps({'encoding': 'base64', 'content': base64.b64encode(output.read_bytes()).decode()}))
result = subprocess.run(['gh','api','--method','POST',f'repos/{os.environ["GITHUB_REPOSITORY"]}/git/blobs','--input',str(payload)], check=True, capture_output=True, text=True)
sha = json.loads(result.stdout)['sha']
print(f'::notice title=Danapur preview handoff::GITHUB_BLOB_SHA:{sha}')
print('Preview bundle handed off without changing any branch or versioned tree.')
payload.unlink()
