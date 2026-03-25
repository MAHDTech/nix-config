"""ai-launcher — Universal Local AI Launcher."""

import argparse
import logging
import shutil
import sys
from pathlib import Path

from core.log import console
from core.config import load_catalog
from core.ui import interactive_menu
from core.runner import run_engine
from engines import get_engine_specs
from huggingface.detect import resolve_engine
from system.process import stop_server


def main():
    parser = argparse.ArgumentParser(description="Universal Local AI Launcher")
    parser.add_argument(
        "action", nargs="?", choices=["start", "stop", "cleanup"],
        help="Action to perform"
    )
    parser.add_argument(
        "--model", type=str, help="Bypass menu and load a specific model"
    )
    parser.add_argument("--cpu", action="store_true", help="Force CPU inference only")

    args = parser.parse_args()
    logging.info(f"Launcher started with args: {args}")

    if not args.action:
        logging.warning("No action provided, printing help and exiting")
        parser.print_help()
        sys.exit(1)

    if args.action == "stop":
        stop_server()
        sys.exit(0)

    if args.action == "cleanup":
        cleanup_caches()
        sys.exit(0)

    if args.action == "start":
        catalog = load_catalog()

        if args.model:
            model_to_load = args.model
            # Find category for the passed model
            category = "general" # Fallback
            for cat_key, ui_lbl, models in catalog:
                if model_to_load in models:
                    category = cat_key
                    break
        else:
            model_to_load, category = interactive_menu(catalog)

        # Dynamic engine detection (HF / Local fork)
        if model_to_load.startswith("local/"):
            import core.local
            engine_name = core.local.resolve_engine(model_to_load, category=category)
            logging.info(f"Auto-detected engine: {engine_name} for local model {model_to_load} (category: {category})")
        else:
            engine_name = resolve_engine(model_to_load)
            logging.info(f"Auto-detected engine: {engine_name} for model {model_to_load}")

        console.print(
            f"⚙️  [cyan]Auto-detected Engine:[/cyan] [bold white]{engine_name}[/bold white]"
        )

        # Look up the engine spec
        specs = get_engine_specs()
        spec = specs.get(engine_name)
        if not spec:
            console.print(f"[bold red]❌ Unknown engine type: {engine_name}[/bold red]")
            sys.exit(1)

        # Run it
        run_engine(model_to_load, spec, category=category, force_cpu=args.cpu)


def cleanup_caches():
    """Wipe all model caches, venvs, and downloaded files."""
    home = Path.home()
    cache_dirs = [
        (home / ".cache" / "llama.cpp",    "LLM models (llama.cpp)"),
        (home / ".cache" / "xtts",         "TTS models + venv (XTTS/Coqui)"),
        (home / ".cache" / "qwen3-tts",    "TTS models + venv (Qwen3)"),
        (home / ".cache" / "onnx-tts",     "TTS models + venv (ONNX)"),
        (home / ".cache" / "chatterbox",   "TTS models + venv (Chatterbox)"),
        (home / ".cache" / "huggingface",  "HuggingFace hub cache"),
    ]

    console.print("\n[bold #00FF41]🧹 AI Launcher — Cache Cleanup[/bold #00FF41]\n")

    found_any = False
    total_bytes = 0
    dirs_to_clean = []

    for path, label in cache_dirs:
        if path.exists():
            size = sum(f.stat().st_size for f in path.rglob("*") if f.is_file())
            size_gb = size / (1024**3)
            total_bytes += size
            dirs_to_clean.append((path, label, size))
            console.print(f"  [bold white]📁 {path}[/bold white]")
            console.print(f"     {label} — [cyan]{size_gb:.2f} GB[/cyan]")
            found_any = True

    if not found_any:
        console.print("[bold #008F11]✅ No caches found. Already clean![/bold #008F11]")
        return

    total_gb = total_bytes / (1024**3)
    console.print(f"\n  [bold yellow]Total: {total_gb:.2f} GB[/bold yellow]\n")

    try:
        answer = input("  ⚠️  Delete all caches? This cannot be undone. [y/N] ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        console.print("\n[dim]Cancelled.[/dim]")
        return

    if answer != "y":
        console.print("[dim]Cancelled.[/dim]")
        return

    for path, label, _ in dirs_to_clean:
        console.print(f"  [bold red]🗑️  Removing {path}...[/bold red]")
        shutil.rmtree(path)

    console.print(f"\n[bold #00FF41]✅ Freed {total_gb:.2f} GB. All caches wiped.[/bold #00FF41]\n")


if __name__ == "__main__":
    logging.info("=== AI LAUNCHER INITIALIZED ===")
    main()
