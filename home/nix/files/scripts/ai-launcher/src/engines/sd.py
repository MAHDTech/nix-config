"""Stable Diffusion (sd.cpp) engine spec."""

import logging
import subprocess
import sys

from huggingface.api import download_file, fetch_model_info
from core.log import console
from core.ports import PORT_IMAGE_GEN
from engines import EngineSpec


def _handle_sd(model_id: str, spec: EngineSpec, force_cpu: bool):
    """Custom handler — picks the right model file from the repo."""
    console.print(
        f"🎨 [bold #00FF41]Starting Image Server for:[/bold #00FF41] {model_id}"
    )
    info = fetch_model_info(model_id)
    files = [f.rfilename for f in info.siblings]
    valid_files = [
        f for f in files if f.endswith(".gguf") or f.endswith(".safetensors")
    ]

    if not valid_files:
        console.print(f"[bold red]❌ No model files found in {model_id}![/bold red]")
        sys.exit(1)

    target_file = next(
        (f for f in valid_files if "q4_k" in f.lower()), valid_files[0]
    )

    console.print(f"⬇️  [dim]Fetching model weights...[/dim]")
    logging.info(f"Fetching sd.cpp model weights: {target_file}")
    local_path = download_file(model_id, target_file)

    cmd = [
        "nix", "shell", "nixpkgs#stable-diffusion-cpp", "--command",
        "sd-server", "-m", local_path, "--port", str(spec.port),
    ]
    console.print(
        f"[bold #008F11]🌐 Image API: http://127.0.0.1:{spec.port}[/bold #008F11]\n"
    )
    logging.info(f"Executing command: {' '.join(cmd)}")
    try:
        proc = subprocess.Popen(cmd)
        proc.wait()
    except KeyboardInterrupt:
        logging.info("Caught KeyboardInterrupt, shutting down server")
        proc.terminate()
        console.print("\n[bold #00FF41]✅ Server stopped.[/bold #00FF41]")


SPEC = EngineSpec(
    name="sd.cpp",
    nix_packages=["nixpkgs#stable-diffusion-cpp"],
    port=PORT_IMAGE_GEN,
    custom_handler=_handle_sd,
)
