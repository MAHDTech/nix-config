# burn-launcher: Adding Engines and Models

> This document is the canonical reference for AI agents and humans adding new
> model families (engines) or model entries to burn-launcher.

## Architecture Overview

burn-launcher uses a four-level hierarchy:

```
Category (YAML) → Vendor (YAML) → Engine (Rust trait) → Model (YAML data)
     5                 N                  100                    500
```

- **Categories** are UI groupings only (e.g., `text`, `vision`) — no code required.
- **Vendors** are UI groupings by provider (e.g., `Google`, `Qwen`, `Meta`) — no code required.
- **Models** are YAML data entries — no code required. The engine's dynamic
  `config.json` parser handles architectural differences automatically.
- **Engines** are Rust trait implementations — one per model family. This is
  where architecture-specific code lives.

The TUI drill-down follows this hierarchy:

```
Category → Vendor → Engine → Model
  text      Google   gemma4   Gemma 4 E2B Base
  text      Qwen     qwen35   Qwen 3.5 0.8B
  text      Meta     llama    TinyLlama 1.1B
```

## Adding a New Model (Zero Code)

If the model family already has an engine (e.g., adding a new Gemma 4 variant),
you only need a YAML entry.

### Step 1: Add to `src/config/default.rs`

Add an entry under the appropriate category:

```yaml
- name: "Gemma 4 12B Instruct (Image-Text)"
  description: "google/gemma-4-12B-it"
  vendor: "Google" # Vendor for TUI grouping
  engine: "gemma4" # Must match an engine ID
  repo_id: "google/gemma-4-12B-it" # HuggingFace repo
  weight_file: "model.safetensors" # Weight file in the repo
  required_ram_gb: 14.0 # Minimum system RAM
  required_vram_gb: 12.0 # Optional: minimum VRAM
  default_context_length: 8192 # Optional: default context window
```

### Required Fields

| Field                    | Type   | Required | Description                                         |
| ------------------------ | ------ | -------- | --------------------------------------------------- |
| `name`                   | String | Yes      | Display name in TUI and CLI (`--model`)             |
| `description`            | String | No       | Shown below model name in TUI                       |
| `vendor`                 | String | Yes      | Vendor grouping (e.g., `Google`, `Meta`, `Qwen`)    |
| `engine`                 | String | Yes      | Must match an `EngineFactory::id()`                 |
| `repo_id`                | String | Yes      | HuggingFace repository (e.g., `google/gemma-4-E2B`) |
| `weight_file`            | String | Yes      | Weight filename in the repo                         |
| `required_ram_gb`        | f64    | No       | Minimum system RAM for safety checks                |
| `required_vram_gb`       | f64    | No       | Minimum GPU VRAM                                    |
| `default_context_length` | usize  | No       | Default context window (adjustable in TUI)          |

### Step 2: Test

```bash
burn-launcher --model "Gemma 4 12B Instruct (Image-Text)" --log-level DEBUG
```

**That's it. No code changes.**

---

## Adding a New Engine (New Model Family)

When adding support for a completely new model architecture (e.g., Mistral,
Phi-4), you need to implement the `EngineFactory` trait.

### Directory Structure

Create a new module under `src/engine/`:

```
src/engine/mistral/
├── mod.rs          # EngineFactory implementation
├── config.rs       # Dynamic config.json parser (HfConfig structs)
├── model.rs        # Burn Module definitions (transformer layers)
├── attention.rs    # Attention mechanism (GQA, MQA, sliding window, etc.)
├── mlp.rs          # Feed-forward network
├── loader.rs       # SafeTensors key remapping rules
└── sampling.rs     # Token sampling strategies (optional)
```

### Step 1: Implement `EngineFactory`

In `src/engine/mistral/mod.rs`:

```rust
use burn::tensor::backend::Backend;
use crate::config::ModelSpec;
use crate::engine::{EngineError, EngineFactory};
use std::path::Path;

pub struct MistralFactory;

impl<B: Backend> EngineFactory<B> for MistralFactory {
    fn id(&self) -> &str {
        "mistral"  // Must match the YAML `engine` field
    }

    fn launch(
        &self,
        spec: &ModelSpec,
        weights_path: Option<&Path>,
        config_path: Option<&Path>,
        device: &burn::tensor::Device<B>,
    ) -> Result<Option<crate::api::InferenceClosure>, EngineError> {
        // 1. Parse config.json dynamically
        // 2. Build Burn model from config
        // 3. Load SafeTensors weights with key remapping
        // 4. Return inference closure
        todo!()
    }
}
```

### Step 2: Register the Engine

In `src/engine/mod.rs`:

1. Add the module declaration: `pub mod mistral;`
2. Add the factory bound and instantiation to `create_registry()`:

