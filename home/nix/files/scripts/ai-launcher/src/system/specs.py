"""System spec calculation — VRAM budgeting and context sizing."""

import logging
import sys

import psutil
from core.log import console
from huggingface.api import get_param_count

from system.gpu import get_gpu_vendor_and_vram


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

    # Get actual param count from HuggingFace metadata (not regex guessing)
    params_b = get_param_count(model_name)
    console.print(
        f"[bold #008F11]🧠 Model size: {params_b:.1f}B parameters[/bold #008F11]"
    )

    brain_gb = params_b * 0.65
    logging.debug(
        f"Estimated brain size: {brain_gb:.2f}GB (based on {params_b}B parameters)"
    )

    if vendor == "cpu" or force_cpu:
        desk_gb = sys_mem_gb * 0.75
        fixed_sizes = [32768, 16384, 8192, 4096]
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
        fixed_sizes = [32768, 16384, 8192, 4096]
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
        fixed_sizes = [32768, 16384, 8192, 4096]
        budget_type = "GPU VRAM"

    # Conservative estimate for KV cache memory per token.
    # Actual values range from ~0.055 (Qwen) to ~0.125 (LLaMA-3) MB/token,
    # halved for Q4 quantization. We use a middle-ground value.
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
