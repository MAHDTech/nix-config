use axum::extract as ax_extract;
use axum::routing as ax_routing;
use axum::{Json, response::IntoResponse, response::sse::{Event, Sse}};
use crate::types::{ModelList, ModelInfo, ChatRequest, ChatResponse, ChatChoice, ChatMessage, MessageContent};
use crate::queue::FifoQueue;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone)]
pub struct ApiState {
    pub queue: Arc<FifoQueue>,
}

pub fn router(state: ApiState) -> ax_routing::Router {
    ax_routing::Router::new()
        .route("/v1/models", ax_routing::get(list_models))
        .route("/v1/chat/completions", ax_routing::post(chat_completions))
        .with_state(state)
}

async fn list_models() -> impl IntoResponse {
    let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    Json(ModelList {
        data: vec![ModelInfo {
            id: "gemma-4-e2b".to_string(),
            object: "model".to_string(),
            created: timestamp,
            owned_by: "google".to_string(),
        }],
    })
}

async fn chat_completions(
    ax_extract::State(state): ax_extract::State<ApiState>,
    Json(payload): Json<ChatRequest>,
) -> impl IntoResponse {
    let prompt = payload.messages.last().map(|m| match &m.content {
        MessageContent::Text(t) => t.clone(),
    }).unwrap_or_else(|| "hello".to_string());

    let res = state.queue.submit(prompt).await.unwrap_or_else(|e| crate::queue::InferenceResponse { text: format!("Error: {}", e) });

    let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    Json(ChatResponse {
        id: format!("chatcmpl-{}", timestamp),
        object: "chat.completion".to_string(),
        created: timestamp,
        choices: vec![ChatChoice {
            index: 0,
            message: ChatMessage {
                role: "assistant".to_string(),
                content: MessageContent::Text(res.text),
            },
            finish_reason: Some("stop".to_string()),
        }],
    })
}
