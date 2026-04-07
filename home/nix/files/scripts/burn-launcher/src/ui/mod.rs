pub mod app;
pub mod render;

use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::io;

use crate::config::{Catalog, ModelSpec};
use app::App;
use render::ui;

pub fn run_interactive_menu(catalog: Catalog) -> Result<Option<(String, ModelSpec)>, io::Error> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new(catalog);

    loop {
        terminal.draw(|f| ui(f, &mut app))?;

        if let Event::Key(key) = event::read()? {
            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => app.should_quit = true,
                KeyCode::Down | KeyCode::Char('j') => app.handle_down(),
                KeyCode::Up | KeyCode::Char('k') => app.handle_up(),
                KeyCode::Tab => app.toggle_focus(),
                KeyCode::Left | KeyCode::Char('h') => app.focus_left(),
                KeyCode::Right | KeyCode::Char('l') => app.focus_right(),
                KeyCode::Enter => app.select(),
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
