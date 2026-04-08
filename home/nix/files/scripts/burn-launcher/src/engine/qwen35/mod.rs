use burn::tensor::backend::Backend;
use crate::config::ModelSpec;
use crate::engine::{EngineError, EngineFactory};
use std::path::Path;

/// Factory for Qwen 3.5 model family (0.8B through 397B-A17B MoE).
///
/// Qwen 3.5 models are multimodal (Image-Text-to-Text) with MoE variants.
/// Architecture uses RoPE, SwiGLU MLP, RMSNorm, and grouped-query attention.
pub struct Qwen35Factory;

impl<B: Backend> EngineFactory<B> for Qwen35Factory {
    fn id(&self) -> &str {
        "qwen35"
    }

    fn launch(
        &self,
        spec: &ModelSpec,
        weights_path: Option<&Path>,
        config_path: Option<&Path>,
        _device: &burn::tensor::Device<B>,
    ) -> Result<Option<crate::api::InferenceClosure>, EngineError> {
        log::info!("Qwen 3.5 engine bridging for: {}", spec.name);

        let weights = weights_path
            .ok_or_else(|| EngineError::Weights("No weights path provided".to_string()))?;
        log::info!("Weights found at: {:?}", weights);

        if let Some(cfg_path) = config_path {
            log::info!("Config found at: {:?}", cfg_path);
            match std::fs::read_to_string(cfg_path) {
                Ok(content) => log::debug!("Qwen 3.5 config.json:\n{}", content),
                Err(e) => log::warn!("Could not read config.json: {}", e),
            }
        }

        // TODO: Implement Qwen 3.5 model structure, config parser, and weight loader.
        // The architecture is similar to Gemma 4 (transformer + vision tower) but uses:
        // - SwiGLU activation in MLP
        // - RoPE positional encoding
        // - Mixture-of-Experts for A3B/A10B/A17B variants
        // - Potentially different normalization conventions

        let infer_fn = Box::new(move |prompt: String| -> String {
            format!("(Qwen 3.5 Engine Scaffold)\nEvaluating Prompt: {}", prompt)
        });

        Ok(Some(infer_fn))
    }
}
