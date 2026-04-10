pub mod gemma4;
pub mod shared;

use crate::config::ModelSpec;
use std::path::Path;

pub enum EngineError {
    Config(String),
    Weights(String),
}

pub trait EngineFactory<B: burn::tensor::backend::Backend> {
    fn id(&self) -> &str;
    fn launch(
        &self,
        spec: &ModelSpec,
        weights_path: Option<&Path>,
        config_path: Option<&Path>,
        device: &burn::tensor::Device<B>,
    ) -> Result<Option<Box<dyn FnMut(String) -> String + Send>>, EngineError>;
}
