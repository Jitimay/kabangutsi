"""Pre-G0 test: send and receive SMS through an Android phone over USB (no internet).

Why: the team phone (Samsung SM-G970F) refuses AT commands on /dev/ttyACM0
(`+CME Error:PACM(AP),NOT_ALLOWED_SLO`), so a plain AT/gammu gateway is impossible on it.
Fallback: the open-source app "SMS Gateway for Android" (me.capcom.smsgateway) in
*Local Server* mode, reached through adb port forwarding over the USB cable.

Setup on the phone (once):
  1. Grant the app SMS permissions (Android auto-revoked them), or:
       adb shell pm grant me.capcom.smsgateway android.permission.SEND_SMS
       adb shell pm grant me.capcom.smsgateway android.permission.RECEIVE_SMS
       adb shell pm grant me.capcom.smsgateway android.permission.READ_SMS
  2. Open the app -> enable "Local Server" -> Online. Note username/password shown.

Usage:
    export SMSGW_USER=sms SMSGW_PASS=xxxx
    python android_gateway_test.py send +257XXXXXXXX "Kabangutsi test"
    python android_gateway_test.py listen          # waits for one incoming SMS (webhook)

Host <-> phone wiring (done by this script):
    adb forward tcp:8085 tcp:8080   host:8085 -> phone app API :8080
    adb reverse tcp:9009 tcp:9009   phone 127.0.0.1:9009 -> host webhook :9009
"""

import json
import os
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

import requests

API = "http://127.0.0.1:8085"
HOOK_PORT = 9009
AUTH = (os.environ.get("SMSGW_USER", "sms"), os.environ.get("SMSGW_PASS", ""))


def adb(*args: str) -> None:
    subprocess.run(["adb", *args], check=True, capture_output=True)


def send(number: str, text: str) -> None:
    t0 = time.monotonic()
    r = requests.post(f"{API}/message", auth=AUTH, timeout=10,
                      json={"textMessage": {"text": text}, "phoneNumbers": [number]})
    r.raise_for_status()
    msg_id = r.json()["id"]
    print("queued", msg_id)
    for _ in range(30):
        state = requests.get(f"{API}/message/{msg_id}", auth=AUTH, timeout=10).json()
        print(state.get("state"), state.get("recipients"))
        if state.get("state") in ("Sent", "Delivered", "Failed"):
            break
        time.sleep(1)
    print(f"elapsed {time.monotonic() - t0:.1f}s")


class Hook(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        print("WEBHOOK", json.dumps(json.loads(body or b"{}"), indent=2, ensure_ascii=False))
        self.send_response(200)
        self.end_headers()
        Hook.got_one = True


def listen() -> None:
    adb("reverse", f"tcp:{HOOK_PORT}", f"tcp:{HOOK_PORT}")
    hook = {"id": "kabangutsi-test", "url": f"http://127.0.0.1:{HOOK_PORT}/sms",
            "event": "sms:received"}
    requests.post(f"{API}/webhooks", auth=AUTH, json=hook, timeout=10).raise_for_status()
    print("webhook registered; send an SMS to the phone now")
    Hook.got_one = False
    srv = HTTPServer(("127.0.0.1", HOOK_PORT), Hook)
    try:
        while not Hook.got_one:
            srv.handle_request()
    finally:
        requests.delete(f"{API}/webhooks/kabangutsi-test", auth=AUTH, timeout=10)


def main() -> int:
    adb("forward", "tcp:8085", "tcp:8080")
    if sys.argv[1:2] == ["send"]:
        send(sys.argv[2], sys.argv[3])
    elif sys.argv[1:2] == ["listen"]:
        listen()
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
