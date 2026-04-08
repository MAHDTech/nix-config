use crate::config::ModelSpec;

pub fn models() -> Vec<ModelSpec> {
    serde_yaml::from_str(include_str!("llama4.yaml")).expect("Valid llama4.yaml")
}
