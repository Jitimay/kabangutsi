"""Pre-G0 test: probe a GSM modem (or phone modem port) with AT commands.

Usage:
    python at_probe.py /dev/ttyACM0             # identify modem, SIM, network, signal
    python at_probe.py /dev/ttyACM0 --list      # list stored SMS (text mode)
    python at_probe.py /dev/ttyACM0 --send +257XXXXXXXX "Kabangutsi test"

Only uses standard 3GPP TS 27.005 / 27.007 commands, so the same script works with a
USB GSM dongle (/dev/ttyUSB*) later. Requires: pyserial. The user must be in the group
that owns the device (`dialout` on Debian/Ubuntu, `uucp` on Arch).
"""

import argparse
import sys
import time

import serial


def at(port: serial.Serial, cmd: str, wait: float = 1.0, terminator: bytes = b"\r") -> str:
    port.reset_input_buffer()
    port.write(cmd.encode() + terminator)
    deadline = time.monotonic() + wait
    buf = b""
    while time.monotonic() < deadline:
        chunk = port.read(port.in_waiting or 1)
        if chunk:
            buf += chunk
            if buf.rstrip().endswith((b"OK", b"ERROR")) or b"+CMS ERROR" in buf or b"+CME ERROR" in buf:
                break
    return buf.decode(errors="replace").strip()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("device")
    p.add_argument("--baud", type=int, default=115200)
    p.add_argument("--list", action="store_true")
    p.add_argument("--send", nargs=2, metavar=("NUMBER", "TEXT"))
    a = p.parse_args()

    with serial.Serial(a.device, a.baud, timeout=0.2) as port:
        for cmd in ["AT", "ATE0", "ATI", "AT+CGMI", "AT+CGMM", "AT+CGMR", "AT+CPIN?",
                    "AT+COPS?", "AT+CSQ", "AT+CREG?", "AT+CMGF=?", "AT+CSCA?", "AT+CPMS?"]:
            print(f">>> {cmd}\n{at(port, cmd)}\n")

        if a.list or a.send:
            print(">>> AT+CMGF=1\n" + at(port, "AT+CMGF=1") + "\n")
        if a.list:
            print('>>> AT+CMGL="ALL"\n' + at(port, 'AT+CMGL="ALL"', wait=5) + "\n")
        if a.send:
            number, text = a.send
            print(f'>>> AT+CMGS="{number}"\n' + at(port, f'AT+CMGS="{number}"', wait=2))
            print(at(port, text, wait=30, terminator=b"\x1a"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
