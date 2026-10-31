#!/usr/bin/env bash
# Download every voice model (build time only, never at runtime). ~4.9 GB.
#   scripts/download_models.sh [dest]     default dest: voice/models (gitignored); Docker build: /models
# Resumable (curl -C -): just re-run if the connection drops. Small models first.
set -euo pipefail
M="${1:-$(cd "$(dirname "$0")/.." && pwd)/models}"
HF=https://huggingface.co

get() {  # repo file dest_dir
  mkdir -p "$3"
  local out="$3/$(basename "$2")"
  for try in 1 2 3 4 5; do
    curl -sSfL -C - --retry 5 --retry-delay 5 --speed-time 60 --speed-limit 1000 \
      -o "$out" "$HF/$1/resolve/main/$2" && { echo "ok  $1/$2"; return 0; }
    echo "retry $try $1/$2"; sleep 5
  done
  return 1
}

for v in fr/fr_FR/siwis/medium/fr_FR-siwis-medium fr/fr_FR/upmc/medium/fr_FR-upmc-medium \
         en/en_US/lessac/medium/en_US-lessac-medium en/en_US/amy/medium/en_US-amy-medium; do
  for ext in .onnx .onnx.json; do
    [ -s "$M/piper/$v$ext" ] || get rhasspy/piper-voices "$v$ext" "$M/piper/$(dirname "$v")"
  done
done

for f in config.json vocab.json tokenizer_config.json special_tokens_map.json model.safetensors; do
  get facebook/mms-tts-run "$f" "$M/mms-tts-run"
done

for size in base small; do
  for f in config.json tokenizer.json vocabulary.txt model.bin; do
    get "Systran/faster-whisper-$size" "$f" "$M/faster-whisper-$size"
  done
done

for f in config.json preprocessor_config.json tokenizer_config.json special_tokens_map.json vocab.json \
         adapter.run.safetensors model.safetensors; do
  get facebook/mms-1b-all "$f" "$M/mms-1b-all"
done
echo ALL_DONE
