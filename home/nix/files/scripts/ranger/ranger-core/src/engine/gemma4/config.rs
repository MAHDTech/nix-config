use burn::config::Config;
use std::path::Path;
use serde::Deserialize;

#[derive(Deserialize, Debug, Clone)]
pub struct HfTextConfig {
    pub vocab_size: usize,
    pub hidden_size: usize,
    pub num_hidden_layers: usize,
    pub num_attention_heads: usize,
    pub num_key_value_heads: usize,
    pub intermediate_size: usize,
    pub head_dim: Option<usize>,
    pub sliding_window: Option<usize>,
    #[serde(default = "default_rope_theta")]
    pub rope_theta: f32,
    pub layer_types: Option<Vec<String>>,
    pub num_kv_shared_layers: Option<usize>,
    pub use_double_wide_mlp: Option<bool>,
}

#[derive(Deserialize, Debug)]
pub struct HfGemmaConfig {
    pub text_config: Option<HfTextConfig>,
    pub vocab_size: Option<usize>,
    pub hidden_size: Option<usize>,
    pub num_hidden_layers: Option<usize>,
    pub num_attention_heads: Option<usize>,
    pub num_key_value_heads: Option<usize>,
    pub intermediate_size: Option<usize>,
    pub head_dim: Option<usize>,
    pub sliding_window: Option<usize>,
    #[serde(default = "default_rope_theta")]
    pub rope_theta: f32,
    pub layer_types: Option<Vec<String>>,
    pub num_kv_shared_layers: Option<usize>,
    pub use_double_wide_mlp: Option<bool>,
}

fn default_rope_theta() -> f32 {
    10000.0
}

#[derive(Config, Debug, Copy)]
pub enum LayerType {
    Local,
    Global,
}

#[derive(Config, Debug)]
pub struct LayerConfig {
    pub layer_type: LayerType,
    pub hidden_size: usize,
    pub head_dim: usize,
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
    pub fn from_json(path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let file = std::fs::File::open(path)?;
        let reader = std::io::BufReader::new(file);
        let hf_config: HfGemmaConfig = serde_json::from_reader(reader)?;

        let base_config = if let Some(tc) = hf_config.text_config {
            tc
        } else {
            HfTextConfig {
                vocab_size: hf_config.vocab_size.ok_or("missing vocab_size")?,
                hidden_size: hf_config.hidden_size.ok_or("missing hidden_size")?,
                num_hidden_layers: hf_config.num_hidden_layers.ok_or("missing num_hidden_layers")?,
                num_attention_heads: hf_config.num_attention_heads.ok_or("missing num_attention_heads")?,
                num_key_value_heads: hf_config.num_key_value_heads.ok_or("missing num_key_value_heads")?,
                intermediate_size: hf_config.intermediate_size.ok_or("missing intermediate_size")?,
                head_dim: hf_config.head_dim,
                sliding_window: hf_config.sliding_window,
                rope_theta: hf_config.rope_theta,
                layer_types: hf_config.layer_types,
                num_kv_shared_layers: hf_config.num_kv_shared_layers,
                use_double_wide_mlp: hf_config.use_double_wide_mlp,
            }
        };

        let head_dim = base_config.head_dim
            .unwrap_or(base_config.hidden_size / base_config.num_attention_heads);

        let mut layers = Vec::new();
        for i in 0..base_config.num_hidden_layers {
            let is_global = if let Some(ref lt) = base_config.layer_types {
                lt.get(i).map(|s| s == "full_attention").unwrap_or(false)
            } else {
                i % 5 == 4
            };

            let n_heads = if is_global { base_config.num_attention_heads * 2 } else { base_config.num_attention_heads };
            let n_kv_heads = if is_global { base_config.num_key_value_heads * 2 } else { base_config.num_key_value_heads };

            let intermediate_size = if base_config.use_double_wide_mlp.unwrap_or(false) {
                let kv_shared = base_config.num_kv_shared_layers.unwrap_or(0);
                let threshold = base_config.num_hidden_layers.saturating_sub(kv_shared);
                if i >= threshold { base_config.intermediate_size * 2 } else { base_config.intermediate_size }
            } else {
                base_config.intermediate_size
            };

            layers.push(LayerConfig {
                layer_type: if is_global { LayerType::Global } else { LayerType::Local },
                hidden_size: base_config.hidden_size,
                head_dim,
                n_heads,
                n_kv_heads,
                intermediate_size,
                window_size: if is_global { None } else { base_config.sliding_window },
                rope_theta: if is_global { 1_000_000.0 } else { base_config.rope_theta },
                partial_rotary_factor: if is_global { Some(0.25) } else { None },
                is_shared_kv: false,
            });
        }

        Ok(Self {
            vocab_size: base_config.vocab_size,
            hidden_size: base_config.hidden_size,
            n_layers: base_config.num_hidden_layers,
            layers,
            norm_eps: 1e-6,
            tie_word_embeddings: true,
        })
    }
}
