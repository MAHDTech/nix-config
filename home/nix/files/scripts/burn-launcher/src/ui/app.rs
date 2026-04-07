use ratatui::widgets::ListState;
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
