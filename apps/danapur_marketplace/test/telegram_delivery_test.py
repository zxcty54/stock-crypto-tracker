"""Offline Telegram-delivery tests. No real bot/chat/network is used."""
from contextlib import redirect_stderr, redirect_stdout
from importlib.util import module_from_spec, spec_from_file_location
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from zipfile import ZipFile

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "send_apk_to_telegram.py"
spec = spec_from_file_location("danapur_telegram_delivery", SCRIPT)
delivery = module_from_spec(spec)
spec.loader.exec_module(delivery)
TOKEN = "123456:FAKE_FOR_OFFLINE_TESTS"
CHAT = "-100123456789"


def response(value):
    return io.BytesIO(json.dumps(value).encode())


def success():
    return response({"ok": True, "result": {"message_id": 321, "document": {"file_name": "danapur-bazaar.apk"}}})


class TelegramDeliveryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.apk = Path(self.directory.name) / "danapur-bazaar.apk"
        self.make_apk()

    def make_apk(self, *, package="in.danapur.bazaar", abis=delivery.ABIS):
        # Synthetic tiny fixtures stay in a disposable directory; not deliverables.
        with ZipFile(self.apk, "w") as archive:
            archive.writestr("AndroidManifest.xml", package)
            for abi in abis:
                archive.writestr(f"lib/{abi}/libapp.so", b"offline-test-fixture")

    def test_numeric_chat_ids_and_public_channels(self):
        for value, expected in [
            (CHAT, CHAT), ("12345", "12345"), ("@ExampleChannel", "@ExampleChannel"),
            ("https://t.me/ExampleChannel", "@ExampleChannel"),
            ("https://telegram.me/ExampleChannel/", "@ExampleChannel"),
        ]:
            with self.subTest(value=value):
                self.assertEqual(delivery.normalize_chat_id(value), expected)

    def test_private_invites_and_unrelated_urls_are_rejected(self):
        for value in ["https://t.me/+invite", "https://t.me/joinchat/abc", "https://t.me/c/123/4", "https://example.com/channel", "", "0"]:
            with self.subTest(value=value):
                with self.assertRaises(delivery.DeliveryError):
                    delivery.normalize_chat_id(value)

    def test_universal_danapur_apk_is_validated(self):
        self.assertEqual(delivery.validate_apk(self.apk), self.apk.stat().st_size)

    def test_split_and_other_app_apks_are_rejected(self):
        self.make_apk(abis=("arm64-v8a",))
        with self.assertRaises(delivery.DeliveryError):
            delivery.validate_apk(self.apk)
        self.make_apk(package="com.example.otherapp")
        with self.assertRaises(delivery.DeliveryError):
            delivery.validate_apk(self.apk)

    def test_invalid_archive_and_missing_apk_are_rejected(self):
        self.apk.write_bytes(b"not-an-apk")
        with self.assertRaises(delivery.DeliveryError):
            delivery.validate_apk(self.apk)
        self.apk.unlink()
        with self.assertRaises(delivery.DeliveryError):
            delivery.validate_apk(self.apk)

    def test_telegram_size_limit_is_checked_before_request(self):
        with patch.object(delivery, "MAX_APK_BYTES", 1):
            with self.assertRaises(delivery.DeliveryError):
                delivery.validate_apk(self.apk)

    def test_document_is_zip_containing_exactly_one_apk(self):
        boundary, data = delivery.multipart_document(self.apk, CHAT, "Demo build")
        self.assertIn(b'filename="danapur-bazaar.zip"', data)
        self.assertIn(b"application/zip", data)
        start = data.index(b'PK\x03\x04')
        end = data.rfind(f"\r\n--{boundary}--\r\n".encode())
        with ZipFile(io.BytesIO(data[start:end])) as archive:
            self.assertEqual(archive.namelist(), ['danapur-bazaar.apk'])
            self.assertEqual(archive.read('danapur-bazaar.apk'), self.apk.read_bytes())
        self.assertTrue(data.endswith(f"--{boundary}--\r\n".encode()))
        self.assertNotIn(TOKEN.encode(), data)

    def test_success_requires_confirmed_message_id(self):
        captured = []
        def opener(request, timeout):
            captured.append(request)
            self.assertEqual(timeout, 180)
            return success()
        self.assertEqual(delivery.send_apk(self.apk, TOKEN, "https://t.me/ExampleChannel", "Demo", opener=opener), 321)
        self.assertEqual(captured[0].method, "POST")
        self.assertEqual(captured[0].full_url, f"https://api.telegram.org/bot{TOKEN}/sendDocument")
        self.assertIn(b"@ExampleChannel", captured[0].data)

    def test_http_200_ok_false_is_not_success_and_hides_credentials(self):
        def opener(request, timeout):
            return response({"ok": False, "description": f"error {TOKEN} {CHAT}"})
        with self.assertRaises(delivery.DeliveryError) as error:
            delivery.send_apk(self.apk, TOKEN, CHAT, "Demo", opener=opener)
        self.assertNotIn(TOKEN, str(error.exception))
        self.assertNotIn(CHAT, str(error.exception))

    def test_http_errors_are_checked_and_redacted(self):
        def opener(request, timeout):
            raise HTTPError(request.full_url, 403, "Forbidden", {}, response({"ok": False, "description": f"forbidden {TOKEN} {CHAT}"}))
        with self.assertRaises(delivery.DeliveryError) as error:
            delivery.send_apk(self.apk, TOKEN, CHAT, "Demo", opener=opener)
        self.assertNotIn(TOKEN, str(error.exception))
        self.assertNotIn(CHAT, str(error.exception))

    def test_explicit_rate_limit_is_retried(self):
        calls, waits = [], []
        def opener(request, timeout):
            calls.append(request)
            if len(calls) == 1:
                raise HTTPError(request.full_url, 429, "Too Many Requests", {}, response({"ok": False, "error_code": 429, "parameters": {"retry_after": 2}}))
            return success()
        self.assertEqual(delivery.send_apk(self.apk, TOKEN, CHAT, "Demo", opener=opener, sleeper=waits.append), 321)
        self.assertEqual(len(calls), 2)
        self.assertEqual(waits, [2])

    def test_ambiguous_network_failure_is_not_retried(self):
        calls = []
        def opener(request, timeout):
            calls.append(request)
            raise URLError("offline test")
        with self.assertRaises(delivery.DeliveryError):
            delivery.send_apk(self.apk, TOKEN, CHAT, "Demo", opener=opener)
        self.assertEqual(len(calls), 1)

    def test_invalid_json_or_missing_confirmation_is_not_success(self):
        for raw in [b"not-json", b"[]", b'{"ok":true,"result":{}}']:
            with self.subTest(raw=raw):
                with self.assertRaises(delivery.DeliveryError):
                    delivery.send_apk(self.apk, TOKEN, CHAT, "Demo", opener=lambda request, timeout: io.BytesIO(raw))

    def test_invalid_token_and_oversized_caption_do_not_send(self):
        for token, caption in [("", "Demo"), ("not-a-bot-token", "Demo"), (TOKEN, "x" * 1025)]:
            with self.subTest(token=token, length=len(caption)):
                with patch.object(delivery, "urlopen") as opener:
                    with self.assertRaises(delivery.DeliveryError):
                        delivery.send_apk(self.apk, token, CHAT, caption)
                    opener.assert_not_called()

    def test_missing_secrets_fail_without_printing_values(self):
        stderr = io.StringIO()
        with patch.dict(os.environ, {"BOT_TOKEN": TOKEN, "CHAT_ID": ""}, clear=True), redirect_stderr(stderr):
            self.assertEqual(delivery.main([str(self.apk)]), 1)
        self.assertNotIn(TOKEN, stderr.getvalue())

    def test_cli_logs_confirmation_without_credentials(self):
        stdout = io.StringIO()
        summary = Path(self.directory.name) / "summary.md"
        with patch.dict(os.environ, {"BOT_TOKEN": TOKEN, "CHAT_ID": CHAT, "GITHUB_STEP_SUMMARY": str(summary)}, clear=True), patch.object(delivery, "urlopen", return_value=success()), redirect_stdout(stdout):
            self.assertEqual(delivery.main([str(self.apk), "--mode", "sample"]), 0)
        for text in (stdout.getvalue(), summary.read_text()):
            self.assertIn("321", text)
            self.assertIn("one universal APK", text)
            self.assertNotIn(TOKEN, text)
            self.assertNotIn(CHAT, text)


if __name__ == "__main__":
    unittest.main()
