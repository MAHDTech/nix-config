use burn::tensor::backend::Backend;

pub mod attention;
pub mod cache;
pub mod config;
pub mod loader;
pub mod mlp;
pub mod model;
pub mod sampling;

pub use config::*;
pub use model::*;

pub fn run<B: Backend>() {
    println!("Executing Burn Gemma 4 logic...");
    println!("Gemma 4 integration is currently scaffolding under the hood.");
}
