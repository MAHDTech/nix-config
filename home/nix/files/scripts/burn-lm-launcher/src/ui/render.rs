use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph},
};

use crate::system::{evaluate_memory_with_context, MemoryStatus};
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
    // 0. Boundary Verification
    let vendors_len = app.current_vendors().len();
    if vendors_len > 0 && app.selected_vendor >= vendors_len {
        app.selected_vendor = vendors_len - 1;
        app.state_vendor.select(Some(app.selected_vendor));
    }
    let engines_len = app.current_engines().len();
    if engines_len > 0 && app.selected_engine >= engines_len {
        app.selected_engine = engines_len - 1;
        app.state_eng.select(Some(app.selected_engine));
    }
    let models_len = app.current_models().len();
    if models_len > 0 && app.selected_model >= models_len {
        app.selected_model = models_len - 1;
        app.state_mod.select(Some(app.selected_model));
    }

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints(
            [
                Constraint::Length(8),
                Constraint::Length(2), // Memory Bar
                Constraint::Min(0),
                Constraint::Length(3), // Footer
            ]
            .as_ref(),
        )
        .split(f.area());

    // 1. ASCII Art Header
    let ascii_art = vec![
        Line::from(Span::styled("████████╗ █████╗ ██████╗ ███████╗", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("╚══██╔══╝██╔══██╗██╔══██╗██╔════╝", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ██║   ███████║██████╔╝███████╗", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ██║   ██╔══██║██╔══██╗╚════██║", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ██║   ██║  ██║██║  ██║███████║", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled(">> Task Automation and Resolution System", Style::default().fg(Color::Cyan))),
    ];
    let header = Paragraph::new(ascii_art)
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::NONE));
    f.render_widget(header, chunks[0]);

    // 2. Memory Bar
    let models = app.current_models();
    let memory_eval = if app.focused_pane != FocusedPane::Models || models.is_empty() {
        None
    } else {
        let m = models[app.selected_model.min(models.len().saturating_sub(1))];
        Some(evaluate_memory_with_context(m.required_ram_gb, m.required_vram_gb, app.context_length, &app.hw))
    };

    if let Some(eval) = memory_eval {
        let ratio = (eval.footprint_gb / eval.budget_gb.max(0.1)).clamp(0.0, 1.0);
        let color = match eval.status {
            MemoryStatus::Safe => Color::Green,
            MemoryStatus::Tight => Color::Yellow,
            MemoryStatus::Unsafe => Color::Red,
        };
        let label = format!("{} Mem: {:.1} GB / {:.1} GB", eval.device, eval.footprint_gb, eval.budget_gb);
        let gauge = ratatui::widgets::Gauge::default()
            .block(Block::default().borders(Borders::NONE))
            .gauge_style(Style::default().fg(color).bg(Color::DarkGray))
            .ratio(ratio)
            .label(Span::styled(label, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)));
        f.render_widget(gauge, chunks[1]);
    } else {
        f.render_widget(Block::default().borders(Borders::NONE), chunks[1]);
    }

    // 3. Drill-down Menu (4-level: Category → Vendor → Engine → Model)
    let list_chunk = chunks[2];
    let space = Line::from(Span::raw(""));

    match app.focused_pane {
        FocusedPane::Categories => {
            let items: Vec<ListItem> = app.categories
                .iter()
                .map(|i| {
                    let text = Line::from(Span::raw(format_category(i.as_str()))).alignment(Alignment::Center);
                    ListItem::new(vec![space.clone(), text, space.clone()])
                })
                .collect();
            let list = List::new(items)
                .block(Block::default()
                    .title(Line::from(" Choose a Category ").alignment(Alignment::Center))
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(Color::Green)))
                .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
                .highlight_symbol(">> ");
            f.render_stateful_widget(list, list_chunk, &mut app.state_cat);
        }
        FocusedPane::Vendors => {
            let vendors = app.current_vendors();
            let items: Vec<ListItem> = vendors
                .iter()
                .map(|v| {
                    let text = Line::from(Span::raw(v.as_str())).alignment(Alignment::Center);
                    ListItem::new(vec![space.clone(), text, space.clone()])
                })
                .collect();
            let parent_cat = format_category(&app.categories[app.selected_category]);
            let list = List::new(items)
                .block(Block::default()
                    .title(Line::from(format!(" Choose a Vendor in '{}' ", parent_cat)).alignment(Alignment::Center))
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(Color::Green)))
                .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
                .highlight_symbol(">> ");
            f.render_stateful_widget(list, list_chunk, &mut app.state_vendor);
        }
        FocusedPane::Engines => {
            let engines = app.current_engines();
            let items: Vec<ListItem> = engines
                .iter()
                .map(|e| {
                    let text = Line::from(Span::raw(capitalize(e))).alignment(Alignment::Center);
                    ListItem::new(vec![space.clone(), text, space.clone()])
                })
                .collect();
            let vendors = app.current_vendors();
            let parent_vendor = if !vendors.is_empty() {
                vendors[app.selected_vendor.min(vendors.len().saturating_sub(1))].clone()
            } else {
                "None".to_string()
            };
            let list = List::new(items)
                .block(Block::default()
                    .title(Line::from(format!(" Choose an Engine from '{}' ", parent_vendor)).alignment(Alignment::Center))
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(Color::Green)))
                .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
                .highlight_symbol(">> ");
            f.render_stateful_widget(list, list_chunk, &mut app.state_eng);
        }
        FocusedPane::Models => {
             let engines = app.current_engines();
             let engine = if !engines.is_empty() { capitalize(&engines[app.selected_engine]) } else { "None".to_string() };

             let items: Vec<ListItem> = models
                 .iter()
                 .map(|m| {
                     let desc = m.description.clone().unwrap_or("No description".to_string());
                     let eval = evaluate_memory_with_context(m.required_ram_gb, m.required_vram_gb, app.context_length, &app.hw);
                     let (marker, color) = match eval.status {
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
                         Line::from(name_span).alignment(Alignment::Center),
                         Line::from(Span::styled(format!("  ╰─ {}", desc), Style::default().fg(Color::DarkGray))).alignment(Alignment::Center),
                         space.clone(),
                     ];
                     ListItem::new(text)
                 })
                 .collect();

             let list = List::new(items)
                 .block(Block::default()
                     .title(Line::from(format!(" Models for {} ", engine)).alignment(Alignment::Center))
                     .borders(Borders::ALL)
                     .border_style(Style::default().fg(Color::Green)))
                 .highlight_style(Style::default().bg(Color::DarkGray))
                 .highlight_symbol(">> ");
             f.render_stateful_widget(list, list_chunk, &mut app.state_mod);
        }
    }

    // 4. Centered Footer
    let footer_text = vec![
        Span::styled(format!("Context Size [{}] ", app.context_length), Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
        Span::raw("[+/-]"),
        Span::styled(" Adjust Context   ", Style::default().fg(Color::DarkGray)),
        Span::raw("[Up/Down/j/k]"),
        Span::styled(" Navigate   ", Style::default().fg(Color::DarkGray)),
        Span::raw("[Enter/Right]"),
        Span::styled(" Next   ", Style::default().fg(Color::DarkGray)),
        Span::raw("[Esc/Left]"),
        Span::styled(" Back/Quit", Style::default().fg(Color::DarkGray)),
    ];
    let footer = Paragraph::new(Line::from(footer_text))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::NONE));
    f.render_widget(footer, chunks[3]);
}
