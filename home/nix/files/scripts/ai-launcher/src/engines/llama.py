"""llama.cpp engine — custom handler for GGUF file selection and VRAM budgeting."""

import logging
import subprocess
import sys

from huggingface.api import download_file, fetch_model_info
from core.log import console
from system.specs import get_system_specs
from core.ports import PORT_LLM
from engines import EngineSpec


def _handle_llama(model_id: str, spec: EngineSpec, force_cpu: bool):
    """Full custom handler for llama.cpp — GGUF file selection, VRAM math, nix-shell."""
    console.print(
        f"\n🌐 [bold #00FF41]Contacting Hugging Face API for:[/bold #00FF41] {model_id}"
    )

    info = fetch_model_info(model_id)
    files = [f.rfilename for f in info.siblings]
    ggufs = [f for f in files if f.endswith(".gguf")]

    if not ggufs:
        logging.error(f"No GGUF files found in {model_id}")
        console.print(f"[bold red]❌ No GGUF files found in {model_id}![/bold red]")
        sys.exit(1)

    # Find main model with preferred quant
    quant = "Q4_K"  # Default preference
    target_file = next((f for f in ggufs if quant.lower() in f.lower()), None)
    if not target_file:
        target_file = next(
            (f for f in ggufs if "q4_0" in f.lower() or "q4_k" in f.lower()),
            ggufs[0],
        )
        logging.debug(f"Preferred quant not found, falling back to {target_file}")

    console.print(f"🎯 [bold #00FF41]Resolved File:[/bold #00FF41] {target_file}")
    logging.info(f"Target file resolved: {target_file}")

    # Find Vision Projector (if Multimodal)
    mmproj_file = None
    for f in ggufs:
        if "mmproj" in f.lower():
            mmproj_file = f
            console.print(
                f"👁️ [bold #00FF41]Vision Projector detected:[/bold #00FF41] {mmproj_file}"
            )
            break

    vendor, sys_ram, gpu_ram, ctx_size = get_system_specs(model_id, False, force_cpu)
    short_name = model_id.split("/")[-1].replace("-GGUF", "").replace("-gguf", "")

    nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp"
    if vendor not in ["cpu", "nvidia"] and not force_cpu:
        nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp-vulkan"

    console.print(
        f"🚀 [bold #00FF41]Igniting llama-server ({vendor.upper()} Mode)...[/bold #00FF41]"
    )
    console.print(
        f"[bold #008F11]🌐 Chat UI + API: http://127.0.0.1:{spec.port}[/bold #008F11]\n"
    )

    cmd = [
        "nix", "shell", "--impure", nix_package, "--command",
        "llama-server",
        "--hf-repo", model_id,
        "--hf-file", target_file,
        "--host", "127.0.0.1",
        "--port", str(spec.port),
        "--ctx-size", str(ctx_size),
        "--alias", short_name,
    ]

    if mmproj_file:
        console.print(f"⬇️  [dim]Downloading Vision Projector...[/dim]")
        local_mmproj = download_file(model_id, mmproj_file)
        cmd.extend(["--mmproj", local_mmproj])

    # Check if embedding mode
    if vendor != "cpu" and not force_cpu:
        cmd.extend(["--n-gpu-layers", "999"])

    logging.info(f"Executing command: {' '.join(cmd)}")
    try:
        proc = subprocess.Popen(cmd)
        proc.wait()
    except KeyboardInterrupt:
        logging.info("Caught KeyboardInterrupt, shutting down server")
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        console.print("\n[bold #00FF41]✅ Server stopped.[/bold #00FF41]")


SPEC = EngineSpec(
    name="llama.cpp",
    nix_packages=["github:NixOS/nixpkgs/nixos-unstable#llama-cpp"],
    port=PORT_LLM,
    custom_handler=_handle_llama,
)
