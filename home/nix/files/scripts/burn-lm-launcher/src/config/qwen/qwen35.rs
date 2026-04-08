use crate::config::ModelSpec;

pub fn models() -> Vec<ModelSpec> {
    serde_yaml::from_str(include_str!("qwen35.yaml")).expect("Valid qwen35.yaml")
}
