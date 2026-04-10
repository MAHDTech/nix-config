use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use tokio::sync::Semaphore;
use tracing::{error, info, warn};

use crate::config::ModelSpec;

// ---------------------------------------------------------------------------
// Shared server state
// ---------------------------------------------------------------------------

/// Guards inference so only one request runs at a time.
/// If a panic poisons the engine, the flag prevents further requests.
pub struct InferenceGuard {
    semaphore: Semaphore,
    poisoned: Arc<AtomicBool>,
}

impl InferenceGuard {
    pub fn new() -> Self {
        Self {
            semaphore: Semaphore::new(1),
            poisoned: Arc::new(AtomicBool::new(false)),
        }
    }
}

pub struct AppState {
    pub guard: Arc<InferenceGuard>,
    pub model: ModelSpec,
}

// ---------------------------------------------------------------------------
// Request / Response types (permissive OpenAI-compatible schema)
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct ChatMessage {
    pub role: String,
    pub content: Option<String>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct ChatCompletionRequest {
    pub model: Option<String>,
    pub messages: Vec<ChatMessage>,
    #[serde(default)]
    pub temperature: Option<f64>,
    #[serde(default)]
    pub max_tokens: Option<usize>,
    #[serde(default)]
    pub stream: Option<bool>,

    // Permissive: accept and ignore unsupported fields
    #[serde(default)]
    pub tools: Option<serde_json::Value>,
    #[serde(default)]
    pub tool_choice: Option<serde_json::Value>,
    #[serde(default)]
    pub parallel_tool_calls: Option<bool>,
    #[serde(default)]
    pub stream_options: Option<serde_json::Value>,
}

#[derive(Serialize)]
pub struct ChatCompletionResponse {
    pub id: String,
    pub object: String,
    pub created: i64,
    pub model: String,
    pub choices: Vec<Choice>,
    pub usage: Usage,
}

#[derive(Serialize)]
pub struct Choice {
    pub index: usize,
    pub message: ResponseMessage,
    pub finish_reason: String,
}

#[derive(Serialize)]
pub struct ResponseMessage {
    pub role: String,
    pub content: String,
}

#[derive(Serialize)]
pub struct Usage {
    pub prompt_tokens: usize,
    pub completion_tokens: usize,
    pub total_tokens: usize,
}

#[derive(Serialize)]
pub struct ModelInfo {
    pub id: String,
    pub object: String,
    pub owned_by: String,
}

#[derive(Serialize)]
pub struct ModelListResponse {
    pub object: String,
    pub data: Vec<ModelInfo>,
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

pub fn create_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/v1/models", get(list_models))
        .route("/v1/chat/completions", post(chat_completions))
        .route("/health", get(health))
        .with_state(state)
}

async fn health() -> impl IntoResponse {
    Json(serde_json::json!({ "status": "ok" }))
}

async fn list_models(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    let model = &state.model;
    Json(ModelListResponse {
        object: "list".to_string(),
        data: vec![ModelInfo {
            id: model.id.clone(),
            object: "model".to_string(),
            owned_by: model.vendor.clone(),
        }],
    })
}

async fn chat_completions(
    State(state): State<Arc<AppState>>,
    Json(req): Json<ChatCompletionRequest>,
) -> Result<impl IntoResponse, (StatusCode, Json<serde_json::Value>)> {
    let request_id = uuid::Uuid::new_v4().to_string();

    // Check poison state
    if state.guard.poisoned.load(Ordering::Relaxed) {
        error!(request_id = %request_id, "Engine is poisoned — refusing request");
        return Err((
            StatusCode::SERVICE_UNAVAILABLE,
            Json(serde_json::json!({
                "error": {
                    "message": "Inference engine has been poisoned by a previous error. Restart required.",
                    "type": "server_error",
                    "code": "engine_poisoned"
                }
            })),
        ));
    }

    // Log stripped features
    if req.tools.is_some() {
        warn!(
            model = %state.model.name,
            "Stripping tool definitions from request — model does not support tool calling"
        );
    }
    if req.stream_options.is_some() {
        info!("Extra fields from client (ignored): [\"stream_options\"]");
    }

    // Acquire inference lock
    let _permit = state
        .guard
        .semaphore
        .acquire()
        .await
        .map_err(|_| {
            (
                StatusCode::SERVICE_UNAVAILABLE,
                Json(serde_json::json!({
                    "error": {
                        "message": "Inference semaphore closed",
                        "type": "server_error"
                    }
                })),
            )
        })?;

    // TODO: Actual inference with loaded burn model
    // For now, return a placeholder response
    let prompt = req
        .messages
        .last()
        .and_then(|m| m.content.as_deref())
        .unwrap_or("");

    info!(request_id = %request_id, prompt_preview = %&prompt[..prompt.len().min(80)], "Processing request");

    let response = ChatCompletionResponse {
        id: format!("chatcmpl-{}", request_id),
        object: "chat.completion".to_string(),
        created: chrono::Utc::now().timestamp(),
        model: state.model.id.clone(),
        choices: vec![Choice {
            index: 0,
            message: ResponseMessage {
                role: "assistant".to_string(),
                content: format!(
                    "[burn-onnx-launcher] Model '{}' loaded but inference not yet wired. Your prompt: {}",
                    state.model.name,
                    &prompt[..prompt.len().min(200)]
                ),
            },
            finish_reason: "stop".to_string(),
        }],
        usage: Usage {
            prompt_tokens: prompt.len() / 4,
            completion_tokens: 0,
            total_tokens: prompt.len() / 4,
        },
    };

    info!(request_id = %request_id, status = 200, "Sent response");
    Ok(Json(response))
}

/// Start the Axum HTTP server on the given port.
pub async fn start_server(model: ModelSpec, port: u16) -> Result<(), Box<dyn std::error::Error>> {
    let guard = Arc::new(InferenceGuard::new());
    let state = Arc::new(AppState {
        guard: guard.clone(),
        model: model.clone(),
    });

    // Install custom panic hook to suppress noisy output
    let poisoned_flag = guard.poisoned.clone();
    std::panic::set_hook(Box::new(move |info| {
        poisoned_flag.store(true, Ordering::Relaxed);
        tracing::error!("PANIC in inference thread: {}", info);
    }));

    let app = create_router(state);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
    info!(
        model = %model.name,
        port = port,
        "burn-onnx-launcher server started"
    );
    info!("  → http://localhost:{}/v1/models", port);
    info!("  → http://localhost:{}/v1/chat/completions", port);

    axum::serve(listener, app).await?;

    Ok(())
}
