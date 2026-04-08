use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, Layer};

pub fn setup_tracing(stdout_level: &str, file_level: &str) -> std::result::Result<(), Box<dyn std::error::Error>> {
    let tmp_dir = std::env::temp_dir();
    let log_path = tmp_dir.join("burn-lm-launcher.log");

    let log_file = std::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&log_path)?;

    let file_filter = tracing_subscriber::EnvFilter::new(file_level);
    let stdout_filter = tracing_subscriber::EnvFilter::new(stdout_level);

    let file_layer = tracing_subscriber::fmt::layer()
        .with_writer(std::sync::Arc::new(log_file))
        .with_ansi(false)
        .with_filter(file_filter);

    let stdout_layer = tracing_subscriber::fmt::layer()
        .with_writer(std::io::stderr)
        .with_filter(stdout_filter);

    tracing_subscriber::registry()
        .with(file_layer)
        .with(stdout_layer)
        .init();

    Ok(())
}
