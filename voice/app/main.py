"""Kabangutsi voice service (STT + TTS). Contract: contracts/voice_api.yaml. Port 8001, internal."""
import logging
import time
from contextlib import asynccontextmanager
from typing import Literal

from fastapi import FastAPI, File, Form, Response, UploadFile
from pydantic import BaseModel, ConfigDict, Field

from . import audio as audio_mod
from . import errors
from .config import PIPER_VOICES, Settings
from .errors import ApiError
from .stt import MmsStt, WhisperStt
from .tts import MmsTts, PhraseCache, PiperTts

log = logging.getLogger("voice")
Lang = Literal["fr", "en", "rn"]


class Engines:
    """Everything loaded once at startup. A model that fails to load leaves the service `degraded`."""

    def __init__(self, s: Settings):
        self.s = s
        self.whisper: WhisperStt | None = None
        self.mms_stt: MmsStt | None = None
        self.tts: dict[str, list] = {"fr": [], "en": [], "rn": []}  # default voice first
        self.phrases = PhraseCache()
        self.failed: dict[str, str] = {}

    def _try(self, name: str, fn):
        t0 = time.perf_counter()
        try:
            out = fn()
            log.info("loaded %s in %.1fs", name, time.perf_counter() - t0)
            return out
        except Exception as e:  # keep serving the other languages
            log.exception("failed to load %s", name)
            self.failed[name] = f"{type(e).__name__}: {e}"[:300]
            return None

    def load(self) -> "Engines":
        s, wanted = self.s, self.s.engines
        if "whisper" in wanted:
            self.whisper = self._try("whisper", lambda: WhisperStt(s.models_dir, s.whisper_size, s.threads))
            if self.whisper and s.lid_referee and s.lid_referee != s.whisper_size:
                self.whisper.referee = self._try(
                    "lid_referee", lambda: WhisperStt(s.models_dir, s.lid_referee, s.threads))
        if "mms_stt" in wanted:
            self.mms_stt = self._try("mms_stt", lambda: MmsStt(s.models_dir, s.threads, s.mms_stt_dtype))
        if "piper" in wanted:
            for vid, (lang, rel, gender, default) in PIPER_VOICES.items():
                eng = self._try(f"piper/{vid}",
                                lambda: PiperTts(vid, lang, s.models_dir / "piper" / rel, gender, default))
                if eng:
                    self.tts[lang].insert(0 if default else len(self.tts[lang]), eng)
        if "mms_tts" in wanted:
            eng = self._try("mms_tts", lambda: MmsTts(s.models_dir, s.threads))
            if eng:
                self.tts["rn"].insert(0, eng)
        self._try("phrase_cache", lambda: self.phrases.load(s.phrases_file, s.prerecorded_dir, self.tts))
        return self

    def models(self) -> dict[str, str]:
        m = {}
        if self.whisper:
            m["stt_fr"] = m["stt_en"] = self.whisper.name
        if self.whisper and getattr(self.whisper, "referee", None):
            m["lang_id_referee"] = self.whisper.referee.name
        if self.mms_stt:
            m["stt_rn"] = self.mms_stt.name
        for lang, engines in self.tts.items():
            if engines:
                e = engines[0]
                m[f"tts_{lang}"] = f"piper/{e.voice.id}" if e.voice.engine == "piper" else e.voice.id
        return m

    def complete(self) -> bool:
        return not self.failed and all(k in self.models() for k in
                                       ("stt_fr", "stt_en", "stt_rn", "tts_fr", "tts_en", "tts_rn"))


def create_app(engines: Engines | None = None) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if engines is None:
            logging.basicConfig(level=logging.INFO)
            app.state.engines = Engines(Settings()).load()
        else:
            app.state.engines = engines
        yield

    app = FastAPI(title="Kabangutsi voice", version="1.0.0", lifespan=lifespan)
    errors.install(app)

    def eng() -> Engines:
        return app.state.engines

    @app.get("/health")
    def health():
        e = eng()
        body = {"status": "ok" if e.complete() else "degraded", "models": e.models()}
        if e.failed:
            body["failed"] = e.failed
        return body

    @app.get("/voices")
    def voices():
        return {"voices": [v.voice.public() for lang in ("fr", "en", "rn") for v in eng().tts[lang]]}

    @app.post("/stt")
    def stt(audio: UploadFile = File(...), lang: Lang | None = Form(None)):
        e, s = eng(), eng().s
        data = audio.file.read(s.max_audio_bytes + 1)
        if len(data) > s.max_audio_bytes:
            raise ApiError(413, "too_large", "audio larger than 20 MB", {"max_bytes": s.max_audio_bytes})
        t0 = time.perf_counter()
        pcm = audio_mod.decode(data, s.max_audio_seconds)
        detected = lang is None
        res = None
        if detected and e.whisper:
            # Whisper detects fr/en and transcribes in one pass; None = looks like Kirundi.
            # Without the Kirundi model, never answer rn: threshold 0 keeps fr/en.
            res = e.whisper.transcribe_auto(pcm, s.rn_lid_threshold if e.mms_stt else 0.0)
            lang = res.lang if res else "rn"
        elif detected:
            lang = "rn"
        if res is None:
            if lang == "rn":
                if not e.mms_stt:
                    raise ApiError(503, "internal_error", "Kirundi STT model not loaded")
                res = e.mms_stt.transcribe(pcm)
            else:
                if not e.whisper:
                    raise ApiError(503, "internal_error", "fr/en STT model not loaded")
                res = e.whisper.transcribe(pcm, lang)
        return {"text": res.text, "lang": res.lang, "confidence": res.confidence,
                "duration_ms": int(len(pcm) / audio_mod.SR * 1000),
                "processing_ms": int((time.perf_counter() - t0) * 1000),
                "lang_detected": detected, "model": res.model}

    class TtsRequest(BaseModel):
        model_config = ConfigDict(extra="forbid")
        text: str = Field(min_length=1, max_length=600)
        lang: Lang
        voice: str | None = None
        speed: float = Field(1.0, ge=0.5, le=2.0)

    @app.post("/tts")
    def tts(req: TtsRequest):
        e = eng()
        t0 = time.perf_counter()
        if not req.text.strip():
            raise ApiError(422, "validation_error", "text is empty", {"field": "text"})
        candidates = e.tts[req.lang]
        if req.voice is not None:
            candidates = [v for v in candidates if v.voice.id == req.voice]
            if not candidates:
                raise ApiError(422, "validation_error", f"unknown voice {req.voice!r} for lang {req.lang}",
                               {"field": "voice"})
        # Phrase cache: only for the default voice at normal speed (pre-recorded = the agreed rn fallback)
        hit = e.phrases.get(req.lang, req.text) if req.voice is None and req.speed == 1.0 else None
        if hit:
            pcm, sr, voice_id = hit
            fallback = "phrase_cache"
        else:
            if not candidates:
                raise ApiError(503, "internal_error", f"no TTS voice loaded for {req.lang}")
            engine = candidates[0]
            pcm, sr, voice_id = engine.synth(req.text, req.speed), engine.voice.sample_rate, engine.voice.id
            fallback = "none"
        return Response(audio_mod.to_wav(pcm, sr), media_type="audio/wav", headers={
            "X-Voice-Id": voice_id, "X-Voice-Fallback": fallback,
            "X-Duration-Ms": str(int(len(pcm) / sr * 1000)),
            "X-Processing-Ms": str(int((time.perf_counter() - t0) * 1000))})

    return app


app = create_app()
