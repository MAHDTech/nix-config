pub mod config;
pub mod models;
pub mod runner;
pub mod ui;

use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long)]
    model: Option<String>,

    #[arg(long)]
    cpu: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
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
        ui::run_interactive_menu(catalog)?
            .ok_or("No model selected or cancelled.".to_string())?
    };

    println!("\n🔥 Launching: {} (Engine: {})\n", model_spec.name, model_spec.engine);
    runner::run_engine(model_spec, args.cpu)?;

    Ok(())
}
