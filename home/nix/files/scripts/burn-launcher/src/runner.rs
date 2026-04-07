use crate::config::ModelSpec;
use burn::backend::{NdArray, Wgpu};
use hf_hub::api::sync::Api;
use std::path::PathBuf;
use std::sync::Arc;

pub async fn run_engine(spec: ModelSpec, force_cpu: bool) -> Result<(), Box<dyn std::error::Error>> {
    println!("⚙️  Initializing Burn Backend...");

    let mut weight_path: Option<PathBuf> = None;
    if let Some(repo) = &spec.repo_id {
        if let Some(file) = &spec.weight_file {
            println!("⏳ Fetching weights from Hugging Face Hub ({})...", repo);
            let api = Api::new()?;
            let repo_api = api.model(repo.clone());
            let path = repo_api.get(file)?;
            println!("✅ Resolved weights at: {:?}", path);
            weight_path = Some(path);
        }
    }

    let infer_closure = if force_cpu {
        println!("🚀 Backend: burn-ndarray (CPU)");
        crate::models::execute::<NdArray>(&spec, weight_path)?
    } else {
        println!("🚀 Backend: burn-wgpu (GPU via Vulkan/Metal)");
        crate::models::execute::<Wgpu>(&spec, weight_path)?
    };

    if let Some(closure) = infer_closure {
        let api_state = crate::api::ApiState {
            model_name: spec.name.clone(),
            infer_fn: Arc::new(closure),
        };
        crate::api::start_server(8080, api_state).await?;
    }

    Ok(())
}
