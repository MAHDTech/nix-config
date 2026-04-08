use crate::config::ModelSpec;
use burn::backend::{NdArray, Wgpu};
use std::path::PathBuf;
use std::sync::Arc;

pub async fn run_engine(spec: ModelSpec, force_cpu: bool) -> Result<(), Box<dyn std::error::Error>> {
    log::info!("⚙️  Initializing Burn Backend...");

    let mut weight_path: Option<PathBuf> = None;
    let mut config_path: Option<PathBuf> = None;
    if let Some(repo) = &spec.repo_id {
        if let Some(file) = &spec.weight_file {
            log::info!("⏳ Fetching weights from Hugging Face Hub ({})...", repo);
            let mut api_builder = hf_hub::api::sync::ApiBuilder::new();
            if let Ok(token) = std::env::var("HF_TOKEN").or_else(|_| std::env::var("HUGGING_FACE_HUB_TOKEN")) {
                let token = token.trim();
                if !token.is_empty() {
                    api_builder = api_builder.with_token(Some(token.to_string()));
                }
            }
            let api = api_builder.build()?;
            let repo_api = api.model(repo.clone());
            let path = repo_api.get(file)?;
            log::info!("✅ Resolved weights at: {:?}", path);
            weight_path = Some(path);

            // Fetch config.json if we are using HuggingFace
            match repo_api.get("config.json") {
                Ok(p) => {
                    log::info!("✅ Resolved config at: {:?}", p);
                    config_path = Some(p);
                }
                Err(e) => {
                    log::warn!("⚠️ Could not resolve config.json: {}", e);
                }
            }
        }
    }

    let infer_closure = if force_cpu {
        log::info!("🚀 Backend: burn-ndarray (CPU)");
        crate::engine::execute::<NdArray>(&spec, weight_path, config_path)?
    } else {
        log::info!("🚀 Backend: burn-wgpu (GPU via Vulkan/Metal)");
        crate::engine::execute::<Wgpu>(&spec, weight_path, config_path)?
    };

    if let Some(closure) = infer_closure {
        log::info!("✅ Engine returned inference closure — starting API server");
        let api_state = crate::api::ApiState {
            model_name: spec.name.clone(),
            infer_fn: Arc::new(closure),
        };
        crate::api::start_server(8080, api_state).await?;
    } else {
        log::warn!("⚠️ Engine returned no inference closure. Model loaded but cannot serve requests.");
        log::warn!("   This engine may be a scaffold — check src/engine/{}/mod.rs", spec.engine);
    }

    Ok(())
}
