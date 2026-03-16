import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import psutil
import requests
from huggingface_hub import HfApi
from rich import print as rprint
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt

console = Console()
api = HfApi()

# --- 🛒 DYNAMIC MODEL CATALOG & ROUTER ---
CATALOG = {
    "💬 General Chat": {
        "engine": "llama.cpp",
        "models": [
            "bartowski/gemma-2-9b-it-GGUF",
            "maziyarpanahi/Mistral-7B-Instruct-v0.3-GGUF",
            "bartowski/Meta-Llama-3.1-8B-Instruct-GGUF",
        ]
    },
    "💻 Coding & Dev": {
        "engine": "llama.cpp",
        "models": [
            "Tesslate/OmniCoder-9B-GGUF",
            "Qwen/Qwen2.5-Coder-14B-Instruct-GGUF",
            "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF",
            "Qwen/Qwen2.5-Coder-3B-Instruct-GGUF",
            "bartowski/Meta-Llama-3.1-8B-Instruct-GGUF",
            "bartowski/codegeex4-all-9b-GGUF",
        ]
    },
    "🧠 Math & Logic": {
        "engine": "llama.cpp",
        "models": [
            "bartowski/Phi-3-mini-4k-instruct-GGUF",
            "Qwen/Qwen2-Math-7B-Instruct-GGUF",
        ]
    },
    "🎨 Image Generation": {
        "engine": "sd.cpp",
        "models": [
            "leejet/FLUX.1-schnell-gguf",
            "stablediffusionapi/turbovisionxl"
        ]
    },
    "🔊 Text to Speech": {
        "engine": ["piper", "docker-fishaudio"],
        "models": [
            "rhasspy/piper-voices",
            "fishaudio/s2-pro",
            "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
        ]
    }
}

def stop_server():
    """Finds and kills orphaned AI server processes."""
    killed = False
    process_names = ["llama-server", "sd-server", "piper"]
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
    # 1. NVIDIA (nvidia-smi)
    try:
        output = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            text=True, stderr=subprocess.DEVNULL
        )
        return "nvidia", float(output.strip()) / 1024.0
    except Exception:
        pass

    # 2. AMD (sysfs)
    try:
        hwmon_paths = list(Path("/sys/class/drm").glob("card*/device/mem_info_vram_total"))
        if hwmon_paths:
            with open(hwmon_paths[0], "r") as f:
                vram_bytes = int(f.read().strip())
                return "amd", vram_bytes / (1024**3)
    except Exception:
        pass

    # 3. Intel / Generic (glxinfo)
    try:
        cmd = ["glxinfo", "-B"]
        output = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
        match = re.search(r"Dedicated video memory:\s*(\d+)\s*MB", output)
        if match:
            vram_mb = int(match.group(1))
            vendor = "intel"
            if "AMD" in output.upper():
                vendor = "amd"
            elif "NVIDIA" in output.upper():
                vendor = "nvidia"
            return vendor, vram_mb / 1024.0
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

    # Brain Size: ~0.65 GB per 1 Billion parameters
    brain_gb = params_b * 0.65

    if vendor == "cpu" or force_cpu:
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [262144, 131072, 65536, 32768, 16384, 8192, 4096]
        budget_type = "System RAM (CPU Mode)"
        split = False
    elif split:
        gpu_budget = total_gpu_vram * 0.90
        if brain_gb > gpu_budget:
            console.print(f"\n[red]⚠️ GPU LIMIT REACHED[/red]")
            console.print(f"[red]❌ Model ({brain_gb:.1f}GB) exceeds available GPU memory ({gpu_budget:.1f}GB).[/red]")
            sys.exit(1)
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [262144, 131072, 65536, 32768, 16384, 8192, 4096]
        budget_type = "System RAM"
    else:
        gpu_budget = total_gpu_vram * 0.75
        desk_gb = gpu_budget - brain_gb
        if desk_gb <= 0:
            console.print(f"\n[red]⚠️ HARDWARE LIMIT REACHED[/red]")
            console.print(f"[red]❌ Model ({brain_gb:.1f}GB) exceeds your AI budget ({gpu_budget:.1f}GB).[/red]")
            sys.exit(1)
        fixed_sizes = [131072, 65536, 32768, 16384, 8192, 4096]
        budget_type = "GPU VRAM"

    if "QWEN" in model_upper:
        mb_per_token = 0.055
    elif "LLAMA-3" in model_upper:
        mb_per_token = 0.125
    else:
        mb_per_token = 0.09

    mb_per_token = mb_per_token / 2.0
    desk_mb = desk_gb * 1024
    theoretical_max = int(desk_mb / mb_per_token)

    ctx_size = 4096
    for size in fixed_sizes:
        if theoretical_max >= size:
            ctx_size = size
            break

    console.print(
        f"📊 [dim]Math ({'CPU' if vendor == 'cpu' else ('SPLIT' if split else 'GPU ONLY')}): "
        f"Brain {brain_gb:.1f}GB | Desk {desk_gb:.1f}GB ({budget_type}) -> "
        f"{theoretical_max} theoretical tokens[/dim]"
    )

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

    models = CATALOG[selected_cat]["models"]
    for idx, mod in enumerate(models, 1):
        console.print(f"[bold white]{idx}.[/bold white] {mod}")

    mod_choice = Prompt.ask("\n👉 Select a model", choices=[str(i) for i in range(1, len(models) + 1)])
    selected_model = models[int(mod_choice) - 1]

    engines = CATALOG[selected_cat]["engine"]
    if isinstance(engines, list) and len(engines) > 1:
        console.print(f"\n[bold cyan]AVAILABLE ENGINES[/bold cyan]")
        for idx, eng in enumerate(engines, 1):
            console.print(f"[bold white]{idx}.[/bold white] {eng}")
        eng_choice = Prompt.ask("\n👉 Select an engine", choices=[str(i) for i in range(1, len(engines) + 1)])
        selected_engine = engines[int(eng_choice) - 1]
    elif isinstance(engines, list):
        selected_engine = engines[0]
    else:
        selected_engine = engines

    cat_data = CATALOG[selected_cat].copy()
    cat_data["engine"] = selected_engine

    return cat_data, selected_model

