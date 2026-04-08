pub mod config;
pub mod models;
pub mod runner;
pub mod ui;
pub mod api;
pub mod system;

use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long)]
    model: Option<String>,

    #[arg(long)]
    cpu: bool,

    #[arg(long, default_value = "INFO")]
    log_level: String,
}

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

    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or(&args.log_level)).init();

    log::info!("🔥 Launching: {} (Engine: {})", model_spec.name, model_spec.engine);

    let hw = system::get_hardware_budget(args.cpu);
    let context_length = model_spec.default_context_length.unwrap_or(4096);
    let eval = system::evaluate_memory_with_context(
        model_spec.required_ram_gb,
        model_spec.required_vram_gb,
        context_length,
        &hw
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

    runner::run_engine(model_spec, args.cpu).await?;

    Ok(())
}
