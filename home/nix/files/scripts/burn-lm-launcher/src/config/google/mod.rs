use crate::config::ModelSpec;

pub mod gemma4;

pub fn models() -> Vec<ModelSpec> {
    gemma4::models()
}
