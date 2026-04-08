pub(crate) mod cache;
#[allow(clippy::module_inception)]
pub mod llama;
pub mod pretrained;
pub mod sampling;
pub mod tokenizer;
mod transformer;

use burn::tensor::backend::Backend;
use crate::config::ModelSpec;
use crate::engine::{EngineError, EngineFactory};
use std::sync::{Arc, Mutex};
use std::path::Path;

// Chat template tokens for TinyLlama
const SYSTEM_TAG: &str = "\x3c|system|\x3e";
const USER_TAG: &str = "\x3c|user|\x3e";
const ASSISTANT_TAG: &str = "\x3c|assistant|\x3e";
const END_TAG: &str = "\x3c/s\x3e";

/// Factory for Llama model family (TinyLlama, Llama 3, etc.)
pub struct LlamaFactory;

impl LlamaFactory {
    fn format_chat_prompt(prompt: &str) -> String {
        format!(
            "{}\nYou are a friendly chatbot.{}\n{}\n{}{}\n{}\n",
            SYSTEM_TAG, END_TAG, USER_TAG, prompt, END_TAG, ASSISTANT_TAG
        )
    }
}

impl<B: Backend> EngineFactory<B> for LlamaFactory {
    fn id(&self) -> &str {
        "llama"
    }

    fn launch(
        &self,
        spec: &ModelSpec,
        weights_path: Option<&Path>,
        _config_path: Option<&Path>,
        _device: &burn::tensor::Device<B>,
    ) -> Result<Option<crate::api::InferenceClosure>, EngineError> {
        log::info!("Llama engine bridging for: {}", spec.name);

        let weights = weights_path
            .ok_or_else(|| EngineError::Weights("Could not resolve weight paths".to_string()))?;
        let repo = spec.repo_id.as_ref()
            .ok_or_else(|| EngineError::Config("No repo_id specified".to_string()))?;

        log::info!("Weights found at: {:?}", weights);

        let api = hf_hub::api::sync::Api::new()
            .map_err(|e| EngineError::Config(format!("Failed to init hf hub api: {}", e)))?;
        let repo_api = api.model(repo.clone());

        let tokenizer_file = "tokenizer.json";
        log::info!("Fetching {}...", tokenizer_file);
        let tokenizer_path = repo_api.get(tokenizer_file)
            .map_err(|e| EngineError::Config(format!("Failed to fetch tokenizer: {}", e)))?;
        log::info!("Resolved tokenizer at: {:?}", tokenizer_path);

        let device = burn::tensor::Device::<B>::default();

        #[cfg(feature = "tiny")]
        {
            if repo.contains("tiny-llama") {
                let weights_str = weights.to_str().unwrap();
                let tz_str = tokenizer_path.to_str().unwrap();
                let model = llama::LlamaConfig::load_tiny_llama::<B>(
                    weights_str,
                    tz_str,
                    128,
                    &device
                ).map_err(|e| EngineError::Weights(format!("Failed to load TinyLlama: {}", e)))?;

                let sampler = sampling::Sampler::new_top_p(0.9, 42);
                let generation_state = Arc::new(Mutex::new((model, sampler)));

                let infer_fn = Box::new(move |prompt: String| -> String {
                    let mut state = generation_state.lock().unwrap();
                    let (model, sampler) = &mut *state;

                    let formatted = LlamaFactory::format_chat_prompt(&prompt);
                    log::info!("Generating answer...");
                    let generated = model.generate(formatted.as_str(), 100, 0.6, sampler);
                    generated.text
                });

                return Ok(Some(infer_fn));
            }
        }

        log::info!("We have the model and tokenizer resolved. Run logic to be expanded!");
        Ok(None)
    }
}
