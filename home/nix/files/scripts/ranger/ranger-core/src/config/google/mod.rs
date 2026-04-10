pub mod gemma4;

pub fn models() -> Vec<super::ModelSpec> {
    let mut all_models = Vec::new();
    all_models.extend(gemma4::models());
    all_models
}
