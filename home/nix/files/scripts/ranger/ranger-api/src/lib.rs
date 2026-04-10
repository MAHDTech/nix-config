pub mod routes;
pub mod queue;
pub mod types;

use std::sync::Arc;
use crate::routes::{ApiState, router};
use crate::queue::{FifoQueue, background_worker};

pub async fn start_server(port: u16) -> Result<(), Box<dyn std::error::Error>> {
    let (queue, rx) = FifoQueue::new();
    let queue = Arc::new(queue);

    // Spawn background worker
    tokio::spawn(background_worker(rx));

    let state = ApiState { queue: queue.clone() };
    let app = router(state);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
    log::info!("API Server running on http://127.0.0.1:{}", port);

    axum::serve(listener, app).await?;

    Ok(())
}
