import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

import psutil
from huggingface_hub import HfApi, hf_hub_download
from rich import print as rprint
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt

console = Console()
api = HfApi()

# --- 🛒 DYNAMIC MODEL CATALOG ---
CATALOG = {
    "💬 General Chat": [
        "bartowski/gemma-2-9b-it-GGUF",
        "maziyarpanahi/Mistral-7B-Instruct-v0.3-GGUF",
        "bartowski/Meta-Llama-3.1-8B-Instruct-GGUF",
    ],
    "💻 Coding & Dev": [
        "Tesslate/OmniCoder-9B-GGUF",
        "Qwen/Qwen2.5-Coder-14B-Instruct-GGUF",
        "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF",
        "Qwen/Qwen2.5-Coder-3B-Instruct-GGUF",
        "bartowski/Meta-Llama-3.1-8B-Instruct-GGUF",
    ],
    "👁️ Vision (Image to Text)": [
        "xtuner/llava-phi-3-mini-gguf",
        "cjpais/llava-1.5-7b-gguf"
    ],
    "🧠 Math & Logic": [
        "bartowski/Phi-3-mini-4k-instruct-GGUF",
        "Qwen/Qwen2-Math-7B-Instruct-GGUF",
    ],
    "🗃️ Text Embeddings": [
        "nomic-ai/nomic-embed-text-v1.5-GGUF"
    ],
    "🎨 Image Generation": [
        "leejet/FLUX.1-schnell-gguf",
        "stablediffusionapi/turbovisionxl"
    ],
    "🎤 Speech to Text": [
        "ggerganov/whisper.cpp"
    ],
    "🔊 Text to Speech": [
        "en_US-lessac-medium",
        "en_GB-alba-medium",
        "fishaudio/s2-pro"
    ]
}

def stop_server():
    """Finds and kills orphaned AI server processes."""
    killed = False
    process_names = ["llama-server", "sd-server", "piper", "whisper-server", "whisper-cpp-server"]
    for proc in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            name = proc.info["name"] or ""
            cmdline = " ".join(proc.info["cmdline"] or [])
            if any(p in name for p in process_names) or any(p in cmdline for p in process_names):
                os.kill(proc.info["pid"], 9)
                killed = True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    if killed:
        console.print("[green]✅ AI server stopped successfully.[/green]")
    else:
        console.print("[yellow]⚠️ No running AI server found.[/yellow]")

def get_gpu_vendor_and_vram():
    """Programmatically gets exact VRAM and GPU Vendor."""
    try:
        output = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            text=True, stderr=subprocess.DEVNULL
        )
        return "nvidia", float(output.strip()) / 1024.0
    except Exception:
        pass

    try:
        hwmon_paths = list(Path("/sys/class/drm").glob("card*/device/mem_info_vram_total"))
        if hwmon_paths:
            with open(hwmon_paths[0], "r") as f:
                vram_bytes = int(f.read().strip())
                return "amd", vram_bytes / (1024**3)
    except Exception:
        pass

    return "cpu", 0.0

def get_system_specs(model_name: str, split: bool = False, force_cpu: bool = False):
    """Calculates dynamic context sizing using strict mathematical VRAM/RAM budgeting."""
    sys_mem_bytes = psutil.virtual_memory().available
    sys_mem_gb = sys_mem_bytes / (1024**3)

    if force_cpu:
        vendor = "cpu"
        total_gpu_vram = 0.0
    else:
        vendor, total_gpu_vram = get_gpu_vendor_and_vram()

    model_upper = model_name.upper()
    param_match = re.search(r"(\d+(?:\.\d+)?)B", model_upper)
    params_b = float(param_match.group(1)) if param_match else 7.0

    brain_gb = params_b * 0.65

    if vendor == "cpu" or force_cpu:
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [262144, 131072, 65536, 32768, 16384, 8192, 4096]
        split = False
    elif split:
        gpu_budget = total_gpu_vram * 0.90
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [262144, 131072, 65536, 32768, 16384, 8192, 4096]
    else:
        gpu_budget = total_gpu_vram * 0.75
        desk_gb = gpu_budget - brain_gb
        fixed_sizes = [131072, 65536, 32768, 16384, 8192, 4096]

    ctx_size = 4096
    return vendor, sys_mem_gb, total_gpu_vram, ctx_size

