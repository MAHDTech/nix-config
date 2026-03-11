#!/usr/bin/env bash

# mistral-wrapper.sh
# A simple CLI wrapper for mistral.rs and mistral-vibe local model management

clear
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1

ACTION=$1
shift # Move past the action so we can parse the flags

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
	echo "Usage: ./mistral-wrapper.sh <shell|start|stop|tune|bench|vibe|dev> [--model MODEL_NAME] [--isq ISQ_LEVEL]"
	echo ""
	echo "Commands:"
	echo "  shell   - Enters the Nix environment"
	echo "  start   - Starts the server in the background"
	echo "  stop    - Stops the server"
	echo "  tune    - Auto-profiles hardware"
	echo "  bench   - Runs performance benchmark"
	echo "  vibe    - Starts Mistral Vibe with the model"
	echo "  dev     - The ultimate combo: Shell -> Tune -> Bench -> Start -> Vibe -> Auto-Stop"
	exit 1
fi

# Require --model for everything except shell and stop
if [[ $ACTION != "shell" && $ACTION != "stop" ]] && [[ -z $MODEL ]]; then
	echo "❌ Error: You must specify a model using --model"
	echo "Example: ./mistral-wrapper.sh $ACTION --model Qwen/Qwen2.5-Coder-7B-Instruct"
	exit 1
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
	echo "❄️ Entering Nix shell..."
	nix shell \
		--impure \
		github:NixOS/nixpkgs/nixos-unstable#mistral-rs \
		github:NixOS/nixpkgs/nixos-unstable#mistral-vibe github:NixOS/nixpkgs/nixos-unstable#cacert
	;;

start)
	echo "🚀 Starting server for $MODEL (ISQ: $ISQ)..."
	nohup mistralrs serve --ui auto -m "$MODEL" --isq "$ISQ" >mistral-server.log 2>&1 &

	PID=$!
	echo $PID >.mistral.pid
	echo "✅ Server started in background (PID: $PID). Logs: tail -f mistral-server.log"
	;;

stop)
	if [ -f .mistral.pid ]; then
		PID=$(cat .mistral.pid)
		echo "🛑 Stopping server (PID: $PID)..."
		kill "$PID" 2>/dev/null
		rm .mistral.pid
		echo "✅ Server stopped."
	else
		echo "⚠️ No .mistral.pid file found. Force killing orphaned processes..."
		pkill -f mistralrs
		echo "✅ Cleanup complete."
	fi
	;;

tune)
	echo "⚙️ Tuning hardware for $MODEL..."
	mistralrs tune -m "$MODEL"
	;;

bench)
	echo "⏱️ Benchmarking $MODEL (ISQ: $ISQ)..."
	mistralrs bench auto -m "$MODEL" --isq "$ISQ"
	;;

vibe)
	echo "🤖 Launching Vibe CLI connected to $MODEL..."
	vibe --model "$MODEL"
	;;

dev)
	echo "🌟 Launching Full Dev Workflow for $MODEL..."
	# We pass the entire sequence into the Nix shell using the --command flag
	nix shell github:NixOS/nixpkgs/nixos-unstable#mistral-rs github:NixOS/nixpkgs/nixos-unstable#mistral-vibe github:NixOS/nixpkgs/nixos-unstable#cacert \
		--command bash -c "
			echo -e '\n=== 1/4 Tuning ==='
			mistralrs tune -m '$MODEL'

			echo -e '\n=== 2/4 Benchmarking ==='
			mistralrs bench auto -m '$MODEL' --isq '$ISQ'

			echo -e '\n=== 3/4 Starting Server ==='
			nohup mistralrs serve --ui auto -m '$MODEL' --isq '$ISQ' > mistral-server.log 2>&1 &
			echo \$! > .mistral.pid
			echo 'Waiting 5 seconds for shards to load into memory...'
			sleep 5

			echo -e '\n=== 4/4 Launching Vibe ==='
			vibe --model '$MODEL'

			echo -e '\n🛑 Vibe session ended. Cleaning up background server...'
			kill \$(cat .mistral.pid) 2>/dev/null
			rm .mistral.pid
			echo '✅ Clean exit.'
		"
	;;

*)
	echo "❌ Unknown action: $ACTION"
	exit 1
	;;
esac
