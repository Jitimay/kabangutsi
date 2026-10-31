"""Build STT test sets (16 kHz mono WAV) from TTS output + espeak-ng, plus a phone-quality copy.

Sets written to out/stt_input/<lang>/<source>/NN.wav:
  - <tts voice>        clean TTS audio
  - espeak             espeak-ng (a second, very different synthetic voice) for fr/en
  - <voice>_phone      8 kHz band-limited + white noise at ~20 dB SNR (simulates a phone line)
  - real               any real recordings found in recordings/<lang>/NN.wav (see README)
"""
import shutil
import subprocess

import librosa
import numpy as np
import soundfile as sf

from common import HERE, OUT
from sentences import SENTENCES

SR = 16000
ESPEAK_VOICE = {"fr": "fr", "en": "en-us"}
rng = np.random.default_rng(0)


def to16k(src, dst):
    y, _ = librosa.load(src, sr=SR, mono=True)
    dst.parent.mkdir(parents=True, exist_ok=True)
    sf.write(dst, y, SR)
    return y


def phone(y):
    y8 = librosa.resample(y, orig_sr=SR, target_sr=8000)
    y = librosa.resample(y8, orig_sr=8000, target_sr=SR)
    p = np.mean(y ** 2)
    noise = rng.normal(0, np.sqrt(p / 10 ** (20 / 10)), len(y))
    return np.clip(y + noise, -1, 1).astype(np.float32)


def main():
    dst_root = OUT / "stt_input"
    shutil.rmtree(dst_root, ignore_errors=True)
    for voice_dir in sorted((OUT / "tts").iterdir()):
        for lang_dir in voice_dir.iterdir():
            for wav in sorted(lang_dir.glob("*.wav")):
                y = to16k(wav, dst_root / lang_dir.name / voice_dir.name / wav.name)
                p = dst_root / lang_dir.name / f"{voice_dir.name}_phone" / wav.name
                p.parent.mkdir(parents=True, exist_ok=True)
                sf.write(p, phone(y), SR)
    for lang, ev in ESPEAK_VOICE.items():
        for i, text in enumerate(SENTENCES[lang], 1):
            tmp = OUT / "espeak_tmp.wav"
            subprocess.run(["espeak-ng", "-v", ev, "-s", "150", "-w", str(tmp), text], check=True)
            to16k(tmp, dst_root / lang / "espeak" / f"{i:02d}.wav")
        (OUT / "espeak_tmp.wav").unlink()
    rec = HERE / "recordings"
    if rec.exists():
        for lang_dir in rec.iterdir():
            for f in sorted(lang_dir.iterdir()):
                to16k(f, dst_root / lang_dir.name / "real" / (f.stem + ".wav"))
    for d in sorted(dst_root.glob("*/*")):
        print(d.relative_to(dst_root), len(list(d.glob("*.wav"))))


if __name__ == "__main__":
    main()
