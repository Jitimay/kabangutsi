# T3 Step 1 — voice model experiments (CPU only)

Everything here is throw-away test code: the real service comes after G0.
Results (JSON) are in `results/`; the summary table is in `status/T3.md`.

## Setup (Python 3.12, same as the Docker image)
```bash
uv venv --python 3.12 voice/experiments/.venv
VIRTUAL_ENV=voice/experiments/.venv uv pip install --index-strategy unsafe-best-match \
  --extra-index-url https://download.pytorch.org/whl/cpu \
  torch==2.5.1+cpu transformers==4.46.3 faster-whisper==1.1.0 piper-tts==1.3.0 onnxruntime==1.20.1 \
  soundfile jiwer "numpy<2.1" scipy librosa "huggingface_hub<1"
voice/experiments/download_models.sh       # ~4.9 GB into voice/models/ (gitignored), resumable
```
Then run everything offline from `voice/experiments/`:
```bash
.venv/bin/python tts_bench.py                 # Piper fr/en + MMS-TTS rn -> out/tts/, results/tts_*.json
.venv/bin/python make_stt_inputs.py           # 16 kHz STT test sets (+ phone-line copies, + espeak-ng)
.venv/bin/python stt_bench.py whisper --size base
.venv/bin/python stt_bench.py whisper --size small
.venv/bin/python stt_bench.py mms             # Kirundi, MMS-1b-all + run adapter (~4 GB RAM)
.venv/bin/python gemma_audio_test.py out/gemma/fr16.wav out/gemma/en16.wav   # needs ollama + gemma4:e4b
```

## Test audio — important limitation
No real recordings were available, so STT test audio is **synthetic**: Piper / MMS-TTS output, espeak-ng
(fr/en, a very different robotic voice) and a "phone" copy of each (8 kHz band-limit + noise at 20 dB SNR).
Real callers will be harder. For Kirundi the TTS and ASR models come from the same MMS project
(same Bible-reading training data), so the `rn` STT number is optimistic.

**To test with real voices:** record the 10 sentences of `sentences.py` (any format ffmpeg reads) as
`recordings/<lang>/01.wav … 10.wav`, then re-run `make_stt_inputs.py` and `stt_bench.py`; a `real` set appears.
The Kirundi sentences in `sentences.py` also need review by a native speaker.

## Files
| File | What |
|---|---|
| `sentences.py` | 10 synthetic banking sentences per language |
| `download_models.sh` | model download (build-time only) |
| `tts_bench.py` | TTS load time, time to first audio, real-time factor |
| `make_stt_inputs.py` | builds STT test sets |
| `stt_bench.py` | WER, language-ID, latency per 5 s of audio |
| `gemma_audio_test.py` | Gemma 4 audio input via Ollama |
