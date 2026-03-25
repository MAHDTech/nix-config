"""Centralized port assignments for all ai-launcher services.

Convention:
  808X = API / inference servers
  909X = Web UIs (future use)

Port map:
  8080 = LLM inference (llama.cpp — text generation, vision)
  8081 = Embeddings (llama.cpp — feature extraction)
  8082 = Image generation (sd.cpp)
  8083 = Speech to text (whisper.cpp)
  8084 = Text to speech (all TTS engines — xtts, qwen3, onnx, chatterbox, piper)
"""

PORT_LLM = 8080
PORT_EMBEDDINGS = 8081
PORT_IMAGE_GEN = 8082
PORT_STT = 8083
PORT_TTS = 8084
