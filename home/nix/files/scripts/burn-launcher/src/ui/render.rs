use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph},
};

use crate::system::{evaluate_memory, MemoryStatus};
use super::app::{App, FocusedPane};

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

pub fn ui(f: &mut ratatui::Frame, app: &mut App) {
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

                let (marker, color) = match evaluate_memory(m.required_ram_gb) {
                    MemoryStatus::Safe =>   ("✅", Color::Green),
                    MemoryStatus::Tight =>  ("🟡", Color::Yellow),
                    MemoryStatus::Unsafe => ("❌", Color::Red),
                };

                let name_span = Span::styled(
                    format!("{} {}", marker, m.name),
                    Style::default().fg(color).add_modifier(Modifier::BOLD)
                );

                let text = vec![
                    space.clone(),
                    Line::from(name_span),
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
