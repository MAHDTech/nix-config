use std::time::Instant;

use burn::module::Module;
use burn::record::{FileRecorder, RecorderError};
use burn::tensor::cast::ToElement;
use burn::{
    config::Config,
    nn::{RotaryEncoding, RotaryEncodingConfig},
    tensor::{
        activation::softmax, backend::Backend, Device, ElementConversion, Int, Shape, Tensor,
        TensorData,
    },
};
#[cfg(feature = "import")]
use burn_store::{
    KeyRemapper, ModuleSnapshot, PytorchStore, SafetensorsStore,
};

use crate::engine::shared::sampling::Sampler;
use super::transformer::{KeyValueCache, Transformer, TransformerConfig};

#[derive(Config, Debug)]
pub struct LlamaConfig {
    /// The size of the model.
    #[config(default = "4096")]
    pub d_model: usize,
    /// The size of the feed-forward hidden inner features.
    pub hidden_size: usize,
    /// The number of transformer blocks.
    #[config(default = "32")]
    pub num_hidden_layers: usize,
    /// The number of attention heads.
    #[config(default = "32")]
    pub num_attention_heads: usize,
    /// The number of key-value heads.
    pub num_key_value_heads: Option<usize>,
    /// The vocabulary size.
    pub vocab_size: usize,
    /// RMSNorm epsilon
    #[config(default = "1e-5")]
    pub norm_eps: f64,
    /// Rotary positional encoding (RoPE).
    #[config(default = "RopeConfig::new(10000.0)")]
    pub rope: RopeConfig,
    /// Maximum sequence length for input text.
    #[config(default = "128")]
    pub max_seq_len: usize,
    /// Maximum batch size (used for key-value cache).
    #[config(default = "1")]
    pub max_batch_size: usize,
    /// The tokenizer path.
    pub tokenizer: String,
}

/// Rotary positional encoding (RoPE)
#[derive(Config, Debug)]
pub struct RopeConfig {
    pub theta: f32,
    #[config(default = "None")]
    pub scaled: Option<RopeFrequencyScaling>,
}

/// RoPE frequency scaling.
#[derive(Config, Debug)]
pub struct RopeFrequencyScaling {
    #[config(default = "8.")]
    pub scale_factor: f32,
    #[config(default = "1.")]
    pub low_freq_factor: f32,
    #[config(default = "4.")]
    pub high_freq_factor: f32,
    #[config(default = "8192.")]
    pub old_context_len: f32,
}

impl LlamaConfig {
    // Dynamic loading using HfLlamaConfig is done outside of LlamaConfig, so hardcoded presets have been removed.

    /// Initialize a new [Llama] module.
    pub fn init<B: Backend>(
        &self,
        device: &Device<B>,
    ) -> Result<Llama<B>, String> {
        let tokenizer = crate::engine::shared::tokenizer::Tokenizer::new(&self.tokenizer).map_err(|e| e.to_string())?;
        let num_key_value_heads = self.num_key_value_heads.unwrap_or(self.num_attention_heads);
        let model = TransformerConfig::new(
            self.vocab_size,
            self.num_hidden_layers,
            self.d_model,
            self.hidden_size,
            self.num_attention_heads,
            num_key_value_heads,
        )
        .with_max_seq_len(self.max_seq_len)
        .with_norm_eps(self.norm_eps)
        .init(device);

        let cache = (0..self.num_hidden_layers)
            .map(|_| {
                KeyValueCache::new(
                    self.max_batch_size,
                    num_key_value_heads,
                    self.max_seq_len,
                    self.d_model / self.num_attention_heads,
                    device,
                )
            })
            .collect::<Vec<_>>();

        let rope = RotaryEncodingConfig::new(
            self.max_seq_len * 2,
            self.d_model / self.num_attention_heads,
        )
        .with_theta(self.rope.theta);

        let rope = if let Some(scaling) = &self.rope.scaled {
            let freq_scaling_fn = move |x| scaling.freq_scaling_by_parts(x);
            rope.init_with_frequency_scaling(freq_scaling_fn, device)
        } else {
            rope.init(device)
        };

        Ok(Llama {
            tokenizer,
            model,
            cache,
            rope,
            device: device.clone(),
        })
    }

