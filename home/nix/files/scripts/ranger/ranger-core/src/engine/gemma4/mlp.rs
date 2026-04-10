use burn::config::Config;
use burn::module::Module;
use burn::nn::{Linear, LinearConfig};
use burn::tensor::backend::Backend;
use burn::tensor::Tensor;
use burn::tensor::activation::gelu;

/// Configuration to create a [feed-forward transformation network](FeedForward).
#[derive(Config, Debug)]
pub struct FeedForwardConfig {
    pub hidden_size: usize,
    pub intermediate_size: usize,
}

impl FeedForwardConfig {
    pub fn init<B: Backend>(&self, device: &burn::tensor::Device<B>) -> FeedForward<B> {
        let gate_proj = LinearConfig::new(self.hidden_size, self.intermediate_size)
            .with_bias(false)
            .init(device);
        let up_proj = LinearConfig::new(self.hidden_size, self.intermediate_size)
            .with_bias(false)
            .init(device);
        let down_proj = LinearConfig::new(self.intermediate_size, self.hidden_size)
            .with_bias(false)
            .init(device);

        FeedForward {
            gate_proj,
            up_proj,
            down_proj,
        }
    }
}

#[derive(Module, Debug)]
pub struct FeedForward<B: Backend> {
    pub gate_proj: Linear<B>,
    pub up_proj: Linear<B>,
    pub down_proj: Linear<B>,
}

impl<B: Backend> FeedForward<B> {
    pub fn forward(&self, input: Tensor<B, 3>) -> Tensor<B, 3> {
        let gate = gelu(self.gate_proj.forward(input.clone()));
        let up = self.up_proj.forward(input);

        let activated = gate.mul(up);

        self.down_proj.forward(activated)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use burn::backend::NdArray;

    #[test]
    fn test_feed_forward_init() {
        type B = NdArray<f32>;
        let device = Default::default();
        let config = FeedForwardConfig::new(128, 512);
        let ff = config.init::<B>(&device);

        let input = Tensor::<B, 3>::zeros([1, 10, 128], &device);
        let output = ff.forward(input);

        assert_eq!(output.dims(), [1, 10, 128]);
    }
}
