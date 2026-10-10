"""Send one genuine, universal Danapur APK using the existing repository bot.

Credentials are read only from environment variables, never CLI arguments/logs.
The public Telegram Bot API accepts documents up to 50 MB. APKs are sent directly,
not zipped, and a successful HTTP response must also confirm `ok: true`.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse
from urllib.request import Request, urlopen
from uuid import uuid4
from zipfile import BadZipFile, ZipFile

MAX_APK_BYTES = 50_000_000
ABIS = ("armeabi-v7a", "arm64-v8a", "x86_64")


class DeliveryError(Exception):
    """A safe-to-display delivery failure; never include credential values."""


def normalize_chat_id(value):
    value = value.strip()
    if re.fullmatch(r"-?[0-9]+", value) and int(value) != 0:
        return value
    if re.fullmatch(r"@[A-Za-z][A-Za-z0-9_]{0,31}", value):
        return value
    link = urlparse(value)
    if (
        link.scheme in ("http", "https")
        and link.hostname in ("t.me", "telegram.me")
        and link.username is None
    ):
        name = link.path.strip("/")
        if re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,31}", name) and name not in (
            "joinchat", "c", "s", "share", "addstickers", "addemoji"
        ):
            return "@" + name
    raise DeliveryError(
        "Telegram destination must be a numeric chat ID, @channel username, "
        "or public t.me/channel link. Private invite links are not chat IDs."
    )


def validate_apk(path):
    path = Path(path)
    if path.suffix.lower() != ".apk" or not path.is_file():
        raise DeliveryError("The universal APK file is missing or is not an .apk.")
    size = path.stat().st_size
    if size <= 0 or size > MAX_APK_BYTES:
        raise DeliveryError(
            "APK is empty or exceeds the public Telegram Bot API 50 MB limit. "
            "Keep compressed native-library packaging enabled."
        )
    try:
        with ZipFile(path) as apk:
            names = set(apk.namelist())
            required = {f"lib/{abi}/libapp.so" for abi in ABIS}
            if "AndroidManifest.xml" not in names or not required.issubset(names):
                raise DeliveryError("Expected one universal APK containing all three Android ABIs.")
            manifest = apk.read("AndroidManifest.xml")
            package = "in.danapur.bazaar"
            if package.encode() not in manifest and package.encode("utf-16-le") not in manifest:
                raise DeliveryError("Refusing to send an APK for a different application.")
    except (BadZipFile, OSError, RuntimeError, ValueError, KeyError):
        raise DeliveryError("The built APK archive could not be validated.") from None
    return size


def multipart_document(path, chat_id, caption):
    boundary = "danapur-" + uuid4().hex
    chunks = []
    for name, value in (("chat_id", chat_id), ("caption", caption)):
        chunks.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
        )
    chunks.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="document"; '
        'filename="danapur-bazaar.apk"\r\n'
        'Content-Type: application/vnd.android.package-archive\r\n\r\n'.encode()
    )
    chunks.append(Path(path).read_bytes())
    chunks.append(f"\r\n--{boundary}--\r\n".encode())
    return boundary, b"".join(chunks)


def safe_description(reply, token, original_chat, normalized_chat):
    description = reply.get("description", "Telegram rejected the document.")
    if not isinstance(description, str):
        description = "Telegram rejected the document."
    for value in (token, quote(token, safe=""), original_chat, normalized_chat):
        if value:
            description = description.replace(value, "[REDACTED]")
    return " ".join(description.split())[:220]


def read_reply(response):
    try:
        reply = json.loads(response.read(65536))
    except (ValueError, UnicodeError):
        raise DeliveryError("Telegram returned an invalid response; delivery is not confirmed.") from None
    if not isinstance(reply, dict):
        raise DeliveryError("Telegram returned an invalid response; delivery is not confirmed.")
    return reply


def send_apk(path, token, chat_id, caption, *, opener=None, sleeper=None):
    token = token.strip()
    if not re.fullmatch(r"[0-9]+:[A-Za-z0-9_-]+", token):
        raise DeliveryError("Telegram bot token is missing or malformed in repository secrets.")
    destination = normalize_chat_id(chat_id)
    validate_apk(path)
    if len(caption) > 1024:
        raise DeliveryError("Telegram document caption must not exceed 1024 characters.")
    boundary, body = multipart_document(path, destination, caption)
    request = Request(
        f"https://api.telegram.org/bot{token}/sendDocument",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    opener = opener or urlopen
    sleeper = sleeper or time.sleep
    for attempt in range(3):
        status = 200
        try:
            with opener(request, timeout=180) as response:
                reply = read_reply(response)
        except HTTPError as error:
            status = error.code
            try:
                reply = read_reply(error)
            finally:
                error.close()
        except (URLError, TimeoutError, OSError):
            # An ambiguous connection failure might have delivered the file.
            # Do not automatically resend and produce duplicate Telegram APKs.
            raise DeliveryError(
                "Telegram connection failed; delivery could not be confirmed. "
                "Check the chat before rerunning delivery."
            ) from None
        if status == 200 and reply.get("ok") is True:
            result = reply.get("result")
            if isinstance(result, dict) and type(result.get("message_id")) is int:
                return result["message_id"]
            raise DeliveryError("Telegram did not confirm a document message ID.")
        if status == 429 or reply.get("error_code") == 429:
            parameters = reply.get("parameters")
            retry_after = parameters.get("retry_after") if isinstance(parameters, dict) else None
            if attempt < 2 and type(retry_after) is int and 1 <= retry_after <= 60:
                sleeper(retry_after)
                continue
        description = safe_description(reply, token, chat_id.strip(), destination)
        raise DeliveryError("Telegram APK delivery failed: " + description)
    raise DeliveryError("Telegram rate limit prevented delivery.")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Deliver one universal Danapur APK to Telegram.")
    parser.add_argument("apk", type=Path)
    parser.add_argument("--mode", choices=("demo", "cloud"), default="demo")
    parser.add_argument("--run-url", default="")
    args = parser.parse_args(argv)
    token = os.environ.get("BOT_TOKEN", "")
    chat_id = os.environ.get("CHAT_ID", "")
    if not token.strip() or not chat_id.strip():
        print(
            "::error::Telegram secrets are missing. Configure TELEGRAM_BOT_TOKEN "
            "and TELEGRAM_CHAT_ID (or the documented existing aliases) in GitHub, not in chat.",
            file=sys.stderr,
        )
        return 1
    mode = "Local demo: changes stay on this device." if args.mode == "demo" else "Configured cloud build."
    caption = (
        "Danapur Bazaar — one universal Android APK\n"
        "Android 7+ | ARMv7, ARM64 and x86_64 in one file.\n"
        f"{mode}\nCI testing build; production signing/setup are separate."
    )
    if args.run_url:
        caption += "\n" + args.run_url
    try:
        message_id = send_apk(args.apk, token, chat_id, caption)
    except DeliveryError as error:
        print("::error::" + str(error), file=sys.stderr)
        return 1
    size = args.apk.stat().st_size / 1_000_000
    confirmation = (
        f"Telegram confirmed message {message_id}: danapur-bazaar.apk, "
        f"{size:.1f} MB, one universal APK."
    )
    print("::notice title=Danapur APK delivered::" + confirmation)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as stream:
            stream.write("## Danapur APK delivered to Telegram\n\n" + confirmation + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
