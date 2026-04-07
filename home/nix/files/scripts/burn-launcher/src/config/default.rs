pub const DEFAULT_CONFIG: &str = r#"# burn-launcher model catalog
# Categories are for the interactive menu only.

models:
  text:
    - name: "Llama 3.2 1B (TinyLlama)"
      description: "Small language model for basic tasks"
      engine: "llama"
      repo_id: "tracel-ai/tiny-llama-1.1b-burn"
      weight_file: "model.mpk"
      required_ram_gb: 2.0
    - name: "Gemma 4 31B Instruct (Image-Text)"
      description: "google/gemma-4-31B-it"
      engine: "gemma4"
      repo_id: "google/gemma-4-31B-it"
      weight_file: "model.safetensors"
      required_ram_gb: 34.0
    - name: "Gemma 4 31B Base (Image-Text)"
      description: "google/gemma-4-31B"
      engine: "gemma4"
      repo_id: "google/gemma-4-31B"
      weight_file: "model.safetensors"
      required_ram_gb: 34.0
    - name: "Gemma 4 26B-A4B Instruct (Image-Text)"
      description: "google/gemma-4-26B-A4B-it"
      engine: "gemma4"
      repo_id: "google/gemma-4-26B-A4B-it"
      weight_file: "model.safetensors"
      required_ram_gb: 28.0
    - name: "Gemma 4 26B-A4B Base (Image-Text)"
      description: "google/gemma-4-26B-A4B"
      engine: "gemma4"
      repo_id: "google/gemma-4-26B-A4B"
      weight_file: "model.safetensors"
      required_ram_gb: 28.0
    - name: "Gemma 4 E4B Instruct (Any-to-Any)"
      description: "google/gemma-4-E4B-it"
      engine: "gemma4"
      repo_id: "google/gemma-4-E4B-it"
      weight_file: "model.safetensors"
      required_ram_gb: 5.0
    - name: "Gemma 4 E4B Base (Any-to-Any)"
      description: "google/gemma-4-E4B"
      engine: "gemma4"
      repo_id: "google/gemma-4-E4B"
      weight_file: "model.safetensors"
      required_ram_gb: 5.0
    - name: "Gemma 4 E2B Instruct (Any-to-Any)"
      description: "google/gemma-4-E2B-it"
      engine: "gemma4"
      repo_id: "google/gemma-4-E2B-it"
      weight_file: "model.safetensors"
      required_ram_gb: 3.0
    - name: "Gemma 4 E2B Base (Any-to-Any)"
      description: "google/gemma-4-E2B"
      engine: "gemma4"
      repo_id: "google/gemma-4-E2B"
      weight_file: "model.safetensors"
      required_ram_gb: 3.0"#;
