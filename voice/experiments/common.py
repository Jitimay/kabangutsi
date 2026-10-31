import json
import os
import re
import unicodedata
from pathlib import Path

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

HERE = Path(__file__).resolve().parent
MODELS = HERE.parent / "models"
OUT = HERE / "out"
RESULTS = HERE / "results"
OUT.mkdir(exist_ok=True)
RESULTS.mkdir(exist_ok=True)


def normalize(text: str) -> str:
    """Lowercase, strip punctuation, unify apostrophes; keep accents (they matter in French)."""
    t = unicodedata.normalize("NFC", text.lower()).replace("’", "'")
    t = re.sub(r"[^\w\s']", " ", t)
    t = t.replace("'", " ")
    return re.sub(r"\s+", " ", t).strip()


def machine_state() -> dict:
    """Load and free RAM at measurement time: other terminals share this CPU (see CLAUDE.md)."""
    mem = dict(line.split(":") for line in open("/proc/meminfo"))
    return {"loadavg_1m": round(os.getloadavg()[0], 2),
            "mem_available_gb": round(int(mem["MemAvailable"].split()[0]) / 1e6, 1)}


def save_json(name: str, data) -> Path:
    if isinstance(data, dict):
        data["machine_after"] = machine_state()
    p = RESULTS / name
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    return p
