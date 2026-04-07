use axum::{
    extract::State,
    routing::post,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Deserialize)]
pub struct ChatRequest {
    pub messages: Vec<ChatMessage>,
}

#[derive(Deserialize, Serialize)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

#[derive(Serialize)]
pub struct ChatResponse {
    pub id: String,
    pub object: String,
    pub created: u64,
    pub choices: Vec<ChatChoice>,
}

#[derive(Serialize)]
pub struct ChatChoice {
    pub index: u32,
    pub message: ChatMessage,
    pub finish_reason: String,
}

// Type alias for our inference callback.
// We use a parking_lot mutex or standard mutex around the model inside the closure if needed.
pub type InferenceClosure = Box<dyn Fn(String) -> String + Send + Sync>;

#[derive(Clone)]
pub struct ApiState {
    pub model_name: String,
    // We wrap the closure in Arc for Axum routing
    pub infer_fn: Arc<InferenceClosure>,
}

pub async fn start_server(port: u16, state: ApiState) -> Result<(), Box<dyn std::error::Error>> {
    let app = Router::new()
        .route("/v1/chat/completions", post(chat_completions))
        .with_state(state.clone());

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
    println!("\n🌐 OpenAI API Server running on http://127.0.0.1:{}/v1", port);

    axum::serve(listener, app).await?;

    Ok(())
}

async fn chat_completions(
    State(state): State<ApiState>,
    Json(payload): Json<ChatRequest>,
) -> Json<ChatResponse> {

    // Naively extract the last user message to feed inference
    let prompt = payload
        .messages
        .into_iter()
        .filter(|m| m.role == "user")
        .last()
        .map(|m| m.content)
        .unwrap_or_else(|| "Hello".to_string());

    println!("📥 Received prompt: {}", prompt);

    // Execute inference block (could be slow, probably should spawn_blocking, but this is a prototype)
    let infer_fn = state.infer_fn.clone();

    let generated_text = tokio::task::spawn_blocking(move || {
        (infer_fn)(prompt)
    }).await.unwrap_or_else(|_| "Inference thread crashed.".to_string());

    let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();

    let response = ChatResponse {
        id: format!("chatcmpl-{}", timestamp),
        object: "chat.completion".to_string(),
        created: timestamp,
        choices: vec![ChatChoice {
            index: 0,
            message: ChatMessage {
                role: "assistant".to_string(),
                content: generated_text,
            },
            finish_reason: "stop".to_string(),
        }],
    };

    println!("📤 Sent response!");
    Json(response)
}
