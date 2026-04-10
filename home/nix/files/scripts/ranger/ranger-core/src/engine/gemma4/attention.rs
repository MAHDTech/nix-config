use burn::{
    config::Config,
    module::Module,
    nn::{Linear, LinearConfig, RotaryEncoding},
    tensor::{activation::softmax, backend::Backend, Bool, Device, Tensor},
};

use super::cache::KeyValueCache;
use super::config::LayerType;

/// Configuration to create a [multi-head attention](Gemma4Attention) module.
#[derive(Config, Debug)]
pub struct Gemma4AttentionConfig {
    pub hidden_size: usize,
    pub head_dim: usize,
    pub n_heads: usize,
    pub n_kv_heads: usize,
    pub layer_type: LayerType,
    pub window_size: Option<usize>,
}

impl Gemma4AttentionConfig {
    pub fn init<B: Backend>(&self, device: &Device<B>) -> Gemma4Attention<B> {
        let head_dim = self.head_dim;

        let q_proj = LinearConfig::new(self.hidden_size, self.n_heads * head_dim)
            .with_bias(false)
            .init(device);
        let k_proj = LinearConfig::new(self.hidden_size, self.n_kv_heads * head_dim)
            .with_bias(false)
            .init(device);
        let v_proj = LinearConfig::new(self.hidden_size, self.n_kv_heads * head_dim)
            .with_bias(false)
            .init(device);
        let o_proj = LinearConfig::new(self.n_heads * head_dim, self.hidden_size)
            .with_bias(false)
            .init(device);

        Gemma4Attention {
            q_proj,
            k_proj,
            v_proj,
            o_proj,
            n_heads: self.n_heads,
            n_kv_heads: self.n_kv_heads,
            head_dim,
            is_local: matches!(self.layer_type, LayerType::Local),
            window_size: self.window_size.unwrap_or(0),
        }
    }
}

#[derive(Module, Debug)]
pub struct Gemma4Attention<B: Backend> {
    pub q_proj: Linear<B>,
    pub k_proj: Linear<B>,
    pub v_proj: Linear<B>,
    pub o_proj: Linear<B>,

    pub n_heads: usize,
    pub n_kv_heads: usize,
    pub head_dim: usize,
    pub is_local: bool,
    pub window_size: usize,
}

impl<B: Backend> Gemma4Attention<B> {
    pub fn forward(
        &self,
        input: Tensor<B, 3>,
        cache: &mut KeyValueCache<B>,
        rope: &RotaryEncoding<B>,
    ) -> Tensor<B, 3> {
        let device = input.device();
        let [batch_size, seq_len, _hidden_size] = input.dims();

        let q = self.q_proj.forward(input.clone());
        let k = self.k_proj.forward(input.clone());
        let v = self.v_proj.forward(input);

        let q = q
            .reshape([batch_size, seq_len, self.n_heads, self.head_dim])
            .swap_dims(1, 2);
        let k = k
            .reshape([batch_size, seq_len, self.n_kv_heads, self.head_dim])
            .swap_dims(1, 2);
        let v = v
            .reshape([batch_size, seq_len, self.n_kv_heads, self.head_dim])
            .swap_dims(1, 2);

        let cache_seq_len = cache.len();

        let q = rope.apply(q, cache_seq_len);
        let k = rope.apply(k, cache_seq_len);

        let (k, v) = cache.forward(k, v);

        // Repeat KV for Grouped Query Attention (GQA)
        let k = self.repeat_kv(k);
        let v = self.repeat_kv(v);

        let mut scores = q
            .matmul(k.swap_dims(2, 3))
            .div_scalar((self.head_dim as f32).sqrt());

        let cache_len = cache.len();

        // Generate causal mask
        let mask = Tensor::<B, 2, Bool>::tril_mask(
            [seq_len, cache_len],
            (cache_len - seq_len) as i64,
            &device,
        );
        scores = scores.mask_fill(mask.unsqueeze::<4>().bool_not(), f32::NEG_INFINITY);

        // Apply sliding window attention limit if configured
        if self.is_local && self.window_size > 0 {
            let window_size = self.window_size;
            let window_mask = Tensor::<B, 2, Bool>::triu_mask(
                [seq_len, cache_len],
                ((cache_len - seq_len) as i64) - (window_size as i64),
                &device,
            );
            scores = scores.mask_fill(window_mask.unsqueeze::<4>(), f32::NEG_INFINITY);
        }

        let scores = softmax(scores, 3);

        let output = scores.matmul(v);
        let output = output
            .swap_dims(1, 2)
            .reshape([batch_size, seq_len, self.n_heads * self.head_dim]);
        self.o_proj.forward(output)
    }

    fn repeat_kv(&self, x: Tensor<B, 4>) -> Tensor<B, 4> {
        let n_rep = self.n_heads / self.n_kv_heads;
        if n_rep == 1 {
            x
        } else {
            let [batch_size, num_kv_heads, seq_len, head_dim] = x.dims();
            x.unsqueeze_dim::<5>(2)
                .expand([batch_size, num_kv_heads, n_rep, seq_len, head_dim])
                .reshape([batch_size, num_kv_heads * n_rep, seq_len, head_dim])
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use burn::backend::NdArray;

    #[test]
    fn test_attention_init() {
        type B = NdArray<f32>;
        let device = Default::default();
        let config = Gemma4AttentionConfig::new(128, 16, 8, 2, LayerType::Global);
        let attention = config.init::<B>(&device);

        assert_eq!(attention.n_heads, 8);
        assert_eq!(attention.n_kv_heads, 2);
        assert_eq!(attention.head_dim, 16);
    }
}
