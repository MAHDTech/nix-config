use clap::Parser;
use tokio::task;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, default_value_t = 8080)]
    port: u16,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Setup logging (optional, TUI might suppress it)
    tracing_subscriber::fmt::init();

    log::info!("Starting Ranger system on port {}...", args.port);

    // 1. Spawn API task in background
    let port = args.port;
    let _api_handle = task::spawn(async move {
        if let Err(e) = ranger_api::start_server(port).await {
            log::error!("API Server failed: {}", e);
        }
    });

    // 2. Launch TUI in foreground (main thread)
    // TUI will talk to the local API
    if let Err(e) = ranger_tui::run_tui(args.port).await {
        log::error!("TUI failed: {}", e);
    }

    Ok(())
}
