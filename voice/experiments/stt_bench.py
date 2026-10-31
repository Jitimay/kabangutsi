"""STT benchmark: faster-whisper (fr, en; int8) and Meta MMS-1b-all + `run` adapter (rn) on CPU.

Reads out/stt_input/<lang>/<source>/NN.wav (built by make_stt_inputs.py), reports
WER, language-ID accuracy (whisper, no hint) and latency normalised to 5 s of audio.

    python stt_bench.py whisper --size small [--threads 4]
    python stt_bench.py mms [--threads 4]
"""
import argparse
import time

import jiwer
import numpy as np
import soundfile as sf

from common import MODELS, OUT, machine_state, normalize, save_json
from sentences import SENTENCES

INPUT = OUT / "stt_input"


def sets(langs):
    for lang in langs:
        for d in sorted((INPUT / lang).iterdir()):
            files = sorted(d.glob("*.wav"))
            if files:
                yield lang, d.name, files


def score(lang, source, rows, model):
    refs = [normalize(SENTENCES[lang][int(r["file"][:2]) - 1]) for r in rows]
    hyps = [normalize(r["text"]) or "<empty>" for r in rows]
    wer = jiwer.wer(refs, hyps)
    audio = sum(r["audio_s"] for r in rows)
    proc = sum(r["proc_s"] for r in rows)
    res = {"model": model, "lang": lang, "source": source, "n": len(rows),
           "wer": round(wer, 3), "word_acc": round(1 - wer, 3),
           "latency_per_5s_audio_s": round(proc / audio * 5, 3), "rtf": round(proc / audio, 3),
           "rows": rows}
    if rows and "detected" in rows[0]:
        res["langid_acc"] = round(np.mean([r["detected"] == lang for r in rows]), 2)
        res["detected"] = sorted({r["detected"] for r in rows})
    print(f"{model:22s} {lang} {source:24s} WER={res['wer']:.3f} lat/5s={res['latency_per_5s_audio_s']:.2f}s"
          + (f" langid={res['langid_acc']} {res['detected']}" if "langid_acc" in res else ""))
    return res


def run_whisper(size, threads, langs):
    from faster_whisper import WhisperModel

    before = machine_state()

    t0 = time.perf_counter()
    model = WhisperModel(str(MODELS / f"faster-whisper-{size}"), device="cpu",
                         compute_type="int8", cpu_threads=threads)
    load_s = time.perf_counter() - t0
    # warm-up
    model.transcribe(np.zeros(16000, dtype=np.float32), language="en")
    results = []
    for lang, source, files in sets(langs):
        for mode in ("hint", "auto") if lang in ("fr", "en") else ("auto",):
            rows = []
            for f in files:
                y, sr = sf.read(f, dtype="float32")
                t0 = time.perf_counter()
                segs, info = model.transcribe(y, language=lang if mode == "hint" else None,
                                              beam_size=1, vad_filter=False,
                                              condition_on_previous_text=False)
                text = " ".join(s.text for s in segs).strip()
                rows.append({"file": f.name, "text": text, "audio_s": len(y) / sr,
                             "proc_s": time.perf_counter() - t0, "detected": info.language,
                             "detected_p": round(info.language_probability, 2)})
            if mode == "hint":
                for r in rows:
                    r.pop("detected"), r.pop("detected_p")
            results.append(score(lang, f"{source}[{mode}]", rows, f"whisper-{size}-int8"))
    save_json(f"stt_whisper_{size}.json", {"threads": threads, "load_s": round(load_s, 2),
                                           "beam_size": 1, "machine_before": before, "results": results})


def run_mms(threads, langs):
    import torch
    from transformers import AutoProcessor, Wav2Vec2ForCTC

    torch.set_num_threads(threads)
    before = machine_state()
    path = MODELS / "mms-1b-all"
    t0 = time.perf_counter()
    processor = AutoProcessor.from_pretrained(path)
    model = Wav2Vec2ForCTC.from_pretrained(path, target_lang="run", ignore_mismatched_sizes=True,
                                           use_safetensors=True).eval()
    processor.tokenizer.set_target_lang("run")
    load_s = time.perf_counter() - t0
    results = []
    for lang, source, files in sets(langs):
        rows = []
        for f in files:
            y, sr = sf.read(f, dtype="float32")
            t0 = time.perf_counter()
            inputs = processor(y, sampling_rate=sr, return_tensors="pt")
            with torch.inference_mode():
                ids = model(**inputs).logits.argmax(-1)[0]
            text = processor.decode(ids)
            rows.append({"file": f.name, "text": text, "audio_s": len(y) / sr,
                         "proc_s": time.perf_counter() - t0})
        results.append(score(lang, source, rows, "mms-1b-all+run"))
    save_json("stt_mms_run.json", {"threads": threads, "load_s": round(load_s, 2), "machine_before": before,
                                     "results": results})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("engine", choices=["whisper", "mms"])
    ap.add_argument("--size", default="small")
    ap.add_argument("--threads", type=int, default=4)
    a = ap.parse_args()
    print("machine before:", machine_state())
    if a.engine == "whisper":
        run_whisper(a.size, a.threads, ["fr", "en", "rn"])
    else:
        run_mms(a.threads, ["rn"])


if __name__ == "__main__":
    main()
