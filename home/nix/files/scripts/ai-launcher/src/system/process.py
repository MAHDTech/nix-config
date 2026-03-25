"""Process management — find and stop AI server processes."""

import logging
import os

import psutil

from core.log import console


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
        "xtts_api_server",
        "voice_server",
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
