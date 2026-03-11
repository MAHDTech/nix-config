#!/usr/bin/env bash

# llm-local.sh
# A wrapper script to start a local model for OpenCode on NixOS.
# Auto-detects NVIDIA/AMD (mistralrs) or Intel (Ollama Vulkan), or CPU-only mode.
# Dynamically allocates 75% GPU VRAM and 50% System RAM for hybrid workloads.

set -euo pipefail
export NIXPKGS_ALLOW_UNFREE=1

# --- CONFIGURATION & DEFAULTS ---
SCRIPT_NAME=$(basename "$0")
TMP_DIR="${TMPDIR:-/tmp}"
LOG_FILE="$TMP_DIR/${SCRIPT_NAME%.*}.log"
PID_FILE="$TMP_DIR/.llm.pid"

ACTION=""
MODEL="Qwen/Qwen2.5-Coder-7B-Instruct"
CPU_ENABLED=false
CPU_TYPE="ollama"
UPDATE_CONFIG=false
ISQ="Q4K"

# HuggingFace to Ollama Model Mapping (Update this array as needed)
declare -A OLLAMA_MODEL_MAP=(
	["Qwen/Qwen2.5-Coder-7B-Instruct"]="qwen2.5-coder:7b"
	["Qwen/Qwen2.5-Coder-1.5B-Instruct"]="qwen2.5-coder:1.5b"
	["Qwen/Qwen2.5-Coder-32B-Instruct"]="qwen2.5-coder:32b"
	["deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct"]="deepseek-coder-v2"
	["meta-llama/Llama-3-8B-Instruct"]="llama3:8b"
)

# --- ARGUMENT PARSING ---
while [[ $# -gt 0 ]]; do
	case $1 in
	start | stop | opencode)
		ACTION="$1"
		shift
		;;
	--help)
		ACTION="help"
		shift
		;;
	--cpu)
		CPU_ENABLED=true
		if [[ -n ${2:-} && $2 != --* ]]; then
			CPU_TYPE="$2"
			shift 2
		else
			shift
		fi
		;;
	--config)
		UPDATE_CONFIG=true
		shift
		;;
	--model)
		MODEL="$2"
		shift 2
		;;
	--isq)
		ISQ="$2"
		shift 2
		;;
	*)
		echo "❌ Unknown parameter: $1"
		exit 1
		;;
	esac
done

if [[ -z $ACTION || $ACTION == "help" ]]; then
	echo "Usage: $0 <start|stop|opencode> [OPTIONS]"
	echo ""
	echo "Actions:"
	echo "  start       Starts the model, tails logs in foreground. CTRL+C to stop cleanly."
	echo "  stop        Stops the server from another terminal and cleans up processes."
	echo "  opencode    Launches OpenCode from Nixpkgs."
	echo ""
	echo "Options:"
	echo "  --help      Show this help message."
	echo "  --model     HuggingFace model name (default: Qwen/Qwen2.5-Coder-7B-Instruct)."
	echo "  --config    Overwrite the OpenCode config for the active model/backend."
	echo "  --cpu       Force CPU mode [ollama|mistralrs] (default: ollama, caps at 50% of system RAM)."
	echo "  --isq       Quantization level for MistralRS (default: Q4K)."
	exit 0
fi

# --- CLEANUP / STOP LOGIC ---
stop_servers() {
	# Prevent multiple invocations
	if [[ -n ${_STOP_IN_PROGRESS:-} ]]; then
		return 0
	fi
	_STOP_IN_PROGRESS=1

	echo "🛑 Stopping servers and cleaning up..."
	if [[ -f $PID_FILE ]]; then
		PID=$(cat "$PID_FILE")
		kill "$PID" 2>/dev/null || true
		rm -f "$PID_FILE"
	fi
	pkill -f mistralrs 2>/dev/null || true
	pkill -f "ollama serve" 2>/dev/null || true
	echo "✅ Cleanup complete."

	unset _STOP_IN_PROGRESS
}

if [[ $ACTION == "stop" ]]; then
	stop_servers
	exit 0
