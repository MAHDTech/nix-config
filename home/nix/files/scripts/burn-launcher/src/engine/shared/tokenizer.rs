use tokenizers::Tokenizer as HfTokenizer;

/// A generic Hugging Face tokenizer wrapper.
pub struct Tokenizer {
    inner: HfTokenizer,
    bos_id: u32,
    eos_id: u32,
}

impl Tokenizer {
    /// Load a Hugging Face `tokenizer.json` from a file path.
    pub fn new(path: &str) -> Result<Self, String> {
        let inner = HfTokenizer::from_file(path)
            .map_err(|e| format!("Failed to load tokenizer from {}: {}", path, e))?;

        let bos_id = inner
            .get_vocab(true)
            .get("<bos>")
            .copied()
            .unwrap_or(2); // standard for Gemma

        let eos_id = inner
            .get_vocab(true)
            .get("<eos>")
            .copied()
            .unwrap_or(1); // standard for Gemma

        Ok(Self {
            inner,
            bos_id,
            eos_id,
        })
    }

    /// Encode a string into a list of token identifiers.
    pub fn encode(&self, text: &str) -> Vec<u32> {
        self.inner
            .encode(text, false)
            .map(|e| e.get_ids().to_vec())
            .unwrap_or_default()
    }

    /// Decode a list of token identifiers into a string.
    pub fn decode(&self, tokens: &[u32]) -> String {
        self.inner
            .decode(tokens, true)
            .unwrap_or_default()
    }

    pub fn bos_id(&self) -> u32 {
        self.bos_id
    }

    pub fn eos_id(&self) -> u32 {
        self.eos_id
    }
}
