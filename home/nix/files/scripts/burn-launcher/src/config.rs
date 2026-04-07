use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ModelSpec {
    pub name: String,
    pub description: Option<String>,
    pub engine: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Catalog {
    pub models: HashMap<String, Vec<ModelSpec>>,
}

impl Catalog {
    pub fn load_from_default() -> Result<Self, Box<dyn std::error::Error>> {
        // Try to load from current directory first, then fallback to expanded user path
        let paths = [
            "src/burn-launcher.yaml",
            "burn-launcher.yaml",
            &format!("{}/.local/bin/burn-launcher.yaml", std::env::var("HOME").unwrap_or_default()),
        ];

        for path in paths {
            if Path::new(path).exists() {
                let content = fs::read_to_string(path)?;
                let catalog: Catalog = serde_yaml::from_str(&content)?;
                return Ok(catalog);
            }
        }

        Err("Could not find burn-launcher.yaml in any standard locations".into())
    }
}
