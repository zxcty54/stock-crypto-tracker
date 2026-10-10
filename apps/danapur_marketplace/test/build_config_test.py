"""Offline tests for the CI credential guard; no credentials or services required."""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'create_build_config.py'

class BuildConfigTests(unittest.TestCase):
    def run_config(self, extra):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'config.json'
            env = {k: v for k, v in os.environ.items() if not k.startswith('DANAPUR_') and k not in ('GITHUB_OUTPUT', 'GITHUB_ENV')}
            result = subprocess.run([sys.executable, str(SCRIPT), str(output)], env={**env, **extra}, capture_output=True, text=True)
            data = json.loads(output.read_text()) if output.exists() else None
            mode = output.stat().st_mode & 0o777 if output.exists() else None
            return result, data, mode

    def test_empty_configuration_is_demo(self):
        result, data, mode = self.run_config({})
        self.assertEqual(result.returncode, 0)
        self.assertEqual(data['DANAPUR_SUPABASE_URL'], '')
        self.assertEqual(mode, 0o600)
        self.assertIn('LOCAL DEMO', result.stdout)

    def test_partial_configuration_fails(self):
        result, data, _ = self.run_config({'DANAPUR_SUPABASE_URL': 'https://example.supabase.co'})
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(data)

    def test_public_key_is_not_printed(self):
        key = 'sb_publishable_example_should_not_be_logged'
        result, data, _ = self.run_config({'DANAPUR_SUPABASE_URL': 'https://example.supabase.co', 'DANAPUR_SUPABASE_ANON_KEY': key})
        self.assertEqual(result.returncode, 0)
        self.assertEqual(data['DANAPUR_SUPABASE_ANON_KEY'], key)
        self.assertNotIn(key, result.stdout + result.stderr)

    def test_secret_key_is_rejected(self):
        result, _, _ = self.run_config({'DANAPUR_SUPABASE_URL': 'https://example.supabase.co', 'DANAPUR_SUPABASE_ANON_KEY': 'sb_secret_do_not_embed'})
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('sb_secret_do_not_embed', result.stdout + result.stderr)

    def test_service_role_jwt_is_rejected(self):
        body = base64.urlsafe_b64encode(b'{"role":"service_role"}').decode().rstrip('=')
        result, _, _ = self.run_config({'DANAPUR_SUPABASE_URL': 'https://example.supabase.co', 'DANAPUR_SUPABASE_ANON_KEY': f'header.{body}.signature'})
        self.assertNotEqual(result.returncode, 0)

    def test_localhost_and_insecure_backend_are_rejected(self):
        for url in ['http://example.supabase.co', 'https://localhost', 'https://127.0.0.1', 'https://user:password@example.supabase.co']:
            with self.subTest(url=url):
                result, _, _ = self.run_config({'DANAPUR_SUPABASE_URL': url, 'DANAPUR_SUPABASE_ANON_KEY': 'sb_publishable_example'})
                self.assertNotEqual(result.returncode, 0)

    def test_incomplete_signing_does_not_use_another_app_key(self):
        for extra in [{'DANAPUR_ANDROID_KEYSTORE_BASE64': base64.b64encode(b'dummy').decode()}, {'DANAPUR_KEY_ALIAS': 'example'}]:
            result, _, _ = self.run_config(extra)
            self.assertNotEqual(result.returncode, 0)

if __name__ == '__main__':
    unittest.main()
