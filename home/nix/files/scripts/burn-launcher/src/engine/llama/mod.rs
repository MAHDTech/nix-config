
#[allow(clippy::module_inception)]
pub mod llama;
pub mod pretrained;
pub mod config;

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

        let mut api_builder = hf_hub::api::sync::ApiBuilder::new();
        if let Ok(token) = std::env::var("HF_TOKEN").or_else(|_| std::env::var("HUGGING_FACE_HUB_TOKEN")) {
            let token = token.trim();
            if !token.is_empty() {
                api_builder = api_builder.with_token(Some(token.to_string()));
            }
        }
        let api = api_builder.build()
            .map_err(|e| EngineError::Config(format!("Failed to init hf hub api: {}", e)))?;
        let repo_api = api.model(repo.clone());

        let tokenizer_file = "tokenizer.json";
        log::info!("Fetching {}...", tokenizer_file);
        let tokenizer_path = repo_api.get(tokenizer_file)
            .map_err(|e| EngineError::Config(format!("Failed to fetch tokenizer: {}", e)))?;
        log::info!("Resolved tokenizer at: {:?}", tokenizer_path);

        let device = burn::tensor::Device::<B>::default();

        let config_file = "config.json";
        log::info!("Fetching {}...", config_file);
        let dynamic_config_path = repo_api.get(config_file)
            .map_err(|e| EngineError::Config(format!("Failed to fetch config.json: {}", e)))?;
        log::info!("Resolved config.json at: {:?}", dynamic_config_path);

        let hf_config = config::HfLlamaConfig::from_json(&dynamic_config_path)
            .map_err(|e| EngineError::Config(format!("Failed to parse config.json: {}", e)))?;

        let tz_str = tokenizer_path.to_str().unwrap();
        let mut llama_config = hf_config.to_burn_config(tz_str);

        if let Some(ctx) = spec.default_context_length {
            llama_config.max_seq_len = ctx;
        }

        let weights_str = weights.to_str().unwrap();

        // Dynamically load the Llama configured from JSON using the HuggingFace wrapper
        #[cfg(feature = "import")]
        let model = llama_config.load_pretrained::<B>(
            weights_str,
            &device
        ).map_err(|e| EngineError::Weights(format!("Failed to load dynamic Llama: {}", e)))?;

        #[cfg(not(feature = "import"))]
        return Err(EngineError::Config("The 'import' feature must be enabled to load weights dynamically".to_string()));

        let sampler = crate::engine::shared::sampling::Sampler::new_top_p(0.9, 42);
        let generation_state = Arc::new(Mutex::new((model, sampler)));

        let infer_fn = Box::new(move |prompt: String| -> String {
            let mut state = generation_state.lock().unwrap();
            let (model, sampler) = &mut *state;

            model.reset();

            let formatted = LlamaFactory::format_chat_prompt(&prompt);
            log::info!("Generating answer (prompt tokens will be computed by model)...");
            let generated = model.generate(formatted.as_str(), 100, 0.6, sampler);
            log::info!("Generated {} tokens in {:.2}s", generated.tokens, generated.time);
            generated.text
        });

        Ok(Some(infer_fn))
    }
}
