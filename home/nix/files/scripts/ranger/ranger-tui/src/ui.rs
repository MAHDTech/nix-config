use ratatui::{
    layout::{Constraint, Direction, Layout},
    widgets::{Block, Borders, List, ListItem},
};
use crate::app::App;

pub fn render(f: &mut ratatui::Frame, app: &mut App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([Constraint::Min(0)].as_ref())
        .split(f.area());

    let items = vec![ListItem::new("gemma-4-e2b")];
    let list = List::new(items)
        .block(Block::default().title("Models").borders(Borders::ALL));

    f.render_stateful_widget(list, chunks[0], &mut app.state_mod);
}
