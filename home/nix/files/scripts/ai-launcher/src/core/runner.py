"""Generic engine runner — provisions nix-shells, venvs, and starts servers."""

import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

from core.log import console
from huggingface.api import download_model_files
from system.gpu import get_gpu_vendor_and_vram


def _resolve_runtime_libs(device: str) -> list[str]:
    """Dynamically resolve runtime library paths from nix store.

    Always includes FFmpeg libs (needed by torchcodec).
    Adds Intel GPU libs when device is xpu.
    """
    nix_pkgs = [
        ("ffmpeg-full.lib", "lib"),       # torchcodec needs libavutil etc.
    ]
    if device == "xpu":
        nix_pkgs += [
            ("level-zero", "lib"),
            ("intel-compute-runtime", "lib"),
            ("intel-compute-runtime", "lib/intel-opencl"),
            ("intel-compute-runtime.drivers", "lib"),  # libze_intel_gpu.so (Level Zero GPU backend)
        ]
    lib_dirs = []
    for pkg, subdir in nix_pkgs:
        try:
            result = subprocess.run(
                ["nix", "eval", "--raw", f"nixpkgs#{pkg}.outPath"],
                capture_output=True, text=True, timeout=30,
            )
            if result.returncode == 0:
                lib_path = Path(result.stdout.strip()) / subdir
                if lib_path.exists():
                    lib_dirs.append(str(lib_path))
                    logging.debug(f"Runtime lib: {lib_path}")
        except Exception as e:
            logging.debug(f"Failed to resolve {pkg}: {e}")
    return lib_dirs