    /// Load pre-trained Llama checkpoint.
    ///
    /// Supports both PyTorch (.pt, .pth, .bin) and SafeTensors (.safetensors) formats.
    #[cfg(feature = "import")]
    pub fn load_pretrained<B: Backend>(
        &self,
        checkpoint: &str,
        device: &Device<B>,
    ) -> Result<Llama<B>, String> {
        let mut llama = self.init(device)?;

        println!("Loading record...");
        let now = Instant::now();

        // Key mappings for HuggingFace -> Burn model tensor names
        #[cfg(not(feature = "hf-tokenizer"))]
        let key_mappings: Vec<(&str, &str)> = vec![
            // Map layers.[i].feed_forward.w1.* -> layers.[i].feed_forward.swiglu.linear_inner.*
            (
                "(layers\\.[0-9]+\\.feed_forward)\\.w1\\.(.+)",
                "$1.swiglu.linear_inner.$2",
            ),
            // Map layers.[i].feed_forward.w3.* -> layers.[i].feed_forward.swiglu.linear_outer.*
            (
                "(layers\\.[0-9]+\\.feed_forward)\\.w3\\.(.+)",
                "$1.swiglu.linear_outer.$2",
            ),
            // Map norm.weight -> norm.gamma for all layers
            ("(.*)norm\\.weight", "${1}norm.gamma"),
        ];

        #[cfg(feature = "hf-tokenizer")]
        let key_mappings: Vec<(&str, &str)> = vec![
            // Map lm_head.* -> output.*
            ("lm_head\\.(.+)", "output.$1"),
            // Remove model. prefix
            ("model\\.(.+)", "$1"),
            // Map embed_tokens.* -> tok_embeddings.*
            ("embed_tokens\\.(.+)", "tok_embeddings.$1"),
            // Map layers.[i].input_layernorm.* -> layers.[i].attention_norm.*
            (
                "(layers\\.[0-9]+)\\.input_layernorm\\.(.+)",
                "$1.attention_norm.$2",
            ),
            // Map layers.[i].post_attention_layernorm.* -> layers.[i].ffn_norm.*
            (
                "(layers\\.[0-9]+)\\.post_attention_layernorm\\.(.+)",
                "$1.ffn_norm.$2",
            ),
            // Map layers.[i].mlp.down_proj.* -> layers.[i].feed_forward.w2.*
            (
                "(layers\\.[0-9]+)\\.mlp\\.down_proj\\.(.+)",
                "$1.feed_forward.w2.$2",
            ),
            // Map layers.[i].mlp.gate_proj.* -> layers.[i].feed_forward.swiglu.linear_inner.*
            (
                "(layers\\.[0-9]+)\\.mlp\\.gate_proj\\.(.+)",
                "$1.feed_forward.swiglu.linear_inner.$2",
            ),
            // Map layers.[i].mlp.up_proj.* -> layers.[i].feed_forward.swiglu.linear_outer.*
            (
                "(layers\\.[0-9]+)\\.mlp\\.up_proj\\.(.+)",
                "$1.feed_forward.swiglu.linear_outer.$2",
            ),
            // Map layers.[i].self_attn.k_proj.* -> layers.[i].attention.wk.*
            (
                "(layers\\.[0-9]+)\\.self_attn\\.k_proj\\.(.+)",
                "$1.attention.wk.$2",
            ),
            // Map layers.[i].self_attn.o_proj.* -> layers.[i].attention.wo.*
            (
                "(layers\\.[0-9]+)\\.self_attn\\.o_proj\\.(.+)",
                "$1.attention.wo.$2",
            ),
            // Map layers.[i].self_attn.q_proj.* -> layers.[i].attention.wq.*
            (
                "(layers\\.[0-9]+)\\.self_attn\\.q_proj\\.(.+)",
                "$1.attention.wq.$2",
            ),
            // Map layers.[i].self_attn.v_proj.* -> layers.[i].attention.wv.*
            (
                "(layers\\.[0-9]+)\\.self_attn\\.v_proj\\.(.+)",
                "$1.attention.wv.$2",
            ),
            // Map norm.weight -> norm.gamma for all layers
            ("(.*)norm\\.weight", "${1}norm.gamma"),
        ];

        let remapper = KeyRemapper::from_patterns(key_mappings).expect("Invalid key mapping regex");

        // Detect file format and load accordingly
        if checkpoint.ends_with(".safetensors") {
            // Load from SafeTensors format (using explicit primitive primitive adapter)
            let mut store = SafetensorsStore::from_file(checkpoint)
                .with_from_adapter(crate::engine::shared::adapter::Bfloat16ToFloat32Adapter::new())
                .remap(remapper.clone());

            llama
                .model
                .load_from(&mut store)
                .map_err(|e| e.to_string())?;
        } else {
            // Load from PyTorch format (.pt, .pth, .bin)
            let mut store = PytorchStore::from_file(checkpoint).remap(remapper);

            llama
                .model
                .load_from(&mut store)
                .map_err(|e| e.to_string())?;
        }

        let elapsed = now.elapsed().as_secs();
        println!("Loaded in {}s", elapsed);

        #[cfg(feature = "hf-tokenizer")]
        {
            // TinyLlama weights from HuggingFace use a different rotary positional encoding
            // which requires weight permutation for wq/wk tensors.
            // See: https://github.com/huggingface/transformers/issues/25199#issuecomment-1687720247
            // See: https://github.com/jzhang38/TinyLlama/issues/24
            println!("Permuting TinyLlama attention weights...");
            permute_rotary_weights(
                &mut llama.model,
                self.num_attention_heads,
                self.num_key_value_heads.unwrap_or(self.num_attention_heads),
                self.d_model,
                device,
            );
        }

        println!("Llama record loaded");

        Ok(llama)
    }
}

