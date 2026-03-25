"""HuggingFace API client — model info, file downloads."""

import logging
import sys
from pathlib import Path

from huggingface_hub import HfApi, hf_hub_download

from core.log import console

api = HfApi()


def fetch_model_info(model_id: str):
    """Fetch model metadata from HuggingFace. Exits on failure."""
    try:
        logging.debug(f"Querying Hugging Face API for {model_id}...")
        console.print(
            f"🔍 [dim]Querying Hugging Face API for {model_id}...[/dim]"
        )
        return api.model_info(model_id)
    except Exception as e:
        logging.error(f"Failed to fetch model info for {model_id}: {e}")
        console.print(
            f"[bold red]❌ UPLINK FAILED. CHECK NETWORK CONNECTION.[/bold red]"
        )
        console.print(f"[bold red]Details: {e}[/bold red]")
        sys.exit(1)


def get_param_count(model_id: str, info=None) -> float:
    """Get total parameter count in billions from HuggingFace metadata.

    Tries (in order):
      1. safetensors.total from API metadata
      2. Regex from model name (e.g. '7B', '0.6B')
      3. Defaults to 7.0B
    """
    import re

    if info is None:
        info = fetch_model_info(model_id)

    # Try safetensors metadata (most accurate)
    safetensors = getattr(info, "safetensors", None)
    if safetensors and isinstance(safetensors, dict):
        total = safetensors.get("total", 0)
        if total > 0:
            params_b = total / 1e9
            logging.info(f"Got param count from safetensors metadata: {params_b:.1f}B")
            return params_b

    # Try card_data / model_index
    card_data = getattr(info, "card_data", None)
    if card_data:
        model_params = getattr(card_data, "model_parameters", None)
        if model_params:
            try:
                params_b = float(model_params) / 1e9
                logging.info(f"Got param count from card_data: {params_b:.1f}B")
                return params_b
            except (ValueError, TypeError):
                pass

    # Fallback: regex from model name
    model_upper = model_id.upper()
    param_match = re.search(r"(\d+(?:\.\d+)?)B", model_upper)
    if param_match:
        params_b = float(param_match.group(1))
        logging.info(f"Got param count from model name regex: {params_b:.1f}B")
        return params_b

    logging.warning(f"Could not determine param count for {model_id}, defaulting to 7.0B")
    return 7.0





def download_file(repo_id: str, filename: str) -> str:
    """Download a single file from a HuggingFace repo. Returns local path."""
    console.print(f"⬇️  [dim]Fetching: {filename}...[/dim]")
    logging.info(f"Downloading {filename} from {repo_id}")
    return hf_hub_download(repo_id=repo_id, filename=filename)


def download_model_files(model_id: str, cache_prefix: str = "models") -> Path:
    """Download all model files and symlink into a local cache directory."""
    info = fetch_model_info(model_id)
    files = [f.rfilename for f in getattr(info, "siblings", [])]
    model_files = [f for f in files if not f.startswith(".")]

    model_dir = Path.home() / ".cache" / cache_prefix / model_id.replace("/", "_")
    model_dir.mkdir(parents=True, exist_ok=True)

    for mf in model_files:
        console.print(f"⬇️  [dim]Fetching: {mf}...[/dim]")
        logging.info(f"Fetching model file: {mf}")
        local_path = hf_hub_download(repo_id=model_id, filename=mf)
        target = model_dir / Path(mf).name
        if not target.exists():
            target.symlink_to(local_path)

    return model_dir
