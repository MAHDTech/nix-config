use tracing::{info, warn};

use crate::config::Catalog;

/// Developer tool: convert a HuggingFace ONNX model to Burn Rust code.
///
/// This generates committed source code for a PR workflow:
/// 1. Download ONNX from HF Hub
/// 2. Run burn-onnx ModelGen → generate .rs + .burnpack
/// 3. Output to src/engine/generated/<model_id>.rs
///
/// Usage: `burn-onnx-launcher convert onnx-community/gemma-4-E4B-it-ONNX`
pub fn convert_model(repo_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    info!(repo_id = %repo_id, "Starting model conversion");

    // 1. Look up in catalog (optional — may be a new model not yet in YAML)
    let catalog = Catalog::load_builtin()?;
    if let Some((cat, spec)) = catalog.find_by_repo(repo_id) {
        info!(
            id = %spec.id,
            category = %cat,
            name = %spec.name,
            "Found existing catalog entry"
        );
    } else {
        warn!(
            repo_id = %repo_id,
            "Model not found in catalog — this is a new model. Will generate config stub."
        );
    }

    // 2. Download ONNX from HuggingFace Hub
    info!("Downloading ONNX model from HuggingFace Hub...");
    let api = hf_hub::api::sync::Api::new()?;
    let repo = api.model(repo_id.to_string());

    // Try to find the ONNX file
    let filenames_to_try = [
        "model.onnx",
        "onnx/model.onnx",
        "onnx/decoder_model_merged.onnx",
        "onnx/decoder_model.onnx",
    ];

    let mut onnx_file = None;
    for &filename in &filenames_to_try {
        match repo.get(filename) {
            Ok(path) => {
                info!(path = %path.display(), "Downloaded ONNX model");
                onnx_file = Some(path);

                // For large models, ONNX exports the raw tensor weight data to separate files
                // usually named "<filename>_data", "<filename>_data_1", etc.
                // We must explicitly fetch them so they exist in the HF cache alongside the protobuf file.
                let data_prefix = format!("{}_data", filename);

                if let Ok(info) = repo.info() {
                    for sibling in info.siblings {
                        if sibling.rfilename.starts_with(&data_prefix) {
                            match repo.get(&sibling.rfilename) {
                                Ok(data_path) => info!(path = %data_path.display(), file = %sibling.rfilename, "Downloaded external ONNX weights layer"),
                                Err(_) => warn!(file = %sibling.rfilename, "Failed to download external ONNX weights layer"),
                            }
                        }
                    }
                } else {
                    // Fallback to just requesting the standard _data file if info fails
                    let _ = repo.get(&data_prefix);
                }

                break;
            }
            Err(_) => {
                info!(filename = filename, "Not found, trying next...");
            }
        }
    }

    let onnx_file = match onnx_file {
        Some(path) => path,
        None => {
            return Err(format!(
                "Could not find any standard ONNX file in repo '{}'. \
                 Try checking the repo structure on HuggingFace.",
                repo_id
            ).into());
        }
    };

    // 3. Generate Rust code via burn-onnx ModelGen
    use burn_onnx::ModelGen;

    let model_id = sanitize_model_id(repo_id);
    let out_dir = format!("src/engine/generated/{}", model_id);
    std::fs::create_dir_all(&out_dir)?;

    ModelGen::new()
        .input(&onnx_file.to_string_lossy())
        .out_dir(&out_dir)
        .run_from_cli();

    info!(out_dir = %out_dir, "Generated Burn model code");

    // 4. Print suggested config entry
    let model_id = sanitize_model_id(repo_id);
    println!("\n--- Suggested models.yaml entry ---");
    println!("    - id: \"{}\"", model_id);
    println!("      name: \"{}\"", repo_id.split('/').next_back().unwrap_or(repo_id));
    println!("      vendor: \"Unknown\"");
    println!("      collection: \"Unknown\"");
    println!("      engine: \"onnx\"");
    println!("      repo_id: \"{}\"", repo_id);
    println!("      onnx_file: \"model.onnx\"");
    println!("      required_ram_gb: 5.0");
    println!("      context_length: 8192");
    println!("---");

    Ok(())
}

/// Sanitize a HuggingFace repo ID into a valid Rust identifier.
/// e.g., "onnx-community/gemma-4-E4B-it-ONNX" → "gemma_4_e4b_it_onnx"
fn sanitize_model_id(repo_id: &str) -> String {
    repo_id
        .split('/')
        .next_back()
        .unwrap_or(repo_id)
        .to_lowercase()
        .replace('-', "_")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sanitize_model_id() {
        assert_eq!(
            sanitize_model_id("onnx-community/gemma-4-E4B-it-ONNX"),
            "gemma_4_e4b_it_onnx"
        );
        assert_eq!(
            sanitize_model_id("google/gemma-2-2b"),
            "gemma_2_2b"
        );
    }
}