def write_opencode_config(model_id: str):
    short_name = model_id.split("/")[-1].replace("-GGUF", "").replace("-gguf", "")
    config_dir = Path.home() / ".config" / "opencode"
    config_file = config_dir / "opencode.json"
    config_dir.mkdir(parents=True, exist_ok=True)

    if config_file.exists():
        with open(config_file, "r") as f:
            try:
                config = json.load(f)
            except json.JSONDecodeError:
                config = {}
    else:
        config = {}

    config.setdefault("provider", {})
    config["provider"]["local"] = {
        "npm": "@ai-sdk/openai-compatible",
        "name": "local",
        "options": {"baseURL": "http://127.0.0.1:8080/v1", "apiKey": "sk-dummy"},
        "models": {short_name: {"name": short_name, "disableTools": True}},
    }
    config["model"] = f"local/{short_name}"

    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)

    return short_name

def get_gguf_repo(model_id: str) -> str:
    try:
        files = api.list_repo_files(repo_id=model_id)
        if any(f.endswith(".gguf") for f in files):
            return model_id
    except:
        pass

    variants = [
        f"{model_id}-GGUF",
        model_id.replace("-Instruct", "-GGUF"),
        f"{model_id}GGUF",
    ]
    for variant in variants:
        try:
            files = api.list_repo_files(repo_id=variant)
            if any(f.endswith(".gguf") for f in files):
                console.print(f"[yellow]→ Using GGUF companion repo: {variant}[/yellow]")
                return variant
        except:
            continue
    return model_id

