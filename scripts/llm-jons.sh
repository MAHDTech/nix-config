#!/usr/bin/env bash

# llm-jons.sh
# Bespoke high-performance LLM runner for 'jons' developer workstation.
# Limits to < 10B models for maximum Intel Arc performance.
# Features an interactive model selection menu with direct GGUF community repos.

set -euo pipefail
export NIXPKGS_ALLOW_UNFREE=1

# --- CONFIGURATION & MODEL CATALOG ---
SCRIPT_NAME=$(basename "$0")
TMP_DIR="${TMPDIR:-/tmp}"
LOG_FILE="$TMP_DIR/${SCRIPT_NAME%.*}.log"
PID_FILE="$TMP_DIR/.llm-jons.pid"

ACTION=""
MODEL_INPUT="" # Left empty to trigger the menu by default
PREFERRED_QUANT="Q4_K_M"

# 🛒 Direct Community GGUF Repositories (Ungated & Ready for Intel Arc)
MODELS_CODING=(
	"Qwen/Qwen2.5-Coder-7B-Instruct-GGUF"
	"Qwen/Qwen2.5-Coder-3B-Instruct-GGUF"
	"bartowski/Meta-Llama-3.1-8B-Instruct-GGUF"
	"bartowski/codegeex4-all-9b-GGUF"
)

MODELS_GENERAL=(
	"bartowski/gemma-2-9b-it-GGUF"
	"maziyarpanahi/Mistral-7B-Instruct-v0.3-GGUF"
	"bartowski/Meta-Llama-3.1-8B-Instruct-GGUF"
)

MODELS_LOGIC=(
	"bartowski/Phi-3-mini-4k-instruct-GGUF"
	"Qwen/Qwen2-Math-7B-Instruct-GGUF"
)

# --- ARGUMENT PARSING ---
while [[ $# -gt 0 ]]; do
	case $1 in
	start | stop)
		ACTION="$1"
		shift
		;;
	--help)
		ACTION="help"
		shift
		;;
	--model)
		MODEL_INPUT="$2"
		shift 2
		;;
	--quant)
		PREFERRED_QUANT="$2"
		shift 2
		;;
	*)
		echo "❌ Unknown parameter: $1"
		exit 1
		;;
	esac
done

if [[ -z $ACTION || $ACTION == "help" ]]; then
	echo "Usage: $0 <start|stop> [OPTIONS]"
	echo "Options:"
	echo "  --help      Show this help message."
	echo "  --model     Bypass menu and load a HuggingFace model directly."
	echo "  --quant     Preferred quantization level (default: Q4_K_M)"
	exit 0
fi

# --- CLEANUP / STOP LOGIC ---
stop_server() {
	if [[ -n ${_STOP_IN_PROGRESS:-} ]]; then return 0; fi
	_STOP_IN_PROGRESS=1
	echo "🛑 Stopping llama-server and cleaning up..."
	if [[ -f $PID_FILE ]]; then
		kill "$(cat "$PID_FILE")" 2>/dev/null || true
		rm -f "$PID_FILE"
	fi
	pkill -f llama-server 2>/dev/null || true
	echo "✅ Cleanup complete."
	unset _STOP_IN_PROGRESS
}

if [[ $ACTION == "stop" ]]; then
	stop_server
	exit 0
fi

# --- INTERACTIVE MENU (If --model is not provided) ---
if [[ -z $MODEL_INPUT && $ACTION == "start" ]]; then
	echo "=================================================="
	echo "🤖 JONS LOCAL AI LAUNCHER (8GB Arc Optimized)"
	echo "=================================================="
	PS3=$'\n👉 Choose a category (1-4): '

	select category in "Coding & Dev" "General Chat" "Math & Logic" "Cancel / Exit"; do
		case $REPLY in
		1)
			echo -e "\n💻 CODING MODELS"
			PS3=$'\n👉 Select a model (1-'${#MODELS_CODING[@]}'): '
			select model in "${MODELS_CODING[@]}"; do
				if [[ -n $model ]]; then
					MODEL_INPUT="$model"
					break 2
				fi
			done
			;;
		2)
			echo -e "\n💬 GENERAL CHAT MODELS"
			PS3=$'\n👉 Select a model (1-'${#MODELS_GENERAL[@]}'): '
			select model in "${MODELS_GENERAL[@]}"; do
				if [[ -n $model ]]; then
					MODEL_INPUT="$model"
					break 2
				fi
			done
			;;
		3)
			echo -e "\n🧠 MATH & LOGIC MODELS"
			PS3=$'\n👉 Select a model (1-'${#MODELS_LOGIC[@]}'): '
			select model in "${MODELS_LOGIC[@]}"; do
				if [[ -n $model ]]; then
					MODEL_INPUT="$model"
					break 2
				fi
			done
			;;
		4)
			echo "Exiting..."
			exit 0
			;;
		*)
			echo "Invalid option. Please choose 1-4."
			;;
		esac
	done
	echo "----------------------------------------------------------------------"
	echo "✅ Selected ${model} from the ${category} category."
