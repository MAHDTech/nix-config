use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

pub mod default;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ModelSpec {
    pub name: String,
    pub description: Option<String>,
    #[serde(default = "default_vendor")]
    pub vendor: String,
    pub engine: String,
    pub repo_id: Option<String>,
    pub weight_file: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub required_ram_gb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub required_vram_gb: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_context_length: Option<usize>,
}

fn default_vendor() -> String {
    "Unknown".to_string()
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Catalog {
    pub models: HashMap<String, Vec<ModelSpec>>,
}

impl Catalog {
    pub fn load_from_default() -> Result<Self, Box<dyn std::error::Error>> {
        // Embed the base defaults inside the compiled binary
        let default_content = default::DEFAULT_CONFIG;
        let mut catalog: Catalog = serde_yaml::from_str(default_content)?;

        // Resolve user home config dir
        if let Some(home) = std::env::var_os("HOME") {
            let config_dir = Path::new(&home).join(".config").join("burn-launcher");
            let user_config_path = config_dir.join("config.yaml");

            if !user_config_path.exists() {
                // If it doesn't exist, create directory and populate with defaults
                if let Err(e) = fs::create_dir_all(&config_dir) {
                    eprintln!("Warning: Failed to create config dir {:?}: {}", config_dir, e);
                } else if let Err(e) = fs::write(&user_config_path, default_content) {
                    eprintln!("Warning: Failed to write default config to {:?}: {}", user_config_path, e);
                }
            } else {
                // Read and merge the user catalog
                match fs::read_to_string(&user_config_path) {
                    Ok(user_content) => {
                        match serde_yaml::from_str::<Catalog>(&user_content) {
                            Ok(user_catalog) => {
                                catalog.merge_with(user_catalog);
                            }
                            Err(e) => eprintln!("Warning: Failed to parse user config at {:?}: {}", user_config_path, e),
                        }
                    }
                    Err(e) => eprintln!("Warning: Failed to read user config at {:?}: {}", user_config_path, e),
                }
            }
        }

        Ok(catalog)
    }

    fn merge_with(&mut self, other: Catalog) {
        for (category, models) in other.models {
            let existing_models = self.models.entry(category).or_default();
            for new_model in models {
                // Avoid duplicating models by name
                if !existing_models.iter().any(|m| m.name == new_model.name) {
                    existing_models.push(new_model);
                }
            }
        }
    }
}
