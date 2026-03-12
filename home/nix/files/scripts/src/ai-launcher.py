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

# --- 🛒 DYNAMIC MODEL CATALOG ---
CATALOG = {
    "💻 Coding & Dev": [
        "Qwen/Qwen2.5-Coder-14B-Instruct-GGUF",
        "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF",
        "Qwen/Qwen2.5-Coder-3B-Instruct-GGUF",
        "bartowski/Meta-Llama-3.1-8B-Instruct-GGUF",
        "bartowski/codegeex4-all-9b-GGUF"
    ],
    "💬 General Chat": [
        "bartowski/gemma-2-9b-it-GGUF",
        "maziyarpanahi/Mistral-7B-Instruct-v0.3-GGUF",
        "bartowski/Meta-Llama-3.1-8B-Instruct-GGUF"
    ],
    "🧠 Math & Logic": [
        "bartowski/Phi-3-mini-4k-instruct-GGUF",
        "Qwen/Qwen2-Math-7B-Instruct-GGUF"
    ]
}

def stop_server():
    """Finds and kills orphaned llama-server processes."""
    killed = False
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            if 'llama-server' in proc.info['name'] or \
               (proc.info['cmdline'] and 'llama-server' in ' '.join(proc.info['cmdline'])):
                os.kill(proc.info['pid'], 9)
                killed = True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    if killed:
        console.print("[green]✅ llama-server stopped successfully.[/green]")
    else:
        console.print("[yellow]⚠️ No running llama-server found.[/yellow]")

def get_gpu_vram_gb():
    """Programmatically gets exact VRAM, relying on glxinfo for Intel ARC."""
    # Fallback to glxinfo (which reliably grabs Dedicated Video Memory across vendors)    try:
        cmd = ["glxinfo", "-B"]
        output = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
        match = re.search(r"Dedicated video memory:\s*(\d+)\s*MB", output)
        if match:
            vram_mb = int(match.group(1))
            return vram_mb / 1024.0

    except Exception as e:
        console.print(f"[yellow]⚠️ glxinfo parsing error: {e}[/yellow]")
        pass

    console.print("[yellow]⚠️ Could not read exact VRAM from glxinfo. Falling back to 12.0 GB default.[/yellow]")
    return 12.0

def get_system_specs(model_name: str, split: bool = False):
    """Calculates dynamic context sizing using strict mathematical VRAM/RAM budgeting."""
    sys_mem_bytes = psutil.virtual_memory().available
    sys_mem_gb = sys_mem_bytes / (1024**3)
    total_gpu_vram = get_gpu_vram_gb()

    model_upper = model_name.upper()
    param_match = re.search(r'(\d+(?:\.\d+)?)B', model_upper)
    params_b = float(param_match.group(1)) if param_match else 7.0

    # Brain Size: ~0.65 GB per 1 Billion parameters
    brain_gb = params_b * 0.65

    if split:
        # SPLIT MODE: Brain goes to GPU, Desk goes to System RAM
        gpu_budget = total_gpu_vram * 0.90 # Leave 10% for OS/Hyprland
        if brain_gb > gpu_budget:
            console.print(f"\n[red]⚠️ GPU LIMIT REACHED[/red]")
            console.print(f"[red]❌ Model ({brain_gb:.1f}GB) exceeds available GPU memory ({gpu_budget:.1f}GB).[/red]")
            sys.exit(1)

        # Context is calculated against System RAM (75% budget)
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [262144, 131072, 65536, 32768, 16384, 8192, 4096] # Unlocked 256k!
        budget_type = "System RAM"
    else:
        # GPU ONLY MODE: Everything must fit in GPU
        gpu_budget = total_gpu_vram * 0.75
        desk_gb = gpu_budget - brain_gb
        if desk_gb <= 0:
            console.print(f"\n[red]⚠️ HARDWARE LIMIT REACHED[/red]")
            console.print(f"[red]❌ Model ({brain_gb:.1f}GB) exceeds your AI budget ({gpu_budget:.1f}GB).[/red]")
            sys.exit(1)

        fixed_sizes = [131072, 65536, 32768, 16384, 8192, 4096]
        budget_type = "GPU VRAM"

    # Architecture Tax
    if "QWEN" in model_upper:
        mb_per_token = 0.055
    elif "LLAMA-3" in model_upper:
        mb_per_token = 0.125
    else:
        mb_per_token = 0.09

    # Apply 50% discount because of q8_0 cache compression
    mb_per_token = mb_per_token / 2.0

    desk_mb = desk_gb * 1024
    theoretical_max = int(desk_mb / mb_per_token)

    ctx_size = 4096
    for size in fixed_sizes:
        if theoretical_max >= size:
            ctx_size = size
            break

    console.print(f"📊 [dim]Math ({'SPLIT' if split else 'GPU ONLY'}): Brain {brain_gb:.1f}GB (GPU) | Desk {desk_gb:.1f}GB ({budget_type}) -> {theoretical_max} theoretical tokens[/dim]")

    return sys_mem_gb, total_gpu_vram, ctx_size

