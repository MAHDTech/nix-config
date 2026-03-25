"""Engine specifications — EngineSpec dataclass and registry."""

from dataclasses import dataclass, field
from typing import Callable, Optional


@dataclass
class EngineSpec:
    """Declares everything needed to run a model with a particular engine."""

    name: str
    nix_packages: list[str] = field(default_factory=list)
    pip_packages: list[str] = field(default_factory=list)
    server_script: Optional[str] = None    # Relative to src/, e.g. "voice/server.py"
    port: int = 8080
    needs_venv: bool = False
    needs_gpu_extras: bool = False          # Whether to install IPEX for Intel
    venv_name: str = "ai-launcher"          # Cache dir: ~/.cache/{venv_name}/venv
    custom_handler: Optional[Callable] = None
    build_command: Optional[Callable] = None  # Builds the run command

    def __post_init__(self):
        if self.pip_packages and not self.needs_venv:
            self.needs_venv = True


def get_engine_specs() -> dict[str, EngineSpec]:
    """Build and return the full engine spec registry.

    Import here to avoid circular imports — each engine module registers its spec.
    """
    from engines.chatterbox import SPEC as chatterbox_spec
    from engines.llama import SPEC as llama_spec
    from engines.onnx_tts import SPEC as onnx_tts_spec
    from engines.piper import SPEC as piper_spec
    from engines.qwen3_tts import SPEC as qwen3_tts_spec
    from engines.sd import SPEC as sd_spec
    from engines.whisper import SPEC as whisper_spec
    from engines.xtts import SPEC as xtts_spec

    specs = {
        "llama.cpp": llama_spec,
        "llama.cpp-embedding": llama_spec,  # Same engine, embedding flag added later
        "sd.cpp": sd_spec,
        "whisper.cpp": whisper_spec,
        "piper": piper_spec,
        "xtts": xtts_spec,
        "qwen3-tts-gguf": qwen3_tts_spec,
        "onnx-tts": onnx_tts_spec,
        "chatterbox": chatterbox_spec,
    }

    return specs
