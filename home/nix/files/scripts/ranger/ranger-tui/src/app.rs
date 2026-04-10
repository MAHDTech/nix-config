use ratatui::widgets::ListState;

pub struct App {
    pub selected_model: usize,
    pub state_mod: ListState,
    pub should_quit: bool,
}

impl App {
    pub fn new() -> Self {
        let mut app = App {
            selected_model: 0,
            state_mod: ListState::default(),
            should_quit: false,
        };
        app.state_mod.select(Some(0));
        app
    }
}
