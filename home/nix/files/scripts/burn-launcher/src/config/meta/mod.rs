use crate::config::ModelSpec;

pub mod llama3;
pub mod llama4;

pub fn models() -> Vec<ModelSpec> {
    let mut all = Vec::new();
    all.extend(llama4::models());
    all.extend(llama3::models());
    all
}
