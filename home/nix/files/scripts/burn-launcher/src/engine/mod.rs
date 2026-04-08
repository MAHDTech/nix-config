use burn::tensor::backend::Backend;
use crate::config::ModelSpec;
use std::path::Path;

pub mod llama;
pub mod gemma4;
pub mod qwen35;
pub mod shared;

/// Error type for engine operations.
#[derive(Debug)]
pub enum EngineError {
    /// Configuration parsing failed (e.g., missing fields in config.json)
    Config(String),
    /// Weight loading failed (e.g., shape mismatch, missing tensors)
    Weights(String),
    /// Inference failed (e.g., tokenizer error, OOM)
    Inference(String),
}

impl std::fmt::Display for EngineError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            EngineError::Config(msg) => write!(f, "Config error: {}", msg),
            EngineError::Weights(msg) => write!(f, "Weights error: {}", msg),
            EngineError::Inference(msg) => write!(f, "Inference error: {}", msg),
        }
    }
}

impl std::error::Error for EngineError {}

/// Type-erased engine factory that bridges generic `Engine<B>` to runtime dispatch.
///
/// Each engine registers a factory that can be looked up at runtime by ID.
/// This mirrors how Burn's Backend trait enables generic code — but for model families.
pub trait EngineFactory<B: Backend>: Send + Sync {
    /// Engine identifier matching the YAML `engine` field (e.g., "gemma4", "llama").
    fn id(&self) -> &str;

    /// Full engine lifecycle: parse config → build model → load weights → return inference closure.
    fn launch(
        &self,
        spec: &ModelSpec,
        weights_path: Option<&Path>,
        config_path: Option<&Path>,
        device: &burn::tensor::Device<B>,
    ) -> Result<Option<crate::api::InferenceClosure>, EngineError>;
}

/// Compile-time engine registry. Add new engines here.
///
/// Usage: `let registry = create_registry::<Wgpu>();`
/// Then: `registry.iter().find(|e| e.id() == "gemma4")`
pub fn create_registry<B: Backend>() -> Vec<Box<dyn EngineFactory<B>>>
where
    gemma4::Gemma4Factory: EngineFactory<B>,
    llama::LlamaFactory: EngineFactory<B>,
    qwen35::Qwen35Factory: EngineFactory<B>,
{
    vec![
        Box::new(gemma4::Gemma4Factory),
        Box::new(llama::LlamaFactory),
        Box::new(qwen35::Qwen35Factory),
    ]
}

/// Top-level dispatch function: looks up the engine by ID and launches it.
///
/// This replaces the old `match spec.engine.as_str()` pattern.
pub fn execute<B: Backend>(
    spec: &ModelSpec,
    model_path: Option<std::path::PathBuf>,
    config_path: Option<std::path::PathBuf>,
) -> Result<Option<crate::api::InferenceClosure>, String>
where
    gemma4::Gemma4Factory: EngineFactory<B>,
    llama::LlamaFactory: EngineFactory<B>,
    qwen35::Qwen35Factory: EngineFactory<B>,
{
    let registry = create_registry::<B>();
    let device = burn::tensor::Device::<B>::default();

    let engine = registry
        .iter()
        .find(|e| e.id() == spec.engine)
        .ok_or_else(|| format!("Unsupported engine: '{}'. Available: {}", spec.engine,
            registry.iter().map(|e| e.id()).collect::<Vec<_>>().join(", ")))?;

    log::info!("Dispatching to engine: {}", engine.id());

    engine
        .launch(
            spec,
            model_path.as_deref(),
            config_path.as_deref(),
            &device,
        )
        .map_err(|e| e.to_string())
}
