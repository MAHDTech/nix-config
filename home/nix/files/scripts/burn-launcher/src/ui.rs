use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Terminal,
};
use std::io;

use crate::config::{Catalog, ModelSpec};

#[derive(PartialEq, Eq)]
pub enum FocusedPane {
    Categories,
    Engines,
    Models,
}

pub struct App {
    pub catalog: Catalog,
    pub categories: Vec<String>,
    pub selected_category: usize,
    pub selected_engine: usize,
    pub selected_model: usize,
    pub state_cat: ListState,
    pub state_eng: ListState,
    pub state_mod: ListState,
    pub should_quit: bool,
    pub chosen_model: Option<(String, ModelSpec)>,
    pub focused_pane: FocusedPane,
}

impl App {
    pub fn new(catalog: Catalog) -> Self {
        let mut categories: Vec<String> = catalog.models.keys().cloned().collect();
        categories.sort(); // Predictable list

        let mut app = App {
            catalog,
            categories,
            selected_category: 0,
            selected_engine: 0,
            selected_model: 0,
            state_cat: ListState::default(),
            state_eng: ListState::default(),
            state_mod: ListState::default(),
            should_quit: false,
            chosen_model: None,
            focused_pane: FocusedPane::Categories,
        };
        app.state_cat.select(Some(0));
        app.state_eng.select(Some(0));
        app.state_mod.select(Some(0));
        app
    }

