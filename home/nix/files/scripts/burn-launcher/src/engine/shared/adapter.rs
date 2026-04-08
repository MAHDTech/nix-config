use burn_store::{ModuleAdapter, PyTorchToBurnAdapter, TensorSnapshot};
use burn::tensor::DType;
use std::rc::Rc;

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
        // First adapt from PyTorch structural representation to Burn structural representation
        let adapted = self.inner.adapt(snapshot);

        // Only convert bf16 tensors to prevent WebGPU primitive translation panics on older hardware.
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