fi

# --- HARDWARE & MEMORY DETECTION ---
GPU_VENDOR="unknown"
if [[ $CPU_ENABLED == true ]]; then
	GPU_VENDOR="cpu"
elif command -v lsgpu >/dev/null 2>&1; then
	if lsgpu | grep -iE 'NVIDIA|GeForce|Quadro|Tesla' >/dev/null; then
		GPU_VENDOR="nvidia"
	elif lsgpu | grep -iE 'AMD|Radeon|RX|Ryzen Integrated' >/dev/null; then
		GPU_VENDOR="amd"
	elif lsgpu | grep -iE 'Intel.*Arc|Battlemage|Alchemist' >/dev/null; then
		GPU_VENDOR="intel"
	elif lsgpu | grep -i 'vga compatible controller' | grep -i intel >/dev/null; then
		GPU_VENDOR="intel"
	elif lsgpu | grep -i 'vga compatible controller' | grep -i amd >/dev/null; then
		GPU_VENDOR="amd"
	fi
fi

# 1. Calculate 50% System RAM
TOTAL_SYS_BYTES=$(free -b | awk '/^Mem:/{print $2}')
SYS_MEM_BYTES=$((TOTAL_SYS_BYTES * 50 / 100))
SYS_MEM_GB=$((SYS_MEM_BYTES / 1024 / 1024 / 1024))

# 2. Calculate 75% GPU VRAM (0 if CPU mode)
GPU_MEM_BYTES=0
GPU_MEM_GB=0

if [[ $GPU_VENDOR != "cpu" ]]; then
	TOTAL_VRAM_MB=0
	if [[ $GPU_VENDOR == "nvidia" ]] && command -v nvidia-smi >/dev/null 2>&1; then
		TOTAL_VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)
	else
		VRAM_BYTES=$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | sort -nr | head -n 1 || true)
		if [[ -n $VRAM_BYTES ]]; then
			TOTAL_VRAM_MB=$((VRAM_BYTES / 1024 / 1024))
		elif command -v lspci >/dev/null 2>&1; then
			VRAM_G=$(lspci -v 2>/dev/null | grep -iE 'VGA|Display|3D' -A 10 | grep "Memory at" | grep "prefetchable" | grep -oE '[0-9]+G' | head -n 1 | tr -d 'G' || true)
			if [[ -n $VRAM_G ]]; then
				TOTAL_VRAM_MB=$((VRAM_G * 1024))
			fi
		fi
	fi

	if [[ $TOTAL_VRAM_MB -gt 0 ]]; then
		GPU_MEM_BYTES=$((TOTAL_VRAM_MB * 1024 * 1024 * 75 / 100))
		GPU_MEM_GB=$((GPU_MEM_BYTES / 1024 / 1024 / 1024))
	fi
fi

# Total Combined Allocation for Context Window Math
TOTAL_ALLOC_GB=$((SYS_MEM_GB + GPU_MEM_GB))

case $TOTAL_ALLOC_GB in
24 | 2[4-9] | [3-9][0-9]) CONTEXT_SIZE=65536 ;;
16 | 1[6-9] | 2[0-3]) CONTEXT_SIZE=49152 ;;
12 | 1[2-5]) CONTEXT_SIZE=32768 ;;
8 | [8-9] | 1[0-1]) CONTEXT_SIZE=16384 ;;
6 | 7) CONTEXT_SIZE=8192 ;;
*) CONTEXT_SIZE=4096 ;;
esac

# --- APPLY BACKEND SETTINGS ---
case "${GPU_VENDOR:-unknown}" in
"nvidia" | "amd")
	BACKEND="mistralrs"
	NIX_PKGS=(
		"github:NixOS/nixpkgs/nixos-unstable#mistral-rs"
		"github:NixOS/nixpkgs/nixos-unstable#opencode"
		"github:NixOS/nixpkgs/nixos-unstable#cacert"
	)
	TARGET_REPO="$MODEL"
	;;
