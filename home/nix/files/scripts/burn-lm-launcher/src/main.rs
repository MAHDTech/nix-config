pub mod config;
pub mod system;
pub mod ui;
pub mod utils;

use std::collections::HashMap;
use std::io::Write;
use std::net::SocketAddr;
use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use axum::body::Bytes;
use axum::extract::State;
use axum::http::{HeaderName, Request, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use clap::Parser;
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;
use tower_http::request_id::{MakeRequestUuid, PropagateRequestIdLayer, SetRequestIdLayer};
use tower_http::trace::TraceLayer;
use tracing::Span;

// Re-use upstream types for responses and handler logic
use burn_lm_http::controllers::chat_controllers::ChatController;
use burn_lm_http::handlers::chat_handlers::REPLY_MARKER;
use burn_lm_http::handlers::model_handlers::{get_model, list_models};
use burn_lm_http::schemas::chat_schemas::{
    ChatCompletionChunkSchema, ChatCompletionSchema, ChoiceMessageRoleSchema, ChoiceMessageSchema,
    ChoiceSchema, FinishReasonSchema, StreamingChunk, UsageSchema,
};
use burn_lm_http::stores::chat_store::{ChatStore, ModelStoreState};
use burn_lm_inference::{InferenceJob, InferenceTask, StatEntry, TextGenerationListener};

use tokio::sync::{mpsc, Semaphore};
use tokio_stream::{wrappers::ReceiverStream, StreamExt};

const DEBUG_LOG_PATH: &str = "/tmp/burn-lm-debug-requests.log";

// ---------------------------------------------------------------------------
// Inference guard — serializes requests and tracks poisoned model state
// ---------------------------------------------------------------------------

/// Global inference guard shared across all request handlers.
/// - `semaphore`: permits=1 ensures only one inference runs at a time
/// - `poisoned`: set to true after an inference panic; short-circuits future requests
struct InferenceGuard {
    semaphore: Semaphore,
    poisoned: AtomicBool,
}

impl InferenceGuard {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            semaphore: Semaphore::new(1),
            poisoned: AtomicBool::new(false),
        })
    }

    fn is_poisoned(&self) -> bool {
        self.poisoned.load(Ordering::Relaxed)
    }

    fn mark_poisoned(&self) {
        self.poisoned.store(true, Ordering::Relaxed);
        tracing::error!(
            "⚠️  Inference engine is now POISONED. All future requests will be rejected. \
             Please restart the server to recover."
        );
    }
}

type InferenceGuardState = Arc<InferenceGuard>;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long)]
    model: Option<String>,

    #[arg(long)]
    cpu: bool,

    #[arg(long, default_value = "INFO")]
    log_level: String,

    #[arg(long, default_value = "DEBUG")]
    log_file_level: String,

    #[arg(short, long, default_value_t = 8080)]
    port: u16,
}

// ---------------------------------------------------------------------------
// Permissive local schemas — accept all OpenAI-compat fields gracefully
// ---------------------------------------------------------------------------

/// Message content can be a plain string or an array of content parts
/// (e.g. `[{"type": "text", "text": "..."}]` for multimodal).
#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum PermissiveContent {
    Text(String),
    Parts(Vec<serde_json::Value>),
}

impl PermissiveContent {
    /// Collapse to a single string (extract text from array parts if needed)
    fn into_string(self) -> String {
        match self {
            PermissiveContent::Text(s) => s,
            PermissiveContent::Parts(parts) => parts
                .iter()
                .filter_map(|p| p.get("text").and_then(|t| t.as_str()))
                .collect::<Vec<_>>()
                .join("\n"),
        }
    }
}

/// Permissive message schema that accepts content as string or array
#[derive(Debug, Deserialize)]
struct PermissiveMessage {
    role: ChoiceMessageRoleSchema,
    content: PermissiveContent,
    #[serde(default)]
    refusal: Option<String>,
    /// Catch-all for extra message-level fields (name, tool_call_id, etc.)
    #[serde(flatten)]
    _extra: HashMap<String, serde_json::Value>,
}

