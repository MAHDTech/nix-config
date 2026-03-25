"""Piper TTS engine spec — lightweight ONNX-based TTS via nix-shell."""

import logging
import subprocess
import sys

from huggingface.api import download_file, fetch_model_info
from core.log import console
from core.ports import PORT_TTS
from engines import EngineSpec


def _build_piper_cmd(model_dir, model_id, device, venv_python, server_script, **kw):
    """Build the voice server command for Piper TTS."""
    model_name = model_id.split("/")[-1]
    return (
        f"'{venv_python}' '{server_script}' "
        f"--backend piper "
        f"--device cpu --port {PORT_TTS} "
        f"--model-dir '{model_dir}' "
        f"--model-name '{model_name}'"
    )

SPEC = EngineSpec(
    name="piper",
    nix_packages=["nixpkgs#piper-tts"],
    pip_packages=[],  # No pip dependencies needed, relies entirely on standard lib + nix piper binary
    server_script="voice/server.py",
    port=PORT_TTS,
    needs_venv=True,
    needs_gpu_extras=False,
    venv_name="piper",
    build_command=_build_piper_cmd,
)
