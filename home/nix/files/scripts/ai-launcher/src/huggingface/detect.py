"""Engine detection from HuggingFace model metadata."""

import logging
import sys

from core.log import console
from huggingface.api import fetch_model_info

# Supported pipeline tasks → engine mappings
SUPPORTED_TASKS = {
    "text-generation": "llama.cpp",
    "image-text-to-text": "llama.cpp",
    "feature-extraction": "llama.cpp-embedding",
    "text-to-image": "sd.cpp",
    "automatic-speech-recognition": "whisper.cpp",
    "text-to-speech": None,  # Resolved further by file heuristics
}

SUPPORTED_TASK_LABELS = [
    "text-generation (LLMs)",
    "image-text-to-text (Vision LLMs)",
    "feature-extraction (Embeddings)",
    "text-to-image (Image Generation)",
    "automatic-speech-recognition (Speech to Text)",
    "text-to-speech (Text to Speech)",
]


def resolve_engine(model_id: str) -> str:
    """Query HuggingFace API and determine the engine type from metadata.

    Returns an engine name string that maps to ENGINE_SPECS in engines/__init__.py.
    Exits with a helpful message if the model type is unsupported.
    """
    try:
        info = fetch_model_info(model_id)
        task = getattr(info, "pipeline_tag", None)
        tags = getattr(info, "tags", []) or []
        library = getattr(info, "library_name", "") or ""
        files = [f.rfilename for f in getattr(info, "siblings", [])]

        logging.debug(f"HF metadata — task={task}, library={library}, tags={tags[:5]}")

        # --- Check if we support this task at all ---
        if task and task not in SUPPORTED_TASKS:
            console.print(
                f"\n[bold red]❌ Unsupported model type: [white]{task}[/white][/bold red]"
            )
            console.print(
                f"[bold red]   Model [white]{model_id}[/white] is a [white]{task}[/white] model.[/bold red]\n"
            )
            console.print("[bold #008F11]Supported model types:[/bold #008F11]")
            for label in SUPPORTED_TASK_LABELS:
                console.print(f"[#008F11]   • {label}[/#008F11]")
            console.print(
                f"\n[dim]   Pipeline tag from HuggingFace: {task}[/dim]"
            )
            sys.exit(1)

        # --- Direct task mappings ---
        if task in SUPPORTED_TASKS and SUPPORTED_TASKS[task] is not None:
            return SUPPORTED_TASKS[task]

        # --- Text to speech: resolve by file heuristics ---
        if task == "text-to-speech":
            return _resolve_tts_engine(files, tags, library, info)

        # --- No pipeline tag: fallback heuristics ---
        if task is None:
            logging.warning(f"Model {model_id} has no pipeline_tag — using file heuristics")
            console.print(
                f"[yellow]⚠️ Model has no pipeline tag — detecting from file contents...[/yellow]"
            )

            if any(f == "model.pth" or f.endswith("model.pth") for f in files):
                return "xtts"
            if any(f.endswith(".gguf") for f in files):
                return "llama.cpp"
            if any(f.endswith(".onnx") for f in files):
                return "onnx-tts"

            # Completely unknown
            console.print(
                f"\n[bold red]❌ Could not determine model type for: [white]{model_id}[/white][/bold red]"
            )
            console.print(
                f"[bold red]   No pipeline tag and no recognizable model files found.[/bold red]\n"
            )
            console.print("[bold #008F11]Supported model types:[/bold #008F11]")
            for label in SUPPORTED_TASK_LABELS:
                console.print(f"[#008F11]   • {label}[/#008F11]")
            sys.exit(1)

        # Should not reach here — all task branches are handled above
        _abort_unknown(model_id, task, files, library, tags)

    except SystemExit:
        raise  # Let sys.exit() through
    except Exception as e:
        logging.error(f"Engine detection failed for {model_id}: {e}")
        console.print(
            f"\n[bold red]❌ Failed to detect engine for: [white]{model_id}[/white][/bold red]"
        )
        console.print(f"[bold red]   Error: {e}[/bold red]\n")
        console.print("[bold #008F11]Supported model types:[/bold #008F11]")
        for label in SUPPORTED_TASK_LABELS:
            console.print(f"[#008F11]   • {label}[/#008F11]")
        console.print(
            f"\n[dim]   Check that the model ID is correct and the repository is public.[/dim]"
        )
        sys.exit(1)


