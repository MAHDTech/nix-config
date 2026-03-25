"""GPU detection: vendor identification and VRAM measurement."""

import logging
import re
import subprocess
from pathlib import Path


def get_gpu_vendor_and_vram():
    """Programmatically gets exact VRAM and GPU Vendor."""
    logging.debug("Detecting GPU vendor and VRAM...")

    # Try NVIDIA first
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

    # Try AMD via sysfs
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

    # Try glxinfo fallback
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
