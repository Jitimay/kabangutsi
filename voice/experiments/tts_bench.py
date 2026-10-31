"""TTS benchmark: Piper (fr, en) and Meta MMS-TTS (rn) on CPU.

Records load time, time to first audio (TTFA), real-time factor (RTF), and writes WAVs to
out/tts/<voice>/<lang>/NN.wav (also used as STT test input by stt_bench.py).

    python tts_bench.py [--threads 4]
"""
import argparse
import time
import wave

import numpy as np

from common import MODELS, OUT, save_json
from sentences import SENTENCES


def write_wav(path, audio_i16: np.ndarray, sr: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(audio_i16.tobytes())


def bench_piper(name: str, lang: str) -> dict:
    from piper import PiperVoice

    t0 = time.perf_counter()
    voice = PiperVoice.load(str(MODELS / "piper" / f"{name}.onnx"))
    load_s = time.perf_counter() - t0
    voice_id = name.rsplit("/", 1)[-1]
    rows = []
    for i, text in enumerate(SENTENCES[lang], 1):
        t0 = time.perf_counter()
        first = None
        chunks = []
        sr = None
        for chunk in voice.synthesize(text):
            if first is None:
                first = time.perf_counter() - t0
            chunks.append(np.frombuffer(chunk.audio_int16_bytes, dtype=np.int16))
            sr = chunk.sample_rate
        total = time.perf_counter() - t0
        audio = np.concatenate(chunks)
        dur = len(audio) / sr
        write_wav(OUT / "tts" / voice_id / lang / f"{i:02d}.wav", audio, sr)
        rows.append({"i": i, "ttfa_s": first, "total_s": total, "audio_s": dur, "rtf": total / dur})
    return summarize(voice_id, lang, load_s, rows)


def bench_mms(lang: str, model_dir: str) -> dict:
    import torch
    from transformers import AutoTokenizer, VitsModel

    t0 = time.perf_counter()
    model = VitsModel.from_pretrained(MODELS / model_dir).eval()
    tok = AutoTokenizer.from_pretrained(MODELS / model_dir)
    load_s = time.perf_counter() - t0
    sr = model.config.sampling_rate
    rows = []
    for i, text in enumerate(SENTENCES[lang], 1):
        inputs = tok(text, return_tensors="pt")
        torch.manual_seed(0)
        t0 = time.perf_counter()
        with torch.inference_mode():
            wav = model(**inputs).waveform[0].numpy()
        total = time.perf_counter() - t0
        audio = (np.clip(wav, -1, 1) * 32767).astype(np.int16)
        dur = len(audio) / sr
        write_wav(OUT / "tts" / model_dir / lang / f"{i:02d}.wav", audio, sr)
        # MMS-TTS is not streaming: first audio = whole sentence
        rows.append({"i": i, "ttfa_s": total, "total_s": total, "audio_s": dur, "rtf": total / dur})
    return summarize(model_dir, lang, load_s, rows)


def summarize(voice: str, lang: str, load_s: float, rows: list[dict]) -> dict:
    # first sentence includes warm-up; report warm numbers separately
    warm = rows[1:]
    res = {
        "voice": voice, "lang": lang, "load_s": round(load_s, 2),
        "ttfa_first_call_s": round(rows[0]["ttfa_s"], 3),
        "ttfa_warm_mean_s": round(float(np.mean([r["ttfa_s"] for r in warm])), 3),
        "ttfa_warm_max_s": round(float(np.max([r["ttfa_s"] for r in warm])), 3),
        "rtf_warm_mean": round(float(np.mean([r["rtf"] for r in warm])), 3),
        "rows": rows,
    }
    print(f"{voice:28s} {lang} load={res['load_s']}s ttfa_warm={res['ttfa_warm_mean_s']}s "
          f"(max {res['ttfa_warm_max_s']}s) rtf={res['rtf_warm_mean']}")
    return res


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--engines", default="piper,mms")
    args = ap.parse_args()
    engines = args.engines.split(",")
    import torch
    torch.set_num_threads(args.threads)

    results = []
    if "piper" in engines:
        for name, lang in [("fr/fr_FR/siwis/medium/fr_FR-siwis-medium", "fr"),
                           ("fr/fr_FR/upmc/medium/fr_FR-upmc-medium", "fr"),
                           ("en/en_US/lessac/medium/en_US-lessac-medium", "en"),
                           ("en/en_US/amy/medium/en_US-amy-medium", "en")]:
            results.append(bench_piper(name, lang))
    if "mms" in engines:
        results.append(bench_mms("rn", "mms-tts-run"))
    save_json(f"tts_{'_'.join(engines)}.json", {"threads": args.threads, "results": results})


if __name__ == "__main__":
    main()
