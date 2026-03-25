"""Local Model resolution and file prep (bypassing HuggingFace APIs)."""

import shutil
import sys
from pathlib import Path

from core.log import console
from huggingface.detect import _resolve_tts_engine

def resolve_engine(model_id: str, category: str = "voice") -> str:
    """Determine the engine type for a local model based on its files."""
    model_name = model_id.split("/")[-1]
    local_dir = Path.home() / ".local" / "share" / "ai-launcher" / "models" / category / model_name

    if not local_dir.exists():
        console.print(f"\n[bold red]❌ Local model directory not found: [white]{local_dir}[/white][/bold red]")
        sys.exit(1)

    files = [f.name for f in local_dir.iterdir() if f.is_file()]

    # Use TTS file heuristics if category is voice
    if category in ("voice", "tts"):
        return _resolve_tts_engine(files, tags=[], library="local", info=None)

    # Simple heuristics for non-voice
    if any(f.endswith(".gguf") for f in files):
        return "llama.cpp"

    console.print(f"\n[bold red]❌ Could not determine engine for local model: [white]{model_id}[/white][/bold red]")
    sys.exit(1)


def prepare_model_files(model_id: str, cache_prefix: str, category: str = "voice") -> Path:
    """Copy local model files into the execution cache directory."""
    model_name = model_id.split("/")[-1]
    local_src_dir = Path.home() / ".local" / "share" / "ai-launcher" / "models" / category / model_name

    model_dir = Path.home() / ".cache" / cache_prefix / model_id.replace("/", "_")
    model_dir.mkdir(parents=True, exist_ok=True)

    console.print(f"📦 [dim]Copying local model: {model_name}...[/dim]")
    for src_file in local_src_dir.iterdir():
        if src_file.is_file():
            target = model_dir / src_file.name
            if not target.exists():
                shutil.copy2(src_file, target)

    return model_dir
