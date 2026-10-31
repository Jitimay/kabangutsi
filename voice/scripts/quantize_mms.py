"""Build a Kirundi-only int8 copy of MMS-1b-all (+ `run` adapter) with low peak RAM.

fp32 MMS-1b needs ~4 GB and was OOM-killed on the shared 16 GB demo machine. This loads the model in
fp16, then quantises each Linear layer to int8 one at a time (dynamic quantisation).
Measured 2026-10-31: peak RSS 6.3 GB during the build (from_pretrained still materialises fp32 weights),
output file 1.02 GB, ~2.6 GB RSS when loaded for inference.

    python scripts/quantize_mms.py [models_dir]     → <models_dir>/mms-1b-all/run-int8.pt
Run at build time (Dockerfile) or once locally; the service loads the .pt file.
"""
import gc
import sys
import time
from pathlib import Path

import torch
from torch.ao.nn.quantized.dynamic import Linear as QLinear
from torch.ao.quantization import default_dynamic_qconfig
from transformers import Wav2Vec2ForCTC

OUT_NAME = "run-int8.pt"


def quantize(models_dir: Path) -> Path:
    src = models_dir / "mms-1b-all"
    t0 = time.perf_counter()
    model = Wav2Vec2ForCTC.from_pretrained(src, target_lang="run", ignore_mismatched_sizes=True,
                                           use_safetensors=True, torch_dtype=torch.float16).eval()
    linears = [(name, m) for name, m in model.named_modules() if isinstance(m, torch.nn.Linear)]
    for name, lin in linears:
        parent = model.get_submodule(name.rsplit(".", 1)[0]) if "." in name else model
        lin.float()
        lin.qconfig = default_dynamic_qconfig
        setattr(parent, name.rsplit(".", 1)[-1], QLinear.from_float(lin))
        del lin
    del linears
    gc.collect()
    # weight_norm on the positional conv is a parametrization, which torch.save cannot pickle: bake it in
    from torch.nn.utils import parametrize
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