    pub fn current_engines(&self) -> Vec<String> {
        if self.categories.is_empty() { return vec![]; }
        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            let mut engines: Vec<String> = models.iter().map(|m| m.engine.clone()).collect();
            engines.sort();
            engines.dedup();
            engines
        } else {
            vec![]
        }
    }

    pub fn current_models(&self) -> Vec<&ModelSpec> {
        let engines = self.current_engines();
        if engines.is_empty() { return vec![]; }
        let target_eng = &engines[self.selected_engine.min(engines.len().saturating_sub(1))];
        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            models.iter().filter(|m| &m.engine == target_eng).collect()
        } else {
            vec![]
        }
    }

    pub fn handle_down(&mut self) {
        match self.focused_pane {
            FocusedPane::Categories => self.next_cat(),
            FocusedPane::Engines => self.next_eng(),
            FocusedPane::Models => self.next_mod(),
        }
    }

    pub fn handle_up(&mut self) {
        match self.focused_pane {
            FocusedPane::Categories => self.prev_cat(),
            FocusedPane::Engines => self.prev_eng(),
            FocusedPane::Models => self.prev_mod(),
        }
    }

    pub fn toggle_focus(&mut self) {
        self.focused_pane = match self.focused_pane {
            FocusedPane::Categories => FocusedPane::Engines,
            FocusedPane::Engines => FocusedPane::Models,
            FocusedPane::Models => FocusedPane::Categories,
        };
    }

    pub fn focus_left(&mut self) {
        self.focused_pane = match self.focused_pane {
            FocusedPane::Categories => FocusedPane::Models,
            FocusedPane::Engines => FocusedPane::Categories,
            FocusedPane::Models => FocusedPane::Engines,
        };
    }

    pub fn focus_right(&mut self) {
        self.focused_pane = match self.focused_pane {
            FocusedPane::Categories => FocusedPane::Engines,
            FocusedPane::Engines => FocusedPane::Models,
            FocusedPane::Models => FocusedPane::Categories,
        };
    }

    pub fn next_cat(&mut self) {
        if self.categories.is_empty() { return; }
        self.selected_category = (self.selected_category + 1) % self.categories.len();
        self.state_cat.select(Some(self.selected_category));
        self.selected_engine = 0;
        self.state_eng.select(Some(0));
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
        self.selected_engine = 0;
        self.state_eng.select(Some(0));
        self.selected_model = 0;
        self.state_mod.select(Some(0));
    }

    pub fn next_eng(&mut self) {
        let engines = self.current_engines();
        if engines.is_empty() { return; }
        self.selected_engine = (self.selected_engine + 1) % engines.len();
        self.state_eng.select(Some(self.selected_engine));
        self.selected_model = 0;
        self.state_mod.select(Some(0));
    }

    pub fn prev_eng(&mut self) {
        let engines = self.current_engines();
        if engines.is_empty() { return; }
        if self.selected_engine == 0 {
            self.selected_engine = engines.len() - 1;
        } else {
            self.selected_engine -= 1;
        }
        self.state_eng.select(Some(self.selected_engine));
        self.selected_model = 0;
        self.state_mod.select(Some(0));
    }

    pub fn next_mod(&mut self) {
        let models = self.current_models();
        if models.is_empty() { return; }
        self.selected_model = (self.selected_model + 1) % models.len();
        self.state_mod.select(Some(self.selected_model));
    }

    pub fn prev_mod(&mut self) {
        let models = self.current_models();
        if models.is_empty() { return; }
        if self.selected_model == 0 {
            self.selected_model = models.len() - 1;
        } else {
            self.selected_model -= 1;
        }
        self.state_mod.select(Some(self.selected_model));
    }

    pub fn select(&mut self) {
        // Implicitly move focus deeper if enter is pushed on outer columns
        match self.focused_pane {
            FocusedPane::Categories => {
                self.focused_pane = FocusedPane::Engines;
                return;
            }
            FocusedPane::Engines => {
                self.focused_pane = FocusedPane::Models;
                return;
            }
            FocusedPane::Models => {}
        }

        if self.categories.is_empty() { return; }
        let models = self.current_models();
        if let Some(&model) = models.get(self.selected_model) {
            let cat = &self.categories[self.selected_category];
            self.chosen_model = Some((cat.clone(), model.clone()));
            self.should_quit = true;
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

fn format_category(cat: &str) -> &str {
    match cat {
        "text" => "Text Generation",
        "vision" => "Vision",
        "voice" => "Voice",
        "coming_soon" => "Coming Soon",
        _ => cat,
    }
}

fn capitalize(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    }
}

fn ui(f: &mut ratatui::Frame, app: &mut App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints(
            [
                Constraint::Length(8),
                Constraint::Min(0),
                Constraint::Length(3),
            ]
            .as_ref(),
        )
        .split(f.area());

    // ASCII Art Header
    let ascii_art = vec![
        Line::from(Span::styled("████████╗ █████╗ ██████╗ ███████╗", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("╚══██╔══╝██╔══██╗██╔══██╗██╔════╝", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ██║   ███████║██████╔╝███████╗", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ██║   ██╔══██║██╔══██╗╚════██║", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ██║   ██║  ██║██║  ██║███████║", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled(">> Terminal Agentic Robotic Servant", Style::default().fg(Color::Cyan))),
    ];
    let header = Paragraph::new(ascii_art)
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::NONE));
    f.render_widget(header, chunks[0]);

    // 3-Stage Layout
    let main_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(25), // Category
            Constraint::Percentage(25), // Engine
            Constraint::Percentage(50), // Model
        ].as_ref())
        .split(chunks[1]);

    // Focus Colors
    let get_style = |is_focused: bool| -> (Color, Color, &'static str) {
        if is_focused { (Color::Green, Color::DarkGray, ">> ") } else { (Color::Reset, Color::Reset, "   ") }
    };

    let (cat_border, cat_highlight_bg, cat_symbol) = get_style(app.focused_pane == FocusedPane::Categories);
    let (eng_border, eng_highlight_bg, eng_symbol) = get_style(app.focused_pane == FocusedPane::Engines);
    let (mod_border, mod_highlight_bg, mod_symbol) = get_style(app.focused_pane == FocusedPane::Models);

    let space = Line::from(Span::raw(""));

    // 1. Categories UI
    let cat_items: Vec<ListItem> = app.categories
        .iter()
        .map(|i| {
            let text = Line::from(Span::raw(format_category(i.as_str())));
            ListItem::new(vec![space.clone(), text, space.clone()])
        })
        .collect();

    let categories_list = List::new(cat_items)
        .block(Block::default()
            .title(Line::from(" Categories ").alignment(Alignment::Center))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(cat_border)))
        .highlight_style(Style::default().bg(cat_highlight_bg).add_modifier(Modifier::BOLD))
        .highlight_symbol(cat_symbol);
    f.render_stateful_widget(categories_list, main_chunks[0], &mut app.state_cat);

    // 2. Engines UI
    let engines_len = app.current_engines().len();
    if engines_len > 0 && app.selected_engine >= engines_len {
        app.selected_engine = engines_len - 1;
        app.state_eng.select(Some(app.selected_engine));
    }

    let engines = app.current_engines();
    let eng_items: Vec<ListItem> = engines
        .iter()
        .map(|e| {
            let text = Line::from(Span::raw(capitalize(e)));
            ListItem::new(vec![space.clone(), text, space.clone()])
        })
        .collect();

    let engines_list = List::new(eng_items)
        .block(Block::default()
            .title(Line::from(" Engines ").alignment(Alignment::Center))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(eng_border)))
        .highlight_style(Style::default().bg(eng_highlight_bg).add_modifier(Modifier::BOLD))
        .highlight_symbol(eng_symbol);
    f.render_stateful_widget(engines_list, main_chunks[1], &mut app.state_eng);

    // 3. Models UI
    let models_len = app.current_models().len();
    if models_len > 0 && app.selected_model >= models_len {
        app.selected_model = models_len - 1;
        app.state_mod.select(Some(app.selected_model));
    }

    let (mod_items, active_engine) = {
        let models = app.current_models();
        let items: Vec<ListItem> = models
            .iter()
            .map(|m| {
                let desc = m.description.clone().unwrap_or("No description".to_string());
                let text = vec![
                    space.clone(),
                    Line::from(Span::styled(m.name.clone(), Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))),
                    Line::from(Span::styled(format!("  ╰─ {}", desc), Style::default().fg(Color::DarkGray))),
                    space.clone(),
                ];
                ListItem::new(text)
            })
            .collect();

        let engine = if !engines.is_empty() { capitalize(&engines[app.selected_engine]) } else { "None".to_string() };
        (items, engine)
    };

    let models_list = List::new(mod_items)
        .block(Block::default()
            .title(Line::from(format!(" Models - {} ", active_engine)).alignment(Alignment::Center))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(mod_border)))
        .highlight_style(Style::default().bg(mod_highlight_bg))
        .highlight_symbol(mod_symbol);
    f.render_stateful_widget(models_list, main_chunks[2], &mut app.state_mod);

    // Centered Footer
    let footer_text = vec![
        Span::raw("[Up/Down/j/k]"),
        Span::styled(" Navigate   ", Style::default().fg(Color::DarkGray)),
        Span::raw("[Tab/Right/Left]"),
        Span::styled(" Switch Pane   ", Style::default().fg(Color::DarkGray)),
        Span::raw("[Enter]"),
        Span::styled(" Select   ", Style::default().fg(Color::DarkGray)),
        Span::raw("[Esc/q]"),
        Span::styled(" Quit", Style::default().fg(Color::DarkGray)),
    ];
    let footer = Paragraph::new(Line::from(footer_text))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::NONE));
    f.render_widget(footer, chunks[2]);
}
