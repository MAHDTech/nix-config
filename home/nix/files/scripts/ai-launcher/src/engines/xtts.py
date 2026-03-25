"""XTTSv2 engine spec — Coqui TTS voice cloning via venv."""

from core.ports import PORT_TTS
from engines import EngineSpec


def _build_xtts_cmd(model_dir, model_id, device, venv_python, server_script, **kw):
    """Build the voice server command for XTTSv2."""
    model_name = model_id.split("/")[-1]
    return (
        f"'{venv_python}' '{server_script}' "
        f"--backend coqui "
        f"--device {device} --port {PORT_TTS} "
        f"--model-dir '{model_dir}' "
        f"--model-name '{model_name}'"
    )


SPEC = EngineSpec(
    name="xtts",
    pip_packages=["torch", "torchaudio", "torchcodec", "coqui-tts[codec]", "numpy", "transformers<5.0"],
    server_script="voice/server.py",
    port=PORT_TTS,
    needs_venv=True,
    needs_gpu_extras=True,
    venv_name="xtts",
    build_command=_build_xtts_cmd,
)
