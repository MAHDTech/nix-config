extern crate alloc;
mod config;
mod convert;
mod engine;
mod server;
mod system;
mod ui;

use clap::{Parser, Subcommand};
use tracing_subscriber::EnvFilter;

#[derive(Parser)]
#[command(
    name = "burn-onnx-launcher",
    about = "ONNX Model Launcher powered by Burn — Gemma 4 Prototype",
    version
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Force CPU-only mode (ignore GPU)
    #[arg(long, global = true)]
    cpu: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the OpenAI-compatible HTTP server for a specific model
    Serve {
        /// Model ID from the catalog (e.g., "gemma-4-e4b-it")
        #[arg(short, long)]
        model: Option<String>,

        /// Port to listen on
        #[arg(short, long, default_value = "3000")]
        port: u16,
    },

    /// Developer tool: download & convert an ONNX model from HuggingFace
    Convert {
        /// HuggingFace repo ID (e.g., "onnx-community/gemma-4-E4B-it-ONNX")
        repo_id: String,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    let cli = Cli::parse();

    match cli.command {
        // `burn-onnx-launcher convert <REPO_ID>`
        Some(Commands::Convert { repo_id }) => {
            convert::convert_model(&repo_id)?;
        }

        // `burn-onnx-launcher serve [--model ID] [--port PORT]`
        Some(Commands::Serve { model, port }) => {
            let catalog = config::Catalog::load_builtin()?;

            let spec = if let Some(model_id) = model {
                let (_, spec) = catalog
                    .find_by_id(&model_id)
                    .ok_or_else(|| format!("Model '{}' not found in catalog", model_id))?;
                spec.clone()
            } else {
                // If no model specified, run TUI to select one
                match ui::run_interactive_menu(catalog, cli.cpu)? {
                    Some((_, spec)) => spec,
                    None => {
                        tracing::info!("No model selected — exiting.");
                        return Ok(());
                    }
                }
            };

            tracing::info!(model = %spec.name, port = port, "Starting server");
            server::start_server(spec, port).await?;
        }

        // Default (no subcommand): run TUI → serve
        None => {
            let catalog = config::Catalog::load_builtin()?;

            match ui::run_interactive_menu(catalog, cli.cpu)? {
                Some((_, spec)) => {
                    tracing::info!(model = %spec.name, "Starting server on port 3000");
                    server::start_server(spec, 3000).await?;
                }
                None => {
                    tracing::info!("No model selected — exiting.");
                }
            }
        }
    }

    Ok(())
}