impl From<PermissiveMessage> for burn_lm_inference::Message {
    fn from(m: PermissiveMessage) -> Self {
        let role = match m.role {
            ChoiceMessageRoleSchema::System => burn_lm_inference::MessageRole::System,
            ChoiceMessageRoleSchema::User => burn_lm_inference::MessageRole::User,
            ChoiceMessageRoleSchema::Assistant => burn_lm_inference::MessageRole::Assistant,
            ChoiceMessageRoleSchema::Tool => burn_lm_inference::MessageRole::Tool,
            ChoiceMessageRoleSchema::Unknown(v) => burn_lm_inference::MessageRole::Unknown(v),
        };
        Self {
            role,
            content: m.content.into_string(),
            refusal: m.refusal,
        }
    }
}

/// Permissive request schema — accepts all OpenAI-compat fields without error.
/// Unknown fields are captured in `_extra` and inspected for unsupported features.
#[derive(Debug, Deserialize)]
struct PermissiveRequest {
    model: String,
    messages: Vec<PermissiveMessage>,
    #[serde(default)]
    stream: bool,

    // Known generation params (forwarded to inference engine)
    #[serde(default)]
    seed: Option<u64>,
    #[serde(default)]
    temperature: Option<f32>,
    #[serde(default)]
    top_p: Option<f32>,
    #[serde(default)]
    max_tokens: Option<u64>,

    // Fields we accept but explicitly don't support yet
    #[serde(default)]
    tools: Option<serde_json::Value>,
    #[serde(default, rename = "tool_choice")]
    _tool_choice: Option<serde_json::Value>,
    #[serde(default, rename = "parallel_tool_calls")]
    _parallel_tool_calls: Option<bool>,

    /// Catch-all for anything else (stop, n, response_format, etc.)
    #[serde(flatten)]
    _extra: HashMap<String, serde_json::Value>,
}

impl PermissiveRequest {
    /// Build the JSON params string that burn-lm-inference expects
    fn params_json(&self) -> String {
        let params = serde_json::json!({
            "seed": self.seed,
            "temperature": self.temperature,
            "top_p": self.top_p,
            "max_tokens": self.max_tokens,
        });
        serde_json::to_string(&params).unwrap_or_default()
    }

}

// ---------------------------------------------------------------------------
// OpenAI-compatible error response format
// ---------------------------------------------------------------------------

/// Standard OpenAI API error response body
#[derive(Debug, Serialize)]
struct OpenAIError {
    error: OpenAIErrorBody,
}

#[derive(Debug, Serialize)]
struct OpenAIErrorBody {
    message: String,
    r#type: String,
    param: Option<String>,
    code: Option<String>,
}

impl OpenAIError {
    fn new(code: &str, message: &str, param: &str) -> Self {
        Self {
            error: OpenAIErrorBody {
                message: message.to_string(),
                r#type: "invalid_request_error".to_string(),
                param: Some(param.to_string()),
                code: Some(code.to_string()),
            },
        }
    }
}

impl IntoResponse for OpenAIError {
    fn into_response(self) -> Response {
        (StatusCode::UNPROCESSABLE_ENTITY, Json(self)).into_response()
    }
}

// ---------------------------------------------------------------------------
// Custom debug handler
// ---------------------------------------------------------------------------

/// Generate a unique chat completion ID
fn new_chat_id() -> String {
    format!("chatcmpl-{}", uuid::Uuid::new_v4())
}

/// Log the raw request body to the dedicated debug log file
fn log_raw_body(body: &str) {
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(DEBUG_LOG_PATH)
    {
        let _ = writeln!(f, "--- {} ---\n{}\n", chrono::Utc::now(), body);
    }
}

