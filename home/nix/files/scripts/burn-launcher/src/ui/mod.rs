pub mod app;
pub mod render;

use crossterm::{
    event::{self, DisableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::io;

use crate::config::{Catalog, ModelSpec};
use render::ui;

pub fn run_interactive_menu(catalog: Catalog, cpu: bool) -> Result<Option<(String, ModelSpec)>, Box<dyn std::error::Error>> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app
    let mut app = app::App::new(catalog, cpu);

    loop {
        terminal.draw(|f| ui(f, &mut app))?;

        if let Event::Key(key) = event::read()? {
            match key.code {
                KeyCode::Char('q') => app.should_quit = true,
                KeyCode::Esc | KeyCode::Left | KeyCode::Char('h') => app.go_back(),
                KeyCode::Down | KeyCode::Char('j') => app.handle_down(),
                KeyCode::Up | KeyCode::Char('k') => app.handle_up(),
                KeyCode::Tab | KeyCode::Right | KeyCode::Char('l') | KeyCode::Enter => app.select(),
                KeyCode::Char('+') | KeyCode::Char('=') | KeyCode::Char(']') => app.increase_context(),
                KeyCode::Char('-') | KeyCode::Char('_') | KeyCode::Char('[') => app.decrease_context(),
                _ => {}
            }
        }

        if app.should_quit {
            break;
        }
    }

    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    Ok(app.chosen_model)
}
