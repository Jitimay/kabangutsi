# Phrase cache

`phrases.json`: frequent replies per language. At startup the service generates each one with the
default voice of its language and keeps it in memory, so `POST /tts` with exactly that text (case,
spaces and final punctuation ignored) answers instantly with `X-Voice-Fallback: phrase_cache`.

**Pre-recorded human voice** (Kirundi fallback): put a 16-bit mono WAV at `<lang>/<phrase id>.wav`,
e.g. `rn/greeting.wav`. It replaces the generated audio for that phrase.
The Kirundi texts need review by a native speaker.
