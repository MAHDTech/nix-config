use burn::tensor::backend::Backend;
use crate::config::ModelSpec;

pub mod mnist;
pub mod llama;
pub mod gemma4;

pub fn execute<B: Backend>(spec: &ModelSpec) -> Result<(), String> {
    match spec.engine.as_str() {
        "burn-native" => {
            println!("Executing Burn Native logic for: {}", spec.name);
            mnist::run::<B>();
            Ok(())
        }
        "burn-llama" => {
            println!("Executing Burn Llama logic for: {}", spec.name);
            llama::run::<B>();
            Ok(())
        }
        "gemma4" => {
            println!("Executing Gemma4 logic for: {}", spec.name);
            gemma4::run::<B>();
            Ok(())
        }
        _ => Err(format!("Unsupported engine variant: {}", spec.engine)),
    }
}
