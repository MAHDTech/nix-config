import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import psutil
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
    """Finds and kills the llama-server process."""
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
    """Dynamically queries the Vulkan driver for the physical device-local memory (VRAM)."""
    try:
        cmd = ["vulkaninfo", "--summary"]
        output = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)

        # Find all memory heaps marked as 'device local' (Actual physical VRAM)
        heaps = re.findall(r"Heap \d+: (\d+) MB \(device local\)", output)
        if heaps:
            max_heap_mb = max([int(h) for h in heaps])
            return max_heap_mb / 1024.0
    except Exception:
        pass

    # Fallback if vulkaninfo fails or is missing
    console.print("[yellow]⚠️ Could not read exact VRAM from Vulkan. Falling back to 12.0 GB default.[/yellow]")
    return 12.0

def get_system_specs(model_name: str):
    """Calculates dynamic context sizing based on exact hardware limits and model size."""
    sys_mem_bytes = psutil.virtual_memory().available
    sys_mem_gb = sys_mem_bytes / (1024**3)

    # 1. Determine exactly how much RAM the GPU has
    total_gpu_vram = get_gpu_vram_gb()

    # 2. Determine 75% of that VRAM as our strict operating budget
    gpu_budget = total_gpu_vram * 0.75

    model_upper = model_name.upper()

    # 3. Extract the parameter size of the model from its name (e.g., "7B", "14B")
    param_match = re.search(r'(\d+(?:\.\d+)?)B', model_upper)
    params_b = float(param_match.group(1)) if param_match else 7.0

    # 4. Calculate "The Brain": Q4_K_M quantizations use ~0.65 GB per 1 Billion parameters
    model_vram_gb = params_b * 0.65

    # 5. Calculate "The Desk": Subtract the Brain from the Budget to find free context space
    free_vram_for_ctx = gpu_budget - model_vram_gb

    # Hardware Protector: Does the brain even fit in the budget?
    if free_vram_for_ctx <= 0:
        console.print(f"\n[red]⚠️ HARDWARE LIMIT REACHED[/red]")
        console.print(f"[red]❌ Model ({model_vram_gb:.1f}GB) exceeds your 75% GPU budget ({gpu_budget:.1f}GB).[/red]")
        console.print("👉 Please select a smaller model.")
        sys.exit(1)

    # 6. Convert free VRAM to Context Tokens (1GB VRAM ≈ 16,000 tokens)
    calculated_ctx = int(free_vram_for_ctx * 16000)

    # 7. Snap to the nearest safe power of 2 for optimal engine performance
    if calculated_ctx >= 131072: ctx_size = 131072
    elif calculated_ctx >= 65536: ctx_size = 65536
    elif calculated_ctx >= 32768: ctx_size = 32768
    elif calculated_ctx >= 16384: ctx_size = 16384
    elif calculated_ctx >= 8192: ctx_size = 8192
    else: ctx_size = 4096

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

    # 1. Read the existing config (managed by Nix)
    if config_file.exists():
        with open(config_file, "r") as f:
            try:
                config = json.load(f)
            except json.JSONDecodeError:
                config = {}
    else:
        config = {}

    # 2. Ensure base dictionary structures exist
    config.setdefault("provider", {})

    # 3. UPSERT the local provider (Leaves MCPs and Gemini alone!)
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

    # 4. Set the active model
    config["model"] = f"local/{short_name}"

    # 5. Save it safely back to disk
    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)

    return short_name

def start_server(model_id: str, quant: str):
    console.print(f"\n🌐 [cyan]Contacting Hugging Face API for:[/cyan] {model_id}")

    try:
        files = api.list_repo_files(repo_id=model_id)
    except Exception as e:
        console.print(f"[red]❌ Error connecting to Hugging Face: {e}[/red]")
        sys.exit(1)

    ggufs = [f for f in files if f.endswith('.gguf')]
    if not ggufs:
        console.print(f"[red]❌ No GGUF files found in {model_id}![/red]")
        sys.exit(1)

    # Find the right quantization
    target_file = next((f for f in ggufs if quant.lower() in f.lower()), None)
    if not target_file:
        target_file = next((f for f in ggufs if 'q4_0' in f.lower()), ggufs[0])

    console.print(f"🎯 [green]Resolved File:[/green] {target_file}")

    sys_ram, gpu_ram, ctx_size = get_system_specs(model_id)
    short_name = write_opencode_config(model_id)

    console.print(f"⚙️  [cyan]Limits:[/cyan] {gpu_ram:.1f}GB Total VRAM | Context Size: {ctx_size}")
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
        "--alias", short_name
    ]

    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        console.print("\n[yellow]Shutting down server...[/yellow]")
        stop_server()

def main():
    parser = argparse.ArgumentParser(description="Local AI Launcher")
    parser.add_argument("action", choices=["start", "stop"], help="Action to perform")
    parser.add_argument("--model", type=str, help="Bypass menu and load a specific model")
    parser.add_argument("--quant", type=str, default="Q4_K_M", help="Preferred quantization")

    args = parser.parse_args()

    if args.action == "stop":
        stop_server()
        sys.exit(0)

    if args.action == "start":
        stop_server()
        model_to_load = args.model if args.model else interactive_menu()
        start_server(model_to_load, args.quant)

if __name__ == "__main__":
    main()
