"""Minimal SMS PDU codec (3GPP TS 23.040 / 23.038): SMS-SUBMIT encode, SMS-DELIVER decode.

PDU mode is used instead of text mode because it is modem-independent: accents (GSM-7 or
UCS-2) and multi-part (concatenated) SMS are handled here, not by the modem firmware.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta, timezone

# GSM 03.38 default alphabet, index = septet value
GSM7 = (
    "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ\x1bÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?"
    "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà"
)
GSM7_EXT = {0x0A: "\f", 0x14: "^", 0x28: "{", 0x29: "}", 0x2F: "\\", 0x3C: "[", 0x3D: "~",
            0x3E: "]", 0x40: "|", 0x65: "€"}
_ENC = {c: i for i, c in enumerate(GSM7) if c != "\x1b"}
_ENC_EXT = {c: i for i, c in GSM7_EXT.items()}


class PduError(ValueError):
    pass


# ---------------------------------------------------------------- GSM-7 -----
def gsm7_septets(text: str) -> list[int]:
    out: list[int] = []
    for ch in text:
        if ch in _ENC:
            out.append(_ENC[ch])
        elif ch in _ENC_EXT:
            out += [0x1B, _ENC_EXT[ch]]
        else:
            raise PduError(f"character not in GSM-7: {ch!r}")
    return out


def is_gsm7(text: str) -> bool:
    return all(c in _ENC or c in _ENC_EXT for c in text)


def pack_septets(septets: list[int], fill_bits: int = 0) -> bytes:
    nbits = fill_bits
    acc = 0
    out = bytearray()
    for s in septets:
        acc |= (s & 0x7F) << nbits
        nbits += 7
        while nbits >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            nbits -= 8
    if nbits > 0:
        out.append(acc & 0xFF)
    return bytes(out)


def unpack_septets(data: bytes, count: int, fill_bits: int = 0) -> list[int]:
    acc = int.from_bytes(data, "little")
    return [(acc >> (fill_bits + 7 * i)) & 0x7F for i in range(count)]


def decode_gsm7(septets: list[int]) -> str:
    out, esc = [], False
    for s in septets:
        if esc:
            out.append(GSM7_EXT.get(s, " "))
            esc = False
        elif s == 0x1B:
            esc = True
        else:
            out.append(GSM7[s])
    return "".join(out)


# ---------------------------------------------------------------- numbers ---
def _bcd_swap(digits: str) -> bytes:
    if len(digits) % 2:
        digits += "F"
    return bytes.fromhex("".join(digits[i + 1] + digits[i] for i in range(0, len(digits), 2)))


def _bcd_unswap(data: bytes, ndigits: int) -> str:
    h = data.hex().upper()
    return "".join(h[i + 1] + h[i] for i in range(0, len(h), 2))[:ndigits]


# ---------------------------------------------------------------- SUBMIT ----
def encode_submit(to: str, text: str) -> tuple[str, int]:
    """Single SMS-SUBMIT PDU. Returns (hex pdu incl. empty SMSC field, TPDU length for AT+CMGS).

    GSM-7 when possible (≤160 septets), else UCS-2 (≤70 chars). Longer text is rejected:
    the gateway sends `short_text`, which the contract caps at 160.
    """
    digits = to.lstrip("+")
    if not digits.isdigit():
        raise PduError("destination must be digits")
    tpdu = bytearray([0x01, 0x00, len(digits), 0x91 if to.startswith("+") else 0x81])
    tpdu += _bcd_swap(digits)
    if is_gsm7(text):
        septets = gsm7_septets(text)
        if len(septets) > 160:
            raise PduError("text longer than 160 GSM-7 septets")
        tpdu += bytes([0x00, 0x00, len(septets)]) + pack_septets(septets)
    else:
        ud = text.encode("utf-16-be")
        if len(ud) > 140:
            raise PduError("text longer than 70 UCS-2 characters")
        tpdu += bytes([0x00, 0x08, len(ud)]) + ud
    return "00" + tpdu.hex().upper(), len(tpdu)


# ---------------------------------------------------------------- DELIVER ---
@dataclass
class Deliver:
    sender: str            # '+25779000101', or an alphanumeric name like 'LUMITEL'
    numeric: bool          # False for alphanumeric senders (operators, promos)
    text: str
    ts: str                # ISO 8601 UTC with Z
    concat: tuple[int, int, int] | None = None  # (reference, total parts, part number)


def _scts(b: bytes) -> str:
    """Service-centre timestamp (7 swapped-BCD octets; tz in quarter-hours, sign = bit 3)."""
    d = _bcd_unswap(b[:6], 12)
    tz = b[6]
    quarters = (tz & 0x07) * 10 + (tz >> 4)
    sign = -1 if tz & 0x08 else 1
    try:
        local = datetime(2000 + int(d[0:2]), int(d[2:4]), int(d[4:6]), int(d[6:8]), int(d[8:10]),
                         int(d[10:12]), tzinfo=timezone(timedelta(minutes=15 * quarters * sign)))
        return local.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def decode_deliver(pdu_hex: str) -> Deliver:
    try:
        b = bytes.fromhex(pdu_hex.strip())
        i = 1 + b[0]                      # skip SMSC
        first = b[i]; i += 1
        if first & 0x03 != 0x00:
            raise PduError("not an SMS-DELIVER")
        udhi = bool(first & 0x40)
        olen, otype = b[i], b[i + 1]; i += 2
        onbytes = (olen + 1) // 2
        oraw = b[i:i + onbytes]; i += onbytes
        if otype & 0x70 == 0x50:          # alphanumeric
            sender = decode_gsm7(unpack_septets(oraw, olen * 4 // 7))
            numeric = False
        else:
            digits = _bcd_unswap(oraw, olen)
            sender = ("+" if otype & 0x70 == 0x10 else "") + digits
            numeric = True
        i += 1                            # PID
        dcs = b[i]; i += 1
        ts = _scts(b[i:i + 7]); i += 7
        udl = b[i]; i += 1
        ud = b[i:]
        alphabet = (dcs >> 2) & 0x03 if dcs & 0xC0 == 0x00 else (2 if dcs & 0xF0 == 0xE0 else 0)
        if dcs & 0xF0 == 0xF0:
            alphabet = 1 if dcs & 0x04 else 0

        concat = None
        hdr_octets = 0
        if udhi:
            udhl = ud[0]
            hdr_octets = udhl + 1
            j = 1
            while j < hdr_octets:
                iei, iel = ud[j], ud[j + 1]
                val = ud[j + 2:j + 2 + iel]
                if iei == 0x00 and iel == 3:
                    concat = (val[0], val[1], val[2])
                elif iei == 0x08 and iel == 4:
                    concat = ((val[0] << 8) | val[1], val[2], val[3])
                j += 2 + iel

        if alphabet == 0:
            hdr_septets = (hdr_octets * 8 + 6) // 7
            fill = hdr_septets * 7 - hdr_octets * 8
            septets = unpack_septets(ud[hdr_octets:], udl - hdr_septets, fill)
            text = decode_gsm7(septets)
        elif alphabet == 2:
            text = ud[hdr_octets:udl].decode("utf-16-be", errors="replace")
        else:
            text = ud[hdr_octets:udl].decode("latin-1")
        return Deliver(sender=sender, numeric=numeric, text=text, ts=ts, concat=concat)
    except (IndexError, ValueError) as e:
        raise PduError(f"bad PDU: {e}") from e
