"""Write ephemeral public Flutter config and optional Android upload key.
Never print credentials and never use the StockPulse secrets.
"""
import base64
import json
import os
import re
from pathlib import Path
import sys
from urllib.parse import urlparse

url = os.environ.get('DANAPUR_SUPABASE_URL', '').strip()
key = os.environ.get('DANAPUR_SUPABASE_ANON_KEY', '').strip()
if bool(url) != bool(key):
    raise SystemExit('Set BOTH Danapur Supabase secrets, or neither for demo.')
if url and (urlparse(url).scheme != 'https' or not urlparse(url).hostname or urlparse(url).hostname in ('localhost', '127.0.0.1', '::1') or urlparse(url).username is not None):
    raise SystemExit('Danapur backend URL must be HTTPS.')
if key.startswith('sb_secret_'):
    raise SystemExit('Do not embed a Supabase secret key. Use publishable/anon.')
if len(key.split('.')) == 3:
    try:
        encoded = key.split('.')[1]
        payload = json.loads(base64.urlsafe_b64decode(encoded + '=' * (-len(encoded) % 4)))
    except Exception:
        raise SystemExit('The Supabase anon JWT is malformed.') from None
    if not isinstance(payload, dict) or payload.get('role') != 'anon':
        raise SystemExit('Only public anon-role JWTs may be embedded; not service-role or user-session tokens.')

if key and len(key.split('.')) != 3 and not re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]+', key):
    raise SystemExit('Use a Supabase publishable key or a legacy public anon JWT.')

output = Path(sys.argv[1])
output.write_text(json.dumps({'DANAPUR_SUPABASE_URL': url, 'DANAPUR_SUPABASE_ANON_KEY': key}))
output.chmod(0o600)
print('Build mode: CLOUD' if url else 'Build mode: LOCAL DEMO (no shared onboarding)')
if os.environ.get('GITHUB_OUTPUT'):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
        stream.write(f'mode={"cloud" if url else "demo"}\n')

keystore = os.environ.get('DANAPUR_ANDROID_KEYSTORE_BASE64', '').strip()
parts = ['DANAPUR_KEYSTORE_PASSWORD', 'DANAPUR_KEY_ALIAS', 'DANAPUR_KEY_PASSWORD']
if keystore:
    if any(not os.environ.get(name) for name in parts):
        raise SystemExit('All three Danapur Android signing secrets are required with a keystore.')
    key_path = output.parent / 'danapur-upload.jks'
    try:
        key_path.write_bytes(base64.b64decode(''.join(keystore.split()), validate=True))
    except Exception:
        raise SystemExit('Invalid Danapur keystore encoding.') from None
    if not key_path.stat().st_size:
        raise SystemExit('Danapur keystore is empty.')
    key_path.chmod(0o600)
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a') as stream:
            stream.write(f'DANAPUR_KEYSTORE_PATH={key_path}\n')
    print('APK signing: dedicated upload key')
else:
    if any(os.environ.get(name) for name in parts):
        raise SystemExit('Signing passwords are configured but the Danapur keystore is missing.')
    print('APK signing: DEBUG KEY — installation testing only, not Play Store')
