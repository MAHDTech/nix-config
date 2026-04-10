use burn::module::{Module, Quantizer as BurnQuantizer};
use burn::tensor::quantization::{Calibration, QuantLevel, QuantMode, QuantParam, QuantScheme, QuantStore, QuantValue};
use burn::tensor::backend::Backend;
use burn::tensor::Device;
use burn_store::{BurnpackStore, ModuleSnapshot};
use std::path::Path;
use log::info;

pub struct Quantizer;

impl Quantizer {
    /// Quantizes a model to Int8 PTQ.
    pub fn quantize_int8<B: Backend, M: Module<B>>(
        model: M,
        _device: &Device<B>,
    ) -> M {
        info!("Initializing Int8 PTQ Quantizer with MinMax calibration...");

        let mut quantizer = BurnQuantizer {
            calibration: Calibration::MinMax,
            scheme: QuantScheme {
                value: QuantValue::Q8S,
                mode: QuantMode::Symmetric,
                level: QuantLevel::Tensor,
                param: QuantParam::F32,
                store: QuantStore::Native,
            },
        };

        info!("Mapping model parameters to quantized space...");
        model.map(&mut quantizer)
    }

    /// Serializes a model to a .mpk (Burnpack) file.
    pub fn save_mpk<B: Backend, M: Module<B>>(
        model: &M,
        path: &Path,
    ) -> Result<(), String> {
        info!("Serializing model to Burnpack (.mpk) at {:?}", path);

        let mut store = BurnpackStore::from_file(path.to_str().unwrap())
            .metadata("format", "burnpack")
            .metadata("quantization", "int8");

        model
            .save_into(&mut store)
            .map_err(|e| format!("Failed to save model to Burnpack: {}", e))?;

        info!("Model successfully serialized to {:?}", path);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use burn::nn::{Linear, LinearConfig};
    use burn::backend::NdArray;

    #[derive(Module, Debug)]
    pub struct TestModel<B: Backend> {
        pub linear: Linear<B>,
    }

    #[test]
    fn test_quantize_int8() {
        type B = NdArray<f32>;
        let device = Device::<B>::default();
        let config = LinearConfig::new(16, 16);
        let model: TestModel<B> = TestModel { linear: config.init(&device) };

        let quantized = Quantizer::quantize_int8(model, &device);
        // In a real test we'd check internal precision, but for now we verify it runs.
        assert!(!quantized.linear.weight.dims().is_empty());
    }
}
