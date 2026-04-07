use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Terminal,
};
use std::io;

use crate::config::{Catalog, ModelSpec};

pub struct App {
    pub catalog: Catalog,
    pub categories: Vec<String>,
    pub selected_category: usize,
    pub selected_model: usize,
    pub state_cat: ListState,
    pub state_mod: ListState,
    pub should_quit: bool,
    pub chosen_model: Option<(String, ModelSpec)>,
}

impl App {
    pub fn new(catalog: Catalog) -> Self {
        let mut categories: Vec<String> = catalog.models.keys().cloned().collect();
        categories.sort(); // Predictable list

        let mut app = App {
            catalog,
            categories,
            selected_category: 0,
            selected_model: 0,
            state_cat: ListState::default(),
            state_mod: ListState::default(),
            should_quit: false,
            chosen_model: None,
        };
        app.state_cat.select(Some(0));
        app.state_mod.select(Some(0));
        app
    }

    pub fn next_cat(&mut self) {
        if self.categories.is_empty() { return; }
        self.selected_category = (self.selected_category + 1) % self.categories.len();
        self.state_cat.select(Some(self.selected_category));
        self.selected_model = 0;
        self.state_mod.select(Some(0));
    }

    pub fn prev_cat(&mut self) {
        if self.categories.is_empty() { return; }
        if self.selected_category == 0 {
            self.selected_category = self.categories.len() - 1;
        } else {
            self.selected_category -= 1;
        }
        self.state_cat.select(Some(self.selected_category));
        self.selected_model = 0;
        self.state_mod.select(Some(0));
    }

    pub fn next_mod(&mut self) {
        if self.categories.is_empty() { return; }
        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            if models.is_empty() { return; }
            self.selected_model = (self.selected_model + 1) % models.len();
            self.state_mod.select(Some(self.selected_model));
        }
    }

    pub fn prev_mod(&mut self) {
        if self.categories.is_empty() { return; }
        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            if models.is_empty() { return; }
            if self.selected_model == 0 {
                self.selected_model = models.len() - 1;
            } else {
                self.selected_model -= 1;
            }
            self.state_mod.select(Some(self.selected_model));
        }
    }

    pub fn select(&mut self) {
        if self.categories.is_empty() { return; }
        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            if let Some(model) = models.get(self.selected_model) {
                self.chosen_model = Some((cat.clone(), model.clone()));
                self.should_quit = true;
            }
        }
    }
}

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
                KeyCode::Left | KeyCode::Char('h') => app.prev_cat(),
                KeyCode::Right | KeyCode::Char('l') => app.next_cat(),
                KeyCode::Down | KeyCode::Char('j') => app.next_mod(),
                KeyCode::Up | KeyCode::Char('k') => app.prev_mod(),
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

fn ui(f: &mut ratatui::Frame, app: &mut App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints(
            [
                Constraint::Length(3),
                Constraint::Min(0),
                Constraint::Length(3),
            ]
            .as_ref(),
        )
        .split(f.area());

    let header = Paragraph::new(Line::from(vec![
        Span::styled("🔥 Burn Launcher", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        Span::raw(" | Universal Local AI Launcher"),
    ]))
    .block(Block::default().borders(Borders::ALL));
    f.render_widget(header, chunks[0]);

    let main_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(30), Constraint::Percentage(70)].as_ref())
        .split(chunks[1]);

    // Categories
    let items: Vec<ListItem> = app.categories
        .iter()
        .map(|i| ListItem::new(i.as_str()))
        .collect();
    let categories_list = List::new(items)
        .block(Block::default().title("Categories").borders(Borders::ALL))
        .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
        .highlight_symbol(">> ");
    f.render_stateful_widget(categories_list, main_chunks[0], &mut app.state_cat);

    // Models
    if !app.categories.is_empty() {
        let cat = &app.categories[app.selected_category];
        if let Some(models) = app.catalog.models.get(cat) {
            let items: Vec<ListItem> = models
                .iter()
                .map(|m| {
                    let desc = m.description.as_deref().unwrap_or("No description");
                    let text = vec![
                        Line::from(Span::styled(&m.name, Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))),
                        Line::from(Span::styled(format!("  ╰─ {}", desc), Style::default().fg(Color::DarkGray))),
                    ];
                    ListItem::new(text)
                })
                .collect();
            let models_list = List::new(items)
                .block(Block::default().title(format!("Models - {}", cat)).borders(Borders::ALL))
                .highlight_style(Style::default().bg(Color::DarkGray))
                .highlight_symbol(">> ");
            f.render_stateful_widget(models_list, main_chunks[1], &mut app.state_mod);
        }
    }

    let footer_text = vec![
        Span::raw("Navigate: "),
        Span::styled("Arrows/hjkl", Style::default().fg(Color::Cyan)),
        Span::raw(" | Select: "),
        Span::styled("Enter", Style::default().fg(Color::Cyan)),
        Span::raw(" | Quit: "),
        Span::styled("q or Esc", Style::default().fg(Color::Cyan)),
    ];
    let footer = Paragraph::new(Line::from(footer_text))
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(footer, chunks[2]);
}
