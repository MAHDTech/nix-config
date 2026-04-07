use burn::config::Config;
use serde::{Deserialize, Serialize};

#[derive(Config, Debug, Copy)]
pub enum LayerType {
    Local,
    Global,
}

#[derive(Config, Debug)]
pub struct LayerConfig {
    pub layer_type: LayerType,
    pub hidden_size: usize,
    pub n_heads: usize,
    pub n_kv_heads: usize,
    pub intermediate_size: usize,
    pub window_size: Option<usize>,
    pub rope_theta: f32,
    pub partial_rotary_factor: Option<f32>,
    pub is_shared_kv: bool,
}

#[derive(Config, Debug)]
pub struct Gemma4Config {
    pub vocab_size: usize,
    pub hidden_size: usize,
    pub n_layers: usize,
    pub layers: Vec<LayerConfig>,
    pub norm_eps: f32,
    pub tie_word_embeddings: bool,
}

impl Gemma4Config {
    pub fn e2b() -> Self {
        // Approximate dimensions for E2B based on report
        let n_layers = 24; // Dummy value, actual might differ
        let hidden_size = 2048;
        let n_heads = 16;
        let n_kv_heads = 2; // GQA
        let intermediate_size = 8192;

        let mut layers = Vec::new();
        for i in 0..n_layers {
            let is_global = i % 2 == 1; // Alternating
            layers.push(LayerConfig {
                layer_type: if is_global {
                    LayerType::Global
                } else {
                    LayerType::Local
                },
                hidden_size,
                n_heads,
                n_kv_heads,
                intermediate_size,
                window_size: if is_global { None } else { Some(1024) },
                rope_theta: if is_global { 1_000_000.0 } else { 10_000.0 },
                partial_rotary_factor: if is_global { Some(0.25) } else { None },
                is_shared_kv: i >= n_layers - 4, // Shared KV for last 4 layers
            });
        }

        Self {
            vocab_size: 256000,
            hidden_size,
            n_layers,
            layers,
            norm_eps: 1e-6,
            tie_word_embeddings: true,
        }
    }
}
