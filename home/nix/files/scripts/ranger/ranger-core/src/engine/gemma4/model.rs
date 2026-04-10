use burn::{
    config::Config,
    module::Module,
    nn::{
        Embedding, EmbeddingConfig, RmsNorm, RmsNormConfig, RotaryEncoding,
    },
    tensor::{backend::Backend, Device, Float, Int, Tensor},
};

use super::attention::{Gemma4Attention, Gemma4AttentionConfig};
use super::cache::KeyValueCache;
use super::config::{Gemma4Config, LayerConfig};
use super::mlp::{FeedForward, FeedForwardConfig};

#[derive(Config, Debug)]
pub struct Gemma4LayerConfig {
    pub config: LayerConfig,
    pub norm_eps: f32,
}

impl Gemma4LayerConfig {
    pub fn init<B: Backend>(&self, device: &Device<B>) -> Gemma4Layer<B> {
        let attention = Gemma4AttentionConfig::new(
            self.config.hidden_size,
            self.config.head_dim,
            self.config.n_heads,
            self.config.n_kv_heads,
            self.config.layer_type,
        )
        .with_window_size(self.config.window_size)
        .init(device);

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
        // Pre-norm: h = x + Attn(Norm(x))
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

        Gemma4Model {
            model: Gemma4Core {
                embed_tokens: tok_embeddings,
                layers,
                norm,
            },
            hidden_size: self.config.hidden_size,
        }
    }
}

#[derive(Module, Debug)]
pub struct Gemma4Model<B: Backend> {
    pub model: Gemma4Core<B>,
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
        let mut h = self.model.embed_tokens.forward(input).mul_scalar(
            (self.hidden_size as f32).sqrt(),
        );

        let mut actual_cache_idx = 0;

        for layer in self.model.layers.iter() {
            let rope = &ropes[actual_cache_idx];
            h = layer.forward(h, &mut caches[actual_cache_idx], rope);

            if !layer.is_shared_kv {
                actual_cache_idx += 1;
            }
        }

        let h = self.model.norm.forward(h);

        let [batch_size, seq_len, _hidden] = h.dims();
        let embed_weight: Tensor<B, 2, Float> = self.model.embed_tokens.clone().into_record().weight.val();
        let h_flat = h.reshape([batch_size * seq_len, self.hidden_size]);
        let logits = h_flat.matmul(embed_weight.transpose());
        let vocab_size = logits.dims()[1];
        logits.reshape([batch_size, seq_len, vocab_size])
    }
}
