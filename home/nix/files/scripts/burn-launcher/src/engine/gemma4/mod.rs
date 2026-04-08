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
use crate::engine::shared::sampling::Sampler;
use crate::engine::shared::tokenizer::Tokenizer;
use burn::nn::RotaryEncodingConfig;
use burn::prelude::ToElement;
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

        let config = Gemma4ModelConfig::new(base_config.clone());
        let model = config.init::<B>(device);

        log::info!("Attaching Gemma 4 Safetensors topological structure mapper...");
        let model = loader::load_gemma4_safetensors(weights.to_str().unwrap(), model)
            .map_err(|e| EngineError::Weights(format!("Mismatched SafeTensors Architecture: {}", e)))?;

        log::info!("Gemma 4 mathematical abstraction scaffolded seamlessly!");

        let repo = spec.repo_id.as_ref()
            .ok_or_else(|| EngineError::Config("No repo_id specified for tokenizer".to_string()))?;

        log::info!("Fetching tokenizer.json...");
        let mut api_builder = hf_hub::api::sync::ApiBuilder::new();
        if let Ok(token) = std::env::var("HF_TOKEN").or_else(|_| std::env::var("HUGGING_FACE_HUB_TOKEN")) {
            let token = token.trim();
            if !token.is_empty() {
                api_builder = api_builder.with_token(Some(token.to_string()));
            }
        }
        let api = api_builder.build()
            .map_err(|e| EngineError::Config(format!("Failed to init hf hub api for tokenizer: {}", e)))?;

        let tokenizer_path = api.model(repo.clone()).get("tokenizer.json")
            .map_err(|e| EngineError::Weights(format!("Failed to download tokenizer: {}", e)))?;

        let tokenizer = Tokenizer::new(tokenizer_path.to_str().unwrap())
            .map_err(|e| EngineError::Weights(e.to_string()))?;

        // max_seq_len from spec
        let max_seq_len = spec.default_context_length.unwrap_or(4096);

        // Initialize per-layer KeyValueCaches and RotaryEncodings
        let mut ropes = Vec::new();
        let mut caches = Vec::new();
        for layer_cfg in base_config.layers.iter() {
            // Ropes
            let rope = RotaryEncodingConfig::new(max_seq_len * 2, layer_cfg.head_dim)
                .with_theta(layer_cfg.rope_theta)
                .init(device);
            ropes.push(rope);

            // Caches
            caches.push(attention::KeyValueCache::new(
                1, // batch_size
                layer_cfg.n_kv_heads,
                max_seq_len,
                layer_cfg.head_dim,
                device,
            ));
        }

        let sampler = Sampler::new_top_p(0.9, 42);
        let device_moved = device.clone();

        let state = std::sync::Arc::new(std::sync::Mutex::new((
            model,
            ropes,
            caches,
            sampler,
            tokenizer,
        )));

        let infer_fn = Box::new(move |prompt: String| -> String {
            log::info!("Tokenizing prompt for Gemma 4...");
            let mut s = state.lock().unwrap();
            let (model, ropes, caches, sampler, tokenizer) = &mut *s;

            let mut tokens = tokenizer.encode(&prompt);
            tokens.insert(0, tokenizer.bos_id());
            let stop_token = tokenizer.eos_id();

            let mut current_tokens = tokens.clone();

            for cache in caches.iter_mut() {
                cache.reset();
            }

            for _ in 0..max_seq_len {
                let seq_len = current_tokens.len();
                let shape = burn::tensor::Shape::new([1, seq_len]);
                let input = burn::tensor::Tensor::<B, 2, burn::tensor::Int>::from_data(
                    burn::tensor::TensorData::new(current_tokens.clone(), shape),
                    &device_moved
                );

                let logits = model.forward(input, caches, ropes);

                let [batch, seq, vocab] = logits.dims();
                let next_token_logits = logits.slice([0..batch, (seq - 1)..seq, 0..vocab]).squeeze::<2>();

                let next_token = sampler.sample(next_token_logits);
                let next_token_val = next_token.into_scalar().to_i64() as u32;

                if next_token_val == stop_token {
                    break;
                }

                tokens.push(next_token_val);
                current_tokens = vec![next_token_val];
            }


            tokenizer.decode(&tokens)
        });

        Ok(Some(infer_fn))
    }
}
