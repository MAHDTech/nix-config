use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A single model specification in the catalog.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ModelSpec {
    pub id: String,
    pub name: String,
    #[serde(default = "default_vendor")]
    pub vendor: String,
    pub collection: String,
    pub engine: String,
    pub repo_id: String,
    #[serde(default = "default_onnx_file")]
    pub onnx_file: String,
    #[serde(default)]
    pub required_ram_gb: Option<f64>,
    #[serde(default)]
    pub required_vram_gb: Option<f64>,
    #[serde(default)]
    pub context_length: Option<usize>,
}

fn default_vendor() -> String {
    "Unknown".to_string()
}

fn default_onnx_file() -> String {
    "model.onnx".to_string()
}

/// The top-level catalog: category name → list of models.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Catalog {
    pub models: HashMap<String, Vec<ModelSpec>>,
}

impl Catalog {
    /// Load the built-in catalog from the embedded YAML.
    pub fn load_builtin() -> Result<Self, Box<dyn std::error::Error>> {
        let yaml = include_str!("../config/models.yaml");
        let catalog: Catalog = serde_yaml::from_str(yaml)?;
        Ok(catalog)
    }

    /// Find a model by its ID across all categories.
    pub fn find_by_id(&self, id: &str) -> Option<(&str, &ModelSpec)> {
        for (category, models) in &self.models {
            for model in models {
                if model.id == id {
                    return Some((category.as_str(), model));
                }
            }
        }
        None
    }

    /// Find a model by HuggingFace repo_id.
    pub fn find_by_repo(&self, repo_id: &str) -> Option<(&str, &ModelSpec)> {
        for (category, models) in &self.models {
            for model in models {
                if model.repo_id == repo_id {
                    return Some((category.as_str(), model));
                }
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_load_builtin_catalog() {
        let catalog = Catalog::load_builtin().expect("Should parse embedded YAML");
        assert!(!catalog.models.is_empty(), "Catalog should have at least one category");

        let text_models = catalog.models.get("text").expect("Should have 'text' category");
        assert!(!text_models.is_empty(), "Should have at least 1 model");
    }

    #[test]
    fn test_find_by_id() {
        let catalog = Catalog::load_builtin().unwrap();
        let (cat, spec) = catalog.find_by_id("gemma-4-e4b-it").expect("Should find Gemma 4 E4B");
        assert_eq!(cat, "text");
        assert_eq!(spec.vendor, "Google");
    }

    #[test]
    fn test_find_by_repo() {
        let catalog = Catalog::load_builtin().unwrap();
        let (_, spec) = catalog.find_by_repo("onnx-community/gemma-4-E4B-it-ONNX")
            .expect("Should find by repo");
        assert_eq!(spec.id, "gemma-4-e4b-it");
    }
}
