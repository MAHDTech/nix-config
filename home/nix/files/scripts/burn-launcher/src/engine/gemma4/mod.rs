use burn::tensor::backend::Backend;

pub mod attention;
pub mod cache;
pub mod config;
pub mod loader;
pub mod mlp;
pub mod model;
pub mod sampling;

pub use config::*;
pub use model::*;

use crate::config::ModelSpec;
use crate::engine::{EngineError, EngineFactory};
use std::path::Path;

/// Factory for Gemma 4 model family (E2B, E4B, 26B, 31B, etc.)
pub struct Gemma4Factory;

impl<B: Backend> EngineFactory<B> for Gemma4Factory {
    fn id(&self) -> &str {
        "gemma4"
    }

    fn launch(
        &self,
        spec: &ModelSpec,
        weights_path: Option<&Path>,
        config_path: Option<&Path>,
        device: &burn::tensor::Device<B>,
    ) -> Result<Option<crate::api::InferenceClosure>, EngineError> {
        log::info!("Executing Burn Gemma 4 logic for {}...", spec.name);

        let weights = weights_path
            .ok_or_else(|| EngineError::Weights("No weights path provided".to_string()))?;
        log::info!("Weights found at: {:?}", weights);

        let base_config = if let Some(path) = config_path {
            log::info!("Parsing explicit config mathematically at {:?}", path);
            Gemma4Config::from_json(path).map_err(|e| EngineError::Config(e.to_string()))?
        } else {
            log::warn!("⚠️ Fallback to E2B proxy topology (no config.json provided)");
            Gemma4Config::e2b()
        };

        let config = Gemma4ModelConfig::new(base_config);
        let model = config.init::<B>(device);

        log::info!("Attaching Gemma 4 Safetensors topological structure mapper...");
        let _model = loader::load_gemma4_safetensors(weights.to_str().unwrap(), model)
            .map_err(|e| EngineError::Weights(format!("Mismatched SafeTensors Architecture: {}", e)))?;

        log::info!("Gemma 4 mathematical abstraction scaffolded seamlessly!");

        let infer_fn = Box::new(move |prompt: String| -> String {
            format!("(Gemma 4 Engine Generation Placeholder)\nEvaluating Prompt: {}", prompt)
        });

        Ok(Some(infer_fn))
    }
}