/// Generated text sample output.
pub struct GenerationOutput {
    /// The generated text.
    pub text: String,
    /// The number of generated tokens.
    pub tokens: usize,
    /// The time it took to produce the output tokens (generation + decoding).
    pub time: f64,
}

/// Meta Llama large language model and tokenizer.
pub struct Llama<B: Backend> {
    /// The tokenizer.
    pub tokenizer: crate::engine::shared::tokenizer::Tokenizer,
    /// Llama decoder-only transformer.
    pub model: Transformer<B>,
    /// Key-value cache for each transformer block.
    pub cache: Vec<KeyValueCache<B>>,
    /// Rotary positional encoding (RoPE).
    pub rope: RotaryEncoding<B>,
    pub device: Device<B>,
}

impl<B: Backend> Llama<B> {
    /// Generate text sample based on the provided prompt.
    ///
    /// # Arguments
    /// - `prompt`: The prompt string to use for generating the samples.
    /// - `sample_len`: The number of new tokens to generate (i.e., the number of generation steps to take).
    /// - `temperature`: Temperature value for controlling randomness in sampling (scales logits by `1 / temperature`).
    ///   High values result in more random sampling.
    /// - `sampler`: The sampling strategy to use when selecting the next token based on the predicted probabilities.
    ///
    /// # Returns
    /// The generated text along with some other metadata (see [GenerationOutput]).
    #[allow(clippy::single_range_in_vec_init)]
    pub fn generate(
        &mut self,
        prompt: &str,
        sample_len: usize,
        temperature: f64,
        sampler: &mut Sampler,
    ) -> GenerationOutput {
        let input_tokens = self.tokenize(prompt);
        let prompt_len = input_tokens.dims()[0];
        let mut tokens = Tensor::<B, 1, Int>::empty([prompt_len + sample_len], &self.device);
        tokens = tokens.slice_assign([0..prompt_len], input_tokens);

        let stop_tokens = Tensor::from_ints([self.tokenizer.eos_id()].as_slice(), &self.device);

        let mut num_tokens: usize = 0;
        let mut input_pos = Tensor::<B, 1, Int>::arange(0..prompt_len as i64, &self.device);
        let now = Instant::now();
        for i in 0..sample_len {
            let x = tokens.clone().select(0, input_pos.clone()).reshape([1, -1]);
            let logits = self.model.forward(x, &mut self.cache, &self.rope);

            let [batch_size, seq_len, _vocab_size] = logits.dims();
            let mut next_token_logits = logits
                .slice([0..batch_size, seq_len - 1..seq_len])
                .squeeze_dim(1); // [batch_size=1, vocab_size]

            if temperature > 0.0 {
                next_token_logits = temperature_scaled_softmax(next_token_logits, temperature);
            };

            let next_token = sampler.sample(next_token_logits).squeeze_dim(0);

            // Stop when any of the valid stop tokens is encountered
            if stop_tokens
                .clone()
                .equal(next_token.clone())
                .any()
                .into_scalar()
                .to_bool()
            {
                break;
            }

            // Update with the new generated token
            tokens = tokens.slice_assign([prompt_len + i..prompt_len + i + 1], next_token);
            num_tokens += 1;

            // Advance
            let t = input_pos.dims()[0];
            input_pos = input_pos.slice([t - 1..t]) + 1;
        }

        let tokens = tokens.into_data().as_slice::<B::IntElem>().unwrap()
            [prompt_len..prompt_len + num_tokens]
            .iter()
            .map(|t| t.elem::<u32>())
            .collect::<Vec<_>>();

        let generated = self.tokenizer.decode(&tokens);
        let elapsed = now.elapsed().as_secs_f64();

        GenerationOutput {
            text: generated,
            tokens: num_tokens,
            time: elapsed,
        }
    }

