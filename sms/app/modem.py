"""AT-command GSM modem driver in PDU mode (SIM800A via Arduino Nano passthrough, USB dongles).

All serial access goes through one lock, so the poll loop and /send never interleave.
"""

from __future__ import annotations

import logging
import re
import threading
import time
from dataclasses import dataclass

import serial

from .pdu import Deliver, PduError, decode_deliver, encode_submit

log = logging.getLogger("sms.modem")

_FINAL = re.compile(rb"\r\n(OK|ERROR|\+CMS ERROR: [^\r]*|\+CME ERROR: [^\r]*)\r\n$")


class ModemError(RuntimeError):
    pass


@dataclass
class StoredSms:
    index: int
    pdu: str
    sms: Deliver | None   # None when the PDU could not be decoded


class Modem:
    def __init__(self, device: str, baud: int = 9600, timeout: float = 0.2):
        self.device, self.baud, self.timeout = device, baud, timeout
        self.port: serial.Serial | None = None
        self.lock = threading.Lock()
        self.model = "unknown"

    # ---- low level -----------------------------------------------------------------
    def open(self) -> None:
        self.port = serial.Serial(self.device, self.baud, timeout=self.timeout)
        for cmd in ("AT", "ATE0", "AT+CMEE=2", "AT+CMGF=0", 'AT+CPMS="SM","SM","SM"', "AT+CNMI=2,1,0,0,0"):
            try:
                self.cmd(cmd, wait=3)
            except ModemError:
                if cmd in ("AT", "AT+CMGF=0"):
                    raise
                log.warning("modem init: %s not supported", cmd)
        try:
            self.model = self.cmd("AT+CGMM").strip() or "unknown"
        except ModemError:
            pass

    def close(self) -> None:
        if self.port:
            self.port.close()
            self.port = None

    def cmd(self, command: str, wait: float = 5.0) -> str:
        """Send one AT command, return the response body (without the final OK)."""
        with self.lock:
            return self._cmd(command, wait)

    def _cmd(self, command: str, wait: float) -> str:
        if self.port is None:
            raise ModemError("modem not open")
        self.port.reset_input_buffer()
        self.port.write(command.encode() + b"\r")
        return self._read_final(wait, command)

    def _read_final(self, wait: float, label: str) -> str:
        assert self.port is not None
        buf = b""
        deadline = time.monotonic() + wait
        while time.monotonic() < deadline:
            buf += self.port.read(self.port.in_waiting or 1)
            norm = buf if buf.startswith(b"\r\n") else b"\r\n" + buf
            m = _FINAL.search(norm)
            if m:
                body = norm[: m.start()]
                if m.group(1) != b"OK":
                    raise ModemError(f"{label.split('=')[0]}: {m.group(1).decode(errors='replace')}")
                return body.decode(errors="replace").strip()
        raise ModemError(f"{label.split('=')[0]}: timeout")

    # ---- status --------------------------------------------------------------------
    def signal(self) -> int | None:
        m = re.search(r"\+CSQ:\s*(\d+)", self.cmd("AT+CSQ"))
        v = int(m.group(1)) if m else None
        return None if v in (None, 99) else v

    def registered(self) -> bool:
        m = re.search(r"\+CREG:\s*\d+,(\d+)", self.cmd("AT+CREG?"))
        return bool(m and m.group(1) in ("1", "5"))

    # ---- SMS -----------------------------------------------------------------------
    def list_all(self) -> list[StoredSms]:
        out = []
        lines = self.cmd("AT+CMGL=4", wait=10).splitlines()
        for i, line in enumerate(lines):
            m = re.match(r"\+CMGL:\s*(\d+),", line)
            if not m or i + 1 >= len(lines):
                continue
            pdu = lines[i + 1].strip()
            try:
                sms: Deliver | None = decode_deliver(pdu)
            except PduError:
                sms = None
            out.append(StoredSms(int(m.group(1)), pdu, sms))
        return out

    def delete(self, index: int) -> None:
        self.cmd(f"AT+CMGD={index}")

    def send(self, to: str, text: str, wait: float = 60.0) -> int:
        """Send one SMS. Returns the network message reference."""
        pdu, length = encode_submit(to, text)
        with self.lock:
            if self.port is None:
                raise ModemError("modem not open")
            self.port.reset_input_buffer()
            self.port.write(f"AT+CMGS={length}\r".encode())
            buf = b""
            deadline = time.monotonic() + 5
            while b">" not in buf:
                if time.monotonic() > deadline or b"ERROR" in buf:
                    self.port.write(b"\x1b")
                    raise ModemError("CMGS: no prompt")
                buf += self.port.read(self.port.in_waiting or 1)
            self.port.write(pdu.encode() + b"\x1a")
            body = self._read_final(wait, "CMGS")
        m = re.search(r"\+CMGS:\s*(\d+)", body)
        return int(m.group(1)) if m else -1