```rust
pub fn create_registry<B: Backend>() -> Vec<Box<dyn EngineFactory<B>>>
where
    gemma4::Gemma4Factory: EngineFactory<B>,
    llama::LlamaFactory: EngineFactory<B>,
    qwen35::Qwen35Factory: EngineFactory<B>,
    mistral::MistralFactory: EngineFactory<B>,  // Add bound
{
    vec![
        Box::new(gemma4::Gemma4Factory),
        Box::new(llama::LlamaFactory),
        Box::new(qwen35::Qwen35Factory),
        Box::new(mistral::MistralFactory),  // Add factory
    ]
}
```

3. Add the same bound to the `execute()` function's `where` clause.

### Step 3: Implement Dynamic Config Parser

In `config.rs`, create serde structs that map the HuggingFace `config.json`
schema. Key principles from our Gemma 4 implementation:

1. **Support nested configs**: Multimodal models nest LLM params inside
   `text_config`. Use `Option<HfTextConfig>` with fallback to top-level fields.

2. **Read explicit head_dim**: Never compute `hidden_size / n_heads` — some
   models (e.g., Gemma 4) use a head_dim that differs from this ratio.

3. **Parse layer_types dynamically**: Models may have heterogeneous layers
   (sliding vs full attention). Read the `layer_types` array from config.json.

4. **Handle tied embeddings**: If `tie_word_embeddings` is true, do NOT create
   a separate `lm_head` Linear layer. Use the embedding weight directly in
   the forward pass.

```rust
#[derive(Deserialize, Debug)]
pub struct HfConfig {
    pub vocab_size: usize,
    pub hidden_size: usize,
    pub num_hidden_layers: usize,
    pub num_attention_heads: usize,
    pub num_key_value_heads: usize,
    pub intermediate_size: usize,
    pub head_dim: Option<usize>,        // Explicit, don't derive!
    pub sliding_window: Option<usize>,
    pub layer_types: Option<Vec<String>>,
    pub tie_word_embeddings: Option<bool>,
}
```

### Step 4: Implement SafeTensors Loader

In `loader.rs`, define key remapping rules. Common patterns:

```rust
let key_mappings = vec![
    // Strip multimodal wrapper prefix
    ("language_model\\.", ""),
    // Map HF norm .weight to Burn's .gamma
    ("(.*)norm\\.weight", "${1}norm.gamma"),
];
```

### Step 5: Add YAML Catalog Entries

Add model entries to `src/config/default.rs` with the correct `vendor` and
`engine` fields.

### Step 6: Verify

```bash
cargo check                    # Compiles
cargo test                     # Tests pass
burn-launcher --help           # CLI works
burn-launcher --model "..." --log-level DEBUG  # Weights load
```

---

## Common Pitfalls

### Shape Mismatches

| Symptom                           | Likely Cause              | Fix                                      |
| --------------------------------- | ------------------------- | ---------------------------------------- |
| `embed_tokens.weight` wrong shape | Wrong `vocab_size`        | Parse from config.json                   |
| Q/K/V projection wrong shape      | Wrong `head_dim`          | Use explicit `head_dim` from config      |
| `lm_head.weight` not found        | Tied embeddings           | Don't create `lm_head`, use embed weight |
| MLP gate wrong shape              | Wrong `intermediate_size` | Check `use_double_wide_mlp` flag         |
| Layer count mismatch              | `num_hidden_layers` wrong | Check `text_config` nesting              |

### Key Remapping

HuggingFace SafeTensors use different naming conventions than Burn modules.
Always check the actual tensor keys with:

```bash
python3 -c "
from safetensors import safe_open
f = safe_open('model.safetensors', framework='pt')
for key in sorted(f.keys()):
    print(f'{key}: {f.get_tensor(key).shape}')
"
```

### RMSNorm Convention

Burn's `RmsNorm` stores its weight as `.gamma`, but HuggingFace stores it as
`.weight`. Always include this remapping:

```rust
("(.*)norm\\.weight", "${1}norm.gamma"),
```

---

## Module Reference

| Module               | Purpose                                   |
| -------------------- | ----------------------------------------- |
| `engine/mod.rs`      | `EngineFactory` trait, registry, dispatch |
| `engine/*/mod.rs`    | Per-engine factory implementation         |
| `engine/*/config.rs` | HuggingFace config.json parser            |
| `engine/*/model.rs`  | Burn Module (transformer) definitions     |
| `engine/*/loader.rs` | SafeTensors key remapping                 |
| `runner/mod.rs`      | HF Hub fetching, backend selection        |
| `api/mod.rs`         | OpenAI-compatible HTTP API                |
| `system/mod.rs`      | Hardware detection and memory evaluation  |
| `system/vram.rs`     | GPU VRAM detection (NVIDIA, AMD, Intel)   |
| `system/ram.rs`      | System RAM detection                      |
| `config/mod.rs`      | YAML catalog schema and loading           |
