use burn::{
    config::Config,
    module::Module,
    nn::{
        Embedding, EmbeddingConfig, Linear, LinearConfig, RmsNorm, RmsNormConfig, RotaryEncoding,
    },
    tensor::{backend::Backend, Device, Int, Tensor},
};

use super::attention::{Gemma4Attention, Gemma4AttentionConfig, KeyValueCache};
use super::config::{Gemma4Config, LayerConfig};
use super::mlp::{FeedForward, FeedForwardConfig};

/// Configuration to create a [Gemma 4 transformer block](Gemma4Layer).
#[derive(Config, Debug)]
pub struct Gemma4LayerConfig {
    pub config: LayerConfig,
    pub norm_eps: f32,
}

impl Gemma4LayerConfig {
    pub fn init<B: Backend>(&self, device: &Device<B>) -> Gemma4Layer<B> {
        let attention = Gemma4AttentionConfig::new(
            self.config.hidden_size,
            self.config.n_heads,
            self.config.n_kv_heads,
            self.config.layer_type,
        )
        .with_window_size(self.config.window_size)
        .init(device);

        // GeGLU expansion is typically 4/3 * hidden_size in Gemma,
        // provided directly via intermediate_size
        let feed_forward = FeedForwardConfig::new(
            self.config.hidden_size,
            self.config.intermediate_size,
        ).init(device);

        let attention_norm = RmsNormConfig::new(self.config.hidden_size)
            .with_epsilon(self.norm_eps as f64)
            .init(device);
        let ffn_norm = RmsNormConfig::new(self.config.hidden_size)
            .with_epsilon(self.norm_eps as f64)
            .init(device);

        Gemma4Layer {
            self_attn: attention,
            mlp: feed_forward,
            input_layernorm: attention_norm,
            post_attention_layernorm: ffn_norm,
            is_shared_kv: self.config.is_shared_kv,
        }
    }
}

/// Gemma 4 Transformer Layer Block.
#[derive(Module, Debug)]
pub struct Gemma4Layer<B: Backend> {
    pub self_attn: Gemma4Attention<B>,
    pub mlp: FeedForward<B>,
    pub input_layernorm: RmsNorm<B>,
    pub post_attention_layernorm: RmsNorm<B>,
    pub is_shared_kv: bool,
}

impl<B: Backend> Gemma4Layer<B> {
    pub fn forward(
        &self,
        input: Tensor<B, 3>,
        cache: &mut KeyValueCache<B>,
        rope: &RotaryEncoding<B>,
    ) -> Tensor<B, 3> {
        // Gemma 4 uses pre-norm: h = x + Attn(Norm(x))
        let h = input.clone()
            + self.self_attn.forward(
                self.input_layernorm.forward(input),
                cache,
                rope,
            );

        // h = h + MLP(Norm(h))
        h.clone() + self.mlp.forward(self.post_attention_layernorm.forward(h))
    }
}

/// Top level Gemma 4 Causal LM Configuration
#[derive(Config, Debug)]
pub struct Gemma4ModelConfig {
    pub config: Gemma4Config,
}

impl Gemma4ModelConfig {
    pub fn init<B: Backend>(&self, device: &Device<B>) -> Gemma4Model<B> {
        let tok_embeddings =
            EmbeddingConfig::new(self.config.vocab_size, self.config.hidden_size).init(device);

        let layers = self.config.layers
            .iter()
            .map(|layer_cfg| {
                Gemma4LayerConfig::new(layer_cfg.clone(), self.config.norm_eps).init(device)
            })
            .collect::<Vec<_>>();

        let norm = RmsNormConfig::new(self.config.hidden_size)
            .with_epsilon(self.config.norm_eps as f64)
            .init(device);

        let output = LinearConfig::new(self.config.hidden_size, self.config.vocab_size)
            .with_bias(false)
            .init(device); // If tied embeddings are required later, this can dynamically point to the embedding matrix via custom module bindings.

        Gemma4Model {
            model: Gemma4Core {
                embed_tokens: tok_embeddings,
                layers,
                norm,
            },
            lm_head: output,
            hidden_size: self.config.hidden_size,
        }
    }
}

/// Main entry point for the Gemma 4 computational graph.
#[derive(Module, Debug)]
pub struct Gemma4Model<B: Backend> {
    pub model: Gemma4Core<B>,
    pub lm_head: Linear<B>,
    pub hidden_size: usize,
}

#[derive(Module, Debug)]
pub struct Gemma4Core<B: Backend> {
    pub embed_tokens: Embedding<B>,
    pub layers: Vec<Gemma4Layer<B>>,
    pub norm: RmsNorm<B>,
}

impl<B: Backend> Gemma4Model<B> {
    pub fn forward(
        &self,
        input: Tensor<B, 2, Int>,
        caches: &mut [KeyValueCache<B>],
        ropes: &[RotaryEncoding<B>],
    ) -> Tensor<B, 3> {
        // Input: [batch_size, seq_length]
        // Scale embeddings as per standard Gemma
        let mut h = self.model.embed_tokens.forward(input).mul_scalar(
            (self.hidden_size as f32).sqrt(),
        );

        let mut actual_cache_idx = 0;

        for layer in self.model.layers.iter() {
            // Apply RoPE geometry defined mathematically for this layer's scale
            let rope = &ropes[actual_cache_idx];

            // Advance mutable reference to strictly owned KV block instances.
            // When Shared KV applies to the final 4 layers, they map to the exact same cache footprint.
            h = layer.forward(h, &mut caches[actual_cache_idx], rope);

            if !layer.is_shared_kv {
                actual_cache_idx += 1;
            }
        }

        let h = self.model.norm.forward(h);
        self.lm_head.forward(h)
    }
}
