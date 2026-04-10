use serde::{Deserialize, Serialize};
use crate::system::HardwareInfo;

pub mod google;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ModelSpec {
    pub name: String,
    pub description: Option<String>,
    pub vendor: String,
    pub collection: String,
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

impl ModelSpec {
    pub fn is_supported(&self, hw: &HardwareInfo) -> bool {
        if let Some(req_ram) = self.required_ram_gb {
            if hw.total_ram_gb < req_ram {
                return false;
            }
        }
        if let Some(req_vram) = self.required_vram_gb {
            if hw.total_vram_gb < req_vram {
                return false;
            }
        }
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_model_spec_support() {
        let spec = ModelSpec {
            name: "Test Model".to_string(),
            description: None,
            vendor: "Google".to_string(),
            collection: "Gemma 4".to_string(),
            engine: "gemma4".to_string(),
            repo_id: None,
            weight_file: None,
            required_ram_gb: Some(16.0),
            required_vram_gb: Some(8.0),
            default_context_length: None,
        };

        let hw_supported = HardwareInfo {
            total_ram_gb: 32.0,
            used_ram_gb: 4.0,
            gpu_vendor: "nvidia".to_string(),
            total_vram_gb: 12.0,
        };

        let hw_unsupported_ram = HardwareInfo {
            total_ram_gb: 8.0,
            used_ram_gb: 2.0,
            gpu_vendor: "cpu".to_string(),
            total_vram_gb: 0.0,
        };

        assert!(spec.is_supported(&hw_supported));
        assert!(!spec.is_supported(&hw_unsupported_ram));
    }
}
