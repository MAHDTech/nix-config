import argparse
import logging
import os
import re
import select
import subprocess
import sys
import tempfile
import termios
import traceback
import tty
from pathlib import Path

import psutil
from huggingface_hub import HfApi, hf_hub_download
from rich import print as rprint
from rich.console import Console

# Setup Logging
script_name = Path(__file__).stem
log_file = Path(tempfile.gettempdir()) / f"{script_name}.log"

logging.basicConfig(
    filename=log_file,
    filemode="w",
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

console = Console()
api = HfApi()


def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return

    logging.error("Uncaught exception", exc_info=(exc_type, exc_value, exc_traceback))
    console.print(f"\n[bold red]❌ CRITICAL SYSTEM FAILURE.[/bold red]")
    console.print(f"[bold #008F11]Check diagnostic logs at: {log_file}[/bold #008F11]")
    sys.exit(1)


sys.excepthook = handle_exception

# --- 🛒 DYNAMIC MODEL CATALOG ---
import shutil

import yaml

# Setup Config Directories
SCRIPT_NAME = Path(__file__).stem
HOME_DIR = Path.home()
USER_CONFIG_DIR = HOME_DIR / ".config" / SCRIPT_NAME
USER_CONFIG_FILE = USER_CONFIG_DIR / "config.yaml"
DEFAULT_CONFIG_FILE = Path(__file__).parent / f"{SCRIPT_NAME}.yaml"

# --- 🏷️ CATEGORY SCHEMA ---
# Maps short YAML keys to rich UI display labels
CATEGORY_SCHEMA = {
    "general": "💬 General Chat",
    "coding": "💻 Coding & Dev",
    "vision": "👁️ Vision (Image to Text)",
    "math": "🧠 Math & Logic",
    "embeddings": "🗃️ Text Embeddings",
    "image_gen": "🎨 Image Generation",
    "stt": "🎤 Speech to Text",
    "tts": "🔊 Text to Speech",
}


def load_catalog():
    if not USER_CONFIG_FILE.exists():
        try:
            USER_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            if DEFAULT_CONFIG_FILE.exists():
                shutil.copy(DEFAULT_CONFIG_FILE, USER_CONFIG_FILE)
            else:
                logging.warning(f"Default config not found at {DEFAULT_CONFIG_FILE}")
        except Exception as e:
            console.print(
                f"\n[bold red]Unable to create a default configuration at {USER_CONFIG_FILE}. Please ensure {SCRIPT_NAME} is run with the necessary permissions.[/bold red]"
            )
            logging.error(f"Failed to create user config: {e}")
            sys.exit(1)

    raw_catalog = {}

    # Load defaults
    if DEFAULT_CONFIG_FILE.exists():
        try:
            with open(DEFAULT_CONFIG_FILE, "r") as f:
                data = yaml.safe_load(f)
                raw_catalog = data.get("models", {}) if data else {}
        except Exception as e:
            logging.error(f"Failed to load default config: {e}")

    # Merge user config
    if USER_CONFIG_FILE.exists():
        try:
            with open(USER_CONFIG_FILE, "r") as f:
                data = yaml.safe_load(f)
                user_catalog = data.get("models", {}) if data else {}

                for cat, models in user_catalog.items():
                    # Handle both list of strings and list of dicts formats gracefully
                    parsed_models = []
                    for model in models:
                        if isinstance(model, dict) and "name" in model:
                            parsed_models.append(model["name"])
                        elif isinstance(model, str):
                            parsed_models.append(model)

                    if cat in raw_catalog:
                        merged = raw_catalog[cat].copy()
                        for pm in parsed_models:
                            # Avoid duplicates, treating string vs dict consistency
                            if isinstance(merged[0], dict) and "name" in merged[0]:
                                existing = [
                                    m["name"]
                                    for m in merged
                                    if isinstance(m, dict) and "name" in m
                                ]
                            else:
                                existing = merged

                            if pm not in existing:
                                merged.append({"name": pm})
                        raw_catalog[cat] = merged
                    else:
                        raw_catalog[cat] = [{"name": pm} for pm in parsed_models]
        except Exception as e:
            logging.error(f"Failed to load user config: {e}")

    # Translate raw short keys to rich UI labels using SCHEMA
    final_catalog = {}
    for short_key, models in raw_catalog.items():
        ui_label = CATEGORY_SCHEMA.get(short_key, short_key.replace("_", " ").title())

        # Ensure final structure is a clean list of strings for the interactive menu
        clean_models = []
        for model in models:
            if isinstance(model, dict) and "name" in model:
                clean_models.append(model["name"])
            elif isinstance(model, str):
                clean_models.append(model)

        final_catalog[ui_label] = clean_models

    return final_catalog


CATALOG = load_catalog()

MATRIX_LOGO = r"""[bold #00FF41]
████████╗ █████╗ ██████╗ ███████╗
╚══██╔══╝██╔══██╗██╔══██╗██╔════╝
   ██║   ███████║██████╔╝███████╗
   ██║   ██╔══██║██╔══██╗╚════██║
   ██║   ██║  ██║██║  ██║███████║
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
[/bold #00FF41]"""


def get_key():
    """Reads a single keypress from stdin, handling escape sequences for arrows."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = os.read(fd, 1).decode("utf-8", errors="ignore")
        if ch == "\x1b":  # Escape
            # Set to non-blocking to check for remaining bytes of the escape sequence
            import fcntl
            import time

            old_flags = fcntl.fcntl(fd, fcntl.F_GETFL)
            fcntl.fcntl(fd, fcntl.F_SETFL, old_flags | os.O_NONBLOCK)
            try:
                time.sleep(0.02)  # Give sequence time to buffer
                ch += os.read(fd, 1).decode("utf-8", errors="ignore")
                ch += os.read(fd, 1).decode("utf-8", errors="ignore")
            except OSError:
                pass
            finally:
                fcntl.fcntl(fd, fcntl.F_SETFL, old_flags)
    except Exception as e:
        logging.error(f"Error reading key: {e}")
        return ""
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch


def select_from_menu(
    title: str, options: list, instruction: str, allow_back: bool = False
) -> int:
    selected_idx = 0
    while True:
        output = [MATRIX_LOGO]
        output.append(
            f"[bold #00FF41]>[/bold #00FF41] [bold white]{title}[/bold white]"
        )
        output.append(f"[bold #008F11]{instruction}[/bold #008F11]\n")

        for i, opt in enumerate(options):
            if i == selected_idx:
                output.append(
                    f"   [bold black on #00FF41]  ► {opt}  [/bold black on #00FF41]"
                )
            else:
                output.append(f"   [bold #008F11]    {opt}  [/bold #008F11]")

        footer = "\n[bold #008F11]  \\[↑/↓] Navigate   \\[ENTER] Select"
        if allow_back:
            footer += "   \\[ESC] Back"
        else:
            footer += "   \\[ESC] Exit"
        footer += "[/bold #008F11]"
        output.append(footer)

        console.clear()
        console.print("\n".join(output))

        key = get_key()
        logging.debug(f"Key pressed: {repr(key)}")

        if key in ("\x1b[A", "\x1bOA"):  # Up
            selected_idx = (selected_idx - 1) % len(options)
        elif key in ("\x1b[B", "\x1bOB"):  # Down
            selected_idx = (selected_idx + 1) % len(options)
        elif key in ("\r", "\n"):  # Enter
            return selected_idx
        elif key == "\x1b":  # Esc
            return -1
        elif key in ("q", "Q", "\x03"):  # q, Q, or Ctrl+C
            console.clear()
            sys.exit(0)


def stop_server():
    """Finds and kills orphaned AI server processes."""
    logging.info("Initiating server shutdown sequence...")
    killed = False
    process_names = [
        "llama-server",
        "sd-server",
        "piper",
        "whisper-server",
        "whisper-cpp-server",
    ]
    for proc in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            name = proc.info["name"] or ""
            cmdline = " ".join(proc.info["cmdline"] or [])
            if any(p in name for p in process_names) or any(
                p in cmdline for p in process_names
            ):
                logging.debug(f"Killing process: {name} (PID: {proc.info['pid']})")
                os.kill(proc.info["pid"], 9)
                killed = True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    if killed:
        logging.info("AI server stopped successfully.")
        console.print("[bold #00FF41]✅ NEURAL NET SEVERED.[/bold #00FF41]")
    else:
        logging.info("No running AI server found.")
        console.print(
            "[bold #008F11]⚠️ NO ACTIVE NEURAL CONNECTIONS FOUND.[/bold #008F11]"
        )


def get_gpu_vendor_and_vram():
    """Programmatically gets exact VRAM and GPU Vendor."""
    logging.debug("Detecting GPU vendor and VRAM...")
    try:
        output = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        vram = float(output.strip()) / 1024.0
        logging.debug(f"Detected NVIDIA GPU with {vram:.2f}GB VRAM via nvidia-smi")
        return "nvidia", vram
    except Exception as e:
        logging.debug(f"nvidia-smi check failed: {e}")

    try:
        hwmon_paths = list(
            Path("/sys/class/drm").glob("card*/device/mem_info_vram_total")
        )
        if hwmon_paths:
            with open(hwmon_paths[0], "r") as f:
                vram_bytes = int(f.read().strip())
                vram = vram_bytes / (1024**3)
                logging.debug(f"Detected AMD GPU with {vram:.2f}GB VRAM via sysfs")
                return "amd", vram
    except Exception as e:
        logging.debug(f"AMD sysfs check failed: {e}")

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
            vram = vram_mb / 1024.0
            logging.debug(f"Detected {vendor} GPU with {vram:.2f}GB VRAM via glxinfo")
            return vendor, vram
    except Exception as e:
        logging.debug(f"glxinfo check failed: {e}")

    logging.debug("No GPU detected, defaulting to CPU")
    return "cpu", 0.0


def get_system_specs(model_name: str, split: bool = False, force_cpu: bool = False):
    """Calculates dynamic context sizing using strict mathematical VRAM/RAM budgeting."""
    logging.info(
        f"Calculating system specs for {model_name} (split={split}, force_cpu={force_cpu})"
    )
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
    logging.debug(
        f"Estimated brain size: {brain_gb:.2f}GB (based on {params_b}B parameters)"
    )

    if vendor == "cpu" or force_cpu:
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [262144, 131072, 65536, 32768, 16384, 8192, 4096]
        budget_type = "System RAM (CPU Mode)"
        split = False
    elif split:
        gpu_budget = total_gpu_vram * 0.90
        if brain_gb > gpu_budget:
            logging.error(
                f"GPU limit reached. Model ({brain_gb:.1f}GB) > VRAM budget ({gpu_budget:.1f}GB)"
            )
            console.print(f"\n[bold red]⚠️ GPU LIMIT REACHED[/bold red]")
            console.print(
                f"[bold red]❌ Model ({brain_gb:.1f}GB) exceeds available GPU memory ({gpu_budget:.1f}GB).[/bold red]"
            )
            sys.exit(1)
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [262144, 131072, 65536, 32768, 16384, 8192, 4096]
        budget_type = "System RAM"
    else:
        gpu_budget = total_gpu_vram * 0.75
        desk_gb = gpu_budget - brain_gb
        if desk_gb <= 0:
            logging.error(
                f"Hardware limit reached. Model ({brain_gb:.1f}GB) > VRAM budget ({gpu_budget:.1f}GB)"
            )
            console.print(f"\n[bold red]⚠️ HARDWARE LIMIT REACHED[/bold red]")
            console.print(
                f"[bold red]❌ Model ({brain_gb:.1f}GB) exceeds your AI budget ({gpu_budget:.1f}GB).[/bold red]"
            )
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

    logging.debug(
        f"Context sizing calculated: desk={desk_gb:.2f}GB, theoretical max tokens={theoretical_max}, snapped to {ctx_size}"
    )
    console.print(
        f"[bold #008F11]📊 Math ({'CPU' if vendor == 'cpu' else ('SPLIT' if split else 'GPU ONLY')}): "
        f"Brain {brain_gb:.1f}GB | Desk {desk_gb:.1f}GB ({budget_type}) -> "
        f"{theoretical_max} theoretical tokens[/bold #008F11]"
    )

    return vendor, sys_mem_gb, total_gpu_vram, ctx_size


def interactive_menu():
    """Renders the Rich terminal full-screen Matrix UI for model selection."""
    categories = list(CATALOG.keys())

    while True:
        cat_idx = select_from_menu(
            "UPLINK ESTABLISHED", categories, "SELECT NEURAL PATHWAY:", allow_back=False
        )
        if cat_idx == -1:
            console.clear()
            console.print("\n[bold #00FF41]DISCONNECTING...[/bold #00FF41]")
            sys.exit(0)

        selected_cat = categories[cat_idx]
        models = CATALOG[selected_cat]

        while True:
            mod_idx = select_from_menu(
                f"PATHWAY // {selected_cat.upper()}",
                models,
                "SELECT CONSTRUCT MODEL:",
                allow_back=True,
            )
            if mod_idx == -1:
                break  # Go back to categories

            selected_model = models[mod_idx]
            console.clear()
            return selected_model


def auto_detect_engine(model_id: str) -> str:
    try:
        logging.debug(f"Querying Hugging Face API for {model_id}...")
        console.print(
            f"🔍 [dim]Querying Hugging Face API to detect engine for {model_id}...[/dim]"
        )
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
            if any(f.endswith(".onnx") for f in files) or "piper" in tags:
                return "piper"
            else:
                return "unknown"
        else:
            if any(f.endswith(".gguf") for f in files):
                return "llama.cpp"
    except Exception as e:
        logging.warning(
            f"Could not fetch metadata from Hugging Face for {model_id}. Error: {e}"
        )
        console.print(
            f"[yellow]⚠️ Could not fetch metadata from Hugging Face for {model_id}. Proceeding with default assumptions.[/yellow]"
        )

    # Default catch-all
    return "llama.cpp"


def start_server(model_id: str, quant: str, split: bool, force_cpu: bool):
    engine_type = auto_detect_engine(model_id)
    logging.info(f"Auto-detected engine: {engine_type} for model {model_id}")
    console.print(
        f"⚙️  [cyan]Auto-detected Engine:[/cyan] [bold white]{engine_type}[/bold white]"
    )

    if "llama.cpp" in engine_type:
        console.print(
            f"\n🌐 [bold #00FF41]Contacting Hugging Face API for:[/bold #00FF41] {model_id}"
        )

        try:
            info = api.model_info(model_id)
            files = [f.rfilename for f in info.siblings]
            ggufs = [f for f in files if f.endswith(".gguf")]
        except Exception as e:
            logging.error("Failed to fetch Hugging Face repo files", exc_info=True)
            console.print(
                f"[bold red]❌ UPLINK FAILED. CHECK NETWORK CONNECTION.[/bold red]"
            )
            console.print(f"[bold red]Details: {e}[/bold red]")
            sys.exit(1)

        if not ggufs:
            logging.error(f"No GGUF files found in {model_id}")
            console.print(f"[bold red]❌ No GGUF files found in {model_id}![/bold red]")
            sys.exit(1)

        # 1. Find main model
        target_file = next((f for f in ggufs if quant.lower() in f.lower()), None)
        if not target_file:
            target_file = next(
                (f for f in ggufs if "q4_0" in f.lower() or "q4_k" in f.lower()),
                ggufs[0],
            )
            logging.debug(f"Preferred quant not found, falling back to {target_file}")

        console.print(f"🎯 [bold #00FF41]Resolved File:[/bold #00FF41] {target_file}")
        logging.info(f"Target file resolved: {target_file}")

        # 2. Find Vision Projector (if Multimodal)
        mmproj_file = None
        for f in ggufs:
            if "mmproj" in f.lower():
                mmproj_file = f
                console.print(
                    f"👁️ [bold #00FF41]Vision Projector detected:[/bold #00FF41] {mmproj_file}"
                )
                logging.info(f"Vision Projector detected: {mmproj_file}")
                break

        vendor, sys_ram, gpu_ram, ctx_size = get_system_specs(
            model_id, split, force_cpu
        )
        short_name = model_id.split("/")[-1].replace("-GGUF", "").replace("-gguf", "")

        nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp"
        if vendor not in ["cpu", "nvidia"] and not force_cpu:
            nix_package = "github:NixOS/nixpkgs/nixos-unstable#llama-cpp-vulkan"

        console.print(
            f"🚀 [bold #00FF41]Igniting llama-server ({vendor.upper()} Mode)...[/bold #00FF41]\n"
        )

        cmd = [
            "nix",
            "shell",
            "--impure",
            nix_package,
            "--command",
            "llama-server",
            "--hf-repo",
            model_id,
            "--hf-file",
            target_file,
            "--host",
            "127.0.0.1",
            "--port",
            "8080",
            "--ctx-size",
            str(ctx_size),
            "--alias",
            short_name,
        ]

        if mmproj_file:
            console.print(f"⬇️  [dim]Downloading Vision Projector...[/dim]")
            logging.info(f"Downloading Vision Projector: {mmproj_file}")
            local_mmproj = hf_hub_download(repo_id=model_id, filename=mmproj_file)
            cmd.extend(["--mmproj", local_mmproj])

        if engine_type == "llama.cpp-embedding":
            console.print("🗃️ [bold #00FF41]Embedding mode enabled.[/bold #00FF41]")
            logging.info("Embedding mode enabled.")
            cmd.append("--embedding")

        if vendor != "cpu" and not force_cpu:
            cmd.extend(["--n-gpu-layers", "999"])
        if split and vendor != "cpu":
            cmd.append("--no-kv-offload")

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

    elif engine_type == "sd.cpp":
        console.print(
            f"🎨 [bold #00FF41]Starting Image Server for:[/bold #00FF41] {model_id}"
        )
        files = [f.rfilename for f in api.model_info(model_id).siblings]
        valid_files = [
            f for f in files if f.endswith(".gguf") or f.endswith(".safetensors")
        ]
        target_file = next(
            (f for f in valid_files if quant.lower() in f.lower()), valid_files[0]
        )

        console.print(f"⬇️  [dim]Fetching model weights via HuggingFace Hub...[/dim]")
        logging.info(f"Fetching sd.cpp model weights: {target_file}")
        local_path = hf_hub_download(repo_id=model_id, filename=target_file)

        cmd = [
            "nix",
            "shell",
            "nixpkgs#stable-diffusion-cpp",
            "--command",
            "sd-server",
            "-m",
            local_path,
            "--port",
            "8080",
        ]
        logging.info(f"Executing command: {' '.join(cmd)}")
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            logging.info("Caught KeyboardInterrupt, shutting down server")
            proc.terminate()
            console.print("\n[bold #00FF41]✅ Server stopped.[/bold #00FF41]")

    elif engine_type == "whisper.cpp":
        console.print(
            f"🎤 [bold #00FF41]Starting Whisper Server for:[/bold #00FF41] {model_id}"
        )
        files = [f.rfilename for f in api.model_info(model_id).siblings]
        bin_files = [f for f in files if f.endswith(".bin") and "ggml" in f.lower()]

        if not bin_files:
            logging.error(f"No ggml .bin files found in repository {model_id}")
            console.print(
                "[bold red]❌ No ggml .bin files found in repository![/bold red]"
            )
            sys.exit(1)

        target_file = next(
            (f for f in bin_files if "base.en" in f.lower()), bin_files[0]
        )
        console.print(f"⬇️  [dim]Fetching audio model: {target_file}...[/dim]")
        logging.info(f"Fetching whisper model: {target_file}")
        local_path = hf_hub_download(repo_id=model_id, filename=target_file)

        cmd = [
            "nix",
            "shell",
            "nixpkgs#whisper-cpp",
            "--command",
            "whisper-cpp-server",
            "-m",
            local_path,
            "--port",
            "8080",
        ]
        logging.info(f"Executing command: {' '.join(cmd)}")
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            logging.info("Caught KeyboardInterrupt, shutting down server")
            proc.terminate()
            console.print("\n[bold #00FF41]✅ Server stopped.[/bold #00FF41]")

    elif engine_type == "piper":
        console.print(
            f"🔊 [bold #00FF41]Starting Lightweight TTS Server for:[/bold #00FF41] {model_id}"
        )

        try:
            files = [f.rfilename for f in api.model_info(model_id).siblings]
        except Exception as e:
            logging.error(f"Failed to fetch Hugging Face repo: {e}")
            console.print(
                f"[bold red]❌ Could not reach Hugging Face for {model_id}.[/bold red]"
            )
            sys.exit(1)

        onnx_files = [f for f in files if f.endswith(".onnx")]
        if not onnx_files:
            logging.error(f"No .onnx files found in {model_id}")
            console.print(
                f"[bold red]❌ No .onnx files found in repository {model_id}![/bold red]"
            )
            sys.exit(1)

        target_file = next(
            (f for f in onnx_files if "en_US" in f.lower()), onnx_files[0]
        )
        json_file = f"{target_file}.json"

        console.print(f"⬇️  [dim]Fetching audio model: {target_file}...[/dim]")
        logging.info(f"Fetching piper model: {target_file}")

        local_onnx = hf_hub_download(repo_id=model_id, filename=target_file)
        try:
            # Piper absolutely requires a .json config file alongside the .onnx
            local_json = hf_hub_download(repo_id=model_id, filename=json_file)
        except Exception as e:
            logging.error(f"Failed to download config file {json_file}: {e}")
            console.print(
                f"[bold red]❌ Could not find corresponding .json config for {target_file}![/bold red]"
            )
            sys.exit(1)

        cmd = [
            "nix",
            "shell",
            "nixpkgs#piper-tts",
            "--command",
            "piper",
            "--model",
            local_onnx,
            "--listen",
            "8080",
        ]
        logging.info(f"Executing command: {' '.join(cmd)}")
        try:
            proc = subprocess.Popen(cmd)
            proc.wait()
        except KeyboardInterrupt:
            logging.info("Caught KeyboardInterrupt, shutting down server")
            proc.terminate()
            console.print("\n[bold #00FF41]✅ Server stopped.[/bold #00FF41]")


def main():
    parser = argparse.ArgumentParser(description="Universal Local AI Launcher")
    parser.add_argument(
        "action", nargs="?", choices=["start", "stop"], help="Action to perform"
    )
    parser.add_argument(
        "--model", type=str, help="Bypass menu and load a specific model"
    )
    parser.add_argument(
        "--quant", type=str, default="Q4_K", help="Preferred quantization"
    )
    parser.add_argument(
        "--split",
        action="store_true",
        help="Put model in GPU and context in System RAM",
    )
    parser.add_argument("--cpu", action="store_true", help="Force CPU inference only")

    args = parser.parse_args()
    logging.info(f"Launcher started with args: {args}")

    if not args.action:
        logging.warning("No action provided, printing help and exiting")
        parser.print_help()
        sys.exit(1)

    if args.action == "stop":
        logging.info("Executing stop action")
        stop_server()
        sys.exit(0)

    if args.action == "start":
        logging.info("Executing start action")
        model_to_load = args.model if args.model else interactive_menu()
        start_server(model_to_load, args.quant, args.split, args.cpu)


if __name__ == "__main__":
    logging.info("=== AI LAUNCHER INITIALIZED ===")
    main()
