use ratatui::widgets::ListState;
use ranger_core::system::HardwareInfo;

pub struct App {
    pub selected_model: usize,
    pub state_mod: ListState,
    pub models: Vec<String>,
    pub hardware_info: HardwareInfo,
    pub should_quit: bool,
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}

impl App {
    pub fn new() -> Self {
        let mut app = App {
            selected_model: 0,
            state_mod: ListState::default(),
            models: vec!["gemma-4-e2b".to_string()],
            hardware_info: HardwareInfo::detect(),
            should_quit: false,
        };
        app.state_mod.select(Some(0));
        app
    }

    pub fn update_memory(&mut self) {
        self.hardware_info = HardwareInfo::detect();
    }

    pub fn next_model(&mut self) {
        if self.models.is_empty() {
            return;
        }
        let i = match self.state_mod.selected() {
            Some(i) => {
                if i >= self.models.len() - 1 {
                    0
                } else {
                    i + 1
                }
            }
            None => 0,
        };
        self.state_mod.select(Some(i));
    }

    pub fn previous_model(&mut self) {
        if self.models.is_empty() {
            return;
        }
        let i = match self.state_mod.selected() {
            Some(i) => {
                if i == 0 {
                    self.models.len() - 1
                } else {
                    i - 1
                }
            }
            None => 0,
        };
        self.state_mod.select(Some(i));
    }
}
