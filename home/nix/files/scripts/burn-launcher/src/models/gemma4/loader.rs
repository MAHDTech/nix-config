use burn_store::{
    KeyRemapper, ModuleSnapshot, PyTorchToBurnAdapter, SafetensorsStore,
};
use burn::tensor::backend::Backend;

use super::model::Gemma4Model;

/// Loads pre-trained huggingface safetensors weights into the Gemma4 model.
pub fn load_gemma4_safetensors<B: Backend>(
    checkpoint: &str,
    mut model: Gemma4Model<B>,
) -> Result<Gemma4Model<B>, String> {
    let key_mappings = vec![
        // Gemma 4 multimodal variants (like E2B Base) nest LLM parameters inside `language_model`
        ("language_model\\.", ""),
        // Gemma 4 uses RMSNorm uniformly: `input_layernorm`, `post_attention_layernorm`, and root `norm`.
        // HuggingFace stores param as `.weight`. Burn's RmsNorm structural record strictly expects `.gamma`.
        ("(.*)norm\\.weight", "${1}norm.gamma"),
    ];

    let remapper = KeyRemapper::from_patterns(key_mappings).expect("Invalid key mapping regex");

    // Load from SafeTensors format (using standard PyTorch structural extraction adapter)
    let mut store = SafetensorsStore::from_file(checkpoint)
        .with_from_adapter(PyTorchToBurnAdapter)
        .remap(remapper);

    model
        .load_from(&mut store)
        .map_err(|e| format!("Burn Model Map Failed: {}", e))?;

    Ok(model)
}
