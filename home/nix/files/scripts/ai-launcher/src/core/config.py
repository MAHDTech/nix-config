"""Model catalog loading and category schema."""

import logging
import os
import shutil
from pathlib import Path

import yaml

from core.log import console

# Setup Config Directories
HOME_DIR = Path.home()
USER_CONFIG_DIR = HOME_DIR / ".config" / "ai-launcher"
USER_CONFIG_FILE = USER_CONFIG_DIR / "config.yaml"
DEFAULT_CONFIG_FILE = Path(__file__).parents[1] / "ai-launcher.yaml"

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


def _load_yaml(path: Path) -> dict:
    """Load a YAML file and return the 'models' section, or empty dict."""
    try:
        with open(path, "r") as f:
            data = yaml.safe_load(f)
            return data.get("models", {}) if data else {}
    except Exception as e:
        logging.error(f"Failed to load {path}: {e}")
        return {}


def _extract_names(models: list) -> list[str]:
    """Extract model name strings from a list of dicts or strings."""
    names = []
    for m in models:
        if isinstance(m, dict) and "name" in m:
            names.append(m["name"])
        elif isinstance(m, str):
            names.append(m)
    return names


def _merge_catalogs(defaults: dict, user: dict) -> dict:
    """Merge user catalog into defaults — user models are appended, not duplicated."""
    merged = {}

    # Start with all default categories
    for cat, models in defaults.items():
        merged[cat] = _extract_names(models)

    # Append user models (new categories or additions to existing ones)
    for cat, models in user.items():
        user_names = _extract_names(models)
        if cat in merged:
            for name in user_names:
                if name not in merged[cat]:
                    merged[cat].append(name)
        else:
            merged[cat] = user_names

    return merged


def load_catalog():
    import sys

    # --- Step 1: Ensure user config exists ---
    if not USER_CONFIG_FILE.exists():
        try:
            USER_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            if DEFAULT_CONFIG_FILE.exists():
                shutil.copy2(DEFAULT_CONFIG_FILE, USER_CONFIG_FILE)
                # Ensure writable by user (Nix store source is read-only)
                os.chmod(USER_CONFIG_FILE, 0o644)
                console.print(
                    f"[bold #008F11]📋 Created default config at: {USER_CONFIG_FILE}[/bold #008F11]"
                )
                console.print(
                    f"[dim]   Add your own models by editing this file.[/dim]\n"
                )
            else:
                logging.warning(f"Default config not found at {DEFAULT_CONFIG_FILE}")
        except Exception as e:
            console.print(
                f"\n[bold red]Unable to create config at {USER_CONFIG_FILE}.[/bold red]"
            )
            logging.error(f"Failed to create user config: {e}")
            sys.exit(1)

    # --- Step 2: Load defaults from package ---
    default_catalog = _load_yaml(DEFAULT_CONFIG_FILE) if DEFAULT_CONFIG_FILE.exists() else {}

    # --- Step 3: Load user config and merge ---
    user_catalog = _load_yaml(USER_CONFIG_FILE) if USER_CONFIG_FILE.exists() else {}
    merged = _merge_catalogs(default_catalog, user_catalog)

    # --- Step 4: Translate short keys to rich UI labels and return structured data ---
    final_catalog = []
    for short_key, model_names in merged.items():
        ui_label = CATEGORY_SCHEMA.get(short_key, short_key.replace("_", " ").title())
        final_catalog.append((short_key, ui_label, model_names))

    return final_catalog
