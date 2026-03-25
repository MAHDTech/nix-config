#!/usr/bin/env python3
"""
AI Voice Server — multi-backend TTS HTTP server with Web UI.

Supports backends: coqui (XTTSv2), qwen3 (GGUF), onnx, chatterbox.

Usage:
    python3 voice/server.py --backend coqui --device cpu --port 8084 --model-dir PATH
"""

import argparse
import io
import json
import sys
import wave
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Voice Test</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Courier New', monospace;
    background: #0a0a0a;
    color: #00ff41;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
  }
  .container {
    width: 100%; max-width: 620px; padding: 2rem;
  }
  h1 {
    font-size: 2rem;
    text-align: center;
    margin-bottom: 0.5rem;
    text-shadow: 0 0 10px #00ff41;
  }
  .subtitle {
    text-align: center;
    color: #008f11;
    margin-bottom: 2rem;
    font-size: 0.9rem;
  }
  textarea {
    width: 100%;
    height: 120px;
    background: #111;
    color: #00ff41;
    border: 1px solid #00ff41;
    padding: 1rem;
    font-family: inherit;
    font-size: 1rem;
    resize: vertical;
    border-radius: 4px;
  }
  textarea:focus { outline: none; border-color: #00ff80; box-shadow: 0 0 8px #00ff4133; }
  button {
    width: 100%;
    padding: 1rem;
    margin-top: 1rem;
    background: #00ff41;
    color: #0a0a0a;
    border: none;
    font-family: inherit;
    font-size: 1.1rem;
    font-weight: bold;
    cursor: pointer;
    border-radius: 4px;
    transition: all 0.2s;
  }
  button:hover { background: #00ff80; transform: translateY(-1px); }
  button:disabled { background: #333; color: #666; cursor: wait; }
  #status {
    text-align: center;
    margin-top: 1rem;
    color: #008f11;
    min-height: 1.5rem;
  }
  #model-info {
    text-align: center;
    color: #555;
    font-size: 0.8rem;
    margin-top: 0.5rem;
  }
  audio {
    width: 100%;
    margin-top: 1rem;
    filter: sepia(20%) hue-rotate(90deg);
  }
  .examples {
    margin-top: 2rem;
    border-top: 1px solid #333;
    padding-top: 1rem;
  }
  .examples h3 { color: #008f11; margin-bottom: 0.5rem; }
  .example-btn {
    background: transparent;
    color: #008f11;
    border: 1px solid #333;
    padding: 0.5rem;
    margin: 0.25rem 0;
    font-size: 0.85rem;
    text-align: left;
    width: 100%;
  }
  .example-btn:hover { border-color: #00ff41; color: #00ff41; background: #111; }
</style>
</head>
<body>
<div class="container">
  <h1>🔊 AI VOICE</h1>
  <p class="subtitle">Local Text-to-Speech &bull; ai-launcher</p>

  <textarea id="text" placeholder="Enter text to synthesize...">Hello, I am your local text to speech model.</textarea>

  <button id="speak" onclick="synthesize()">▶ SPEAK</button>
  <div id="status"></div>
  <div id="model-info"></div>
  <audio id="audio" controls style="display:none"></audio>

  <div class="examples">
    <h3>Test Phrases</h3>
    <button class="example-btn" onclick="setExample(this)">The quick brown fox jumps over the lazy dog.</button>
    <button class="example-btn" onclick="setExample(this)">In a world where machines can speak, what stories would they tell?</button>
    <button class="example-btn" onclick="setExample(this)">Testing one, two, three. Can you hear me clearly?</button>
    <button class="example-btn" onclick="setExample(this)">The system is operating within normal parameters. All diagnostics nominal.</button>
  </div>
</div>

<script>
function setExample(btn) {
  document.getElementById('text').value = btn.textContent;
}

fetch('/info').then(r => r.json()).then(info => {
  document.getElementById('model-info').textContent =
    `Model: ${info.model || 'unknown'} | Backend: ${info.backend || 'unknown'} | Device: ${info.device || 'unknown'}`;
}).catch(() => {});

async function synthesize() {
  const text = document.getElementById('text').value.trim();
  if (!text) return;

  const btn = document.getElementById('speak');
  const status = document.getElementById('status');
  const audio = document.getElementById('audio');

  btn.disabled = true;
  btn.textContent = '⏳ SYNTHESIZING...';
  status.textContent = 'Generating speech...';
  audio.style.display = 'none';

  try {
    const res = await fetch('/synthesize', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({text: text})
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(err);
    }

    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    audio.src = url;
    audio.style.display = 'block';
    audio.play();
    status.textContent = '✅ Ready';
  } catch (e) {
    status.textContent = '❌ ' + e.message;
  } finally {
    btn.disabled = false;
    btn.textContent = '▶ SPEAK';
  }
}
</script>
</body>
</html>"""


# ─── TTS Backend Loaders ────────────────────────────────────────────

def load_coqui(model_dir, device):
    """Load Coqui TTS (XTTSv2) backend."""
    from TTS.api import TTS as CoquiTTS

    # XTTS expects the checkpoint directory, not individual file paths
    tts = CoquiTTS(
        model_path=str(model_dir),
        config_path=str(model_dir / "config.json"),
    )
    if device != "cpu":
        import torch
        device_ok = False
        if device == "xpu" and hasattr(torch, "xpu") and torch.xpu.is_available():
            device_ok = True
        elif device == "cuda" and torch.cuda.is_available():
            device_ok = True

        if device_ok:
            tts.to(device)
        else:
            print(f"⚠️  {device.upper()} requested but not available, falling back to CPU")
            device = "cpu"

    def synthesize(text):
        ref_wav = model_dir / "reference.wav"
        tts_kwargs = {"text": text, "language": "en"}
        if ref_wav.exists():
            tts_kwargs["speaker_wav"] = str(ref_wav)
        wav = tts.tts(**tts_kwargs)
        sample_rate = tts.synthesizer.output_sample_rate
        return wav, sample_rate

    return synthesize


def load_qwen3(model_dir, device):
    """Load Qwen3-TTS GGUF backend via py-qwen3-tts-cpp."""
    try:
        from py_qwen3_tts_cpp.model import Qwen3TTSModel
    except ImportError:
        from py_qwen3_tts_cpp import Qwen3TTS as Qwen3TTSModel

    # Find the GGUF model file
    gguf_files = list(model_dir.glob("*.gguf"))
    if not gguf_files:
        print(f"❌ No GGUF files found in {model_dir}")
        sys.exit(1)

    model_file = gguf_files[0]
    print(f"📂 Loading Qwen3-TTS model: {model_file.name}")
    tts = Qwen3TTSModel(str(model_file))

    def synthesize(text):
        # Qwen3-TTS returns (audio_array, sample_rate)
        ref_wav = model_dir / "reference.wav"
        if ref_wav.exists():
            wav, sr = tts.synthesize(text, ref_audio=str(ref_wav))
        else:
            wav, sr = tts.synthesize(text)
        return wav, sr

    return synthesize


def load_onnx(model_dir, device):
    """Load ONNX TTS backend."""
    import numpy as np
    import onnxruntime as ort

    # Find the ONNX model
    onnx_files = list(model_dir.glob("*.onnx"))
    if not onnx_files:
        print(f"❌ No ONNX files found in {model_dir}")
        sys.exit(1)

    model_file = onnx_files[0]
    print(f"📂 Loading ONNX model: {model_file.name}")
    session = ort.InferenceSession(str(model_file))

    def synthesize(text):
        # ONNX inference — the exact API depends on the model
        # This is a generic implementation; specific models may need adjustments
        input_name = session.get_inputs()[0].name
        # Basic tokenization — would need model-specific tokenizer
        inputs = {input_name: np.array([[ord(c) for c in text]], dtype=np.int64)}
        result = session.run(None, inputs)
        wav = result[0].flatten()
        return wav.tolist(), 22050  # Default sample rate

    return synthesize


def load_chatterbox(model_dir, device):
    """Load Chatterbox TTS backend."""
    from chatterbox.tts import ChatterboxTTS

    print(f"📂 Loading Chatterbox model...")
    model = ChatterboxTTS.from_pretrained(device=device)

    def synthesize(text):
        ref_wav = model_dir / "reference.wav"
        if ref_wav.exists():
            wav = model.generate(text, audio_prompt=str(ref_wav))
        else:
            wav = model.generate(text)
        # Chatterbox returns a tensor
        audio = wav.squeeze().cpu().numpy()
        return audio.tolist(), 24000

    return synthesize


def load_piper(model_dir, device):
    """Load Piper TTS backend via subprocess to CLI binary."""
    import subprocess
    import tempfile

    # Find the ONNX model
    onnx_files = list(model_dir.glob("*.onnx"))
    if not onnx_files:
        print(f"❌ No ONNX files found in {model_dir}")
        sys.exit(1)

    # Prefer English if multiple exist
    model_file = next((f for f in onnx_files if "en_US" in f.name.lower()), onnx_files[0])
    print(f"📂 Loading Piper model: {model_file.name}")

    def synthesize(text):
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            out_path = f.name

        cmd = [
            "piper",
            "--model", str(model_file),
            "--output_file", out_path
        ]

        # Piper takes text on stdin
        proc = subprocess.run(
            cmd, input=text, text=True, capture_output=True
        )

        if proc.returncode != 0:
            import os
            if os.path.exists(out_path):
                os.unlink(out_path)
            raise RuntimeError(f"Piper failed: {proc.stderr}")

        # Read the generated WAV file directly
        with open(out_path, "rb") as wf:
            wav_bytes = wf.read()

        import os
        os.unlink(out_path)

        # Return none for sample_rate so the handler knows it's already encoded WAV bytes
        return wav_bytes, None

    return synthesize


BACKEND_LOADERS = {
    "coqui": load_coqui,
    "qwen3": load_qwen3,
    "onnx": load_onnx,
    "chatterbox": load_chatterbox,
    "piper": load_piper,
}


# ─── HTTP Handler ────────────────────────────────────────────────────

class VoiceHandler(SimpleHTTPRequestHandler):
    synthesize_fn = None
    model_name = "unknown"
    backend_name = "unknown"
    device = "cpu"

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode())
        elif self.path == "/info":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            info = {
                "status": "ok",
                "model": VoiceHandler.model_name,
                "backend": VoiceHandler.backend_name,
                "device": VoiceHandler.device,
            }
            self.wfile.write(json.dumps(info).encode())
        elif self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/synthesize":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length))
            text = body.get("text", "")

            if not text:
                self.send_error(400, "No text provided")
                return

            try:
                print(f"🔊 Synthesizing: {text[:80]}...")
                result, sample_rate = VoiceHandler.synthesize_fn(text)

                if sample_rate is None:
                    # Result is already fully encoded WAV bytes
                    audio_bytes = result
                else:
                    # Convert float array to WAV bytes
                    import numpy as np

                    buf = io.BytesIO()
                    with wave.open(buf, "wb") as wf:
                        wf.setnchannels(1)
                        wf.setsampwidth(2)
                        wf.setframerate(sample_rate)
                        audio_int16 = (np.array(result) * 32767).astype(np.int16)
                        wf.writeframes(audio_int16.tobytes())
                    audio_bytes = buf.getvalue()

                self.send_response(200)
                self.send_header("Content-Type", "audio/wav")
                self.send_header("Content-Length", str(len(audio_bytes)))
                self.end_headers()
                self.wfile.write(audio_bytes)
                print("✅ Audio sent")

            except Exception as e:
                print(f"❌ Synthesis failed: {e}")
                self.send_error(500, str(e))
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        pass  # Suppress default access logs


# ─── Main ────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="AI Voice Server")
    parser.add_argument("--backend", required=True, choices=list(BACKEND_LOADERS.keys()),
                        help="TTS backend to use")
    parser.add_argument("--device", default="cpu", choices=["cpu", "cuda", "xpu"],
                        help="Inference device (default: cpu)")
    parser.add_argument("--port", type=int, default=8084, help="Server port")
    parser.add_argument("--model-dir", type=str, required=True,
                        help="Path to model directory")
    parser.add_argument("--model-name", type=str, default="unknown",
                        help="Display name for the model")
    args = parser.parse_args()

    model_dir = Path(args.model_dir)
    if not model_dir.exists():
        print(f"❌ Model directory not found: {model_dir}")
        sys.exit(1)

    print(f"📂 Model directory: {model_dir}")
    print(f"⚙️  Backend: {args.backend}")
    print(f"⚙️  Device: {args.device}")
    print("🔧 Loading TTS model (this may take a moment)...")

    loader = BACKEND_LOADERS[args.backend]
    synthesize_fn = loader(model_dir, args.device)

    VoiceHandler.synthesize_fn = synthesize_fn
    VoiceHandler.model_name = args.model_name
    VoiceHandler.backend_name = args.backend
    VoiceHandler.device = args.device

    print(f"\n🚀 AI Voice Server running at: http://127.0.0.1:{args.port}")
    print(f"   Backend: {args.backend} | Device: {args.device}")
    print("   Open in your browser to test the voice!")
    print("   Press Ctrl+C to stop.\n")

    server = HTTPServer(("127.0.0.1", args.port), VoiceHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n✅ Server stopped.")
        server.server_close()


if __name__ == "__main__":
    main()
