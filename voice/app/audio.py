"""Audio decode (any container ffmpeg reads → 16 kHz mono float32) and WAV encode."""
import io
import subprocess
import wave

import numpy as np

from .errors import ApiError

SR = 16000


def decode(data: bytes, max_seconds: float) -> np.ndarray:
    """Decode wav/webm/ogg/m4a/mp3 bytes with ffmpeg. Raises 415 if not audio, 413 if too long."""
    if not data:
        raise ApiError(422, "validation_error", "audio is empty", {"field": "audio"})
    try:
        proc = subprocess.run(
            ["ffmpeg", "-nostdin", "-loglevel", "error", "-i", "pipe:0", "-t", str(max_seconds + 1),
             "-vn", "-ac", "1", "-ar", str(SR), "-f", "s16le", "pipe:1"],
            input=data, capture_output=True, timeout=30, check=False)
    except subprocess.TimeoutExpired as e:
        raise ApiError(415, "unsupported_media_type", "could not decode audio (timeout)") from e
    if proc.returncode != 0 or not proc.stdout:
        raise ApiError(415, "unsupported_media_type",
                       "could not decode audio; send wav, webm/ogg (opus), m4a/mp4 (aac) or mp3")
    audio = np.frombuffer(proc.stdout, dtype=np.int16).astype(np.float32) / 32768.0
    if len(audio) > max_seconds * SR:
        raise ApiError(413, "too_large", f"audio longer than {int(max_seconds)} s",
                       {"max_seconds": int(max_seconds)})
    return audio


def to_wav(audio: np.ndarray, sample_rate: int) -> bytes:
    """float32 [-1, 1] or int16 → 16-bit PCM mono WAV bytes."""
    if audio.dtype != np.int16:
        audio = (np.clip(audio, -1.0, 1.0) * 32767).astype(np.int16)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(audio.tobytes())
    return buf.getvalue()


def read_wav(path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        if w.getsampwidth() != 2 or w.getnchannels() != 1:
            raise ValueError(f"{path}: expected 16-bit mono WAV")
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16), w.getframerate()
