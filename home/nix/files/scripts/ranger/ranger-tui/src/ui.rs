use ratatui::{
    layout::{Constraint, Direction, Layout},
    style::{Color, Style},
    widgets::{Block, Borders, Gauge, List, ListItem},
};
use crate::app::App;

pub fn render(f: &mut ratatui::Frame, app: &mut App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([
            Constraint::Percentage(70),
            Constraint::Percentage(15),
            Constraint::Percentage(15),
        ])
        .split(f.area());

    let items: Vec<ListItem> = app.models
        .iter()
        .map(|m| ListItem::new(m.as_str()))
        .collect();

    let list = List::new(items)
        .block(Block::default().title("Available Models").borders(Borders::ALL))
        .highlight_style(Style::default().bg(Color::Blue))
        .highlight_symbol(">> ");

    f.render_stateful_widget(list, chunks[0], &mut app.state_mod);

    let ram_ratio = if app.hardware_info.total_ram_gb > 0.0 {
        app.hardware_info.used_ram_gb / app.hardware_info.total_ram_gb
    } else {
        0.0
    };
    let ram_gauge = Gauge::default()
        .block(Block::default().title("System RAM").borders(Borders::ALL))
        .gauge_style(Style::default().fg(Color::Green))
        .percent((ram_ratio * 100.0) as u16)
        .label(format!("{:.1} / {:.1} GB", app.hardware_info.used_ram_gb, app.hardware_info.total_ram_gb));

    f.render_widget(ram_gauge, chunks[1]);

    let vram_label = format!("VRAM ({}): {:.1} GB Total", app.hardware_info.gpu_vendor, app.hardware_info.total_vram_gb);
    let vram_gauge = Gauge::default()
        .block(Block::default().title(vram_label).borders(Borders::ALL))
        .gauge_style(Style::default().fg(Color::Cyan))
        .percent(0)
        .label(format!("{:.1} GB", app.hardware_info.total_vram_gb));

    f.render_widget(vram_gauge, chunks[2]);
}
