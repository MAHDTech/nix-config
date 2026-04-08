use burn::tensor::backend::Backend;
use crate::config::ModelSpec;


pub mod llama;
pub mod gemma4;

pub fn execute<B: Backend>(spec: &ModelSpec, _model_path: Option<std::path::PathBuf>, _config_path: Option<std::path::PathBuf>) -> Result<Option<crate::api::InferenceClosure>, String> {
    match spec.engine.as_str() {
        "llama" => {
            log::info!("Executing Burn Llama logic for: {}", spec.name);
            llama::run::<B>(spec, _model_path, _config_path)
        }
        "gemma4" => {
            log::info!("Executing Gemma4 logic for: {}", spec.name);
            gemma4::run::<B>(spec, _model_path, _config_path)
        }
        _ => Err(format!("Unsupported engine variant: {}", spec.engine)),
    }
}