def run_engine(model_id: str, spec, category: str = "voice", force_cpu: bool = False):
    """Download model, provision environment, and start the server.

    If the spec has a custom_handler, delegate entirely to it.
    Otherwise use the generic nix-shell / venv / subprocess pipeline.
    """
    if spec.custom_handler:
        spec.custom_handler(model_id, spec, force_cpu)
        return

    # --- Detect GPU ---
    if force_cpu:
        vendor, device = "cpu", "cpu"
    else:
        vendor, _ = get_gpu_vendor_and_vram()
        device = {"nvidia": "cuda", "intel": "xpu"}.get(vendor, "cpu")

    console.print(
        f"🚀 [bold #00FF41]Starting {spec.name} for:[/bold #00FF41] {model_id}"
    )
    console.print(
        f"[bold #008F11]⚙️  Device: {device.upper()}[/bold #008F11]"
    )

    # --- Download model files ---
    if model_id.startswith("local/"):
        import core.local
        model_dir = core.local.prepare_model_files(model_id, cache_prefix=spec.venv_name, category=category)
    else:
        model_dir = download_model_files(model_id, cache_prefix=spec.venv_name)

    # --- Build setup commands ---
    setup_cmds = []
    venv_dir = Path.home() / ".cache" / spec.venv_name / "venv"
    venv_pip = venv_dir / "bin" / "pip"
    venv_python = venv_dir / "bin" / "python"

    if spec.needs_venv:
        # Always recreate venv for clean state
        if venv_dir.exists():
            console.print("[bold #008F11]🧹 Clearing old venv...[/bold #008F11]")
            shutil.rmtree(venv_dir)
        console.print("[bold #008F11]🔧 Creating Python venv...[/bold #008F11]")
        setup_cmds.append(f"python3 -m venv '{venv_dir}'")

        if spec.pip_packages:
            # Separate torch packages from the rest for Intel XPU index handling
            # Core torch packages go to XPU index; torchcodec must use CPU index
            # (XPU index doesn't carry torchcodec, and PyPI default has CUDA-linked binaries)
            core_torch_pkgs = [p for p in spec.pip_packages if p.startswith("torch") and p != "torchcodec"]
            torchcodec_pkgs = [p for p in spec.pip_packages if p == "torchcodec"]
            other_pkgs = [p for p in spec.pip_packages if not p.startswith("torch")]

            console.print(
                "[bold #008F11]📦 Installing dependencies (this may take a few minutes)...[/bold #008F11]"
            )

            # Intel XPU: install core torch from official XPU index
            if device == "xpu" and core_torch_pkgs:
                xpu_pkgs = " ".join(f"'{p}'" for p in core_torch_pkgs)
                console.print(
                    "[bold #008F11]⚡ Intel XPU detected — installing PyTorch from Intel XPU index[/bold #008F11]"
                )
                setup_cmds.append(
                    f"'{venv_pip}' install {xpu_pkgs} --index-url https://download.pytorch.org/whl/xpu"
                )
                # torchcodec: install from CPU index (no CUDA deps)
                if torchcodec_pkgs:
                    console.print(
                        "[bold #008F11]⚡ Installing torchcodec from CPU index (no CUDA deps)[/bold #008F11]"
                    )
                    setup_cmds.append(
                        f"'{venv_pip}' install 'torchcodec' --index-url https://download.pytorch.org/whl/cpu"
                    )
            elif core_torch_pkgs:
                pkgs = " ".join(f"'{p}'" for p in core_torch_pkgs + torchcodec_pkgs)
                setup_cmds.append(f"'{venv_pip}' install {pkgs}")

            # Install remaining packages from default PyPI
            if other_pkgs:
                pkgs = " ".join(f"'{p}'" for p in other_pkgs)
                setup_cmds.append(f"'{venv_pip}' install {pkgs}")

    # --- Build run command ---
    if spec.nix_packages and not spec.server_script:
        # Pure Nix-shell CLI execution
        nix_pkg = spec.nix_packages[0]
        if vendor not in ["cpu", "nvidia"] and not force_cpu:
            vulkan_pkg = nix_pkg.replace("#llama-cpp", "#llama-cpp-vulkan")
            if vulkan_pkg != nix_pkg:
                nix_pkg = vulkan_pkg

        cmd = spec.build_command(
            model_dir=model_dir,
            model_id=model_id,
            device=device,
            nix_package=nix_pkg,
        )
    elif spec.server_script and spec.nix_packages:
        # Python server script executed inside a Nix-shell
        nix_pkg = spec.nix_packages[0]
        server_script = Path(__file__).parents[1] / spec.server_script
        run_cmd_args = spec.build_command(
            model_dir=model_dir,
            model_id=model_id,
            device=device,
            venv_python=str(venv_python),
            server_script=str(server_script),
            nix_package=nix_pkg
        )

        # In this hybrid case, we setup the python venv dependencies in bash,
        # then spawn the nix shell which invokes our python server script.
        target_cmd = ["nix", "shell", nix_pkg, "--command", "bash", "-c", run_cmd_args]

        if setup_cmds:
            setup_cmd_str = " && ".join(setup_cmds)
            cmd = ["bash", "-c", f"{setup_cmd_str} && " + " ".join(f"'{c}'" if " " in c else c for c in target_cmd)]
        else:
            cmd = target_cmd

    elif spec.server_script:
        # Standard Venv-based pure Python execution
        server_script = Path(__file__).parents[1] / spec.server_script
        run_cmd = spec.build_command(
            model_dir=model_dir,
            model_id=model_id,
            device=device,
            venv_python=str(venv_python),
            server_script=str(server_script),
        )
        if setup_cmds:
            cmd_str = " && ".join(setup_cmds) + f" && {run_cmd}"
            cmd = ["bash", "-c", cmd_str]
        else:
            cmd = ["bash", "-c", run_cmd]
    else:
        console.print(f"[bold red]❌ Engine {spec.name} has no server configuration.[/bold red]")
        sys.exit(1)

    # --- Execute ---
    console.print(
        f"[bold #008F11]🌐 API will be available at: http://127.0.0.1:{spec.port}[/bold #008F11]\n"
    )
    logging.info(f"Executing: {cmd}")

    env = os.environ.copy()

    # Inject runtime libraries (FFmpeg for torchcodec, Intel GPU for XPU)
    if spec.needs_venv:
        runtime_lib_paths = _resolve_runtime_libs(device)
        if runtime_lib_paths:
            existing = env.get("LD_LIBRARY_PATH", "")
            env["LD_LIBRARY_PATH"] = ":".join(runtime_lib_paths + ([existing] if existing else []))
            console.print(
                f"[bold #008F11]⚡ Injected runtime libraries into LD_LIBRARY_PATH[/bold #008F11]"
            )

    try:
        proc = subprocess.Popen(cmd, env=env)
        proc.wait()
    except KeyboardInterrupt:
        logging.info("Caught KeyboardInterrupt, shutting down server")
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        console.print("\n[bold #00FF41]✅ Server stopped.[/bold #00FF41]")
