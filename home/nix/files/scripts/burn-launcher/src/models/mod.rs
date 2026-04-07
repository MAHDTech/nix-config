use burn::tensor::backend::Backend;
use crate::config::ModelSpec;

pub mod mnist;
pub mod llama;
pub mod gemma4;

pub fn execute<B: Backend>(spec: &ModelSpec, _model_path: Option<std::path::PathBuf>) -> Result<Option<crate::api::InferenceClosure>, String> {
    match spec.engine.as_str() {
        "mnist" => {
            println!("Executing Burn Native logic for: {}", spec.name);
            mnist::run::<B>();
            Ok(None)
        }
        "llama" => {
            println!("Executing Burn Llama logic for: {}", spec.name);
            llama::run::<B>(spec, _model_path)
        }
        "gemma4" => {
            println!("Executing Gemma4 logic for: {}", spec.name);
            gemma4::run::<B>();
            Ok(None)
        }
        _ => Err(format!("Unsupported engine variant: {}", spec.engine)),
    }
}
