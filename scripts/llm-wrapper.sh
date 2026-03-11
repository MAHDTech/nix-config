#!/usr/bin/env bash

# llm-wrapper.sh
# A unified CLI wrapper for Mistral Vibe local coding.
# Auto-detects NVIDIA (uses mistralrs) vs Intel (uses Vulkan llama.cpp)
# Dynamically calculates context window based on GPU VRAM

clear
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1

# --- LOGGING SETUP ---
SCRIPT_NAME=$(basename "$0")
TMP_DIR="${TMPDIR:-/tmp}"
LOG_FILE="$TMP_DIR/${SCRIPT_NAME%.*}.log"

ACTION=${1:-""}
if [[ -n $ACTION ]]; then
	shift # Move past the action so we can parse the flags
fi

# Default values
ISQ="Q4K"
MODEL=""

# Argument parser
while [[ $# -gt 0 ]]; do
	case $1 in
	--model)
		MODEL="$2"
		shift 2
		;;
	--isq)
		ISQ="$2"
		shift 2
		;;
	*)
		echo "Unknown parameter: $1"
		shift
		;;
	esac
done

if [ -z "$ACTION" ]; then
	echo "Usage: ./llm-wrapper.sh <shell|start|stop|tune|bench|vibe|dev> [--model MODEL_NAME] [--isq ISQ_LEVEL]"
	echo ""
	echo "Commands:"
	echo "  shell   - Enters the Nix environment"
	echo "  start   - Starts the server in the background"
	echo "  stop    - Stops the server"
	echo "  tune    - Auto-profiles hardware"
	echo "  bench   - Runs performance benchmark"
	echo "  vibe    - Starts Mistral Vibe with the current backend"
	echo "  dev     - The ultimate combo: Shell -> Tune -> Bench -> Start -> Vibe -> Auto-Stop"
	exit 1
fi

if [[ $ACTION != "shell" && $ACTION != "stop" ]] && [[ -z $MODEL ]]; then
	echo "❌ Error: You must specify a model using --model"
	echo "Example: ./llm-wrapper.sh $ACTION --model Qwen/Qwen2.5-Coder-7B-Instruct"
	exit 1
fi

# --- GPU AUTO-DETECTION ---
GPU_VENDOR="unknown"
if command -v lspci >/dev/null 2>&1 && lspci | grep -i nvidia >/dev/null; then
	GPU_VENDOR="nvidia"
elif command -v lspci >/dev/null 2>&1 && lspci | grep -i intel | grep -iE 'vga|3d|display' >/dev/null; then
	GPU_VENDOR="intel"
elif command -v lsgpu >/dev/null 2>&1 && lsgpu | grep -i intel >/dev/null; then
	GPU_VENDOR="intel"
else
	GPU_VENDOR="intel" # Fallback
fi

# --- VRAM & CONTEXT SIZE CALCULATION ---
GPU_MEM_GB=12 # Safe default fallback

if [[ $GPU_VENDOR == "nvidia" ]] && command -v nvidia-smi >/dev/null 2>&1; then
	# Parse exactly how many GBs NVIDIA reports
	GPU_MEM_GB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | awk '{print int($1/1024)}')
else
	# Parse Linux sysfs or lspci for Intel/AMD VRAM
	VRAM_BYTES=$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | sort -nr | head -n 1 || true)
	if [[ -n $VRAM_BYTES ]]; then
		GPU_MEM_GB=$((VRAM_BYTES / 1024 / 1024 / 1024))
	elif command -v lspci >/dev/null 2>&1; then
		# Fallback: Check PCIe BAR size (often matches VRAM on modern Arc/Radeon GPUs)
		VRAM_G=$(lspci -v 2>/dev/null | grep -iE 'VGA|Display|3D' -A 10 | grep "Memory at" | grep "prefetchable" | grep -oE '[0-9]+G' | head -n 1 | tr -d 'G' || true)
		if [[ -n $VRAM_G ]]; then
			GPU_MEM_GB="$VRAM_G"
		fi
	fi
fi