fi

# --- HARDWARE CHECK (THE PCIe BOTTLENECK PROTECTOR) ---
MODEL_UPPER="${MODEL_INPUT^^}"

if [[ $MODEL_UPPER =~ [1-9][0-9]+B ]]; then
	echo "⚠️  HARDWARE LIMIT REACHED: You selected a large model ($MODEL_INPUT)."
	echo "❌ This is too large for your 8GB Intel Arc GPU."
	echo "📉 It will spill into System RAM across the PCIe bus and crawl at < 2 tokens/sec."
	echo "👉 Please select a model 9B or smaller for real-time interactive speeds."
	exit 1
fi

# --- MEMORY CALCULATIONS & SMART CONTEXT SIZING ---
AVAILABLE_SYS_BYTES=$(free -b | awk '/^Mem:/{print $7}')
if [[ -z $AVAILABLE_SYS_BYTES || $AVAILABLE_SYS_BYTES == "0" ]]; then
	AVAILABLE_SYS_BYTES=$(free -b | awk '/^Mem:/{print $2}')
fi
SYS_MEM_BYTES=$((AVAILABLE_SYS_BYTES * 75 / 100))
SYS_MEM_GB=$((SYS_MEM_BYTES / 1024 / 1024 / 1024))
GPU_MEM_GB=8

# Since we are forcing 100% of the model AND the KV Cache into 8GB VRAM for max speed,
# the context window ("the desk") must shrink as the model ("the brain") gets larger.
if [[ $MODEL_UPPER == *"8B"* || $MODEL_UPPER == *"9B"* ]]; then
	CONTEXT_SIZE=16384 # 8B/9B take ~5GB VRAM. Leaves 3GB for OS + 16k Context.
elif [[ $MODEL_UPPER == *"7B"* ]]; then
	CONTEXT_SIZE=32768 # 7B takes ~4.5GB VRAM. Fits a comfortable 32k Context.
else
	CONTEXT_SIZE=65536 # Smaller models (3B) safely get the massive 64k desk.
fi

# --- NIXOS ENVIRONMENT WRAPPER ---
if [[ -z ${__LLM_WRAPPED:-} ]]; then
	echo "🚀 HARDWARE PROFILE: 'jons' Workstation"
	echo "🧠 Allocating Limits: ${GPU_MEM_GB}GB VRAM (Fixed) + ${SYS_MEM_GB}GB Sys RAM (75%)"
	echo "📏 Context Size: $CONTEXT_SIZE tokens"
	echo "⚡ Engine: llama-cpp-vulkan (100% GPU Offload)"
	export __LLM_WRAPPED=1
	export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
	export GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt
	exec nix shell --impure \
		"github:NixOS/nixpkgs/nixos-unstable#llama-cpp-vulkan" \
		"github:NixOS/nixpkgs/nixos-unstable#jq" \
		"github:NixOS/nixpkgs/nixos-unstable#curl" \
		"github:NixOS/nixpkgs/nixos-unstable#cacert" \
		--command "$0" "$ACTION" --model "$MODEL_INPUT" --quant "$PREFERRED_QUANT"
fi

# --- AUTO-DISCOVERY ENGINE ---
echo "🌐 Contacting Hugging Face API for: $MODEL_INPUT"

HF_API_RESPONSE=$(curl -s -L "https://huggingface.co/api/models/${MODEL_INPUT}")
# Added 2>/dev/null to gracefully handle gated/forbidden API responses
HAS_GGUF=$(echo "$HF_API_RESPONSE" | jq '[.siblings[]? | select(.rfilename | endswith(".gguf"))] | length' 2>/dev/null || echo "0")

if [[ $HAS_GGUF -gt 0 ]]; then
	TARGET_REPO="$MODEL_INPUT"
