use std::path::Path;
use serde::Deserialize;

use super::llama::{LlamaConfig, RopeConfig, RopeFrequencyScaling};

#[derive(Deserialize, Debug)]
pub struct HfRopeScaling {
    pub factor: Option<f32>,
    pub high_freq_factor: Option<f32>,
    pub low_freq_factor: Option<f32>,
    pub original_max_position_embeddings: Option<f32>,
}

#[derive(Deserialize, Debug)]
pub struct HfLlamaConfig {
    pub vocab_size: usize,
    pub hidden_size: usize,
    pub intermediate_size: usize,
    pub num_hidden_layers: usize,
    pub num_attention_heads: usize,
    pub num_key_value_heads: Option<usize>,
    pub max_position_embeddings: Option<usize>,
    pub rms_norm_eps: Option<f64>,
    pub rope_theta: Option<f32>,
    pub rope_scaling: Option<HfRopeScaling>,
}

impl HfLlamaConfig {
    pub fn from_json(path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let file = std::fs::File::open(path)?;
        let reader = std::io::BufReader::new(file);
        let config: HfLlamaConfig = serde_json::from_reader(reader)?;
        Ok(config)
    }

    pub fn to_burn_config(&self, tokenizer_path: &str) -> LlamaConfig {
        let max_seq_len = self.max_position_embeddings.unwrap_or(4096);
        let config = LlamaConfig::new(
            self.intermediate_size,
            self.vocab_size,
            tokenizer_path.to_string(),
        )
        .with_d_model(self.hidden_size)
        .with_num_hidden_layers(self.num_hidden_layers)
        .with_num_attention_heads(self.num_attention_heads)
        .with_num_key_value_heads(self.num_key_value_heads)
        .with_norm_eps(self.rms_norm_eps.unwrap_or(1e-5))
        .with_max_seq_len(max_seq_len);

        let mut rope = RopeConfig::new(self.rope_theta.unwrap_or(10000.0));

        if let Some(scaling) = &self.rope_scaling {
            let mut rope_scaled = RopeFrequencyScaling::new();
            if let Some(f) = scaling.factor {
                rope_scaled = rope_scaled.with_scale_factor(f);
            }
            if let Some(f) = scaling.low_freq_factor {
                rope_scaled = rope_scaled.with_low_freq_factor(f);
            }
            if let Some(f) = scaling.high_freq_factor {
                rope_scaled = rope_scaled.with_high_freq_factor(f);
            }
            if let Some(f) = scaling.original_max_position_embeddings {
                rope_scaled = rope_scaled.with_old_context_len(f);
            }
            rope = rope.with_scaled(Some(rope_scaled));
        }

        config.with_rope(rope)
    }
}
