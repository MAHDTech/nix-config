use crate::config::ModelSpec;

pub fn models() -> Vec<ModelSpec> {
    serde_yaml::from_str(include_str!("llama3.yaml")).expect("Valid llama3.yaml")
}
