use ratatui::widgets::ListState;
use crate::config::{Catalog, ModelSpec};
use crate::system::HardwareBudget;

#[derive(PartialEq, Eq)]
pub enum FocusedPane {
    Categories,
    Vendors,
    Collections,
    Models,
}

pub struct App {
    pub hw: HardwareBudget,
    pub catalog: Catalog,
    pub categories: Vec<String>,
    pub selected_category: usize,
    pub selected_vendor: usize,
    pub selected_collection: usize,
    pub selected_model: usize,
    pub state_cat: ListState,
    pub state_vendor: ListState,
    pub state_coll: ListState,
    pub state_mod: ListState,
    pub should_quit: bool,
    pub chosen_model: Option<(String, ModelSpec)>,
    pub focused_pane: FocusedPane,
    pub context_length: usize,
}

impl App {
    pub fn new(catalog: Catalog, cpu: bool) -> Self {
        let mut categories: Vec<String> = catalog.models.keys().cloned().collect();
        categories.sort();
        let hw = crate::system::get_hardware_budget(cpu);

        let mut app = App {
            hw,
            catalog,
            categories,
            selected_category: 0,
            selected_vendor: 0,
            selected_collection: 0,
            selected_model: 0,
            state_cat: ListState::default(),
            state_vendor: ListState::default(),
            state_coll: ListState::default(),
            state_mod: ListState::default(),
            should_quit: false,
            chosen_model: None,
            focused_pane: FocusedPane::Categories,
            context_length: 4096,
        };
        app.state_cat.select(Some(0));
        app.state_vendor.select(Some(0));
        app.state_coll.select(Some(0));
        app.state_mod.select(Some(0));
        app
    }

