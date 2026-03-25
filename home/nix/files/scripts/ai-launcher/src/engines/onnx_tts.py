"""ONNX TTS engine spec — no PyTorch needed, uses onnxruntime."""

from core.ports import PORT_TTS
from engines import EngineSpec


def _build_onnx_tts_cmd(model_dir, model_id, device, venv_python, server_script, **kw):
    """Build the voice server command for ONNX TTS."""
    model_name = model_id.split("/")[-1]
    return (
        f"'{venv_python}' '{server_script}' "
        f"--backend onnx "
        f"--device cpu --port {PORT_TTS} "
        f"--model-dir '{model_dir}' "
        f"--model-name '{model_name}'"
    )


SPEC = EngineSpec(
    name="onnx-tts",
    pip_packages=["onnxruntime", "numpy", "librosa", "soundfile", "tokenizers"],
    server_script="voice/server.py",
    port=PORT_TTS,
    needs_venv=True,
    needs_gpu_extras=False,
    venv_name="onnx-tts",
    build_command=_build_onnx_tts_cmd,
)
