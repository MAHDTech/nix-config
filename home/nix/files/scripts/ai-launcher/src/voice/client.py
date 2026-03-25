"""Voice client — browser launcher, one-shot synthesis, stop server."""

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

from core.ports import PORT_TTS

PORT = PORT_TTS
BASE_URL = f"http://127.0.0.1:{PORT}"


def cmd_start(args):
    """Open the voice test web UI in the browser."""
    url = f"http://127.0.0.1:{args.port}"

    # Check if the server is running
    try:
        req = urllib.request.urlopen(f"{url}/health", timeout=2)
        if req.status != 200:
            raise Exception("Server not healthy")
    except Exception:
        print(f"\033[1;31m❌ No AI Voice server running on port {args.port}.\033[0m")
        print(f"\033[1;32m   Start one first:\033[0m")
        print(f"\033[0;32m   ai-launcher start  (then pick a TTS model)\033[0m")
        sys.exit(1)

    # Fetch model info
    try:
        req = urllib.request.urlopen(f"{url}/info", timeout=2)
        info = json.loads(req.read())
        model = info.get("model", "unknown")
        backend = info.get("backend", "unknown")
        device = info.get("device", "unknown")
        print(f"\033[1;32m🔊 AI Voice Server active\033[0m")
        print(f"\033[0;32m   Model:   {model}\033[0m")
        print(f"\033[0;32m   Backend: {backend}\033[0m")
        print(f"\033[0;32m   Device:  {device}\033[0m")
    except Exception:
        pass

    print(f"\n\033[1;32m🌐 Opening: {url}\033[0m")
    print(f"\033[0;32m   If the browser doesn't open, visit: {url}\033[0m\n")

    try:
        subprocess.Popen(
            ["xdg-open", url],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        print(f"\033[1;33m⚠️  xdg-open not found. Open manually: {url}\033[0m")


def cmd_say(args):
    """One-shot TTS: send text to the running server and play the audio."""
    text = " ".join(args.text) if args.text else None
    if not text:
        print(f"\033[1;31m❌ Usage: ai-voice say \"text to speak\"\033[0m")
        sys.exit(1)

    url = f"http://127.0.0.1:{args.port}"

    try:
        urllib.request.urlopen(f"{url}/health", timeout=2)
    except Exception:
        print(f"\033[1;31m❌ No AI Voice server running on port {args.port}.\033[0m")
        print(f"\033[0;32m   Start one first: ai-launcher start\033[0m")
        sys.exit(1)

    print(f"\033[1;32m🔊 Synthesizing:\033[0m {text}")

    try:
        data = json.dumps({"text": text}).encode()
        req = urllib.request.Request(
            f"{url}/synthesize",
            data=data,
            headers={"Content-Type": "application/json"},
        )
        resp = urllib.request.urlopen(req, timeout=60)

        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.write(resp.read())
        tmp.close()

        print(f"\033[1;32m✅ Playing audio...\033[0m")

        # Try audio players in order of preference
        player = None
        player_cmd = None
        for candidate in ["pw-play", "paplay", "aplay", "ffplay"]:
            if shutil.which(candidate):
                player = candidate
                if candidate == "ffplay":
                    player_cmd = [candidate, "-nodisp", "-autoexit", tmp.name]
                else:
                    player_cmd = [candidate, tmp.name]
                break

        if player_cmd:
            subprocess.run(
                player_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        else:
            print(f"\033[1;33m⚠️  No audio player found. WAV saved: {tmp.name}\033[0m")
            tmp.name  # keep the file
            return

        os.unlink(tmp.name)

    except urllib.error.HTTPError as e:
        print(f"\033[1;31m❌ Server error: {e.code} {e.reason}\033[0m")
        sys.exit(1)
    except Exception as e:
        print(f"\033[1;31m❌ Failed: {e}\033[0m")
        sys.exit(1)


def cmd_stop(args):
    """Stop the voice server process."""
    try:
        import psutil
    except ImportError:
        print("\033[1;31m❌ psutil not available\033[0m")
        sys.exit(1)

    killed = False
    for proc in psutil.process_iter(["pid", "cmdline"]):
        try:
            cmdline = " ".join(proc.info["cmdline"] or [])
            if "voice/server.py" in cmdline or "voice_server.py" in cmdline:
                os.kill(proc.info["pid"], signal.SIGTERM)
                killed = True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    if killed:
        print("\033[1;32m✅ Voice server stopped.\033[0m")
    else:
        print("\033[0;32m⚠️  No voice server process found.\033[0m")


def main():
    parser = argparse.ArgumentParser(
        description="AI Voice — test text-to-speech models",
        epilog="Start a TTS model with: ai-launcher start (pick a TTS model)\n"
               "Then use: ai-voice start  OR  ai-voice say \"hello world\"",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "action", choices=["start", "say", "stop"],
        help="start=open web UI, say=one-shot synthesis, stop=kill server"
    )
    parser.add_argument(
        "--port", type=int, default=PORT, help=f"Server port (default: {PORT})"
    )
    parser.add_argument(
        "text", nargs="*", help="Text to speak (for 'say' action)"
    )

    args = parser.parse_args()

    if args.action == "start":
        cmd_start(args)
    elif args.action == "say":
        cmd_say(args)
    elif args.action == "stop":
        cmd_stop(args)
