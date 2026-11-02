"""Build a Kirundi-only int8 copy of MMS-1b-all (+ `run` adapter) with low peak RAM.

fp32 MMS-1b needs ~4 GB and was OOM-killed on the shared 16 GB demo machine. `from_pretrained` also
peaks at 6.3 GB here (it materialises fp32 weights), too much for a `docker build` next to other work.
So the model skeleton is created on the `meta` device in fp16, the weights are copied one tensor at a
time from the memory-mapped safetensors file, the `run` adapter is applied on top, and each Linear layer
is then quantised to int8 (dynamic quantisation).

    python scripts/quantize_mms.py [models_dir]     → <models_dir>/mms-1b-all/run-int8.pt
Measured: ~30 s, peak 2.4 GB anonymous RAM (+ reclaimable mmap pages), output 1.02 GB.
Run at build time (Dockerfile) or once locally; the service loads the .pt file (~2.6 GB RSS).
"""
import gc
import sys
import time
from pathlib import Path

import torch
from safetensors import safe_open
from torch.ao.nn.quantized.dynamic import Linear as QLinear
from torch.ao.quantization import default_dynamic_qconfig
from torch.nn.utils import parametrize
from transformers import Wav2Vec2Config, Wav2Vec2ForCTC

OUT_NAME = "run-int8.pt"  # app/stt.py INT8_FILE
LANG = "run"
# old weight_norm names in the checkpoint → torch parametrization names in the model
RENAME = {"weight_g": "parametrizations.weight.original0", "weight_v": "parametrizations.weight.original1"}


def _load_fp16(src: Path) -> Wav2Vec2ForCTC:
    with safe_open(src / f"adapter.{LANG}.safetensors", "pt") as f:
        adapter = {k: f.get_tensor(k) for k in f.keys()}  # 8.8 MB
    cfg = Wav2Vec2Config.from_pretrained(src)
    cfg.vocab_size = adapter["lm_head.weight"].shape[0]  # Kirundi alphabet, not the 154-token default
    torch.set_default_dtype(torch.float16)
    try:
        with torch.device("meta"):
            model = Wav2Vec2ForCTC(cfg)
    finally:
        torch.set_default_dtype(torch.float32)
    model = model.to_empty(device="cpu")
    state = model.state_dict()
    filled = set()
    with torch.no_grad(), safe_open(src / "model.safetensors", "pt") as f:
        for key in f.keys():
            head, _, leaf = key.rpartition(".")
            name = f"{head}.{RENAME[leaf]}" if leaf in RENAME else key
            if name in adapter or name.startswith("lm_head."):
                continue  # replaced by the Kirundi adapter below
            state[name].copy_(f.get_tensor(key))
            filled.add(name)
        for name, t in adapter.items():
            state[name].copy_(t)
            filled.add(name)
    missing = set(state) - filled
    if missing:
        raise RuntimeError(f"weights not loaded: {sorted(missing)[:5]}")
    model.config._name_or_path = str(src)
    return model.eval()


def quantize(models_dir: Path) -> Path:
    src = models_dir / "mms-1b-all"
    t0 = time.perf_counter()
    model = _load_fp16(src)
    # Names only: holding the modules would keep every fp32 copy alive (whole model in fp32 = OOM)
    names = [name for name, m in model.named_modules() if isinstance(m, torch.nn.Linear)]
    for name in names:
        parent_name, _, attr = name.rpartition(".")
        parent = model.get_submodule(parent_name) if parent_name else model
        lin = getattr(parent, attr).float()
        lin.qconfig = default_dynamic_qconfig
        setattr(parent, attr, QLinear.from_float(lin))
        del lin
    gc.collect()
    # weight_norm on the positional conv is a parametrization, which torch.save cannot pickle: bake it in
    for m in model.modules():
        if parametrize.is_parametrized(m):
            for pname in list(m.parametrizations.keys()):
                parametrize.remove_parametrizations(m, pname, leave_parametrized=True)
        m._load_state_dict_pre_hooks.clear()  # weight_norm compat hook is a local function (not picklable)
    model.float()  # what is left (conv feature encoder, norms) back to fp32 for CPU kernels
    out = src / OUT_NAME
    torch.save(model, out)
    print(f"saved {out} ({out.stat().st_size / 1e9:.2f} GB) in {time.perf_counter() - t0:.0f}s")
    return out


if __name__ == "__main__":
    quantize(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "models")
