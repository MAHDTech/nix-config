use crate::config::ModelSpec;

pub mod qwen35;

pub fn models() -> Vec<ModelSpec> {
    qwen35::models()
}
