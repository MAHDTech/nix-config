"""Shared globals: logging, Rich console."""

import logging
import sys
import tempfile
from pathlib import Path

from rich.console import Console

# Setup Logging
script_name = "ai-launcher"
log_file = Path(tempfile.gettempdir()) / f"{script_name}.log"

logging.basicConfig(
    filename=log_file,
    filemode="w",
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

console = Console()


def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return

    logging.error("Uncaught exception", exc_info=(exc_type, exc_value, exc_traceback))
    console.print(f"\n[bold red]❌ CRITICAL SYSTEM FAILURE.[/bold red]")
    console.print(f"[bold #008F11]Check diagnostic logs at: {log_file}[/bold #008F11]")
    sys.exit(1)


sys.excepthook = handle_exception
