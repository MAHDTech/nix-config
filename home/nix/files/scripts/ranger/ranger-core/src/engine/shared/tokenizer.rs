// Minimal Tokenizer for ranger-core
pub struct Tokenizer;

impl Tokenizer {
    pub fn new(_path: &str) -> Result<Self, String> {
        Ok(Self)
    }

    pub fn encode(&self, text: &str) -> Vec<u32> {
        // Simple word-to-id mapping for mocking
        text.bytes().map(|b| b as u32).collect()
    }

    pub fn decode(&self, ids: &[u32]) -> String {
        ids.iter().map(|&id| char::from_u32(id).unwrap_or(' ')).collect()
    }

    pub fn bos_id(&self) -> u32 { 1 }
    pub fn eos_id(&self) -> u32 { 2 }
}
