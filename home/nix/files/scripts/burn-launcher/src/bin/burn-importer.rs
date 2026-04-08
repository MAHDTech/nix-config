use clap::Parser;
use hf_hub::api::sync::Api;
use burn_onnx::ModelGen;
use std::fs;

#[derive(Parser, Debug)]
#[command(name = "burn-importer", about = "Imports HuggingFace ONNX models into Rust code for Burn", long_about = None)]
struct Args {
    /// The Hugging Face repo ID containing the ONNX model
    #[arg(short, long)]
    repo: String,

    /// The name of the .onnx file in the repository (e.g. model.onnx)
    #[arg(short, long, default_value = "model.onnx")]
    file: String,

    /// The name of the output model struct (e.g. gemma4)
    #[arg(short, long)]
    name: String,
}

fn main() {
    let args = Args::parse();
    println!("🔥 Starting Burn Importer DevTool");
    println!("Fetching {} from HF repo: {}...", args.file, args.repo);

    let api = Api::new().expect("Could not initialize HF Hub API");
    let repo = api.model(args.repo.clone());

    let onnx_path = match repo.get(&args.file) {
        Ok(path) => path,
        Err(e) => {
            eprintln!("Failed to fetch ONNX file: {}", e);
            std::process::exit(1);
        }
    };
    println!("✅ Downloaded / Cached ONNX to: {:?}", onnx_path);

    let current_dir = std::env::current_dir().unwrap();
    let out_dir = current_dir.join("src").join("engine").join("generated");
    if !out_dir.exists() {
        fs::create_dir_all(&out_dir).expect("Failed to create out_dir");
    }

    println!("⚙️  Compiling ONNX graph to standard Rust code with burn-onnx...");

    // `burn-onnx` assumes it's running inside a `build.rs` and internally unwraps `OUT_DIR`.
    // Since we're wrapping it as an external dev-tool, we must mock the environment!
    std::env::set_var("OUT_DIR", out_dir.to_str().unwrap());

    ModelGen::new()
        .input(onnx_path.to_str().unwrap())
        .out_dir(out_dir.to_str().unwrap())
        .run_from_script();

    // The output will be named based on the onnx file basename, but we can easily rename it
    // to args.name structure!
    let generated_file = out_dir.join(format!("{}.rs", args.file.strip_suffix(".onnx").unwrap_or(&args.file)));
    let destination_file = out_dir.join(format!("{}.rs", args.name));

    if generated_file.exists() && generated_file != destination_file {
        fs::rename(&generated_file, &destination_file).expect("Failed to rename target generated file");
    }

    println!("✅ Generation complete! Look inside {:?}", out_dir.display());
    println!("You can now wire `{}_generated` into `src/engine/mod.rs`!", args.name);
}
