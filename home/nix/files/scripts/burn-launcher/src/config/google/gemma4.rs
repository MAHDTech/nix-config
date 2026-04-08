use crate::config::ModelSpec;

pub fn models() -> Vec<ModelSpec> {
    serde_yaml::from_str(include_str!("gemma4.yaml")).expect("Valid gemma4.yaml")
}