def interactive_menu():
    """Renders the Rich terminal UI for model selection."""
    console.print(Panel.fit("🤖 [bold cyan]UNIVERSAL AI LAUNCHER[/bold cyan] (Auto-Scaling GPU & Backend)", border_style="cyan"))

    categories = list(CATALOG.keys())
    for idx, cat in enumerate(categories, 1):
        console.print(f"[bold white]{idx}.[/bold white] {cat}")
    console.print(f"[bold white]{len(categories) + 1}.[/bold white] Cancel / Exit\n")

    cat_choice = Prompt.ask("👉 Choose a category", choices=[str(i) for i in range(1, len(categories) + 2)])

    if int(cat_choice) == len(categories) + 1:
        console.print("Exiting...")
        sys.exit(0)

    selected_cat = categories[int(cat_choice) - 1]
    console.print(f"\n[bold cyan]{selected_cat.upper()} MODELS[/bold cyan]")

    models = CATALOG[selected_cat]
    for idx, mod in enumerate(models, 1):
        console.print(f"[bold white]{idx}.[/bold white] {mod}")

    mod_choice = Prompt.ask("\n👉 Select a model", choices=[str(i) for i in range(1, len(models) + 1)])
    return models[int(mod_choice) - 1]

def auto_detect_engine(model_id: str) -> str:
    # Handle local / non-HuggingFace exceptions
    if model_id in ["en_US-lessac-medium", "en_GB-alba-medium"]: return "piper"
    if model_id == "fishaudio/s2-pro": return "docker-fishaudio"
    if "whisper" in model_id.lower(): return "whisper.cpp"

    try:
        console.print(f"🔍 [dim]Querying Hugging Face API to detect engine for {model_id}...[/dim]")
        info = api.model_info(model_id)
        task = getattr(info, "pipeline_tag", None)
        tags = getattr(info, "tags", []) or []
        files = [f.rfilename for f in getattr(info, "siblings", [])]

        if task == "text-generation" or task == "image-text-to-text":
            return "llama.cpp"
        elif task == "feature-extraction":
            return "llama.cpp-embedding"
        elif task == "text-to-image":
            return "sd.cpp"
        elif task == "automatic-speech-recognition":
            return "whisper.cpp"
        elif task == "text-to-speech":
            if any(f.endswith('.onnx') for f in files) or "piper" in tags:
                return "piper"
            else:
                return "docker-fishaudio"
        else:
            if any(f.endswith('.gguf') for f in files): return "llama.cpp"
    except Exception:
        pass
    return "llama.cpp"