    /// Encode a string into a tensor of tokens.
    fn tokenize(&self, text: &str) -> Tensor<B, 1, Int> {
        let mut tokens = self.tokenizer.encode(text);
        tokens.insert(0, self.tokenizer.bos_id());

        let shape = Shape::new([tokens.len()]);
        Tensor::<B, 1, Int>::from_data(TensorData::new(tokens, shape), &self.device)
    }

    /// Save Llama model to file using the specified recorder.
    pub fn save<R: FileRecorder<B>>(
        self,
        file_path: &str,
        recorder: &R,
    ) -> Result<(), RecorderError> {
        println!("Saving record...");
        let now = Instant::now();
        self.model.save_file(file_path, recorder)?;
        let elapsed = now.elapsed().as_secs();
        println!("Saved in {}s", elapsed);

        Ok(())
    }

    /// Load Llama model from file using the specified recorder.
    pub fn load<R: FileRecorder<B>>(
        mut self,
        file_path: &str,
        recorder: &R,
    ) -> Result<Self, RecorderError> {
        println!("Loading record...");
        let now = Instant::now();
        self.model = self.model.load_file(file_path, recorder, &self.device)?;
        let elapsed = now.elapsed().as_secs();
        println!("Loaded in {}s", elapsed);

        Ok(self)
    }

    /// Reset the model state (used between generations)
    pub fn reset(&mut self) {
        self.cache.iter_mut().for_each(|cache| cache.reset());
    }
}

impl RopeFrequencyScaling {
    /// Applies frequency scaling by parts following Llama 3.1's scheme.
    ///
    /// Adapted from: <https://github.com/meta-llama/llama-models/blob/main/models/llama3/reference_impl/model.py#L45>
    pub fn freq_scaling_by_parts<B: Backend>(&self, freqs: Tensor<B, 1>) -> Tensor<B, 1> {
        let low_freq_wavelen = self.old_context_len / self.low_freq_factor;
        let high_freq_wavelen = self.old_context_len / self.high_freq_factor;

        let wavelen = freqs.clone().recip().mul_scalar(2. * core::f32::consts::PI);

        // if wavelen >= high_freq_wavelen
        let cond = wavelen.clone().greater_equal_elem(high_freq_wavelen);
        let smooth = wavelen
            .clone()
            .recip()
            .mul_scalar(self.old_context_len)
            .sub_scalar(self.low_freq_factor)
            .div_scalar(self.high_freq_factor - self.low_freq_factor);
        // (1 - smooth) * freq / scale_factor + smooth * freq
        let new_freqs = smooth
            .clone()
            .neg()
            .add_scalar(1.)
            .mul(freqs.clone().div_scalar(self.scale_factor))
            .add(smooth.clone().mul(freqs.clone()));
        let new_freqs = freqs.clone().mask_where(cond, new_freqs);

        // if wavelen > low_freq_wavelen
        let cond = wavelen.clone().greater_elem(low_freq_wavelen);
        let new_freqs = new_freqs.mask_where(cond, freqs.clone().div_scalar(self.scale_factor));

        // if wavelen < high_freq_wavelen
        let cond = wavelen.lower_elem(high_freq_wavelen);

        new_freqs.mask_where(cond, freqs)
    }
}

