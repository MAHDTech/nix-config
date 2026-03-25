"""Whisper.cpp engine spec for speech-to-text."""

import logging
import subprocess
import sys

from huggingface.api import download_file, fetch_model_info
from core.log import console
from core.ports import PORT_STT
from engines import EngineSpec


def _handle_whisper(model_id: str, spec: EngineSpec, force_cpu: bool):
    """Custom handler — picks the right ggml .bin file."""
    console.print(
        f"🎤 [bold #00FF41]Starting Whisper Server for:[/bold #00FF41] {model_id}"
    )
    info = fetch_model_info(model_id)
    files = [f.rfilename for f in info.siblings]
    bin_files = [f for f in files if f.endswith(".bin") and "ggml" in f.lower()]

    if not bin_files:
        logging.error(f"No ggml .bin files found in {model_id}")
        console.print("[bold red]❌ No ggml .bin files found![/bold red]")
        sys.exit(1)

    target_file = next(
        (f for f in bin_files if "base.en" in f.lower()), bin_files[0]
    )
    console.print(f"⬇️  [dim]Fetching audio model: {target_file}...[/dim]")
    local_path = download_file(model_id, target_file)

    cmd = [
        "nix", "shell", "nixpkgs#whisper-cpp", "--command",
        "whisper-cpp-server", "-m", local_path, "--port", str(spec.port),
    ]
    console.print(
        f"[bold #008F11]🌐 STT API: http://127.0.0.1:{spec.port}[/bold #008F11]\n"
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
    name="whisper.cpp",
    nix_packages=["nixpkgs#whisper-cpp"],
    port=PORT_STT,
    custom_handler=_handle_whisper,
)
