use burn::tensor::{backend::Backend, Tensor, Float};

pub struct Sampler;

impl Sampler {
    pub fn new_top_p(_p: f32, _seed: u64) -> Self {
        Self
    }

    pub fn sample<B: Backend>(&self, logits: Tensor<B, 1, Float>) -> u32 {
        // Very simple greedy sampling for minimal functional version
        let [vocab_size] = logits.dims();
        let argmax = logits.argmax(0).into_scalar();
        // Return as u32
        burn::tensor::cast::ToElement::to_i64(&argmax) as u32
    }
}