    /// Get unique vendors within the selected category.
    pub fn current_vendors(&self) -> Vec<String> {
        if self.categories.is_empty() { return vec![]; }
        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            let mut vendors: Vec<String> = models.iter().map(|m| m.vendor.clone()).collect();
            vendors.sort();
            vendors.dedup();
            vendors
        } else {
            vec![]
        }
    }

    /// Get unique collections within the selected category + vendor.
    pub fn current_collections(&self) -> Vec<String> {
        let vendors = self.current_vendors();
        if vendors.is_empty() { return vec![]; }
        let target_vendor = &vendors[self.selected_vendor.min(vendors.len().saturating_sub(1))];
        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            let mut collections: Vec<String> = models.iter()
                .filter(|m| &m.vendor == target_vendor)
                .map(|m| m.collection.clone())
                .collect();
            collections.sort();
            collections.dedup();
            collections
        } else {
            vec![]
        }
    }

    /// Get models matching the selected category + vendor + collection.
    pub fn current_models(&self) -> Vec<&ModelSpec> {
        let vendors = self.current_vendors();
        if vendors.is_empty() { return vec![]; }
        let target_vendor = &vendors[self.selected_vendor.min(vendors.len().saturating_sub(1))];

        let collections = self.current_collections();
        if collections.is_empty() { return vec![]; }
        let target_coll = &collections[self.selected_collection.min(collections.len().saturating_sub(1))];

        let cat = &self.categories[self.selected_category];
        if let Some(models) = self.catalog.models.get(cat) {
            models.iter()
                .filter(|m| &m.vendor == target_vendor && &m.collection == target_coll)
                .collect()
        } else {
            vec![]
        }
    }

    pub fn handle_down(&mut self) {
        match self.focused_pane {
            FocusedPane::Categories => self.next_cat(),
            FocusedPane::Vendors => self.next_vendor(),
            FocusedPane::Collections => self.next_coll(),
            FocusedPane::Models => self.next_mod(),
        }
    }

    pub fn handle_up(&mut self) {
        match self.focused_pane {
            FocusedPane::Categories => self.prev_cat(),
            FocusedPane::Vendors => self.prev_vendor(),
            FocusedPane::Collections => self.prev_coll(),
            FocusedPane::Models => self.prev_mod(),
        }
    }

    pub fn go_back(&mut self) {
        self.focused_pane = match self.focused_pane {
            FocusedPane::Categories => {
                self.should_quit = true;
                FocusedPane::Categories
            }
            FocusedPane::Vendors => FocusedPane::Categories,
            FocusedPane::Collections => FocusedPane::Vendors,
            FocusedPane::Models => FocusedPane::Collections,
        };
    }

    pub fn select(&mut self) {
        match self.focused_pane {
            FocusedPane::Categories => {
                self.focused_pane = FocusedPane::Vendors;
                return;
            }
            FocusedPane::Vendors => {
                self.focused_pane = FocusedPane::Collections;
                return;
            }
            FocusedPane::Collections => {
                self.focused_pane = FocusedPane::Models;
                return;
            }
            FocusedPane::Models => {}
        }

        if self.categories.is_empty() { return; }
        let models = self.current_models();
        if let Some(&model) = models.get(self.selected_model) {
            let cat = &self.categories[self.selected_category];
            let mut spec = model.clone();
            spec.context_length = Some(self.context_length);
            self.chosen_model = Some((cat.clone(), spec));
            self.should_quit = true;
        }
    }

    pub fn increase_context(&mut self) {
        if self.context_length < 131072 {
            self.context_length *= 2;
        }
    }

    pub fn decrease_context(&mut self) {
        if self.context_length > 1024 {
            self.context_length /= 2;
        }
    }

    // --- Navigation helpers ---

    fn next_cat(&mut self) {
        if self.categories.is_empty() { return; }
        self.selected_category = (self.selected_category + 1) % self.categories.len();
        self.state_cat.select(Some(self.selected_category));
        self.reset_vendor();
    }

    fn prev_cat(&mut self) {
        if self.categories.is_empty() { return; }
        if self.selected_category == 0 {
            self.selected_category = self.categories.len() - 1;
        } else {
            self.selected_category -= 1;
        }
        self.state_cat.select(Some(self.selected_category));
        self.reset_vendor();
    }

    fn next_vendor(&mut self) {
        let vendors = self.current_vendors();
        if vendors.is_empty() { return; }
        self.selected_vendor = (self.selected_vendor + 1) % vendors.len();
        self.state_vendor.select(Some(self.selected_vendor));
        self.reset_collection();
    }

    fn prev_vendor(&mut self) {
        let vendors = self.current_vendors();
        if vendors.is_empty() { return; }
        if self.selected_vendor == 0 {
            self.selected_vendor = vendors.len() - 1;
        } else {
            self.selected_vendor -= 1;
        }
        self.state_vendor.select(Some(self.selected_vendor));
        self.reset_collection();
    }

    fn next_coll(&mut self) {
        let collections = self.current_collections();
        if collections.is_empty() { return; }
        self.selected_collection = (self.selected_collection + 1) % collections.len();
        self.state_coll.select(Some(self.selected_collection));
        self.reset_model();
    }

    fn prev_coll(&mut self) {
        let collections = self.current_collections();
        if collections.is_empty() { return; }
        if self.selected_collection == 0 {
            self.selected_collection = collections.len() - 1;
        } else {
            self.selected_collection -= 1;
        }
        self.state_coll.select(Some(self.selected_collection));
        self.reset_model();
    }

    fn next_mod(&mut self) {
        let models = self.current_models();
        if models.is_empty() { return; }
        self.selected_model = (self.selected_model + 1) % models.len();
        self.state_mod.select(Some(self.selected_model));
    }

    fn prev_mod(&mut self) {
        let models = self.current_models();
        if models.is_empty() { return; }
        if self.selected_model == 0 {
            self.selected_model = models.len() - 1;
        } else {
            self.selected_model -= 1;
        }
        self.state_mod.select(Some(self.selected_model));
    }

    fn reset_vendor(&mut self) {
        self.selected_vendor = 0;
        self.state_vendor.select(Some(0));
        self.reset_collection();
    }

    fn reset_collection(&mut self) {
        self.selected_collection = 0;
        self.state_coll.select(Some(0));
        self.reset_model();
    }

    fn reset_model(&mut self) {
        self.selected_model = 0;
        self.state_mod.select(Some(0));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn get_test_catalog() -> Catalog {
        let mut models = HashMap::new();
        models.insert("text".to_string(), vec![
            ModelSpec {
                id: "gemma-4-e4b-it".to_string(),
                name: "Gemma 4 E4B Instruct".to_string(),
                vendor: "Google".to_string(),
                collection: "Gemma 4".to_string(),
                engine: "gemma4".to_string(),
                repo_id: "onnx-community/gemma-4-E4B-it-ONNX".to_string(),
                onnx_file: "model.onnx".to_string(),
                required_ram_gb: Some(5.0),
                required_vram_gb: None,
                context_length: Some(128000),
            },
        ]);
        Catalog { models }
    }

    #[test]
    fn test_focus_drill_down() {
        let mut app = App::new(get_test_catalog(), true);
        assert!(app.focused_pane == FocusedPane::Categories);
        app.select();
        assert!(app.focused_pane == FocusedPane::Vendors);
        app.select();
        assert!(app.focused_pane == FocusedPane::Collections);
        app.select();
        assert!(app.focused_pane == FocusedPane::Models);
        app.go_back();
        assert!(app.focused_pane == FocusedPane::Collections);
    }

    #[test]
    fn test_context_scaling() {
        let mut app = App::new(get_test_catalog(), true);
        assert_eq!(app.context_length, 4096);
        app.increase_context();
        assert_eq!(app.context_length, 8192);
        app.decrease_context();
        assert_eq!(app.context_length, 4096);
    }
}