# Map VRAM to optimal context window length
case $GPU_MEM_GB in
24 | 2[4-9] | [3-9][0-9]) CONTEXT_SIZE=65536 ;; # 24GB+
16 | 1[6-9] | 2[0-3]) CONTEXT_SIZE=49152 ;;     # 16GB - 23GB
12 | 1[2-5]) CONTEXT_SIZE=32768 ;;              # 12GB - 15GB (Your Arc B580 hits here!)
8 | [8-9] | 1[0-1]) CONTEXT_SIZE=16384 ;;       # 8GB - 11GB
6 | 7) CONTEXT_SIZE=8192 ;;                     # 6GB - 7GB
*) CONTEXT_SIZE=4096 ;;                         # 4GB or fallback
esac

echo "🔍 Detected GPU: ${GPU_VENDOR^^} (~${GPU_MEM_GB}GB VRAM)"
echo "🧠 Allocated Context: $CONTEXT_SIZE tokens"
echo "📝 Server logs will be written to: $LOG_FILE"

# --- BACKEND CONFIGURATION ---
if [[ $GPU_VENDOR == "nvidia" ]]; then
	BACKEND="mistralrs"
	VIBE_ALIAS="qwen-nvidia"
	TARGET_REPO="$MODEL"
	NIX_PKGS=(
		"github:NixOS/nixpkgs/nixos-unstable#mistral-rs"
		"github:NixOS/nixpkgs/nixos-unstable#mistral-vibe"
		"github:NixOS/nixpkgs/nixos-unstable#cacert"
	)
else
	BACKEND="llamacpp"
	VIBE_ALIAS="qwen-arc"
	NIX_PKGS=(
		"github:NixOS/nixpkgs/nixos-unstable#llama-cpp-vulkan"
		"github:NixOS/nixpkgs/nixos-unstable#mistral-vibe"
		"github:NixOS/nixpkgs/nixos-unstable#cacert"
	)

	if [[ $MODEL == *"-GGUF" ]]; then
		LLAMA_REPO="$MODEL"
	else
		LLAMA_REPO="${MODEL}-GGUF"
	fi
	TARGET_REPO="$LLAMA_REPO"

	BASE_MODEL=$(basename "$MODEL")
	BASE_MODEL=${BASE_MODEL%-GGUF}
	BASE_LOWER=${BASE_MODEL,,}

	if [[ $ISQ == "Q4K" ]]; then
		LLAMA_FILE="${BASE_LOWER}-q4_k_m.gguf"
	else
		LLAMA_FILE="${BASE_LOWER}-${ISQ,,}.gguf"
	fi
fi

# --- MODEL VALIDATION ---
if [[ $ACTION != "shell" && $ACTION != "stop" ]]; then
	echo "🌍 Validating \"$TARGET_REPO\" via Hugging Face API..."
	HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://huggingface.co/api/models/$TARGET_REPO" || echo "000")

	if [[ $HTTP_STATUS != "200" ]]; then
		echo "❌ ERROR: No model named \"$TARGET_REPO\" was found on Hugging Face (HTTP $HTTP_STATUS)."
		exit 1
	fi
	echo "✅ Model successfully validated."
fi

# --- NIX NETWORK FIXES ---
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
export GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt

if [ ! -f "$SSL_CERT_FILE" ]; then
	export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
	export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
fi
# -------------------------

case $ACTION in
shell)
	echo "❄️ Entering Nix shell for $BACKEND..."
	nix shell --impure "${NIX_PKGS[@]}"
	;;

start)
	echo "🚀 Starting $BACKEND server for $TARGET_REPO (ISQ: $ISQ)..."
	if [[ $BACKEND == "mistralrs" ]]; then
		nohup mistralrs serve --ui auto -m "$MODEL" --isq "$ISQ" >"$LOG_FILE" 2>&1 &
	else
		nohup llama-server --hf-repo "$LLAMA_REPO" --hf-file "$LLAMA_FILE" -ngl 99 -c "$CONTEXT_SIZE" --port 8080 >"$LOG_FILE" 2>&1 &
	fi

	PID=$!
	echo "$PID" >.llm.pid
	echo "✅ Server started in background (PID: $PID)."
	echo "👉 Open a new terminal and run: tail -f $LOG_FILE"
	;;

