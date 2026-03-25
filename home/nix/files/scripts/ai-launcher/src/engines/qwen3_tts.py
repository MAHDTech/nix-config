"""Qwen3-TTS GGUF engine spec — CPU-only TTS via py-qwen3-tts-cpp."""

from core.ports import PORT_TTS
from engines import EngineSpec


def _build_qwen3_tts_cmd(model_dir, model_id, device, venv_python, server_script, **kw):
    """Build the voice server command for Qwen3-TTS GGUF."""
    model_name = model_id.split("/")[-1]
    return (
        f"'{venv_python}' '{server_script}' "
        f"--backend qwen3 "
        f"--device cpu --port {PORT_TTS} "
        f"--model-dir '{model_dir}' "
        f"--model-name '{model_name}'"
    )


SPEC = EngineSpec(
    name="qwen3-tts-gguf",
    pip_packages=["git+https://github.com/femelo/py-qwen3-tts-cpp", "numpy", "soundfile"],
    server_script="voice/server.py",
    port=PORT_TTS,
    needs_venv=True,
    needs_gpu_extras=False,
    venv_name="qwen3-tts",
    build_command=_build_qwen3_tts_cmd,
)