/// Permissive chat completions handler.
///
/// - Accepts raw body, logs it
/// - Deserializes into the permissive schema (never rejects unknown fields)
/// - Validates feature support and returns structured OpenAI errors
/// - Proceeds with inference if valid
async fn debug_chat_completions(
    State((state, guard)): State<(ModelStoreState, InferenceGuardState)>,
    body: Bytes,
) -> Response {
    // Fast-reject if the inference engine is poisoned
    if guard.is_poisoned() {
        return OpenAIError::new(
            "service_unavailable",
            "The inference engine has crashed and is no longer operational. Please restart the server.",
            "model",
        ).into_response();
    }
    let raw = String::from_utf8_lossy(&body);

    // 1. Always log the raw body
    tracing::debug!("RAW REQUEST BODY ({} bytes):\n{}", body.len(), raw);
    log_raw_body(&raw);

    // 2. Parse into permissive schema
    let req: PermissiveRequest = match serde_json::from_slice(&body) {
        Ok(p) => p,
        Err(e) => {
            tracing::error!("JSON deserialization failed: {e}");
            return OpenAIError::new("invalid_request_error", &format!("Invalid request body: {e}"), "body")
                .into_response();
        }
    };

    // 3. Log extra fields for diagnostics
    if !req._extra.is_empty() {
        tracing::info!(
            "Extra fields from client (ignored): {:?}",
            req._extra.keys().collect::<Vec<_>>()
        );
    }

    // 4. Warn about unsupported features but proceed (graceful degradation)
    if let Some(tools) = &req.tools {
        if tools.is_array() && !tools.as_array().is_none_or(|a| a.is_empty()) {
            let tool_count = tools.as_array().map_or(0, |a| a.len());
            tracing::warn!(
                "Model '{}' does not support tool calling — stripping {} tool definition(s) from request and proceeding.",
                req.model,
                tool_count
            );
        }
    }

    tracing::debug!(
        "Request OK: model={}, stream={}, messages={}",
        req.model,
        req.stream,
        req.messages.len()
    );

    // 5. Acquire inference semaphore (serialize requests — only 1 at a time)
    let _permit = match guard.semaphore.acquire().await {
        Ok(p) => p,
        Err(_) => {
            return OpenAIError::new(
                "service_unavailable",
                "Inference semaphore closed — server is shutting down",
                "model",
            ).into_response();
        }
    };

    // 6. Delegate to handler logic
    if req.stream {
        match handle_streaming_response(state, req, guard.clone()).await {
            Ok(r) => r,
            Err(e) => e.into_response(),
        }
    } else {
        match handle_non_streaming_response(state, req, guard.clone()).await {
            Ok(r) => r,
            Err(e) => e.into_response(),
        }
    }
}

// ---------------------------------------------------------------------------
// Handler logic (using PermissiveRequest instead of upstream schema)
// ---------------------------------------------------------------------------

type HandlerResult = Result<Response, burn_lm_http::errors::ServerError>;

async fn handle_non_streaming_response(
    state: ModelStoreState,
    req: PermissiveRequest,
    guard: InferenceGuardState,
) -> HandlerResult {
    let mut store = state.lock().await;
    let (plugin, _) = store.get_plugin(&req.model).await?;
    let json_params = req.params_json();
    tracing::debug!("Json params from payload: {}", json_params);
    plugin.parse_json_config(&json_params);
    let messages: Vec<burn_lm_inference::Message> =
        req.messages.into_iter().map(Into::into).collect();
    let task = InferenceTask::Context(messages);
    let (job, handle) = InferenceJob::create(task, TextGenerationListener::default());

    // Run inference with panic protection
    let run_result = tokio::task::spawn_blocking({
        let plugin = plugin.clone();
        move || std::panic::catch_unwind(AssertUnwindSafe(|| plugin.run_job(job)))
    })
    .await;

    match run_result {
        Ok(Ok(Ok(_stats))) => {
            let content = handle.join();
            tracing::debug!("Answer: {}", content);
            let response = ChatCompletionSchema {
                id: new_chat_id(),
                object: "chat.completion".to_string(),
                created: chrono::Utc::now().timestamp(),
                model: req.model.clone(),
                choices: vec![ChoiceSchema {
                    index: 0,
                    message: ChoiceMessageSchema {
                        role: ChoiceMessageRoleSchema::Assistant,
                        content,
                        refusal: None,
                    },
                    finish_reason: FinishReasonSchema::Stop,
                    logprobs: None,
                }],
                usage: UsageSchema::default(),
                system_fingerprint: "".to_string(),
            };
            Ok(Json(response).into_response())
        }
        Ok(Ok(Err(e))) => {
            tracing::error!("Inference engine error: {:?}", e);
            Ok(OpenAIError::new(
                "inference_error",
                &format!("Model inference failed: {e}"),
                "model",
            ).into_response())
        }
        Ok(Err(panic_info)) => {
            let msg = if let Some(s) = panic_info.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = panic_info.downcast_ref::<String>() {
                s.clone()
            } else {
                "unknown panic in inference engine".to_string()
            };
            tracing::error!("Inference engine PANICKED (caught): {}", msg);
            guard.mark_poisoned();
            Ok(OpenAIError::new(
                "internal_error",
                &format!("Model inference crashed: {msg}. The server needs to be restarted."),
                "model",
            ).into_response())
        }
        Err(join_err) => {
            tracing::error!("Inference task failed to join: {}", join_err);
            Ok(OpenAIError::new(
                "internal_error",
                "Model inference task was cancelled",
                "model",
            ).into_response())
        }
    }
}