stop)
	if [ -f .llm.pid ]; then
		PID=$(cat .llm.pid)
		echo "🛑 Stopping server (PID: $PID)..."
		kill "$PID" 2>/dev/null || true
		rm .llm.pid
	fi
	pkill -f mistralrs 2>/dev/null || true
	pkill -f llama-server 2>/dev/null || true
	echo "✅ Cleanup complete."
	;;

tune)
	if [[ $BACKEND == "mistralrs" ]]; then
		echo "⚙️ Tuning hardware for $MODEL..."
		mistralrs tune -m "$MODEL"
	else
		echo "⚙️ Tuning bypassed: llama.cpp Vulkan backend automatically offloads VRAM (-ngl 99)."
	fi
	;;

bench)
	if [[ $BACKEND == "mistralrs" ]]; then
		echo "⏱️ Benchmarking $MODEL (ISQ: $ISQ)..."
		mistralrs bench auto -m "$MODEL" --isq "$ISQ"
	else
		echo "⏱️ Benchmarking bypassed: llama-server integrates token metrics natively in logs."
	fi
	;;

vibe)
	echo "🤖 Launching Vibe CLI connected to $VIBE_ALIAS..."
	sed -i 's/^active_model[[:space:]]*=.*/active_model = "'"$VIBE_ALIAS"'"/' ~/.vibe/config.toml
	vibe
	;;

dev)
	echo "🌟 Launching Full Dev Workflow via $BACKEND..."

	sed -i 's/^active_model[[:space:]]*=.*/active_model = "'"$VIBE_ALIAS"'"/' ~/.vibe/config.toml

	if [[ $BACKEND == "mistralrs" ]]; then
		nix shell --impure "${NIX_PKGS[@]}" \
			--command bash -c "
					echo -e '\n=== 1/4 Tuning ==='
					mistralrs tune -m '$MODEL'
					echo -e '\n=== 2/4 Benchmarking ==='
					mistralrs bench auto -m '$MODEL' --isq '$ISQ'
					echo -e '\n=== 3/4 Starting Server ==='
					nohup mistralrs serve --ui auto -m '$MODEL' --isq '$ISQ' > '$LOG_FILE' 2>&1 &
					echo \$! > .llm.pid
					echo '👉 Open a new terminal and run: tail -f $LOG_FILE'
					echo 'Waiting 15 seconds for shards to load...'
					sleep 15
					echo -e '\n=== 4/4 Launching Vibe ==='
					vibe
					echo -e '\n✅ Vibe closed. Server is STILL RUNNING in the background.'
					echo 'To stop it and free VRAM, run: ./scripts/llm-wrapper.sh stop'
				"
	else
		nix shell --impure "${NIX_PKGS[@]}" \
			--command bash -c "
					echo -e '\n=== 1/4 Tuning ==='
					echo 'Using Vulkan (-ngl 99) for Intel GPU'
					echo -e '\n=== 2/4 Benchmarking ==='
					echo 'Skipped for llama-server.'
					echo -e '\n=== 3/4 Starting Server ==='
					nohup llama-server --hf-repo '$LLAMA_REPO' --hf-file '$LLAMA_FILE' -ngl 99 -c '$CONTEXT_SIZE' --port 8080 > '$LOG_FILE' 2>&1 &
					echo \$! > .llm.pid
					echo '👉 Open a new terminal and run: tail -f $LOG_FILE'
					echo 'Waiting 15 seconds for model to load into VRAM...'
					sleep 15
					echo -e '\n=== 4/4 Launching Vibe ==='
					vibe
					echo -e '\n✅ Vibe closed. Server is STILL RUNNING in the background.'
					echo 'To stop it and free ARC VRAM, run: ./scripts/llm-wrapper.sh stop'
				"
	fi
	;;

*)
	echo "❌ Unknown action: $ACTION"
	exit 1
	;;
esac