def start_server(category_data: dict, model_id: str, quant: str, split: bool, force_cpu: bool):
    engine = category_data["engine"]

    if engine == "llama.cpp":
        console.print(f"\n🌐 [cyan]Contacting Hugging Face API for:[/cyan] {model_id}")
        gguf_repo = get_gguf_repo(model_id)
        if gguf_repo != model_id:
            console.print(f"[dim]Resolved GGUF repo: {gguf_repo}[/dim]")

        try:
            files = api.list_repo_files(repo_id=gguf_repo)
        except Exception as e:
            console.print(f"[red]❌ Error connecting to Hugging Face. Please check your internet connection.[/red]")
            console.print(f"[dim]Details: {e}[/dim]")
            sys.exit(1)

        ggufs = [f for f in files if f.endswith(".gguf")]
        if not ggufs:
            console.print(f"[red]❌ No GGUF files found in {gguf_repo}![/red]")
            sys.exit(1)

        target_file = next((f for f in ggufs if quant.lower() in f.lower()), None)
        if not target_file:
            target_file = next((f for f in ggufs if "q4_0" in f.lower()), ggufs[0])

        console.print(f"🎯 [green]Resolved File:[/green] {target_file}")

        vendor, sys_ram, gpu_ram, ctx_size = get_system_specs(model_id, split, force_cpu)
        short_name = write_opencode_config(model_id)

        console.print(f"⚙️  [cyan]Limits:[/cyan] Context Size snapped to: {ctx_size}")

        # Determine NixOS package dynamically based on hardware
        if vendor == "cpu" or force_cpu:
            nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp"
            console.print(f"🚀 [bold green]Igniting llama-server (CPU Mode)...[/bold green]\n")
        elif vendor == "nvidia":
            # Some users prefer llama-cpp-cuda for Nvidia, but if llama-cpp is compiled correctly it works
            nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp"
            console.print(f"🚀 [bold green]Igniting llama-server (NVIDIA Mode)...[/bold green]\n")
        else:
            # AMD or Intel Arc - default to Vulkan package as per previous config
            nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp-vulkan"
            console.print(f"🚀 [bold green]Igniting llama-server (Vulkan Mode)...[/bold green]\n")

        cmd = [
            "nix", "shell", "--impure", nix_package,
            "--command", "llama-server",
            "--hf-repo", gguf_repo,
            "--hf-file", target_file,
            "--host", "127.0.0.1",
            "--port", "8080",
            "--threads", "16",
            "--ctx-size", str(ctx_size),
            "--flash-attn", "on",
            "--cache-type-k", "q8_0",
            "--cache-type-v", "q8_0",
            "--alias", short_name,
        ]

        if vendor != "cpu" and not force_cpu:
            cmd.extend(["--n-gpu-layers", "999"])

        if split and vendor != "cpu":
            cmd.append("--no-kv-offload")

        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            console.print("\n[yellow]Shutting down server gracefully...[/yellow]")
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
            console.print("[green]✅ Server stopped.[/green]")

    elif engine == "sd.cpp":
        console.print(f"🎨 [bold green]Starting Image Server for:[/bold green] {model_id}")
        cmd = [
            "nix", "shell", "nixpkgs#stable-diffusion-cpp",
            "--command", "sd-server",
            "-m", model_id,
            "--port", "8080"
        ]
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            console.print("\n[yellow]Shutting down Image server...[/yellow]")
            proc.terminate()
            console.print("[green]✅ Server stopped.[/green]")

    elif engine == "piper":
        console.print(f"🔊 [bold green]Starting Lightweight TTS Server for:[/bold green] {model_id}")
        cmd = [
            "nix", "shell", "nixpkgs#piper-tts",
            "--command", "piper", "--model", model_id, "--listen", "8080"
        ]
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            console.print("\n[yellow]Shutting down TTS server...[/yellow]")
            proc.terminate()
            console.print("[green]✅ Server stopped.[/green]")

    elif engine == "docker-fishaudio":
        console.print(f"🔊 [bold green]Starting Heavy TTS Server via Docker for:[/bold green] {model_id}")
        cmd = [
            "docker", "run", "--rm", "--gpus", "all",
            "-p", "8080:8080", "ghcr.io/fishaudio/fish-speech:latest-server"
        ]
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            console.print("\n[yellow]Shutting down Docker TTS server...[/yellow]")
            proc.terminate()
            console.print("[green]✅ Server stopped.[/green]")

def main():
    parser = argparse.ArgumentParser(description="Universal Local AI Launcher (Text, Image, Audio)")
    parser.add_argument("action", nargs="?", choices=["start", "stop"], help="Action to perform")
    parser.add_argument("--model", type=str, help="Bypass menu and load a specific model")
    parser.add_argument("--quant", type=str, default="Q4_K_M", help="Preferred quantization")
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
        if args.model:
            # Look for the model in the catalog to get its engine
            found_category = None
            for cat_data in CATALOG.values():
                if args.model in cat_data["models"]:
                    found_category = cat_data.copy()
                    engines = found_category["engine"]
                    if isinstance(engines, list):
                        if len(engines) > 1:
                            console.print(f"\n[bold cyan]AVAILABLE ENGINES FOR {args.model}[/bold cyan]")
                            for idx, eng in enumerate(engines, 1):
                                console.print(f"[bold white]{idx}.[/bold white] {eng}")
                            eng_choice = Prompt.ask("\n👉 Select an engine", choices=[str(i) for i in range(1, len(engines) + 1)])
                            found_category["engine"] = engines[int(eng_choice) - 1]
                        else:
                            found_category["engine"] = engines[0]
                    break

            # Default to llama.cpp if not found
            if not found_category:
                found_category = {"engine": "llama.cpp", "models": [args.model]}

            start_server(found_category, args.model, args.quant, args.split, args.cpu)
        else:
            category_data, model_to_load = interactive_menu()
            start_server(category_data, model_to_load, args.quant, args.split, args.cpu)

if __name__ == "__main__":
    main()
