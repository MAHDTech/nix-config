use burn::config::Config;
use burn::module::Module;
use burn::nn::{Linear, LinearConfig};
use burn::tensor::backend::Backend;
use burn::tensor::Tensor;
use burn::tensor::activation::gelu;

/// Configuration to create a [feed-forward transformation network](FeedForward).
#[derive(Config, Debug)]
pub struct FeedForwardConfig {
    /// The size of the model (hidden_size).
    pub hidden_size: usize,
    /// The intermediate size of the FFN.
    pub intermediate_size: usize,
}

impl FeedForwardConfig {
    /// Initialize a new [feed-forward transformation network](FeedForward).
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

/// Feed-forward transformation network mapped to Gemma 4's GeGLU (Gated Linear Unit).
#[derive(Module, Debug)]
pub struct FeedForward<B: Backend> {
    gate_proj: Linear<B>,
    up_proj: Linear<B>,
    down_proj: Linear<B>,
}

impl<B: Backend> FeedForward<B> {
    /// Applies the forward pass on the input tensor.
    ///
    /// # Math
    /// GeGLU(x) = GELU(x * gate_proj) * (x * up_proj)
    /// Output(x) = GeGLU(x) * down_proj
    ///
    /// # Shapes
    /// - input: `[batch_size, seq_length, hidden_size]`
    /// - output: `[batch_size, seq_length, hidden_size]`
    pub fn forward(&self, input: Tensor<B, 3>) -> Tensor<B, 3> {
        let gate = gelu(self.gate_proj.forward(input.clone()));
        let up = self.up_proj.forward(input);

        let activated = gate.mul(up);

        self.down_proj.forward(activated)
    }
}
