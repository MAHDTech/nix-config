use crate::config::ModelSpec;
use std::path::PathBuf;
use hf_hub::api::sync::ApiBuilder;
use log::{info, error};

pub struct Downloader;

impl Downloader {
    /// Downloads the specified model from HuggingFace Hub.
    /// Returns the path to the main weight file.
    pub fn download_model(spec: &ModelSpec) -> Result<PathBuf, String> {
        let repo_id = spec.repo_id.as_ref()
            .ok_or_else(|| "ModelSpec is missing repo_id".to_string())?;

        info!("Initializing HuggingFace Hub API for repo: {}", repo_id);

        let mut api_builder = ApiBuilder::new();
        if let Ok(token) = std::env::var("HF_TOKEN").or_else(|_| std::env::var("HUGGING_FACE_HUB_TOKEN")) {
            let token = token.trim();
            if !token.is_empty() {
                api_builder = api_builder.with_token(Some(token.to_string()));
            }
        }

        let api = api_builder.build()
            .map_err(|e| format!("Failed to initialize HF API: {}", e))?;

        let repo = api.model(repo_id.clone());

        let weight_file = spec.weight_file.as_deref().unwrap_or("model.safetensors");
        let files_to_download = vec!["config.json", "tokenizer.json", weight_file];

        let mut weight_path = PathBuf::new();

        for file in files_to_download {
            info!("Checking/Downloading {} from {}...", file, repo_id);
            let path = repo.get(file)
                .map_err(|e| {
                    error!("Failed to download {}: {}", file, e);
                    format!("HF Download Error [{}]: {}", file, e)
                })?;

            if file == weight_file {
                weight_path = path;
            }
        }

        info!("Model {} successfully downloaded/verified at {:?}", spec.name, weight_path);
        Ok(weight_path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::ModelSpec;

    #[test]
    #[ignore] // Avoid hitting network in CI/Standard tests
    fn test_download_gemma_tiny() {
        let spec = ModelSpec {
            name: "Gemma 4 Tiny Test".to_string(),
            description: None,
            vendor: "Google".to_string(),
            collection: "Gemma 4".to_string(),
            engine: "gemma4".to_string(),
            repo_id: Some("google/gemma-2b".to_string()),
            weight_file: Some("model.safetensors".to_string()),
            required_ram_gb: None,
            required_vram_gb: None,
            default_context_length: None,
        };

        let result = Downloader::download_model(&spec);
        assert!(result.is_ok());
    }
}