"intel")
	BACKEND="ollama"
	NIX_PKGS=(
		"github:NixOS/nixpkgs/nixos-unstable#ollama-vulkan"
		"github:NixOS/nixpkgs/nixos-unstable#opencode"
		"github:NixOS/nixpkgs/nixos-unstable#cacert"
	)
	if [[ -n ${OLLAMA_MODEL_MAP[$MODEL]:-} ]]; then
		TARGET_REPO="${OLLAMA_MODEL_MAP[$MODEL]}"
	else
		TARGET_REPO=$(basename "$MODEL" | tr '[:upper:]' '[:lower:]')
	fi
	CUSTOM_TAG="${TARGET_REPO}-opencode"
	;;
"cpu")
	export CUDA_VISIBLE_DEVICES=""
	export GGML_VK_VISIBLE_DEVICES=""
	export ROCR_VISIBLE_DEVICES=""

	case "$CPU_TYPE" in
	"mistralrs")
		BACKEND="mistralrs"
		NIX_PKGS=(
			"github:NixOS/nixpkgs/nixos-unstable#mistral-rs"
			"github:NixOS/nixpkgs/nixos-unstable#opencode"
			"github:NixOS/nixpkgs/nixos-unstable#cacert"
		)
		TARGET_REPO="$MODEL"
		;;
	"ollama" | *)
		BACKEND="ollama"
		NIX_PKGS=(
			"github:NixOS/nixpkgs/nixos-unstable#ollama"
			"github:NixOS/nixpkgs/nixos-unstable#opencode"
			"github:NixOS/nixpkgs/nixos-unstable#cacert"
		)
		if [[ -n ${OLLAMA_MODEL_MAP[$MODEL]:-} ]]; then
			TARGET_REPO="${OLLAMA_MODEL_MAP[$MODEL]}"
		else
			TARGET_REPO=$(basename "$MODEL" | tr '[:upper:]' '[:lower:]')
		fi
		CUSTOM_TAG="${TARGET_REPO}-opencode"
		;;
	esac
	;;
*)
	echo "Unknown or unsupported GPU vendor ${GPU_VENDOR}"
	exit 1
	;;
esac

# --- NIXOS ENVIRONMENT WRAPPER ---
if [[ -z ${__LLM_WRAPPED:-} ]]; then
	echo "🔍 Detected Hardware: ${GPU_VENDOR^^}"
	echo "🧠 Memory Limits: ${GPU_MEM_GB}GB VRAM (75%) + ${SYS_MEM_GB}GB RAM (50%)"
	echo "📏 Context Size:  $CONTEXT_SIZE tokens (Based on ${TOTAL_ALLOC_GB}GB Total memory)"
	echo "⚙️ Backend Choice: ${BACKEND^^}"

	export __LLM_WRAPPED=1
	export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
	export GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt
	if [ ! -f "$SSL_CERT_FILE" ]; then
		export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
		export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
	fi

	echo "❄️ Bootstrapping Nix Environment..."
	ARGS=("$ACTION" --model "$MODEL" --isq "$ISQ")
	[[ $CPU_ENABLED == true ]] && ARGS+=(--cpu "$CPU_TYPE")
	[[ $UPDATE_CONFIG == true ]] && ARGS+=(--config)
	exec nix shell --impure "${NIX_PKGS[@]}" --command "$0" "${ARGS[@]}"
fi

# --- INSIDE NIX SHELL EXECUTION ---
if [[ $UPDATE_CONFIG == true ]]; then
	echo "⚙️ Overwriting OpenCode configuration for ${BACKEND^^}..."
	mkdir -p ~/.config/opencode

	if [[ $BACKEND == "ollama" ]]; then
		CONFIG_MODEL="${CUSTOM_TAG}"
		PROVIDER="ollama"
	else
		CONFIG_MODEL="${TARGET_REPO}"
		PROVIDER="mistralrs"
	fi

	cat <<EOF >~/.config/opencode/opencode.json
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "${PROVIDER}": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "${PROVIDER^^} Local Server",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1",
        "apiKey": "sk-dummy"
      },
      "models": {
        "${CONFIG_MODEL}": {
          "name": "${CONFIG_MODEL}"
        }
      }
    }
  },
  "model": "${PROVIDER}/${CONFIG_MODEL}"
}
EOF
	echo "✅ OpenCode config updated successfully."