def _abort_unknown(model_id, task, files, library, tags):
    """Abort with a diagnostic message when no engine could be determined."""
    console.print(
        f"\n[bold red]❌ Could not determine engine for: [white]{model_id}[/white][/bold red]"
    )
    console.print(
        f"[dim]   Pipeline tag: {task or 'none'}[/dim]"
    )
    console.print(
        f"[dim]   Library: {library or 'unknown'} | Tags: {', '.join(tags[:5]) or 'none'}[/dim]"
    )
    console.print(
        f"[dim]   Files: {', '.join(files[:8])}{'...' if len(files) > 8 else ''}[/dim]\n"
    )
    console.print("[bold #008F11]Supported model types:[/bold #008F11]")
    for label in SUPPORTED_TASK_LABELS:
        console.print(f"[#008F11]   • {label}[/#008F11]")
    sys.exit(1)

SUPPORTED_TTS_ENGINES = [
    ("xtts",           "XTTSv2 / Coqui TTS",     "model.pth + config.json"),
    ("qwen3-tts-gguf", "Qwen3-TTS GGUF (CPU)",   ".gguf files"),
    ("onnx-tts",       "ONNX TTS (no PyTorch)",   ".onnx files"),
    ("chatterbox",     "Chatterbox (voice clone)", "chatterbox library tag"),
    ("piper",          "Piper (lightweight)",      ".onnx + piper tag"),
]


def _resolve_tts_engine(files: list, tags: list, library: str, info) -> str:
    """Determine specific TTS engine from file contents and tags."""
    has_gguf = any(f.endswith(".gguf") for f in files)
    has_onnx = any(f.endswith(".onnx") for f in files)
    has_onnx_json = any(f.endswith(".onnx.json") for f in files)
    has_model_pth = any(
        f == "model.pth" or f.endswith("model.pth") for f in files
    )
    is_piper = "piper" in tags or "piper-tts" in tags or has_onnx_json
    is_chatterbox = "chatterbox" in library.lower() or "chatterbox" in " ".join(tags).lower()

    if has_gguf:
        return "qwen3-tts-gguf"
    elif is_chatterbox:
        return "chatterbox"
    elif has_onnx and is_piper:
        return "piper"
    elif has_onnx:
        return "onnx-tts"
    elif has_model_pth:
        return "xtts"
    else:
        # Check model_type in config
        config = getattr(info, "config", None)
        model_type = getattr(config, "model_type", "") if config else ""
        if "qwen" in model_type.lower():
            return "qwen3-tts-gguf"

        # We got a TTS model but can't figure out which engine it needs
        console.print(
            f"\n[bold red]❌ This is a text-to-speech model, but we can't determine "
            f"which TTS engine it needs.[/bold red]\n"
        )
        console.print(
            f"[dim]   Files found: {', '.join(files[:8])}{'...' if len(files) > 8 else ''}[/dim]"
        )
        console.print(
            f"[dim]   Library: {library or 'unknown'} | Tags: {', '.join(tags[:5])}[/dim]\n"
        )
        console.print("[bold #008F11]Supported TTS engines:[/bold #008F11]")
        for _, label, expects in SUPPORTED_TTS_ENGINES:
            console.print(f"[#008F11]   • {label}  [dim](expects: {expects})[/dim][/#008F11]")
        console.print(
            f"\n[dim]   If this model uses a framework we don't support yet, "
            f"please open an issue or add a new engine handler.[/dim]"
        )
        sys.exit(1)
