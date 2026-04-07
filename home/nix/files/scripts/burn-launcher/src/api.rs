use axum::{
    extract::State,
    response::sse::{Event, Sse},
    routing::post,
    Json, Router, response::IntoResponse,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio_stream::StreamExt;
use futures_util::stream::Stream;
use std::convert::Infallible;

#[derive(Deserialize)]
pub struct ChatRequest {
    pub messages: Vec<ChatMessage>,
    pub stream: Option<bool>,
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
    pub finish_reason: Option<String>,
}

#[derive(Serialize)]
pub struct ChatStreamResponse {
    pub id: String,
    pub object: String,
    pub created: u64,
    pub choices: Vec<ChatStreamChoice>,
}

#[derive(Serialize)]
pub struct ChatStreamChoice {
    pub index: u32,
    pub delta: ChatMessageDelta,
    pub finish_reason: Option<String>,
}

#[derive(Serialize)]
pub struct ChatMessageDelta {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub role: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
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
) -> impl IntoResponse {

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

    if payload.stream.unwrap_or(false) {
        // SSE Streaming
        let stream = async_stream::stream! {
            let chunk_id = format!("chatcmpl-{}", timestamp);

            // Send initial role chunk
            let init_chunk = ChatStreamResponse {
                id: chunk_id.clone(),
                object: "chat.completion.chunk".to_string(),
                created: timestamp,
                choices: vec![ChatStreamChoice {
                    index: 0,
                    delta: ChatMessageDelta { role: Some("assistant".to_string()), content: None },
                    finish_reason: None,
                }],
            };
            yield Ok::<_, std::convert::Infallible>(Event::default().json_data(init_chunk).unwrap());

            // Send content chunk (TODO: real token-by-token streaming from Burn)
            let txt_chunk = ChatStreamResponse {
                id: chunk_id.clone(),
                object: "chat.completion.chunk".to_string(),
                created: timestamp,
                choices: vec![ChatStreamChoice {
                    index: 0,
                    delta: ChatMessageDelta { role: None, content: Some(generated_text) },
                    finish_reason: None,
                }],
            };
            yield Ok::<_, std::convert::Infallible>(Event::default().json_data(txt_chunk).unwrap());

            // Send stop chunk
            let stop_chunk = ChatStreamResponse {
                id: chunk_id,
                object: "chat.completion.chunk".to_string(),
                created: timestamp,
                choices: vec![ChatStreamChoice {
                    index: 0,
                    delta: ChatMessageDelta { role: None, content: None },
                    finish_reason: Some("stop".to_string()),
                }],
            };
            yield Ok::<_, std::convert::Infallible>(Event::default().json_data(stop_chunk).unwrap());
            yield Ok::<_, std::convert::Infallible>(Event::default().data("[DONE]"));
        };

        Sse::new(stream).into_response()
    } else {
        // Sync response
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
                finish_reason: Some("stop".to_string()),
            }],
        };

        println!("📤 Sent sync response!");
        Json(response).into_response()
    }
}