def start_server(model_id: str, quant: str, split: bool, force_cpu: bool):
    engine_type = auto_detect_engine(model_id)
    console.print(f"⚙️  [cyan]Auto-detected Engine:[/cyan] [bold white]{engine_type}[/bold white]")

    if "llama.cpp" in engine_type:
        console.print(f"\n🌐 [cyan]Contacting Hugging Face API for:[/cyan] {model_id}")

        info = api.model_info(model_id)
        files = [f.rfilename for f in info.siblings]
        ggufs = [f for f in files if f.endswith(".gguf")]

        if not ggufs:
            console.print(f"[red]❌ No GGUF files found in {model_id}![/red]")
            sys.exit(1)

        # 1. Find main model
        target_file = next((f for f in ggufs if quant.lower() in f.lower()), None)
        if not target_file:
            target_file = next((f for f in ggufs if "q4_0" in f.lower() or "q4_k" in f.lower()), ggufs[0])

        console.print(f"🎯 [green]Resolved File:[/green] {target_file}")

        # 2. Find Vision Projector (if Multimodal)
        mmproj_file = None
        for f in ggufs:
            if "mmproj" in f.lower():
                mmproj_file = f
                console.print(f"👁️ [green]Vision Projector detected:[/green] {mmproj_file}")
                break

        vendor, sys_ram, gpu_ram, ctx_size = get_system_specs(model_id, split, force_cpu)
        short_name = model_id.split("/")[-1].replace("-GGUF", "").replace("-gguf", "")

        nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp"
        if vendor not in ["cpu", "nvidia"] and not force_cpu:
            nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp-vulkan"

        console.print(f"🚀 [bold green]Igniting llama-server ({vendor.upper()} Mode)...[/bold green]\n")

        cmd = [
            "nix", "shell", "--impure", nix_package,
            "--command", "llama-server",
            "--hf-repo", model_id,
            "--hf-file", target_file,
            "--host", "127.0.0.1",
            "--port", "8080",
            "--ctx-size", str(ctx_size),
            "--alias", short_name,
        ]

        if mmproj_file:
            # We must download the mmproj file locally because llama-server
            # currently only supports --hf-file for the MAIN model, not the projector
            console.print(f"⬇️  [dim]Downloading Vision Projector...[/dim]")
            local_mmproj = hf_hub_download(repo_id=model_id, filename=mmproj_file)
            cmd.extend(["--mmproj", local_mmproj])

        if engine_type == "llama.cpp-embedding":
            console.print("🗃️ [green]Embedding mode enabled.[/green]")
            cmd.append("--embedding")

        if vendor != "cpu" and not force_cpu:
            cmd.extend(["--n-gpu-layers", "999"])
        if split and vendor != "cpu":
            cmd.append("--no-kv-offload")

        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()
            console.print("\n[green]✅ Server stopped.[/green]")

    elif engine_type == "sd.cpp":
        console.print(f"🎨 [bold green]Starting Image Server for:[/bold green] {model_id}")
        files = [f.rfilename for f in api.model_info(model_id).siblings]
        valid_files = [f for f in files if f.endswith(".gguf") or f.endswith(".safetensors")]
        target_file = next((f for f in valid_files if quant.lower() in f.lower()), valid_files[0])

        console.print(f"⬇️  [dim]Fetching model weights via HuggingFace Hub...[/dim]")
        local_path = hf_hub_download(repo_id=model_id, filename=target_file)

        cmd = [
            "nix", "shell", "nixpkgs#stable-diffusion-cpp",
            "--command", "sd-server", "-m", local_path, "--port", "8080"
        ]
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()

    elif engine_type == "whisper.cpp":
        console.print(f"🎤 [bold green]Starting Whisper Server for:[/bold green] {model_id}")
        files = [f.rfilename for f in api.model_info(model_id).siblings]
        bin_files = [f for f in files if f.endswith(".bin") and "ggml" in f.lower()]

        if not bin_files:
            console.print("[red]❌ No ggml .bin files found in repository![/red]")
            sys.exit(1)

        target_file = next((f for f in bin_files if "base.en" in f.lower()), bin_files[0])
        console.print(f"⬇️  [dim]Fetching audio model: {target_file}...[/dim]")
        local_path = hf_hub_download(repo_id=model_id, filename=target_file)

        cmd = [
            "nix", "shell", "nixpkgs#whisper-cpp",
            "--command", "whisper-cpp-server", "-m", local_path, "--port", "8080"
        ]
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()

    elif engine_type == "piper":
        console.print(f"🔊 [bold green]Starting Lightweight TTS Server for:[/bold green] {model_id}")
        cmd = ["nix", "shell", "nixpkgs#piper-tts", "--command", "piper", "--model", model_id, "--listen", "8080"]
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()

    elif engine_type == "docker-fishaudio":
        console.print(f"🔊 [bold green]Starting Heavy TTS Server via Docker for:[/bold green] {model_id}")
        cmd = ["docker", "run", "--rm", "--gpus", "all", "-p", "8080:8080", "ghcr.io/fishaudio/fish-speech:latest-server"]
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()

def main():
    parser = argparse.ArgumentParser(description="Universal Local AI Launcher")
    parser.add_argument("action", nargs="?", choices=["start", "stop"], help="Action to perform")
    parser.add_argument("--model", type=str, help="Bypass menu and load a specific model")
    parser.add_argument("--quant", type=str, default="Q4_K", help="Preferred quantization")
    parser.add_argument("--split", action="store_true", help="Put model in GPU and context in System RAM")
    parser.add_argument("--cpu", action="store_true", help="Force CPU inference only")

    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        sys.exit(1)

    if args.action == "stop":
        stop_server()
        sys.exit(0)

    if args.action == "start":
        model_to_load = args.model if args.model else interactive_menu()
        start_server(model_to_load, args.quant, args.split, args.cpu)

if __name__ == "__main__":
    main()