async fn handle_streaming_response(
    state: ModelStoreState,
    req: PermissiveRequest,
    guard: InferenceGuardState,
) -> HandlerResult {
    let (tx, rx) = mpsc::channel(10);
    tokio::spawn(async move {
        // Helper: send a chunk, ignoring channel-closed errors
        macro_rules! send_chunk {
            ($tx:expr, $chunk:expr) => {
                if $tx.send($chunk.to_event_stream()).await.is_err() {
                    tracing::warn!("Client disconnected, aborting stream");
                    return;
                }
            };
        }

        // Helper: send an error message as a streaming chunk, then close
        macro_rules! send_error_and_close {
            ($tx:expr, $id:expr, $model:expr, $now:expr, $msg:expr) => {{
                let err_chunk = StreamingChunk::Data(ChatCompletionChunkSchema::new(
                    $id, $model, $now,
                    &format!("\n\n❌ **Error:** {}\n", $msg),
                ));
                let _ = $tx.send(err_chunk.to_event_stream()).await;
                let _ = $tx.send(StreamingChunk::Done.to_event_stream()).await;
                return;
            }};
        }

        let mut store = state.lock().await;
        let id = new_chat_id();
        let (plugin, old_model_name) = match store.get_plugin(&req.model).await {
            Ok(v) => v,
            Err(e) => {
                tracing::error!("Failed to get model plugin: {e}");
                send_error_and_close!(tx, &id, &req.model, chrono::Utc::now().timestamp(),
                    format!("Failed to load model '{}': {e}", req.model));
            }
        };
        let json_params = req.params_json();
        let req_messages = req.messages;
        plugin.parse_json_config(&json_params);
        let now = chrono::Utc::now().timestamp();
        let model = plugin.model_name();

        // feedback if we unloaded a previously loaded model
        if let Some(name) = old_model_name {
            let chunk = StreamingChunk::Data(ChatCompletionChunkSchema::new(
                &id, model, now,
                &format!("```Burn LM\nUnloaded model '{name}'!\n```\n\n"),
            ));
            send_chunk!(tx, chunk);
        }

        // load model with real-time feedback
        if !plugin.is_loaded() {
            let chunk = StreamingChunk::Data(ChatCompletionChunkSchema::new(
                &id, model, now,
                &format!("```Burn LM\nloading model '{}'... ", plugin.model_name()),
            ));
            send_chunk!(tx, chunk);
            tracing::debug!("Loading model '{}'", plugin.model_name());

            let load_result = tokio::task::spawn_blocking({
                let plugin = plugin.clone();
                move || std::panic::catch_unwind(AssertUnwindSafe(|| plugin.load()))
            })
            .await;

            match load_result {
                Ok(Ok(Ok(loading_stats))) => {
                    tracing::debug!("Model loaded '{}'", plugin.model_name());
                    let loading_duration = match loading_stats {
                        Some(stats) => {
                            let model_duration_stat = stats
                                .entries
                                .iter()
                                .find(|e| matches!(e, StatEntry::ModelLoadingDuration(_)));
                            if let Some(stat) = model_duration_stat {
                                let duration = stat.get_duration().unwrap().as_secs_f64();
                                format!(" ({duration:.2}s)")
                            } else {
                                "".to_string()
                            }
                        }
                        _ => "".to_string(),
                    };
                    let chunk = StreamingChunk::Data(ChatCompletionChunkSchema::new(
                        &id, model, now,
                        &format!("model loaded ! ✓{loading_duration}\n```\n\n"),
                    ));
                    send_chunk!(tx, chunk);
                }
                Ok(Ok(Err(e))) => {
                    tracing::error!("Model loading failed: {:?}", e);
                    send_error_and_close!(tx, &id, model, now,
                        format!("Model '{}' failed to load: {e}", plugin.model_name()));
                }
                Ok(Err(_panic)) => {
                    tracing::error!("Model loading PANICKED for '{}'", plugin.model_name());
                    send_error_and_close!(tx, &id, model, now,
                        format!("Model '{}' crashed during loading. Try restarting the server.", plugin.model_name()));
                }
                Err(join_err) => {
                    tracing::error!("Model loading task cancelled: {}", join_err);
                    send_error_and_close!(tx, &id, model, now,
                        "Model loading was cancelled");
                }
            }
        }

        // answer chunk
        let chunk = StreamingChunk::Data(ChatCompletionChunkSchema::new(
            &id, model, now,
            &format!("\n{REPLY_MARKER}\n"),
        ));
        send_chunk!(tx, chunk);

        let mut messages: Vec<burn_lm_inference::Message> =
            req_messages.into_iter().map(Into::into).collect();
        messages
            .iter_mut()
            .for_each(|m| m.cleanup(REPLY_MARKER, burn_lm_inference::STATS_MARKER));
        tracing::debug!("Cleaned up messages: {:?}", messages);
        let task = InferenceTask::Context(messages);
        let (job, handle) = InferenceJob::create(task, TextGenerationListener::default());

        // Run inference with panic protection
        let run_result = tokio::task::spawn_blocking({
            let plugin = plugin.clone();
            move || std::panic::catch_unwind(AssertUnwindSafe(|| plugin.run_job(job)))
        })
        .await;

        match run_result {
            Ok(Ok(Ok(stats))) => {
                let content = handle.join();
                let content = format!("{}\n\n{}", content, stats.display_stats());
                tracing::debug!("Answer: {}", content);
                let chunk = StreamingChunk::Data(
                    ChatCompletionChunkSchema::new(&id, model, now, &content),
                );
                send_chunk!(tx, chunk);
            }
            Ok(Ok(Err(e))) => {
                tracing::error!("Inference failed: {:?}", e);
                send_error_and_close!(tx, &id, model, now,
                    format!("Inference failed: {e}"));
            }
            Ok(Err(_panic)) => {
                tracing::error!("Inference engine PANICKED for model '{}' — mutex may be poisoned", model);
                guard.mark_poisoned();
                send_error_and_close!(tx, &id, model, now,
                    "Inference engine crashed (PoisonError). The server needs to be restarted.");
            }
            Err(join_err) => {
                tracing::error!("Inference task cancelled: {}", join_err);
                send_error_and_close!(tx, &id, model, now,
                    "Inference was cancelled");
            }
        }

        // Done chunk
        let _ = tx.send(StreamingChunk::Done.to_event_stream()).await;
    });

    let stream = ReceiverStream::new(rx).map(Ok::<_, std::io::Error>);
    let headers = axum::http::HeaderMap::from_iter(vec![
        (
            axum::http::HeaderName::from_static("content-type"),
            axum::http::HeaderValue::from_static("text/event-stream"),
        ),
        (
            axum::http::HeaderName::from_static("cache-control"),
            axum::http::HeaderValue::from_static("no-cache"),
        ),
        (
            axum::http::HeaderName::from_static("connection"),
            axum::http::HeaderValue::from_static("keep-alive"),
        ),
    ]);

    Ok((
        StatusCode::OK,
        headers,
        axum::body::Body::from_stream(stream),
    )
        .into_response())
}

