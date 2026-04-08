/// Pre-trained model metadata.
#[allow(dead_code)]
pub struct Pretrained {
    pub(super) name: &'static str,
    pub(super) model: &'static str,
    pub(super) tokenizer: &'static str,
}


pub trait ModelMeta {
    fn pretrained(&self) -> Pretrained;
}

/// Llama pre-trained weights.
pub enum Llama {
    /// Llama-3-8B.
    Llama3,
    /// Llama-3-8B-Instruct.
    Llama3Instruct,
    /// Llama-3.1-8B-Instruct.
    Llama31Instruct,
    /// Llama-3.2-3B-Instruct.
    Llama323bInstruct,
    /// Llama-3.2-1B-Instruct.
    Llama321bInstruct,
    /// TinyLlama-1.1B Chat v1.0.
    TinyLlama,
}

impl ModelMeta for Llama {
    fn pretrained(&self) -> Pretrained {
        match self {
            Self::Llama3 => Pretrained {
                name: "Llama-3-8B",
                model: "https://huggingface.co/tracel-ai/llama-3-8b-burn/resolve/main/model.mpk?download=true",
                tokenizer: "https://huggingface.co/tracel-ai/llama-3-8b-burn/resolve/main/tokenizer.model?download=true",
            },
            Self::Llama3Instruct => Pretrained {
                name: "Llama-3-8B-Instruct",
                model: "https://huggingface.co/tracel-ai/llama-3-8b-instruct-burn/resolve/main/model.mpk?download=true",
                tokenizer: "https://huggingface.co/tracel-ai/llama-3-8b-instruct-burn/resolve/main/tokenizer.model?download=true",
            },
            Self::Llama31Instruct => Pretrained {
                name: "Llama-3.1-8B-Instruct",
                model: "https://huggingface.co/tracel-ai/llama-3.1-8b-instruct-burn/resolve/main/model.mpk?download=true",
                tokenizer: "https://huggingface.co/tracel-ai/llama-3.1-8b-instruct-burn/resolve/main/tokenizer.model?download=true",
            },
            Self::Llama323bInstruct => Pretrained {
                name: "Llama-3.2-3B-Instruct",
                model: "https://huggingface.co/tracel-ai/llama-3.2-3b-instruct-burn/resolve/main/model.mpk?download=true",
                tokenizer: "https://huggingface.co/tracel-ai/llama-3.2-3b-instruct-burn/resolve/main/tokenizer.model?download=true",
            },
            Self::Llama321bInstruct => Pretrained {
                name: "Llama-3.2-1B-Instruct",
                model: "https://huggingface.co/tracel-ai/llama-3.2-1b-instruct-burn/resolve/main/model.mpk?download=true",
                tokenizer: "https://huggingface.co/tracel-ai/llama-3.2-1b-instruct-burn/resolve/main/tokenizer.model?download=true",
            },
            Self::TinyLlama => Pretrained {
                name: "TinyLlama-1.1B",
                model: "https://huggingface.co/tracel-ai/tiny-llama-1.1b-burn/resolve/main/model.mpk?download=true",
                tokenizer: "https://huggingface.co/tracel-ai/tiny-llama-1.1b-burn/resolve/main/tokenizer.json?download=true",
            },
        }
    }
}
