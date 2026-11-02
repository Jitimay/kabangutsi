"""Settings from environment variables (all optional)."""
import os
from dataclasses import dataclass, field
from pathlib import Path


def _env(name: str, default: str) -> str:
    return os.environ.get(name, default)


@dataclass(frozen=True)
class Settings:
    models_dir: Path = field(default_factory=lambda: Path(_env("VOICE_MODELS_DIR", "/models")))
    threads: int = field(default_factory=lambda: int(_env("VOICE_THREADS", "4")))
    # faster-whisper size for fr/en. "base": 1-2 s per sentence on the shared 8-core demo machine, French
    # WER 13-20 %. "small": French WER 5 % but 3-7 s, which breaks the 3 s turn budget (status/T3.md).
    whisper_size: str = field(default_factory=lambda: _env("VOICE_WHISPER_SIZE", "base"))
    # Second-opinion language ID for ambiguous auto-detect ("" = off). Ignored if equal to whisper_size.
    lid_referee: str = field(default_factory=lambda: _env("VOICE_LID_REFEREE", "small"))
    # MMS-1b dtype: int8 (prebuilt run-int8.pt, ~2.6 GB RSS) or fp32 (needs model.safetensors, ~4 GB RSS)
    mms_stt_dtype: str = field(default_factory=lambda: _env("VOICE_MMS_STT_DTYPE", "int8"))
    # Auto-detect: if Whisper's P(fr)+P(en) is below this, the audio is treated as Kirundi
    rn_lid_threshold: float = field(default_factory=lambda: float(_env("VOICE_RN_LID_THRESHOLD", "0.5")))
    # Comma list of engines to load: whisper,mms_stt,piper,mms_tts (tests can load fewer)
    engines: tuple[str, ...] = field(default_factory=lambda: tuple(
        e.strip() for e in _env("VOICE_ENGINES", "whisper,mms_stt,piper,mms_tts").split(",") if e.strip()))
    phrases_file: Path = field(default_factory=lambda: Path(
        _env("VOICE_PHRASES_FILE", str(Path(__file__).resolve().parent.parent / "phrases" / "phrases.json"))))
    # Generated phrase audio survives restarts here (inside the voice-models volume); "" = memory only
    phrase_cache_dir: str = field(default_factory=lambda: _env("VOICE_PHRASE_CACHE_DIR", ""))
    # Pre-recorded human audio overrides generated phrases: <dir>/<lang>/<id>.wav
    prerecorded_dir: Path = field(default_factory=lambda: Path(
        _env("VOICE_PRERECORDED_DIR", str(Path(__file__).resolve().parent.parent / "phrases"))))

    max_audio_bytes: int = 20 * 1024 * 1024
    max_audio_seconds: float = 60.0


PIPER_VOICES = {
    # id: (lang, relative path under models_dir/piper, gender, default)
    "fr_FR-siwis-medium": ("fr", "fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx", "female", True),
    "fr_FR-upmc-medium": ("fr", "fr/fr_FR/upmc/medium/fr_FR-upmc-medium.onnx", None, False),
    "en_US-lessac-medium": ("en", "en/en_US/lessac/medium/en_US-lessac-medium.onnx", "male", True),
    "en_US-amy-medium": ("en", "en/en_US/amy/medium/en_US-amy-medium.onnx", "female", False),
}
