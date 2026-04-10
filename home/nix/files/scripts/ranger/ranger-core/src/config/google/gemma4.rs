use crate::config::ModelSpec;

pub fn models() -> Vec<ModelSpec> {
    serde_yaml::from_str(include_str!("gemma4.yaml")).expect("Valid gemma4.yaml")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gemma4_models_load() {
        let all_models = models();
        assert!(!all_models.is_empty());
        assert!(all_models.iter().any(|m| m.name.contains("31B")));
        assert!(all_models.iter().any(|m| m.name.contains("E2B")));
    }
}
