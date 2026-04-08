pub(crate) mod cache;
#[allow(clippy::module_inception)]
pub mod llama;
pub mod pretrained;
pub mod sampling;
pub mod tokenizer;
mod transformer;

use burn::tensor::backend::Backend;
use crate::config::ModelSpec;
use std::sync::{Arc, Mutex};
use std::path::PathBuf;

pub fn run<B: Backend>(spec: &ModelSpec, model_path: Option<PathBuf>, _config_path: Option<PathBuf>) -> Result<Option<crate::api::InferenceClosure>, String> {
    println!("Llama engine bridging for: {}", spec.name);

    // We will need to pull the tokenizer based on the spec
    if let (Some(repo), Some(weights)) = (&spec.repo_id, &model_path) {
        println!("Weights found at: {:?}", weights);

        let api = hf_hub::api::sync::Api::new().expect("Failed to init hf hub api");
        let repo_string = repo.to_string();
        let repo_api = api.model(repo_string);

        let tokenizer_file = "tokenizer.json";

        println!("Fetching {}...", tokenizer_file);
        let tokenizer_path = repo_api.get(tokenizer_file).expect("Failed to fetch tokenizer");
        println!("Resolved tokenizer at: {:?}", tokenizer_path);

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
                ).expect("Failed to load TinyLlama");

                let sampler = sampling::Sampler::new_top_p(0.9, 42);

                let generation_state = Arc::new(Mutex::new((model, sampler)));

                let infer_fn = Box::new(move |prompt: String| -> String {
                    let mut state = generation_state.lock().unwrap();
                    let (model, sampler) = &mut *state;

                    let formatted = format!("<|system|>\nYou are a friendly chatbot.</s>\n<|user|>\n{}</s>\n<|assistant|>\n", prompt);
                    println!("Generating answer...");
                    let generated = model.generate(formatted.as_str(), 100, 0.6, sampler);
                    generated.text
                });

                return Ok(Some(infer_fn));
            }
        }

        println!("We have the model and tokenizer resolved. Run logic to be expanded!");
        Ok(None)
    } else {
        Err("Could not resolve weight paths properly.".to_string())
    }
}