def interactive_menu():
    """Renders the Rich terminal UI for model selection."""
    console.print(Panel.fit("🤖 [bold cyan]LOCAL AI LAUNCHER[/bold cyan] (Auto-Scaling GPU)", border_style="cyan"))

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

def write_opencode_config(model_id: str):
    """Smartly updates the opencode.json without destroying Nix-managed settings."""
    short_name = model_id.split('/')[-1].replace('-GGUF', "").replace('-gguf', "")

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
        "options": {
            "baseURL": "http://127.0.0.1:8080/v1",
            "apiKey": "sk-dummy"
        },
        "models": {
            short_name: {
                "name": short_name,
                "disableTools": True
            }
        }
    }
    config["model"] = f"local/{short_name}"

    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)

    return short_name

def start_server(model_id: str, quant: str, split: bool):
    console.print(f"\n🌐 [cyan]Contacting Hugging Face API for:[/cyan] {model_id}")

    try:
        files = api.list_repo_files(repo_id=model_id)
    except Exception as e:
        console.print(f"[red]❌ Error connecting to Hugging Face. Please check your internet connection.[/red]")
        console.print(f"[dim]Details: {e}[/dim]")
        sys.exit(1)

    ggufs = [f for f in files if f.endswith('.gguf')]
    if not ggufs:
        console.print(f"[red]❌ No GGUF files found in {model_id}![/red]")
        sys.exit(1)

    target_file = next((f for f in ggufs if quant.lower() in f.lower()), None)
    if not target_file:
        target_file = next((f for f in ggufs if 'q4_0' in f.lower()), ggufs[0])

    console.print(f"🎯 [green]Resolved File:[/green] {target_file}")

    sys_ram, gpu_ram, ctx_size = get_system_specs(model_id, split)
    short_name = write_opencode_config(model_id)

    console.print(f"⚙️  [cyan]Limits:[/cyan] Context Size snapped to: {ctx_size}")
    console.print(f"🚀 [bold green]Igniting llama-server...[/bold green]\n")

    cmd = [
        "nix", "shell", "--impure", "github:NixOS/nixpkgs/nixos-unstable#llama-cpp-vulkan",
        "--command", "llama-server",
        "--hf-repo", model_id,
        "--hf-file", target_file,
        "--host", "127.0.0.1",
        "--port", "8080",
        "--n-gpu-layers", "999",
        "--threads", "16",
        "--ctx-size", str(ctx_size),
        "--flash-attn", "on",
        "--cache-type-k", "q8_0",
        "--cache-type-v", "q8_0",
        "--alias", short_name
    ]

    # 🚀 If user passes --split, explicitly ban the KV Cache from the GPU
    if split:
        cmd.append("--no-kv-offload")

    try:
        # Use Popen to allow graceful process termination
        proc = subprocess.Popen(cmd)
        proc.wait()
    except KeyboardInterrupt:
        console.print("\n[yellow]Shutting down server gracefully...[/yellow]")
        proc.terminate() # Send SIGTERM
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill() # Force kill if it doesn't respond
        console.print("[green]✅ Server stopped.[/green]")

def main():
    parser = argparse.ArgumentParser(description="Local AI Launcher")
    # Action is now optional (nargs="?"). If not provided, we show help instead of defaulting to start.
    parser.add_argument("action", nargs="?", choices=["start", "stop"], help="Action to perform")
    parser.add_argument("--model", type=str, help="Bypass menu and load a specific model")
    parser.add_argument("--quant", type=str, default="Q4_K_M", help="Preferred quantization")
    parser.add_argument("--split", action="store_true", help="Put model in GPU and context in System RAM")

    args = parser.parse_args()

    # Show help if no action is given
    if not args.action:
        parser.print_help()
        sys.exit(1)

    if args.action == "stop":
        stop_server()
        sys.exit(0)

    if args.action == "start":
        model_to_load = args.model if args.model else interactive_menu()
        start_server(model_to_load, args.quant, args.split)

if __name__ == "__main__":
    main()
