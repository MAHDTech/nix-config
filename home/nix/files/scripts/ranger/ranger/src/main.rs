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

    log::info!("Starting Ranger system...");

    // Spawn API task
    let api_task = task::spawn(async move {
        if let Err(e) = ranger_api::start_server(args.port).await {
            log::error!("API Server failed: {}", e);
        }
    });

    // Dummy TUI task
    log::info!("TUI started (simulated)");

    let _ = tokio::join!(api_task);

    Ok(())
}
