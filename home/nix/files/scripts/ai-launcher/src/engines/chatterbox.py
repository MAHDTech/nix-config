"""Chatterbox TTS engine spec — zero-shot voice cloning."""

from core.ports import PORT_TTS
from engines import EngineSpec


def _build_chatterbox_cmd(model_dir, model_id, device, venv_python, server_script, **kw):
    """Build the voice server command for Chatterbox."""
    model_name = model_id.split("/")[-1]
    return (
        f"'{venv_python}' '{server_script}' "
        f"--backend chatterbox "
        f"--device {device} --port {PORT_TTS} "
        f"--model-dir '{model_dir}' "
        f"--model-name '{model_name}'"
    )


SPEC = EngineSpec(
    name="chatterbox",
    pip_packages=["chatterbox-tts"],
    server_script="voice/server.py",
    port=PORT_TTS,
    needs_venv=True,
    needs_gpu_extras=False,
    venv_name="chatterbox",
    build_command=_build_chatterbox_cmd,
)