fi

if [[ $ACTION == "opencode" ]]; then
	echo "🤖 Launching OpenCode..."
	unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
	export NO_PROXY="localhost,127.0.0.1,::1"
	export OPENAI_API_KEY="sk-dummy"
	exec opencode

elif [[ $ACTION == "start" ]]; then
	trap stop_servers SIGINT SIGTERM EXIT
	echo "🚀 Starting ${BACKEND^^} server for $TARGET_REPO..."

	true >"$LOG_FILE" # Clear old logs

	if [[ $BACKEND == "mistralrs" ]]; then

		# --- MISTRALRS PRE-FLIGHT CHECKS ---
		echo "----------------------------------------------------------------------"
		echo "🩺 Running mistralrs doctor..."
		mistralrs doctor

		echo "----------------------------------------------------------------------"
		echo "🛠️ Running mistralrs tune (Hardware profiling)..."
		mistralrs tune

		echo "----------------------------------------------------------------------"
		echo "📊 Running mistralrs bench for $MODEL..."
		echo "   (This will test your hardware speeds. Please wait...)"
		mistralrs bench -m "$MODEL" --isq "$ISQ"
		echo "----------------------------------------------------------------------"

		echo "🚀 Pre-flight complete. Starting inference server..."
		MISTRAL_ARGS=(serve --host 127.0.0.1 --port 8080 --ui auto -m "$MODEL" --isq "$ISQ")

		mistralrs "${MISTRAL_ARGS[@]}" >"$LOG_FILE" 2>&1 &
		LLM_PID=$!
		echo "$LLM_PID" >"$PID_FILE"

		echo "⏳ Waiting for MistralRS to initialize..."
		echo "   (This takes a few minutes on CPU while it quantizes the model to $ISQ...)"

		# Looping until it responds with HTTP 200
		MISTRAL_COUNTER=0
		while ! curl -s http://127.0.0.1:8080/v1/models >/dev/null; do
			# Check if the process crashed while we were waiting
			if ! kill -0 "$LLM_PID" 2>/dev/null; then
				echo "❌ Error: MistralRS crashed during startup. Check the logs."
				exit 1
			fi
			sleep 10
			MISTRAL_COUNTER=$((MISTRAL_COUNTER + 1))
			echo "Still waiting, attempt ${MISTRAL_COUNTER}..."
		done
	else
		export OLLAMA_HOST="127.0.0.1:8080"
		export OLLAMA_MAX_VRAM="$GPU_MEM_BYTES"
		export OLLAMA_KEEP_ALIVE="-1"
		export OLLAMA_NUM_PARALLEL="1"

		ollama serve >"$LOG_FILE" 2>&1 &
		LLM_PID=$!
		echo "$LLM_PID" >"$PID_FILE"

		echo "⏳ Waiting for Ollama server to boot..."
		sleep 3

		echo "📥 Pulling base model $TARGET_REPO..."
		ollama pull "$TARGET_REPO"

		echo "⚙️ Creating explicit OpenCode tag to enforce $CONTEXT_SIZE context..."
		echo "FROM $TARGET_REPO" >.Modelfile.tmp
		echo "PARAMETER num_ctx $CONTEXT_SIZE" >>.Modelfile.tmp
		ollama create "$CUSTOM_TAG" -f .Modelfile.tmp
		rm -f .Modelfile.tmp
	fi

	echo ""
	echo "✅ Server is READY and running."
	echo "📝 Tailing logs below. Press [CTRL+C] to gracefully stop the server."
	echo "👉 To launch the UI, open a new terminal and run: $0 opencode"
	echo "----------------------------------------------------------------------"

	tail -f "$LOG_FILE" &
	TAIL_PID=$!

	wait "$LLM_PID" 2>/dev/null || true
	kill "$TAIL_PID" 2>/dev/null || true
fi
