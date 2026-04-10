#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    ranger_tui::run_tui(8080).await?;
    Ok(())
}
