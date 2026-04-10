use serde::{Deserialize, Serialize};

#[derive(Deserialize, Debug, Clone)]
pub struct ChatRequest {
    pub messages: Vec<ChatMessage>,
    pub stream: Option<bool>,
}

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct ChatMessage {
    pub role: String,
    pub content: MessageContent,
}

#[derive(Deserialize, Serialize, Debug, Clone)]
#[serde(untagged)]
pub enum MessageContent {
    Text(String),
}

#[derive(Serialize, Debug)]
pub struct ChatResponse {
    pub id: String,
    pub object: String,
    pub created: u64,
    pub choices: Vec<ChatChoice>,
}

#[derive(Serialize, Debug)]
pub struct ChatChoice {
    pub index: u32,
    pub message: ChatMessage,
    pub finish_reason: Option<String>,
}

#[derive(Serialize, Debug)]
pub struct ModelList {
    pub data: Vec<ModelInfo>,
}

#[derive(Serialize, Debug)]
pub struct ModelInfo {
    pub id: String,
    pub object: String,
    pub created: u64,
    pub owned_by: String,
}