else
	MODEL_BASENAME=$(basename "$MODEL_INPUT")
	SEARCH_URL="https://huggingface.co/api/models?search=${MODEL_BASENAME}+GGUF&sort=downloads&limit=1"
	TARGET_REPO=$(curl -s -L "$SEARCH_URL" | jq -r '.[0].id // empty' 2>/dev/null)
	if [[ -z $TARGET_REPO ]]; then
		echo "❌ Could not find any GGUF versions for $MODEL_INPUT on HuggingFace."
		exit 1
	fi
	echo "🌟 Auto-selected GGUF repo: $TARGET_REPO"
fi

ALL_GGUFS=$(curl -s -L "https://huggingface.co/api/models/${TARGET_REPO}" | jq -r '.siblings[]?.rfilename' | grep '\.gguf$' 2>/dev/null || true)
if [[ -z $ALL_GGUFS ]]; then
	echo "❌ Error: Could not parse .gguf files from $TARGET_REPO!"
	exit 1
fi

EXACT_FILE=$(echo "$ALL_GGUFS" | grep -i "$PREFERRED_QUANT" | head -n 1 || true)
if [[ -z $EXACT_FILE ]]; then EXACT_FILE=$(echo "$ALL_GGUFS" | grep -i 'Q4_0' | head -n 1 || true); fi
if [[ -z $EXACT_FILE ]]; then EXACT_FILE=$(echo "$ALL_GGUFS" | head -n 1); fi

echo "🎯 Downloading/Using file: $EXACT_FILE"
echo "----------------------------------------------------------------------"

# --- CHAT TEMPLATE MATCHING ---
CHAT_TEMPLATE=""
case "$MODEL_UPPER" in
*"QWEN"*) CHAT_TEMPLATE="chatml" ;;
*"LLAMA-3"*) CHAT_TEMPLATE="llama3" ;;
*"MISTRAL"*) CHAT_TEMPLATE="mistral" ;;
*"GEMMA"*) CHAT_TEMPLATE="gemma" ;;
*"PHI-3"*) CHAT_TEMPLATE="phi3" ;;
*"PHI-4"*) CHAT_TEMPLATE="phi3" ;;
*"CODEGEEX"*) CHAT_TEMPLATE="chatml" ;;
*)
	echo "⚠️ Unrecognized model family. Relying on GGUF auto-detection for template."
	;;
esac

# --- OPENCODE CONFIG & SERVER START ---
# Strip the author name (e.g., "Qwen/") and the "-GGUF" tag for a pristine UI display name
SHORT_NAME=$(basename "$MODEL_INPUT")
SHORT_NAME=${SHORT_NAME%-GGUF}
SHORT_NAME=${SHORT_NAME%-gguf}

echo "⚙️ Writing OpenCode configuration for local/$SHORT_NAME..."
mkdir -p ~/.config/opencode
cat <<EOF >~/.config/opencode/opencode.json
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "local",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1",
        "apiKey": "sk-dummy"
      },
      "models": {
        "${SHORT_NAME}": {
          "name": "${SHORT_NAME}"
        }
      }
    }
  },
  "model": "local/${SHORT_NAME}"
}
EOF

if [[ $ACTION == "start" ]]; then
	trap stop_server SIGINT SIGTERM EXIT
	true >"$LOG_FILE"
	export GGML_VK_VISIBLE_DEVICES=0

	# Base arguments array
	SERVER_ARGS=(
		--hf-repo "$TARGET_REPO"
		--hf-file "$EXACT_FILE"
		--host 127.0.0.1
		--port 8080
		--n-gpu-layers 999
		--threads 16
		--ctx-size "$CONTEXT_SIZE"
		--flash-attn on
		--alias "$SHORT_NAME"
	)

	# Conditionally append the chat template
	if [[ -n $CHAT_TEMPLATE ]]; then
		SERVER_ARGS+=(--chat-template "$CHAT_TEMPLATE")
	fi

	# Execute the server using the array
	llama-server "${SERVER_ARGS[@]}" >"$LOG_FILE" 2>&1 &

	LLM_PID=$!
	echo "$LLM_PID" >"$PID_FILE"

	until curl -s http://127.0.0.1:8080/health >/dev/null; do
		if ! kill -0 "$LLM_PID" 2>/dev/null; then
			echo "❌ Error: llama-server crashed. Check the logs:"
			cat "$LOG_FILE"
			exit 1
		fi
		sleep 2
	done

	echo "✅ SERVER READY."
	tail -f "$LOG_FILE" &
	TAIL_PID=$!
	wait "$LLM_PID" 2>/dev/null || true
	kill "$TAIL_PID" 2>/dev/null || true
fi