/// Check that the requested context length is within the model's supported maximum.
#[cfg(feature = "pretrained")]
#[allow(dead_code)]
fn check_context_length(max_seq_len: usize, max_context_len: usize) {
    if max_seq_len > max_context_len {
        eprintln!(
            "Warning: max_seq_len ({}) exceeds the model's maximum context length ({})",
            max_seq_len, max_context_len
        );
    }
}

pub(crate) fn temperature_scaled_softmax<B: Backend>(
    logits: Tensor<B, 2>,
    temperature: f64,
) -> Tensor<B, 2> {
    softmax(logits / temperature, 1)
}

/// Permute wq/wk weights to convert HuggingFace rotary encoding format to Burn format.
///
/// HuggingFace TinyLlama uses interleaved rotary position encoding, while Burn expects
/// the standard LLaMA format. This function permutes the query and key projection weights
/// to handle the different conventions.
#[cfg(all(feature = "hf-tokenizer", feature = "import"))]
fn permute_rotary_weights<B: Backend>(
    model: &mut Transformer<B>,
    n_heads: usize,
    n_kv_heads: usize,
    d_model: usize,
    device: &Device<B>,
) {
    use burn_store::TensorSnapshot;

    let snapshots = model.collect(None, None, false);

    let modified: Vec<TensorSnapshot> = snapshots
        .into_iter()
        .map(|snapshot| {
            let path = snapshot.full_path();

            if path.contains(".wq.weight") {
                permute_attention_weight::<B>(&snapshot, n_heads, device)
            } else if path.contains(".wk.weight") {
                let kv_dim = d_model * n_kv_heads / n_heads;
                permute_attention_weight_with_dim::<B>(&snapshot, n_kv_heads, kv_dim, device)
            } else {
                snapshot
            }
        })
        .collect();

    model.apply(modified, None, None, false);
}

/// Helper to permute a single attention weight tensor.
#[cfg(all(feature = "hf-tokenizer", feature = "import"))]
fn permute_attention_weight<B: Backend>(
    snapshot: &burn_store::TensorSnapshot,
    n_heads: usize,
    device: &Device<B>,
) -> burn_store::TensorSnapshot {
    use burn_store::TensorSnapshot;

    let data = snapshot.to_data().expect("Failed to get tensor data");
    let [dim1, dim2] = [data.shape[0], data.shape[1]];

    let tensor: Tensor<B, 2> = Tensor::from_data(data, device);
    let permuted = tensor
        .reshape([dim1, n_heads, 2, dim2 / n_heads / 2])
        .swap_dims(2, 3)
        .reshape([dim1, dim2]);

    TensorSnapshot::from_data(
        permuted.to_data(),
        snapshot.path_stack.clone().unwrap_or_default(),
        snapshot.container_stack.clone().unwrap_or_default(),
        snapshot.tensor_id.unwrap_or_default(),
    )
}

/// Helper to permute attention weight with explicit output dimension.
#[cfg(all(feature = "hf-tokenizer", feature = "import"))]
fn permute_attention_weight_with_dim<B: Backend>(
    snapshot: &burn_store::TensorSnapshot,
    n_heads: usize,
    out_dim: usize,
    device: &Device<B>,
) -> burn_store::TensorSnapshot {
    use burn_store::TensorSnapshot;

    let data = snapshot.to_data().expect("Failed to get tensor data");
    let dim1 = data.shape[0];

    let tensor: Tensor<B, 2> = Tensor::from_data(data, device);
    let permuted = tensor
        .reshape([dim1, n_heads, 2, out_dim / n_heads / 2])
        .swap_dims(2, 3)
        .reshape([dim1, out_dim]);

    TensorSnapshot::from_data(
        permuted.to_data(),
        snapshot.path_stack.clone().unwrap_or_default(),
        snapshot.container_stack.clone().unwrap_or_default(),
        snapshot.tensor_id.unwrap_or_default(),
    )
}

