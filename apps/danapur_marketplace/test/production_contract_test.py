"""Offline release contracts: real backend only, catalogue, no binary artifacts."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT.parents[1] / '.github/workflows/danapur_marketplace.yml'

class ProductionContractTests(unittest.TestCase):
    def test_no_demo_repository_or_fixture_is_imported_by_shipping_code(self):
        for path in (ROOT / 'lib').rglob('*.dart'):
            text = path.read_text()
            self.assertNotIn('DemoRepository', text, str(path))
            self.assertNotIn('test/support/', text, str(path))
            self.assertNotIn('exampleMarket(', text, str(path))

    def test_workflow_never_uploads_or_downloads_actions_artifacts(self):
        text = WORKFLOW.read_text()
        self.assertNotIn('actions/upload-artifact', text)
        self.assertNotIn('actions/download-artifact', text)
        self.assertNotIn('--split-per-abi', text)
        self.assertIn("github.event_name != 'pull_request'", text)
        self.assertIn('needs: backend-security', text)

    def test_configuration_template_has_only_blank_public_slots(self):
        data = json.loads((ROOT / 'config/app_config.example.json').read_text())
        self.assertEqual(set(data), {'DANAPUR_SUPABASE_URL', 'DANAPUR_SUPABASE_ANON_KEY', 'DANAPUR_AUTH_REDIRECT_URL'})
        self.assertTrue(all(value == '' for value in data.values()))

    def test_catalogue_has_unique_bilingual_unpriced_entries(self):
        rows = json.loads((ROOT / 'config/catalog/mandi_items.json').read_text())
        self.assertEqual(len(rows), 117)
        self.assertEqual(len({row['id'] for row in rows}), len(rows))
        for row in rows:
            self.assertTrue(row['name'] and row['hindi_name'])
            self.assertNotIn('price', row)
            self.assertIn(row['category'], ['Vegetables', 'Fruits'])

    def test_committed_seed_matches_editable_catalogue(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tools/generate_mandi_catalog.py'), '--check'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_private_verification_and_no_public_admin_write_grants(self):
        text = (ROOT / 'supabase/migrations/002_verified_marketplace.sql').read_text()
        self.assertIn("'shop-verification','shop-verification',false", text)
        self.assertIn('revoke all on public.market_admins from anon, authenticated', text)
        self.assertIn('Administrator access required', text)
        self.assertIn('review_status=\'approved\'', text)

    def test_first_admin_template_has_no_built_in_account(self):
        text = (ROOT / 'supabase/admin/first_admin.example.sql').read_text()
        self.assertIn('REPLACE_WITH_YOUR_CONFIRMED_AUTH_USER_UUID', text)
        self.assertNotIn('@', text)

    def test_auth_redirect_guard_rejects_insecure_override_without_logging_it(self):
        with __import__('tempfile').TemporaryDirectory() as directory:
            import os
            env = {k:v for k,v in os.environ.items() if not k.startswith('DANAPUR_') and k not in ('GITHUB_ENV','GITHUB_OUTPUT')}
            result = subprocess.run([sys.executable, str(ROOT / 'tools/create_build_config.py'), str(Path(directory)/'config.json')], env={**env, 'DANAPUR_AUTH_REDIRECT_URL':'http://bad.example/private'}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('http://bad.example/private', result.stdout + result.stderr)

if __name__ == '__main__':
    unittest.main()
