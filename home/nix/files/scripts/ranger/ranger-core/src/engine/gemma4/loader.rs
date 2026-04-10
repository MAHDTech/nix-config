use burn_store::{
    BurnpackStore, KeyRemapper, ModuleAdapter, ModuleSnapshot, PyTorchToBurnAdapter, SafetensorsStore,
    TensorSnapshot,
};
use burn::tensor::backend::Backend;
use burn::tensor::DType;
use std::path::Path;
use std::rc::Rc;

use super::model::Gemma4Model;

#[derive(Clone, Default, Debug)]
pub struct Bfloat16ToFloat32Adapter {
    inner: PyTorchToBurnAdapter,
}

impl Bfloat16ToFloat32Adapter {
    pub fn new() -> Self {
        Self {
            inner: PyTorchToBurnAdapter,
        }
    }
}

impl ModuleAdapter for Bfloat16ToFloat32Adapter {
    fn adapt(&self, snapshot: &TensorSnapshot) -> TensorSnapshot {
        let adapted = self.inner.adapt(snapshot);

        if adapted.dtype == DType::BF16 {
            let original_data_fn = adapted.clone_data_fn();
            let new_data_fn = Rc::new(move || {
                let data = original_data_fn()?;
                Ok(data.convert::<f32>())
            });

            TensorSnapshot::from_closure(
                new_data_fn,
                DType::F32,
                adapted.shape.clone(),
                adapted.path_stack.clone().unwrap_or_default(),
                adapted.container_stack.clone().unwrap_or_default(),
                adapted.tensor_id.unwrap_or_default(),
            )
        } else {
            adapted
        }
    }

    fn get_alternative_param_name(&self, param_name: &str, container_type: &str) -> Option<String> {
        self.inner.get_alternative_param_name(param_name, container_type)
    }

    fn clone_box(&self) -> Box<dyn ModuleAdapter> {
        Box::new(self.clone())
    }
}

/// Loads pre-trained huggingface safetensors weights into the Gemma4 model.
pub fn load_gemma4_safetensors<B: Backend>(
    checkpoint: &str,
    mut model: Gemma4Model<B>,
) -> Result<Gemma4Model<B>, String> {
    let key_mappings = vec![
        ("language_model\\.", ""),
        ("(.*)norm\\.weight", "${1}norm.gamma"),
    ];

    let remapper = KeyRemapper::from_patterns(key_mappings).expect("Invalid key mapping regex");

    let mut store = SafetensorsStore::from_file(checkpoint)
        .with_from_adapter(Bfloat16ToFloat32Adapter::new())
        .remap(remapper);

    model
        .load_from(&mut store)
        .map_err(|e| format!("Burn Model Map Failed: {}", e))?;

    Ok(model)
}

/// Loads a quantized Gemma 4 model from a .mpk (Burnpack) file using mmap.
pub fn load_quantized_mpk<B: Backend>(
    path: &Path,
    mut model: Gemma4Model<B>,
) -> Result<Gemma4Model<B>, String> {
    let mut store = BurnpackStore::from_file(path.to_str().unwrap());

    model
        .load_from(&mut store)
        .map_err(|e| format!("Burnpack Load Failed: {}", e))?;

    Ok(model)
}
