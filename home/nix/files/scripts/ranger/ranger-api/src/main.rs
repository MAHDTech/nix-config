use std::process;
use tracing_subscriber::fmt;

#[tokio::main]
async fn main() {
    // Initialize tracing
    fmt::init();

    // The start_server function in lib.rs handles initializing the queue,
    // spawning the background worker, and setting up the routes.
    let port = 3000;
    if let Err(e) = ranger_api::start_server(port).await {
        eprintln!("API Error: {}", e);
        process::exit(1);
    }
}
