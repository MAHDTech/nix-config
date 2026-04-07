use burn::{
    config::Config,
    module::Module,
    nn::{Linear, LinearConfig, RotaryEncoding},
    tensor::{activation::softmax, backend::Backend, Bool, Device, Tensor},
};

use super::config::LayerType;
use crate::models::llama::cache::AutoregressiveCache; // Temporarily using llama's cache

pub struct KeyValueCache<B: Backend> {
    pub key: AutoregressiveCache<B>,
    pub value: AutoregressiveCache<B>,
}

impl<B: Backend> KeyValueCache<B> {
    pub fn new(
        max_batch_size: usize,
        num_heads: usize,
        max_seq_len: usize,
        d_model: usize,
        device: &Device<B>,
    ) -> Self {
        Self {
            key: AutoregressiveCache::new(max_batch_size, num_heads, max_seq_len, d_model, device),
            value: AutoregressiveCache::new(max_batch_size, num_heads, max_seq_len, d_model, device),
        }
    }

    pub fn forward(
        &mut self,
        key: Tensor<B, 4>,
        value: Tensor<B, 4>,
    ) -> (Tensor<B, 4>, Tensor<B, 4>) {
        let k = self.key.forward(key);
        let v = self.value.forward(value);
        (k, v)
    }

    pub fn len(&self) -> usize {
        self.key.len()
    }
}

/// Configuration to create a [multi-head attention](Gemma4Attention) module.
#[derive(Config, Debug)]
pub struct Gemma4AttentionConfig {
    pub hidden_size: usize,
    pub n_heads: usize,
    pub n_kv_heads: usize,
    pub layer_type: LayerType,
    pub window_size: Option<usize>,
}

impl Gemma4AttentionConfig {
    pub fn init<B: Backend>(&self, device: &Device<B>) -> Gemma4Attention<B> {
        let head_dim = self.hidden_size / self.n_heads;

        // Grouped Query Attention uses fewer KV heads
        let wq = LinearConfig::new(self.hidden_size, self.n_heads * head_dim)
            .with_bias(false)
            .init(device);
        let wk = LinearConfig::new(self.hidden_size, self.n_kv_heads * head_dim)
            .with_bias(false)
            .init(device);
        let wv = LinearConfig::new(self.hidden_size, self.n_kv_heads * head_dim)
            .with_bias(false)
            .init(device);
        let wo = LinearConfig::new(self.n_heads * head_dim, self.hidden_size)
            .with_bias(false)
            .init(device);

        Gemma4Attention {
            wq,
            wk,
            wv,
            wo,
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
    wq: Linear<B>,
    wk: Linear<B>,
    wv: Linear<B>,
    wo: Linear<B>,

    n_heads: usize,
    n_kv_heads: usize,
    head_dim: usize,
    is_local: bool,
    window_size: usize,
}

impl<B: Backend> Gemma4Attention<B> {
    pub fn forward(
        &self,
        input: Tensor<B, 3>,
        cache: &mut KeyValueCache<B>,
        rope: &RotaryEncoding<B>,
    ) -> Tensor<B, 3> {
        let device = input.device();
        let [batch_size, seq_len, hidden_size] = input.dims();

        let q = self.wq.forward(input.clone());
        let k = self.wk.forward(input.clone());
        let v = self.wv.forward(input);

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

        if seq_len > 1 {
            let cache_len = cache.len();
            // Generate standard causal mask (hide future tokens)
            let mut mask = Tensor::<B, 2, Bool>::tril_mask(
                [seq_len, cache_len],
                (cache_len - seq_len) as i64,
                &device,
            );

            // Apply sliding window attention limit if configured
            if self.is_local && self.window_size > 0 {
                let window_size = self.window_size;
                // Create an upper triangle mask shifted by `window_size` to block tokens too far in the past
                let window_mask = Tensor::<B, 2, Bool>::triu_mask(
                    [seq_len, cache_len],
                    ((cache_len - seq_len) as i64) - (window_size as i64),
                    &device,
                );

                    // Combine standard causal constraint with sliding window limit
                    // Note: bool tensor ops logic applied using standard binary ops or where clauses.
                    // For simplicity we mask the raw tensor where window_mask is true since it represents the "too old" boundary.
                scores = scores.mask_fill(window_mask.unsqueeze::<4>(), f32::NEG_INFINITY);
            }

            scores = scores.mask_fill(mask.unsqueeze::<4>(), f32::NEG_INFINITY);
        }

        let scores = softmax(scores, 3);

        let output = scores.matmul(v);
        let output = output
            .swap_dims(1, 2)
            .reshape([batch_size, seq_len, hidden_size]);
        self.wo.forward(output)
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
