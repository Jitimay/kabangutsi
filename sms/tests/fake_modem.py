"""A fake SIM800 on a pseudo-terminal, so the real serial code path is tested without hardware."""

from __future__ import annotations

import os
import pty
import re
import threading
import tty

from app.pdu import gsm7_septets, pack_septets


def _bcd(digits: str) -> bytes:
    if len(digits) % 2:
        digits += "F"
    return bytes.fromhex("".join(digits[i + 1] + digits[i] for i in range(0, len(digits), 2)))


def build_deliver(sender: str, text: str, concat: tuple[int, int, int] | None = None,
                  ucs2: bool = False, alnum: bool = False) -> str:
    """SMS-DELIVER PDU as a modem would store it (with a dummy SMSC)."""
    smsc = bytes([0x07, 0x91]) + _bcd("25779999999")
    first = 0x04 | (0x40 if concat else 0)
    if alnum:
        sep = gsm7_septets(sender)
        oa = bytes([len(pack_septets(sep)) * 2, 0xD0]) + pack_septets(sep)
    else:
        d = sender.lstrip("+")
        oa = bytes([len(d), 0x91]) + _bcd(d)
    scts = _bcd("261102081530") + bytes([0x80])  # 2026-11-02 08:15:30, tz +8 quarter-hours (+02:00)
    udh = bytes([0x05, 0x00, 0x03, *concat]) if concat else b""
    if ucs2:
        ud = udh + text.encode("utf-16-be")
        dcs, udl = 0x08, len(ud)
    else:
        sep = gsm7_septets(text)
        if udh:
            hdr_septets = (len(udh) * 8 + 6) // 7
            fill = hdr_septets * 7 - len(udh) * 8
            ud = udh + pack_septets(sep, fill)
            udl = hdr_septets + len(sep)
        else:
            ud, udl = pack_septets(sep), len(sep)
        dcs = 0x00
    return (smsc + bytes([first]) + oa + bytes([0x00, dcs]) + scts + bytes([udl]) + ud).hex().upper()


class FakeSim800:
    def __init__(self, registered: bool = True):
        self.master, slave = pty.openpty()
        tty.setraw(slave)
        self.device = os.ttyname(slave)
        self._slave = slave
        self.registered = registered
        self.stored: dict[int, str] = {}
        self.sent: list[str] = []
        self.commands: list[str] = []
        self._next = 1
        self._stop = False
        self._t = threading.Thread(target=self._run, daemon=True)
        self._t.start()

    def store(self, pdu: str) -> int:
        i = self._next
        self._next += 1
        self.stored[i] = pdu
        return i

    def _w(self, s: str) -> None:
        os.write(self.master, s.encode())

    def _run(self) -> None:
        buf = b""
        pending_send = False
        while not self._stop:
            try:
                data = os.read(self.master, 1024)
            except OSError:
                return
            buf += data
            if pending_send:
                if b"\x1a" in buf:
                    pdu, buf = buf.split(b"\x1a", 1)
                    self.sent.append(pdu.decode().strip())
                    self._w(f"\r\n+CMGS: {len(self.sent)}\r\n\r\nOK\r\n")
                    pending_send = False
                continue
            while b"\r" in buf:
                line, buf = buf.split(b"\r", 1)
                cmd = line.decode(errors="replace").strip()
                if not cmd:
                    continue
                self.commands.append(cmd)
                if cmd.startswith("AT+CMGS="):
                    pending_send = True
                    self._w("\r\n> ")
                    break
                self._w(self._answer(cmd))

    def _answer(self, cmd: str) -> str:
        ok = "\r\nOK\r\n"
        if cmd == "AT+CGMM":
            return "\r\nSIMCOM_SIM800A\r\n" + ok
        if cmd == "AT+CSQ":
            return "\r\n+CSQ: 18,0\r\n" + ok
        if cmd == "AT+CREG?":
            return f"\r\n+CREG: 0,{1 if self.registered else 2}\r\n" + ok
        if cmd == "AT+CMGL=4":
            body = "".join(f"\r\n+CMGL: {i},0,,{len(p) // 2 - 8}\r\n{p}" for i, p in sorted(self.stored.items()))
            return body + "\r\n" + ok
        m = re.match(r"AT\+CMGD=(\d+)", cmd)
        if m:
            self.stored.pop(int(m.group(1)), None)
            return ok
        if cmd.startswith(("AT", "ATE0")):
            return ok
        return "\r\nERROR\r\n"

    def close(self) -> None:
        self._stop = True
        for fd in (self.master, self._slave):
            try:
                os.close(fd)
            except OSError:
                pass
