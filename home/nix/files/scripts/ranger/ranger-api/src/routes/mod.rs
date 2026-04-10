use axum::extract::State;
use axum::routing::{get, post, Router};
use axum::{Json, response::IntoResponse, response::sse::{Event, Sse}};
use crate::types::{
    ModelList, ModelInfo, ChatRequest, ChatResponse, ChatChoice, ChatMessage,
    MessageContent, ChatStreamResponse, ChatStreamChoice, ChatMessageDelta,
    UsageInfo
};
use crate::queue::{FifoQueue, InferenceChunk};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio_stream::StreamExt;
use tokio_stream::wrappers::ReceiverStream;

#[derive(Clone)]
pub struct ApiState {
    pub queue: Arc<FifoQueue>,
}

pub fn router(state: ApiState) -> Router {
    Router::new()
        .route("/v1/models", get(list_models))
        .route("/v1/chat/completions", post(chat_completions))
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
    State(state): State<ApiState>,
    Json(payload): Json<ChatRequest>,
) -> impl IntoResponse {
    let prompt = payload.messages.last().map(|m| match &m.content {
        MessageContent::Text(t) => t.clone(),
    }).unwrap_or_else(|| "hello".to_string());

    let rx = match state.queue.submit(prompt).await {
        Ok(rx) => rx,
        Err(e) => return (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e).into_response(),
    };

    let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    let model_id = payload.model.unwrap_or_else(|| "gemma-4-e2b".to_string());

    if payload.stream.unwrap_or(false) {
        let stream = ReceiverStream::new(rx).map(move |chunk| {
            match chunk {
                InferenceChunk::Token(token) => {
                    let resp = ChatStreamResponse {
                        id: format!("chatcmpl-{}", timestamp),
                        object: "chat.completion.chunk".to_string(),
                        created: timestamp,
                        model: model_id.clone(),
                        choices: vec![ChatStreamChoice {
                            index: 0,
                            delta: ChatMessageDelta {
                                role: None,
                                content: Some(token),
                            },
                            logprobs: None,
                            finish_reason: None,
                        }],
                    };
                    Ok::<Event, std::convert::Infallible>(Event::default().json_data(resp).unwrap())
                }
                InferenceChunk::Done => {
                    let resp = ChatStreamResponse {
                        id: format!("chatcmpl-{}", timestamp),
                        object: "chat.completion.chunk".to_string(),
                        created: timestamp,
                        model: model_id.clone(),
                        choices: vec![ChatStreamChoice {
                            index: 0,
                            delta: ChatMessageDelta {
                                role: None,
                                content: None,
                            },
                            logprobs: None,
                            finish_reason: Some("stop".to_string()),
                        }],
                    };
                    Ok::<Event, std::convert::Infallible>(Event::default().json_data(resp).unwrap())
                }
                InferenceChunk::Error(e) => {
                    Ok::<Event, std::convert::Infallible>(Event::default().data(format!("[ERROR] {}", e)))
                }
            }
        }).chain(tokio_stream::once(Ok(Event::default().data("[DONE]"))));

        Sse::new(stream).into_response()
    } else {
        // Collect all tokens for sync response
        let mut full_text = String::new();
        let mut rx = rx;
        while let Some(chunk) = rx.recv().await {
            match chunk {
                InferenceChunk::Token(t) => full_text.push_str(&t),
                InferenceChunk::Done => break,
                InferenceChunk::Error(e) => {
                    return (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e).into_response();
                }
            }
        }

        let response = ChatResponse {
            id: format!("chatcmpl-{}", timestamp),
            object: "chat.completion".to_string(),
            created: timestamp,
            model: model_id,
            choices: vec![ChatChoice {
                index: 0,
                message: ChatMessage {
                    role: "assistant".to_string(),
                    content: MessageContent::Text(full_text),
                },
                logprobs: None,
                finish_reason: Some("stop".to_string()),
            }],
            usage: Some(UsageInfo {
                prompt_tokens: 0, // Mock
                completion_tokens: 0, // Mock
                total_tokens: 0, // Mock
            }),
        };
        Json(response).into_response()
    }
}
