pub mod app;
pub mod ui;
pub mod client;

use std::io;
use std::time::{Duration, Instant};
use ratatui::{
    backend::CrosstermBackend,
    Terminal,
};
use crossterm::{
    event::{self, DisableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};

use crate::app::App;
use crate::client::Client;
use crate::ui::render;

pub async fn run_tui(port: u16) -> Result<(), Box<dyn std::error::Error>> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();
    let client = Client::new(format!("http://127.0.0.1:{}", port));

    let tick_rate = Duration::from_millis(250);
    let mut last_tick = Instant::now();

    loop {
        terminal.draw(|f| render(f, &mut app))?;

        let timeout = tick_rate
            .checked_sub(last_tick.elapsed())
            .unwrap_or_else(|| Duration::from_secs(0));

        if crossterm::event::poll(timeout)? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') => app.should_quit = true,
                    KeyCode::Down | KeyCode::Char('j') => app.next_model(),
                    KeyCode::Up | KeyCode::Char('k') => app.previous_model(),
                    _ => {}
                }
            }
        }

        if last_tick.elapsed() >= tick_rate {
            app.update_memory();

            // Periodically refresh models from API
            if let Ok(models) = client.list_models().await {
                if models != app.models {
                    app.models = models;
                }
            }

            last_tick = Instant::now();
        }

        if app.should_quit {
            break;
        }
    }

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    Ok(())
}