// ---------------------------------------------------------------------------
// Custom Axum application builder
// ---------------------------------------------------------------------------

fn build_debug_router(guard: InferenceGuardState) -> Router {
    let x_request_id = HeaderName::from_static("x-request-id");
    let model_store = ChatStore::create_state();

    // Chat completions uses combined (ModelStore, InferenceGuard) state
    let chat_routes = Router::new()
        .route("/chat/completions", post(debug_chat_completions))
        .with_state((model_store.clone(), guard));

    // Model list/get routes only need ModelStore state
    let model_routes = Router::new()
        .route("/models", get(list_models))
        .route("/models/{model}", get(get_model))
        .with_state(model_store);

    let api_routes = chat_routes.merge(model_routes);

    let x_req_clone_1 = x_request_id.clone();
    let x_req_clone_2 = x_request_id.clone();

    Router::new()
        .nest("/v1", api_routes)
        .layer(PropagateRequestIdLayer::new(x_request_id.clone()))
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(|request: &Request<_>| {
                    tracing::debug_span!(
                        "http_request",
                        headers = ?request.headers(),
                        version = ?request.version(),
                    )
                })
                .on_request(move |request: &Request<_>, _span: &Span| {
                    tracing::debug!(
                        request_id = ?request.headers().get(&x_req_clone_1),
                        method = %request.method(),
                        uri = %request.uri(),
                        "incoming request",
                    );
                })
                .on_response(
                    move |response: &axum::http::Response<_>, latency: Duration, _span: &Span| {
                        tracing::info!(
                            request_id = ?response.headers().get(&x_req_clone_2),
                            latency_ms = latency.as_millis(),
                            status = response.status().as_u16(),
                            "sent response",
                        );
                    },
                ),
        )
        .layer(SetRequestIdLayer::new(
            x_request_id,
            MakeRequestUuid,
        ))
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let catalog = match config::Catalog::load_from_default() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Failed to load catalog: {}", e);
            return Err(e);
        }
    };

    let (_category, model_spec) = if let Some(m) = args.model {
        let mut found = None;
        for (cat, models) in &catalog.models {
            if let Some(spec) = models.iter().find(|s| s.name == m) {
                found = Some((cat.clone(), spec.clone()));
                break;
            }
        }
        found.ok_or_else(|| format!("Model {} not found in catalog", m))?
    } else {
        ui::run_interactive_menu(catalog, args.cpu)?
            .ok_or("No model selected or cancelled.".to_string())?
    };

    utils::log::setup_tracing(&args.log_level, &args.log_file_level)?;

    log::info!("🔥 Launching Target: {} (Engine: {})", model_spec.name, model_spec.engine);

    // Hardware checks native to our launcher before loading the burn-lm instance
    let hw = system::get_hardware_budget(args.cpu);
    let context_length = model_spec.default_context_length.unwrap_or(4096);
    let eval = system::evaluate_memory_with_context(
        model_spec.required_ram_gb,
        model_spec.required_vram_gb,
        context_length,
        &hw,
    );

    match eval.status {
        system::MemoryStatus::Unsafe => {
            log::error!("❌ Insufficient {} Memory: '{}' requires at least {:.1} GB (Budget is {:.1} GB).", eval.device, model_spec.name, eval.footprint_gb, eval.budget_gb);
            log::error!("Your system cannot execute this model securely. Aborting to prevent a hard crash!");
            std::process::exit(1);
        }
        system::MemoryStatus::Tight => {
            log::warn!("🟡 Warning: '{}' requires {:.1} GB of {} Memory. It may struggle on {:.1} GB.", model_spec.name, eval.footprint_gb, eval.device, eval.budget_gb);
        }
        system::MemoryStatus::Safe => {
            log::info!("✅ System bounds verified ({:.1} GB / {:.1} GB {}). Proceeding with execution...", eval.footprint_gb, eval.budget_gb, eval.device);
        }
    }

    log::info!("Starting Endurance LLM Daemon (Powered by burn-lm)");
    log::info!("Debug request log: {}", DEBUG_LOG_PATH);
    log::info!("Listening on port: {}", args.port);

    // Install custom panic hook to suppress noisy upstream panic output
    // and route it through our tracing logger instead
    std::panic::set_hook(Box::new(|info| {
        let location = info
            .location()
            .map(|l| format!("{}:{}", l.file(), l.line()))
            .unwrap_or_else(|| "unknown".to_string());
        let message = if let Some(s) = info.payload().downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = info.payload().downcast_ref::<String>() {
            s.clone()
        } else {
            "unknown panic".to_string()
        };
        tracing::error!(location = %location, "Thread panicked: {}", message);
    }));

    let guard = InferenceGuard::new();

    let addr = SocketAddr::from(([127, 0, 0, 1], args.port));
    let listener = TcpListener::bind(addr)
        .await
        .expect("Server should bind to address successfully");

    let app = build_debug_router(guard);

    log::info!("Server started! (press CTRL+C to exit)");
    axum::serve(listener, app).await?;
    Ok(())
}
